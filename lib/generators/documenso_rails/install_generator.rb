require "rails/generators/base"
require "rails/generators/active_record"

module DocumensoRails
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("templates", __dir__)

      argument :model_name, type: :string, default: "LegalDocument"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_initializer
        template "initializer.rb.tt", "config/initializers/documenso_rails.rb"
      end

      def create_migration
        migration_template "migration.rb.tt", "db/migrate/add_documenso_fields_to_#{table_name}.rb"
      end

      def add_route
        route 'mount DocumensoRails::Engine, at: "/documenso"'
      end

      def configure_model
        model_path = File.join("app/models", "#{model_name.underscore}.rb")
        if File.exist?(model_path)
          inject_into_class model_path, model_name do
            <<~RUBY
              include DocumensoRails::Model

              has_one_attached :unsigned_pdf
              has_one_attached :signed_pdf

            RUBY
          end
        else
          say "Model #{model_path} not found. Add:", :yellow
          say <<~RUBY
            class #{model_name} < ApplicationRecord
              include DocumensoRails::Model
              has_one_attached :unsigned_pdf
              has_one_attached :signed_pdf
            end
          RUBY
        end
      end

      private

      def table_name
        model_name.tableize
      end

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
