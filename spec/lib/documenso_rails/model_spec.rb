require "rails_helper"

RSpec.describe DocumensoRails::Model do
  let(:doc) { LegalDocument.create!(title: "Engagement Letter") }

  describe "#send_for_signature!" do
    it "raises an error if no unsigned PDF is attached" do
      expect do
        doc.send_for_signature!(signer_name: "Jane Client", signer_email: "jane@example.com")
      end.to raise_error(DocumensoRails::Error, /No unsigned PDF attached/)
    end

    it "sends the attached PDF and updates envelope tracking attributes" do
      doc.unsigned_pdf.attach(
        io: StringIO.new("%PDF-1.4 sample"),
        filename: "engagement.pdf",
        content_type: "application/pdf"
      )

      stub_request(:post, "https://app.documenso.com/api/v2/envelope/create")
        .to_return(status: 200, body: { id: "env_123", status: "DRAFT" }.to_json)
      stub_request(:post, "https://app.documenso.com/api/v2/envelope/distribute")
        .to_return(
          status: 200,
          body: {
            id: "env_123",
            status: "PENDING",
            recipients: [
              { id: 1, email: "jane@example.com", name: "Jane Client", signingUrl: "https://sign/abc" }
            ]
          }.to_json
        )

      envelope = doc.send_for_signature!(signer_name: "Jane Client", signer_email: "jane@example.com")

      expect(envelope).to be_a(DocumensoRails::Envelope)
      expect(envelope.id).to eq("env_123")
      expect(envelope.recipients.first.signing_url).to eq("https://sign/abc")

      doc.reload
      expect(doc.documenso_envelope_id).to eq("env_123")
      expect(doc.signature_status).to eq("sent")
      expect(doc.signature_sent_at).to be_present
    end
  end

  describe "#send_from_template!" do
    it "sends via template without requiring an attached unsigned PDF" do
      stub_request(:post, "https://app.documenso.com/api/v2/envelope/use")
        .to_return(
          status: 200,
          body: {
            id: "env_tpl_88",
            recipients: [
              { id: 1, email: "jane@example.com", name: "Jane Client", signingUrl: "https://sign/tpl" }
            ]
          }.to_json
        )

      envelope = doc.send_from_template!(
        template_id: "envelope_template10",
        signers: [{ id: 1, name: "Jane Client", email: "jane@example.com" }],
        prefill_fields: [{ id: 101, type: "text", value: "2026-0041" }]
      )

      expect(envelope).to be_a(DocumensoRails::Envelope)
      expect(envelope.id).to eq("env_tpl_88")

      doc.reload
      expect(doc.documenso_envelope_id).to eq("env_tpl_88")
      expect(doc.signature_status).to eq("sent")
      expect(doc.signature_sent_at).to be_present
    end

    it "keeps draft status when distribute is false" do
      stub_request(:post, "https://app.documenso.com/api/v2/envelope/use")
        .to_return(status: 200, body: { id: "env_tpl_draft", status: "DRAFT" }.to_json)

      doc.send_from_template!(
        template_id: "envelope_template10",
        signers: [{ id: 1, name: "Jane Client", email: "jane@example.com" }],
        distribute: false
      )

      doc.reload
      expect(doc.documenso_envelope_id).to eq("env_tpl_draft")
      expect(doc.signature_status).to eq("draft")
      expect(doc.signature_sent_at).to be_nil
    end
  end
end
