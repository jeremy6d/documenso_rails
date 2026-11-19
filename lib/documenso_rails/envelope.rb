module DocumensoRails
  class Envelope
    attr_reader :id, :status, :title, :recipients, :envelope_items, :raw

    def initialize(id:, status: nil, title: nil, recipients: [], envelope_items: [], raw: {})
      @id = id
      @status = status
      @title = title
      @recipients = recipients
      @envelope_items = envelope_items
      @raw = raw
    end

    def self.from_api(hash)
      data = hash.transform_keys(&:to_s)
      recipients = Array(data["recipients"]).map { |r| Recipient.from_api(r) }
      items = Array(data["envelopeItems"] || data["envelope_items"])

      new(
        id: data["id"] || data["envelopeId"],
        status: data["status"],
        title: data["title"],
        recipients: recipients,
        envelope_items: items,
        raw: data
      )
    end
  end
end
