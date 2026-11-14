require "rails_helper"

RSpec.describe DocumensoRails::Client do
  subject(:client) do
    described_class.new(base_url: "https://app.documenso.com/api/v2", api_key: "api_test_token_123")
  end

  describe "#create_and_send" do
    it "uploads a multipart PDF envelope and distributes it" do
      create_stub = stub_request(:post, "https://app.documenso.com/api/v2/envelope/create")
        .with(headers: { "Authorization" => "api_test_token_123" })
        .to_return(status: 200, body: { id: "env_999" }.to_json)

      distribute_stub = stub_request(:post, "https://app.documenso.com/api/v2/envelope/distribute")
        .with(
          headers: { "Authorization" => "api_test_token_123", "Content-Type" => "application/json" },
          body: { envelopeId: "env_999" }.to_json
        )
        .to_return(status: 200, body: { success: true }.to_json)

      envelope_id = client.create_and_send(
        file_io:  StringIO.new("%PDF-1.4 fake pdf"),
        filename: "retainer.pdf",
        title:    "Client Retainer",
        signers:  [{ name: "Jane Client", email: "jane@example.com" }],
        fields:   [{ type: "SIGNATURE", page: 1, x: 15, y: 80 }]
      )

      expect(envelope_id).to eq("env_999")
      expect(create_stub).to have_been_requested
      expect(distribute_stub).to have_been_requested
    end

    it "raises DocumensoRails::ApiError on HTTP failure" do
      stub_request(:post, "https://app.documenso.com/api/v2/envelope/create")
        .to_return(status: 401, body: "Unauthorized")

      expect do
        client.create_and_send(
          file_io:  StringIO.new("%PDF-1.4"),
          filename: "retainer.pdf",
          title:    "Client Retainer",
          signers:  [{ name: "Jane Client", email: "jane@example.com" }],
          fields:   []
        )
      end.to raise_error(DocumensoRails::ApiError, /401/)
    end
  end

  describe "#create_and_send_from_template" do
    it "creates an envelope from a template with prefill fields and distributes it" do
      use_stub = stub_request(:post, "https://app.documenso.com/api/v2/envelope/use")
        .with(
          body: {
            templateId:    42,
            recipients:    [{ email: "jane@example.com", name: "Jane Client", role: "SIGNER" }],
            title:         "Smith Retainer",
            prefillFields: [{ label: "fee_amount", value: "$2,500" }],
            meta:          { redirectUrl: "https://secure.lawpay.com/pages/firm/trust" }
          }.to_json
        )
        .to_return(status: 200, body: { id: "env_tpl_42" }.to_json)

      distribute_stub = stub_request(:post, "https://app.documenso.com/api/v2/envelope/distribute")
        .with(body: { envelopeId: "env_tpl_42" }.to_json)
        .to_return(status: 200, body: { success: true }.to_json)

      envelope_id = client.create_and_send_from_template(
        template_id:    42,
        signers:        [{ name: "Jane Client", email: "jane@example.com" }],
        prefill_fields: { fee_amount: "$2,500" },
        title:          "Smith Retainer",
        redirect_url:   "https://secure.lawpay.com/pages/firm/trust"
      )

      expect(envelope_id).to eq("env_tpl_42")
      expect(use_stub).to have_been_requested
      expect(distribute_stub).to have_been_requested
    end
  end
end
