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
