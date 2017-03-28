begin
  fetch(:repository)
  fetch(:application)
rescue IndexError => e
  puts "#{e.message} (ensure :application and :repository are set in deploy.rb)"
end

set :app_with_stage, -> { "#{fetch(:app_name)}" }

set :repo_url, -> { fetch(:repository) } unless fetch(:repo_url)

set :release_dir, -> { Pathname.new("/home/deploy/dockerised_apps/#{fetch(:app_with_stage)}/current") }

set :shared_dir, -> { Pathname.new("/home/deploy/dockerised_apps/#{fetch(:app_with_stage)}/shared") }

set :log_dir, -> { Pathname.new("/home/deploy/dockerised_apps/logs/#{fetch(:app_with_stage)}") }

set :app_dir, -> { fetch(:release_dir).to_s.chomp('/current') }

def exec_on_remote(command, message="Executing command on remote...", container_id='web')
  on roles :app do |server|
    ssh_cmd = "ssh -A -t #{server.user}@#{server.hostname}"
    puts message
    exec "#{ssh_cmd} 'cd #{fetch(:release_dir)} && docker-compose -f docker-compose.yml -f docker-compose.prod.yml -p #{fetch(:app_with_stage)} run web #{command}'"
  end
end

def exec_on_server(command, message="Executing on docker server...")
  on roles :app do |server|
    ssh_cmd = "ssh -A -t #{server.user}@#{server.hostname}"
    puts message
    exec "#{ssh_cmd} '#{command}'"
  end
end

desc 'Run a rails console on remote'
task :console do
  exec_on_remote("bundle exec rails c", "Running console on remote...")
end

desc 'Run a bash terminal on remote'
task :bash do
  exec_on_remote("bash", "Running bash terminal on remote...")
end

namespace :docker do
  desc "deploy a git tag to a docker container"
  task :lift_off do
    on roles :app do
      invoke 'deploy'
      invoke 'docker:setup_env'
      invoke 'docker:build_container'
      invoke 'docker:stop'
      invoke 'docker:start'
      invoke 'docker:cleanup_containers'
      invoke 'docker:cleanup_images'
      invoke 'docker:notify'
    end
  end

  desc 'Setup Environment file'
  task :setup_env do
    on roles :app do
      env_file = "#{fetch(:shared_dir)}/.env"
      unless test "[ -f #{env_file} ]"
        require 'securerandom'
        execute :echo, "'VIRTUAL_HOST=#{fetch(:app_domain)}\nSECRET_KEY_BASE=#{SecureRandom.hex(64)}' > #{env_file}"
      end
    end
  end

  desc "build container"
  task :build_container do
    on roles :app do
      within fetch(:release_dir) do
        execute "cd #{fetch(:release_dir)} && docker-compose -f docker-compose.yml -f docker-compose.prod.yml -p #{fetch(:app_with_stage)} build web"
      end
    end
  end

  desc "start web service"
  task :start do
    on roles :app do
      within fetch(:release_dir) do
        execute "cd #{fetch(:release_dir)} && docker-compose -f docker-compose.yml -f docker-compose.prod.yml -p #{fetch(:app_with_stage)} up -d"
      end
    end
  end

  desc "stop service"
  task :stop do
    on roles :app do
      within fetch(:release_dir) do
        execute "cd #{fetch(:release_dir)} && docker-compose -f docker-compose.yml -f docker-compose.prod.yml -p #{fetch(:app_with_stage)} kill" # kill the running containers
        execute "cd #{fetch(:release_dir)} && docker-compose -f docker-compose.yml -f docker-compose.prod.yml -p #{fetch(:app_with_stage)} rm --force"
      end
    end
  end

  desc 'Run a bash console attached to the running docker application'
  task :bash do
    invoke 'bash'
  end

  desc 'Run a console attached to the running docker application'
  task :console do
    invoke 'console'
  end

  desc 'Run seed_fu against remote url'
  task :seed_fu do
    exec_on_remote("bundle exec rake db:seed_fu", "Seeding database on remote...")
  end

  desc "Tail logs from remote dockerised app"
  task :logs do
    exec_on_remote "cd #{fetch(:log_dir)} && tail -f staging.log"
  end

  desc 'Notify deploy on third party IM'
  task :notify do
    message = "New version of #{fetch(:app_name)} has been deployed at #{fetch(:app_domain)}"
    exec "rake notifier:notify[\"#{message}\"]"
  end

  desc 'Recreate DB tables'
  task :reset_db do
    exec_on_remote("bundle exec rake db:setup", "Recreating database on remote...")
  end

  desc 'Cleanup old docker containers'
  task :cleanup_containers do
    exec_on_server("docker rm -v $(docker ps --filter status=exited -q 2>/dev/null) 2>/dev/null", "Removing exited containers...")
  end

  desc 'Cleanup old docker images'
  task :cleanup_images do
    exec_on_server("docker rmi $(docker images --filter dangling=true -q 2>/dev/null) 2>/dev/null", "Removing unused images...")
  end

  desc 'Precompile assets'
  task :precompile_assets do
    exec_on_remote "bundle exec rake assets:precompile", "Precompiling assets..."
  end

end
