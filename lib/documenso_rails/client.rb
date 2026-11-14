module DocumensoRails
  class Client
    def initialize(base_url:, api_key:)
      @connection = Connection.new(base_url: base_url, api_key: api_key)
    end

    def envelopes
      @envelopes ||= Resources::Envelopes.new(@connection)
    end

    def templates
      @templates ||= Resources::Templates.new(@connection)
    end
  end
end
