require_relative "boot"
require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"

Bundler.require(*Rails.groups)
require "documenso_rails"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.secret_key_base = "test_secret_key_base_for_documenso_rails"
    config.active_storage.service = :test
    config.active_job.queue_adapter = :test
  end
end
