module DocumensoRails
  class ProcessWebhookJob < ActiveJob::Base
    queue_as :default

    STATUS_MAP = {
      "DOCUMENT_SENT"      => "sent",
      "DOCUMENT_OPENED"    => "opened",
      "DOCUMENT_SIGNED"    => "partially_signed",
      "DOCUMENT_COMPLETED" => "completed",
      "DOCUMENT_REJECTED"  => "rejected",
      "DOCUMENT_CANCELLED" => "cancelled"
    }.freeze

    def perform(event, envelope_id, payload = {})
      config = DocumensoRails.configuration
      record = config.model_class.find_by(documenso_envelope_id: envelope_id)
      return unless record

      new_status = STATUS_MAP[event]
      return unless new_status

      return if record.signature_status == "completed" && new_status != "completed"

      if event == "DOCUMENT_COMPLETED"
        attach_completed_pdf!(record, envelope_id, config)
        record.update!(
          signature_status:       "completed",
          signature_completed_at: Time.current
        )
      else
        record.update!(signature_status: new_status)
      end

      ActiveSupport::Notifications.instrument(
        "documenso.#{event.downcase}",
        record:      record,
        envelope_id: envelope_id,
        payload:     payload
      )
    end

    private

    def attach_completed_pdf!(record, envelope_id, config)
      signed_attachment = record.public_send(config.signed_attachment_name)
      return if signed_attachment.attached?

      pdf_binary = DocumensoRails.client.envelopes.download(envelope_id)
      title_slug = (record.try(:title) || "document-#{record.id}").parameterize

      signed_attachment.attach(
        io:           StringIO.new(pdf_binary),
        filename:     "signed_#{title_slug}.pdf",
        content_type: "application/pdf"
      )
    end
  end
end
