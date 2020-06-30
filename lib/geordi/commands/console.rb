desc 'console [TARGET]', 'Open a Rails console locally or on a Capistrano deploy target'
long_desc <<-LONGDESC
Open a local Rails console: `geordi console`

Open a Rails console on `staging`: `geordi console staging`
LONGDESC


option :select_server, type: :string, aliases: '-s'

def console(target = 'development', *_args)
  require 'geordi/remote'

  if target == 'development'
    invoke_cmd 'yarn_install'

    Interaction.announce 'Opening a local Rails console'

    Util.system! Util.console_command(target)
  else
    Interaction.announce 'Opening a Rails console on ' + target

    Geordi::Remote.new(target).console(options)
  end
end
