module DocumensoRails
  class SendResult
    attr_reader :envelope_id, :recipients, :raw

    def initialize(envelope_id:, recipients: [], raw: {})
      @envelope_id = envelope_id
      @recipients  = recipients
      @raw         = raw
    end

    def signing_url
      recipients.find { |r| r[:signing_url].present? }&.dig(:signing_url)
    end
  end
end
