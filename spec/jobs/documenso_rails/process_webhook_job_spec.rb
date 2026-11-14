require "rails_helper"

RSpec.describe DocumensoRails::ProcessWebhookJob, type: :job do
  let!(:doc) do
    LegalDocument.create!(
      title: "Client Fee Agreement",
      documenso_envelope_id: "env_777",
      signature_status: "sent"
    )
  end

  it "updates status on DOCUMENT_OPENED and emits an ActiveSupport::Notification" do
    events = []
    subscriber = ActiveSupport::Notifications.subscribe("documenso.document_opened") do |*args|
      events << ActiveSupport::Notifications::Event.new(*args)
    end

    described_class.perform_now("DOCUMENT_OPENED", "env_777", { "envelopeId" => "env_777" })

    expect(doc.reload.signature_status).to eq("opened")
    expect(events.size).to eq(1)
    expect(events.first.payload[:record]).to eq(doc)
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "downloads and attaches the signed PDF on DOCUMENT_COMPLETED" do
    stub_request(:get, "https://app.documenso.com/api/v2/envelope/env_777")
      .with(headers: { "Authorization" => "api_test_token_123" })
      .to_return(
        status: 200,
        body: {
          id: "env_777",
          status: "COMPLETED",
          envelopeItems: [{ id: "item_777" }]
        }.to_json
      )
    download_stub = stub_request(
      :get,
      "https://app.documenso.com/api/v2/envelope/item/item_777/download?version=signed"
    ).with(headers: { "Authorization" => "api_test_token_123" })
      .to_return(status: 200, body: "%PDF-1.4 signed binary content")

    described_class.perform_now("DOCUMENT_COMPLETED", "env_777", { "envelopeId" => "env_777" })

    doc.reload
    expect(download_stub).to have_been_requested
    expect(doc.signature_status).to eq("completed")
    expect(doc.signature_completed_at).to be_present
    expect(doc.signed_pdf).to be_attached
    expect(doc.signed_pdf.filename.to_s).to eq("signed_client-fee-agreement.pdf")
    expect(doc.signed_pdf.download).to eq("%PDF-1.4 signed binary content")
  end

  it "ignores stale out-of-order webhooks once a document is completed" do
    doc.update!(signature_status: "completed")

    described_class.perform_now("DOCUMENT_OPENED", "env_777", { "envelopeId" => "env_777" })

    expect(doc.reload.signature_status).to eq("completed")
  end
end
