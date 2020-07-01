module Geordi
  class Settings
    require 'yaml'

    require File.expand_path('util', __dir__)

    GLOBAL_SETTINGS_FILE_NAME = Util.testing? ? './tmp/global_settings.yml'.freeze : File.join(ENV['HOME'], '.config/geordi/global.yml').freeze
    LOCAL_SETTINGS_FILE_NAME = Util.testing? ? './tmp/local_settings.yml'.freeze : './.geordi.yml'.freeze

    GITPT_FILE_NAME = '.gitpt'.freeze
    PROJECT_IDS_FILE_NAME = '.pt_project_id'.freeze

    ALLOWED_GLOBAL_SETTINGS = %w[ pivotal_tracker_api_key ].freeze
    ALLOWED_LOCAL_SETTINGS = %w[ use_vnc pivotal_tracker_project_ids ].freeze

    def initialize
      read_settings
    end

    # Global settings
    def pivotal_tracker_api_key
      @global_settings['pivotal_tracker_api_key'] || gitpt_api_key_old || inquire_pt_api_key
    end

    def pivotal_tracker_api_key=(value)
      @global_settings['pivotal_tracker_api_key'] = value
      save_global_settings
    end

    # Local settings
    # They should not be changed by geordi to avoid unexpected diffs, therefore
    # there are no setters for these settings
    def use_vnc?
      @local_settings.fetch('use_vnc', true)
    end

    def pivotal_tracker_project_ids
      project_ids = @local_settings['pivotal_tracker_project_ids'] || pt_project_ids_old

      case project_ids
      when Array
        return project_ids if project_ids.size > 0
      when String
        return project_ids.split(/[\s]+/).map(&:to_i)
      when Integer
        return [project_ids]
      end

      puts
      Geordi::Interaction.warn "Sorry, I could not find a project ID in .geordi.yml :("
      puts

      puts "Please put at least one Pivotal Tracker project id into the .geordi.yml file in this directory, e.g."
      puts
      puts "pivotal_tracker_project_ids:"
      puts "- 123456"
      puts
      puts 'You may add multiple IDs.'
      exit 1
    end

    private

    def read_settings
      global_path = GLOBAL_SETTINGS_FILE_NAME
      local_path = LOCAL_SETTINGS_FILE_NAME

      if File.exists?(global_path)
        global_settings = YAML.safe_load(File.read(global_path))
        check_for_invalid_keys(global_settings, ALLOWED_GLOBAL_SETTINGS, global_path)
      end

      if File.exists?(local_path)
        local_settings = YAML.safe_load(File.read(local_path))
        check_for_invalid_keys(local_settings, ALLOWED_LOCAL_SETTINGS, local_path)
      end

      @global_settings = global_settings || {}
      @local_settings = local_settings || {}
    end

    def check_for_invalid_keys(settings, allowed_keys, file)
      invalid_keys = settings.keys - allowed_keys
      unless invalid_keys.empty?
        Geordi::Interaction.warn "Geordi detected unknown keys in #{file}.\n"

        invalid_keys.sort.each do |key|
          puts "* #{key}"
        end

        puts "\nAllowed keys are:"
        allowed_keys.sort.each do |key|
          puts "* #{key}"
        end
        puts

        exit 1
      end
    end

    def save_global_settings
      global_path = GLOBAL_SETTINGS_FILE_NAME
      global_directory = File.dirname(global_path)
      FileUtils.mkdir_p(global_directory) unless File.directory? global_directory
      File.open(global_path, 'w') do |file|
        file.write @global_settings.to_yaml
      end
    end

    # deprecated
    def gitpt_api_key_old
      file_path = File.join(ENV['HOME'], GITPT_FILE_NAME)
      if File.exist?(file_path)
        token = YAML.load_file(file_path).fetch :token
        highline.say HighLine::RESET
        highline.say highlight("The ~/.gitpt file is deprecated.\n")
        highline.say "The contained setting will be moved to #{bold '~/.config/geordi/global.yml'}."
        highline.say "If you don't need to work with an older version of geordi you can delete #{bold '~/.gitpt'} now."
        self.pivotal_tracker_api_key = token

        token
      end
    end

    def inquire_pt_api_key
      highline.say HighLine::RESET
      highline.say "Welcome to #{bold 'gitpt'}.\n\n"

      highline.say highlight('Your settings are missing or invalid.')
      highline.say "Please configure your Pivotal Tracker access.\n\n"
      token = highline.ask bold('Your API key:') + ' '
      self.pivotal_tracker_api_key = token
      highline.say "\n"

      token
    end

    def pt_project_ids_old
      file_path = PROJECT_IDS_FILE_NAME
      if File.exist?(file_path)
        project_ids = File.read('.pt_project_id')
        Geordi::Interaction.warn "The usage of the .pt_project_id file is deprecated."
        Geordi::Interaction.note Util.strip_heredoc(<<-INSTRUCTIONS)
          Please remove this file from your project and add or extend the .geordi.yml file with the following content:
            pivotal_tracker_project_ids: #{project_ids}
        INSTRUCTIONS

        project_ids
      end
    end

  end
end
