require 'rails/generators/base'
require 'securerandom'

module DockerHouston
  module Generators
    class InstallGenerator < Rails::Generators::Base

      argument :app_name, type: :string, default: Rails.application.class.parent_name.downcase
      argument :app_domain, type: :string, default: "example.com"
      argument :docker_host, type: :string, default: "example.com"

      source_root File.expand_path("../../templates", __FILE__)
      desc "Creates a docker configuration template files to your application."

      def copy_dockerfile
        copy_file "Dockerfile.erb", "Dockerfile"
      end

      def copy_docker_compose
        copy_file "docker-compose.yml.erb", "docker-compose.yml"
        copy_file "docker-compose.override.yml.erb", "docker-compose.override.yml"
        template "docker-compose.prod.yml.erb", "docker-compose.prod.yml"
      end

      def copy_secret
        copy_file "secrets.yml", "config/secrets.yml"
      end

      def copy_database_file
        template "database.yml.erb", "config/database.yml"
      end

      def copy_unicorn
        copy_file "unicorn.rb", "config/unicorn.rb"
      end

      def copy_capistrano_env
        environment = ask("Staging or production? [staging]")
        if environment.blank? || environment == 'staging'
          template 'staging.rb.erb', "config/deploy/staging.rb"
        else
          template 'production.rb.erb', "config/deploy/production.rb"
        end
      end

      def copy_capistrano_deploy
        template 'deploy.rb.erb', "config/deploy.rb"
      end

      def copy_capistrano_file
        copy_file 'Capfile', "Capfile"
      end

      def copy_executable
        copy_file "../../../bin/docker", "bin/docker"
        exec "chmod +x bin/docker"
      end

      def rails_4?
        Rails::VERSION::MAJOR == 4
      end

    end
  end
end