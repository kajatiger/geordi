desc 'rake TASK', 'Run a rake task in several Rails environments'
long_desc <<-LONGDESC
Example: `geordi rake db:migrate`

`TASK` is run in the following Rails environments (if present):

- development
- test
- cucumber
LONGDESC

def rake(*args)
  invoke_geordi 'bundle_install'

  %w[development test cucumber].each do |env| # update long_desc when changing this
    if File.exist? "config/environments/#{env}.rb"
      call = [Util.binstub('rake')] + args + ["RAILS_ENV=#{env}"]
      Interaction.note_cmd call.join(' ')

      Util.run! *call
    end
  end
end
