require "documenso_rails/version"
require "documenso_rails/errors"
require "documenso_rails/configuration"
require "documenso_rails/connection"
require "documenso_rails/recipient"
require "documenso_rails/envelope"
require "documenso_rails/resources/envelopes"
require "documenso_rails/client"
require "documenso_rails/model"
require "documenso_rails/engine"

module DocumensoRails
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def client
      Client.new(
        base_url: configuration.base_url,
        api_key:  configuration.api_key
      )
    end
  end
end
