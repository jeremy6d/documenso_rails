require "net/http"
require "json"

module DocumensoRails
  class Client
    def initialize(base_url:, api_key:)
      @base_url = base_url.to_s.chomp("/")
      @api_key  = api_key
    end

    def create_and_send(file_io:, filename:, title:, signers:, fields:, redirect_url: nil)
      envelope    = create_envelope(
        file_io:      file_io,
        filename:     filename,
        title:        title,
        signers:      signers,
        fields:       fields,
        redirect_url: redirect_url
      )
      envelope_id = envelope.fetch("id")
      distribute_result = distribute_envelope(envelope_id)
      build_send_result(envelope_id, distribute_result)
    end

    def create_and_send_from_template(template_id:, signers:, prefill_fields: {}, title: nil, redirect_url: nil)
      envelope    = use_template(
        template_id:    template_id,
        signers:        signers,
        prefill_fields: prefill_fields,
        title:          title,
        redirect_url:   redirect_url
      )
      envelope_id = envelope.fetch("id")
      distribute_result = distribute_envelope(envelope_id)
      build_send_result(envelope_id, distribute_result)
    end

    def create_envelope(file_io:, filename:, title:, signers:, fields:, redirect_url: nil)
      uri     = URI("#{@base_url}/envelope/create")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = @api_key

      recipients = signers.each_with_index.map do |signer, idx|
        signer_fields = fields.select { |f| f.fetch(:signer_index, 0) == idx }.map do |field|
          {
            identifier: idx,
            type:       field.fetch(:type, "SIGNATURE"),
            page:       field.fetch(:page, 1),
            positionX:  field.fetch(:x, 15),
            positionY:  field.fetch(:y, 80),
            width:      field.fetch(:width, 25),
            height:     field.fetch(:height, 6)
          }
        end

        {
          email:  signer.fetch(:email),
          name:   signer.fetch(:name),
          role:   signer.fetch(:role, "SIGNER"),
          fields: signer_fields
        }
      end

      payload = {
        type:       "DOCUMENT",
        title:      title,
        recipients: recipients
      }
      payload[:meta] = { redirectUrl: redirect_url } if redirect_url.present?

      form_data = [
        ["payload", payload.to_json],
        ["files", file_io, { filename: filename, content_type: "application/pdf" }]
      ]

      request.set_form(form_data, "multipart/form-data")
      JSON.parse(execute(uri, request).body)
    end

    def use_template(template_id:, signers:, prefill_fields: {}, title: nil, redirect_url: nil)
      uri     = URI("#{@base_url}/envelope/use")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = @api_key
      request["Content-Type"]  = "application/json"

      formatted_recipients = signers.each_with_index.map do |signer, idx|
        entry = {
          email: signer.fetch(:email),
          name:  signer.fetch(:name),
          role:  signer.fetch(:role, "SIGNER")
        }
        entry[:id] = signer[:recipient_id] if signer[:recipient_id].present?
        entry[:signingOrder] = idx + 1 if signer[:signing_order]
        entry
      end

      payload = {
        templateId: template_id,
        recipients: formatted_recipients
      }
      payload[:title] = title if title.present?
      payload[:prefillFields] = prefill_fields.map { |k, v| { label: k.to_s, value: v.to_s } } if prefill_fields.any?
      payload[:meta] = { redirectUrl: redirect_url } if redirect_url.present?

      request.body = payload.to_json
      JSON.parse(execute(uri, request).body)
    end

    def distribute_envelope(envelope_id)
      uri     = URI("#{@base_url}/envelope/distribute")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = @api_key
      request["Content-Type"]  = "application/json"
      request.body             = { envelopeId: envelope_id }.to_json

      body = execute(uri, request).body
      body.present? ? JSON.parse(body) : {}
    end

    def download_signed_pdf(envelope_id)
      uri     = URI("#{@base_url}/envelope/#{envelope_id}/download")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = @api_key

      execute(uri, request).body
    end

    private

    def build_send_result(envelope_id, distribute_payload)
      raw_recipients = Array(distribute_payload["recipients"] || distribute_payload[:recipients])
      recipients = raw_recipients.map do |recipient|
        {
          email:       recipient["email"] || recipient[:email],
          name:        recipient["name"] || recipient[:name],
          signing_url: recipient["signingUrl"] || recipient[:signingUrl] || recipient["signing_url"]
        }
      end

      SendResult.new(envelope_id: envelope_id, recipients: recipients, raw: distribute_payload)
    end

    def execute(uri, request)
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = 10
        http.read_timeout = 30
        http.request(request)
      end

      raise ApiError, "Documenso API Error (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      response
    end
  end
end
