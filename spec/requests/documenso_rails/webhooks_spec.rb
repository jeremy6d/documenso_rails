require "rails_helper"

RSpec.describe "Documenso Webhooks", type: :request do
  let(:headers) do
    {
      "CONTENT_TYPE"       => "application/json",
      "X-Documenso-Secret" => "super_secret_webhook_token"
    }
  end

  let(:payload) do
    {
      event: "DOCUMENT_COMPLETED",
      payload: { envelopeId: "env_555" }
    }.to_json
  end

  it "rejects requests with a missing or invalid X-Documenso-Secret header" do
    post "/documenso/webhook", params: payload, headers: { "CONTENT_TYPE" => "application/json", "X-Documenso-Secret" => "wrong" }

    expect(response).to have_http_status(:unauthorized)
    expect(DocumensoRails::ProcessWebhookJob).not_to have_been_enqueued
  end

  it "enqueues ProcessWebhookJob and returns 200 OK for valid requests" do
    expect do
      post "/documenso/webhook", params: payload, headers: headers
    end.to have_enqueued_job(DocumensoRails::ProcessWebhookJob)
      .with("DOCUMENT_COMPLETED", "env_555", { "envelopeId" => "env_555" })

    expect(response).to have_http_status(:ok)
  end
end
