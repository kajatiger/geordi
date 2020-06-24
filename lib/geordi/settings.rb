class GeordiSettings
  require 'yaml'

  GLOBAL_SETTINGS_FILE_NAME = '.config/geordi/global.yml'.freeze
  LOCAL_SETTINGS_FILE_NAME = '.geordi.yml'.freeze

  ALLOWED_GLOBAL_SETTINGS = %w[ pivotal_tracker_api_key ].freeze
  ALLOWED_LOCAL_SETTINGS = %w[ headless_browser pivotal_tracker_project_id ].freeze

  def initialize
    read_settings
  end

  # Global settings
  def pivotal_tracker_api_key
    @global_settings['pivotal_tracker_api_key']
  end

  def pivotal_tracker_api_key=(value)
    @global_settings['pivotal_tracker_api_key'] = value
    save_global_settings
  end

  # Local settings
  # They should not be changed by geordi to avoid unexpected diffs, therefore
  # there are no setters for these settings
  def headless_browser
    @local_settings['headless_browser']
  end

  def pivotal_tracker_project_id
    @local_settings['pivotal_tracker_project_id']
  end

  private

  def read_settings
    global_path = File.join(ENV['HOME'], GLOBAL_SETTINGS_FILE_NAME)
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
    global_path = File.join(ENV['HOME'], GLOBAL_SETTINGS_FILE_NAME)
    global_directory = File.join(ENV['HOME'], %w[.config geordi])
    FileUtils.mkdir_p(global_directory) unless File.directory? global_directory
    File.open(global_path, 'w') do |file|
      file.write @global_settings.to_yaml
    end
  end

end
