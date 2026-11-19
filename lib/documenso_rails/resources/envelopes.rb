module DocumensoRails
  module Resources
    class Envelopes
      def initialize(connection)
        @connection = connection
      end

      def create(file_io:, filename:, title:, recipients:, redirect_url: nil)
        payload = {
          type: "DOCUMENT",
          title: title,
          recipients: format_recipients(recipients)
        }
        payload[:meta] = { redirectUrl: redirect_url } if redirect_url

        response = @connection.post_multipart(
          "/envelope/create",
          payload: payload,
          files: [{ io: file_io, filename: filename, content_type: "application/pdf" }]
        )

        Envelope.from_api(response)
      end

      def get(id)
        Envelope.from_api(@connection.get("/envelope/#{id}"))
      end

      def distribute(id)
        response = @connection.post_json("/envelope/distribute", { envelopeId: id })
        Envelope.from_api(response.is_a?(Hash) ? response.merge("id" => response["id"] || id) : { "id" => id })
      end

      def download(id, version: :signed)
        envelope = get(id)
        item = envelope.envelope_items.first
        raise Error, "No document found in envelope #{id}" unless item

        item_id = item.is_a?(Hash) ? (item["id"] || item[:id]) : item
        @connection.get_raw("/envelope/item/#{item_id}/download?version=#{version}")
      end

      private

      def format_recipients(recipients)
        recipients.map do |recipient|
          fields = Array(recipient[:fields] || recipient["fields"]).map { |field| format_field(field) }

          entry = {
            email: recipient.fetch(:email) { recipient.fetch("email") },
            name: recipient.fetch(:name) { recipient.fetch("name") },
            role: recipient[:role] || recipient["role"] || "SIGNER"
          }
          entry[:fields] = fields if fields.any?
          entry[:id] = recipient[:id] || recipient["id"] if recipient[:id] || recipient["id"]
          entry[:signingOrder] = recipient[:signing_order] || recipient["signingOrder"] if recipient[:signing_order] || recipient["signingOrder"]
          entry
        end
      end

      def format_field(field)
        data = field.transform_keys(&:to_sym)
        {
          identifier: data.fetch(:identifier, 0),
          type: data.fetch(:type, "SIGNATURE"),
          page: data.fetch(:page, 1),
          positionX: data[:position_x] || data[:positionX] || data[:x] || 15,
          positionY: data[:position_y] || data[:positionY] || data[:y] || 80,
          width: data.fetch(:width, 25),
          height: data.fetch(:height, 6)
        }
      end
    end
  end
end
