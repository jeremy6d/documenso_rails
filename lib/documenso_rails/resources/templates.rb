module DocumensoRails
  module Resources
    class Templates
      def initialize(connection)
        @connection = connection
      end

      def use(envelope_id:, recipients:, prefill_fields: [], title: nil, redirect_url: nil, distribute: true)
        payload = {
          envelopeId: envelope_id,
          recipients: format_recipients(recipients),
          distributeDocument: distribute
        }

        formatted_prefill = format_prefill_fields(prefill_fields)
        payload[:prefillFields] = formatted_prefill if formatted_prefill.any?

        if title
          payload[:override] ||= {}
          payload[:override][:title] = title
        end

        if redirect_url
          payload[:meta] = { redirectUrl: redirect_url }
        end

        response = @connection.post_multipart("/envelope/use", payload: payload, files: [])
        Envelope.from_api(response)
      end

      private

      def format_recipients(recipients)
        recipients.map do |recipient|
          data = recipient.transform_keys(&:to_sym)
          entry = {
            id: data.fetch(:id),
            email: data.fetch(:email),
            name: data[:name]
          }
          entry[:signingOrder] = data[:signing_order] || data[:signingOrder] if data[:signing_order] || data[:signingOrder]
          entry.compact
        end
      end

      def format_prefill_fields(fields)
        Array(fields).map do |field|
          data = field.transform_keys(&:to_sym)
          {
            id: data.fetch(:id),
            type: data.fetch(:type),
            value: data.fetch(:value).to_s
          }
        end
      end
    end
  end
end
