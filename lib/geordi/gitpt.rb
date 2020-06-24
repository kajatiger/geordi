class Gitpt
  require 'yaml'
  require 'highline'
  require 'tracker_api'
  require 'geordi/settings'

  SETTINGS_FILE_NAME = '.gitpt'.freeze
  PROJECT_IDS_FILE_NAME = '.pt_project_id'.freeze

  def initialize
    self.highline = HighLine.new
    self.settings = GeordiSettings.new
    self.client = build_client(read_settings)
  end

  def run(git_args)
    Geordi::Interaction.warn <<-WARNING unless Geordi::Util.staged_changes?
No staged changes. Will create an empty commit.
    WARNING

    story = choose_story
    if story
      create_commit "[##{story.id}] #{story.name}", *git_args
    end
  end

  private

  attr_accessor :highline, :client, :settings

  def read_settings
    unless settings.pivotal_tracker_api_key
      # check for (deprecated) .gitpt file
      file_path = File.join(ENV['HOME'], SETTINGS_FILE_NAME)
      if File.exist?(file_path)
        token = YAML.load_file(file_path).fetch :token
        highline.say HighLine::RESET
        highline.say highlight("The ~/.gitpt file is deprecated.\n")
        highline.say "The contained setting will be moved to #{bold '~/.config/geordi/global.yml'}."
        highline.say "If you don't need to work with an older version of geordi you can delete #{bold '~/.gitpt'} now."
      else
        highline.say HighLine::RESET
        highline.say "Welcome to #{bold 'gitpt'}.\n\n"

        highline.say highlight('Your settings are missing or invalid.')
        highline.say "Please configure your Pivotal Tracker access.\n\n"
        token = highline.ask bold('Your API key:') + ' '
        highline.say "\n"
      end

      settings.pivotal_tracker_api_key = token
    end

    { token: settings.pivotal_tracker_api_key }
  end

  def build_client(settings)
    TrackerApi::Client.new(token: settings.fetch(:token))
  end

  def load_projects
    project_ids = read_project_ids
    project_ids.collect { |project_id| client.project(project_id) }
  end

  def read_project_ids
    project_ids = settings.pivotal_tracker_project_id

    file_path = PROJECT_IDS_FILE_NAME
    if !project_ids and File.exist?(file_path)
      project_ids = File.read('.pt_project_id')
      Geordi::Interaction.warn "The usage of the .pt_project_id file is deprecated."
      Geordi::Interaction.note Util.strip_heredoc(<<-INSTRUCTIONS)
          Please remove this file from your project and add or extend the .geordi.yml file with the following content:
            pivotal_tracker_project_id: #{project_ids}
      INSTRUCTIONS
    end

    if project_ids && (project_ids.to_s.length > 0)
      project_ids.to_s.split(/[\s]+/).map(&:to_i)
    else
      Geordi::Interaction.warn "Sorry, I could not find a project ID in .geordi.yml :("
      puts

      puts "Please put at least one Pivotal Tracker project id into the .geordi.yml file in this directory, e.g:\n"
      puts "pivotal_tracker_project_id: 123456\n"
      puts 'You may add multiple IDs, separated using white space.'
      exit 1
    end
  end

  def applicable_stories
    projects = load_projects
    projects.collect do |project|
      project.stories(filter: 'state:started,finished,rejected')
    end.flatten
  end

  def choose_story
    if Geordi::Util.testing?
      return OpenStruct.new(id: 12, name: 'Test Story')
    end

    loading_message = 'Connecting to Pivotal Tracker ...'
    print(loading_message)
    stories = applicable_stories
    reset_loading_message = "\r#{' ' * (loading_message.length + stories.length)}\r"

    highline.choose do |menu|
      menu.header = 'Choose a story'

      stories.each do |story|
        print '.' # Progress

        state = story.current_state
        owners = story.owners
        owner_is_me = owners.collect(&:id).include?(client.me.id)

        if state == 'started'
          state = HighLine::GREEN + state + HighLine::RESET
        elsif state != 'finished'
          state = HighLine::RED + state + HighLine::RESET
        end

        state += HighLine::BOLD if owner_is_me

        label = "(#{owners.collect(&:name).join(', ')}, #{state}) #{story.name}"
        label = bold(label) if owner_is_me

        menu.choice(label) { return story }
      end

      menu.hidden ''
      print reset_loading_message # Once menu is build
    end

    nil # Return nothing
  end

  def create_commit(message, *git_args)
    extra = highline.ask("\nAdd an optional message").strip
    message << ' - ' << extra if extra != ''

    Geordi::Util.system! 'git', 'commit', '--allow-empty', '-m', message, *git_args
  end

  def bold(string)
    HighLine::BOLD + string + HighLine::RESET
  end

  def highlight(string)
    bold HighLine::BLUE + string
  end

end
