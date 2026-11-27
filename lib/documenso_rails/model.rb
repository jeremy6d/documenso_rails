module DocumensoRails
  module Model
    extend ActiveSupport::Concern

    DEFAULT_FIELDS = [
      { type: "SIGNATURE", page: 1, x: 15, y: 80, width: 25, height: 6 },
      { type: "DATE",      page: 1, x: 45, y: 82, width: 15, height: 4 }
    ].freeze

    def send_for_signature!(signer_name:, signer_email:, fields: DEFAULT_FIELDS, redirect_url: nil)
      send_for_multiple_signatures!(
        signers:      [{ name: signer_name, email: signer_email }],
        fields:       fields,
        redirect_url: redirect_url
      )
    end

    def send_for_multiple_signatures!(signers:, fields: DEFAULT_FIELDS, redirect_url: nil)
      unsigned_attachment = public_send(DocumensoRails.configuration.unsigned_attachment_name)
      raise Error, "No unsigned PDF attached to #{self.class.name}##{id}" unless unsigned_attachment.attached?

      result = nil
      target_redirect = redirect_url || DocumensoRails.configuration.redirect_url

      unsigned_attachment.open do |tempfile|
        result = DocumensoRails.client.create_and_send(
          file_io:      tempfile,
          filename:     "#{id}.pdf",
          title:        try(:title) || "Document ##{id}",
          signers:      signers,
          fields:       fields,
          redirect_url: target_redirect
        )
      end

      apply_send_result!(result)
      result
    end

    def send_from_template!(template_id:, signers:, prefill_fields: {}, title: nil, redirect_url: nil)
      target_redirect = redirect_url || DocumensoRails.configuration.redirect_url

      result = DocumensoRails.client.create_and_send_from_template(
        template_id:    template_id,
        signers:        signers,
        prefill_fields: prefill_fields,
        title:          title || try(:title),
        redirect_url:   target_redirect
      )

      apply_send_result!(result)
      result
    end

    private

    def apply_send_result!(result)
      attrs = {
        documenso_envelope_id: result.envelope_id,
        signature_status:      "sent",
        signature_sent_at:     Time.current
      }
      attrs[:signing_url] = result.signing_url if has_attribute?(:signing_url)
      update!(attrs)
    end
  end
end
