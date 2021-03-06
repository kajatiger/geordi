desc 'bundle-install', 'Run bundle install if required', hide: true
def bundle_install
  if File.exist?('Gemfile') && !system('bundle check > /dev/null 2>&1')
    Interaction.announce 'Bundling'
    Util.system! 'bundle install'
  end
end
