module DocumensoRails
  module Model
    extend ActiveSupport::Concern

    DEFAULT_FIELDS = [
      { type: "SIGNATURE", page: 1, x: 15, y: 80, width: 25, height: 6 },
      { type: "DATE",      page: 1, x: 45, y: 82, width: 15, height: 4 }
    ].freeze

    def send_for_signature!(signer_name:, signer_email:, fields: DEFAULT_FIELDS, redirect_url: nil)
      send_for_multiple_signatures!(
        signers: [{ name: signer_name, email: signer_email }],
        fields: fields,
        redirect_url: redirect_url
      )
    end

    def send_for_multiple_signatures!(signers:, fields: DEFAULT_FIELDS, redirect_url: nil)
      unsigned_attachment = public_send(DocumensoRails.configuration.unsigned_attachment_name)
      raise Error, "No unsigned PDF attached to #{self.class.name}##{id}" unless unsigned_attachment.attached?

      target_redirect = redirect_url || DocumensoRails.configuration.redirect_url
      client = DocumensoRails.client
      envelope = nil

      unsigned_attachment.open do |tempfile|
        created = client.envelopes.create(
          file_io: tempfile,
          filename: "#{id}.pdf",
          title: try(:title) || "Document ##{id}",
          recipients: build_recipients(signers, fields),
          redirect_url: target_redirect
        )
        envelope = client.envelopes.distribute(created.id)
      end

      update!(
        documenso_envelope_id: envelope.id,
        signature_status: "sent",
        signature_sent_at: Time.current
      )

      envelope
    end

    def send_from_template!(template_id:, signers:, prefill_fields: [], title: nil, redirect_url: nil, distribute: true)
      target_redirect = redirect_url || DocumensoRails.configuration.redirect_url

      envelope = DocumensoRails.client.templates.use(
        envelope_id: template_id,
        recipients: signers,
        prefill_fields: normalize_prefill_fields(prefill_fields),
        title: title || try(:title),
        redirect_url: target_redirect,
        distribute: distribute
      )

      update!(
        documenso_envelope_id: envelope.id,
        signature_status: "sent",
        signature_sent_at: Time.current
      )

      envelope
    end

    private

    def build_recipients(signers, fields)
      signers.each_with_index.map do |signer, idx|
        signer_fields = Array(fields).select { |f| f.fetch(:signer_index, 0) == idx }
        {
          email: signer.fetch(:email),
          name: signer.fetch(:name),
          role: signer.fetch(:role, "SIGNER"),
          fields: signer_fields
        }.tap do |entry|
          entry[:id] = signer[:id] if signer[:id]
          entry[:signing_order] = signer[:signing_order] if signer[:signing_order]
        end
      end
    end

    def normalize_prefill_fields(prefill_fields)
      Array(prefill_fields)
    end
  end
end
