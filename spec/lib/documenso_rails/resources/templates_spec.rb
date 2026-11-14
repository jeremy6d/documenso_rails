require "rails_helper"

RSpec.describe DocumensoRails::Resources::Templates do
  let(:connection) do
    DocumensoRails::Connection.new(
      base_url: "https://app.documenso.com/api/v2",
      api_key: "api_test"
    )
  end
  subject(:templates) { described_class.new(connection) }

  describe "#use" do
    it "posts multipart payload with envelopeId, recipients, prefill, and distributeDocument" do
      connection = instance_double(DocumensoRails::Connection)
      resource = described_class.new(connection)

      expect(connection).to receive(:post_multipart) do |path, payload:, files:|
        expect(path).to eq("/envelope/use")
        expect(payload).to include(
          envelopeId: "envelope_template123",
          distributeDocument: true
        )
        expect(payload[:recipients]).to eq(
          [{ id: 1, email: "jane@example.com", name: "Jane Client" }]
        )
        expect(payload[:prefillFields]).to eq(
          [{ id: 101, type: "text", value: "$2,500" }]
        )
        expect(files).to eq([])
        {
          "id" => "env_tpl_42",
          "recipients" => [
            { "id" => 1, "email" => "jane@example.com", "name" => "Jane Client", "signingUrl" => "https://sign/t" }
          ]
        }
      end

      envelope = resource.use(
        envelope_id: "envelope_template123",
        recipients: [{ id: 1, email: "jane@example.com", name: "Jane Client" }],
        prefill_fields: [{ id: 101, type: "text", value: "$2,500" }],
        distribute: true
      )

      expect(envelope.id).to eq("env_tpl_42")
      expect(envelope.recipients.first.signing_url).to eq("https://sign/t")
    end

    it "hits the live /envelope/use endpoint over HTTP" do
      stub = stub_request(:post, "https://app.documenso.com/api/v2/envelope/use")
        .with(headers: { "Authorization" => "api_test" })
        .to_return(status: 200, body: { id: "env_tpl_1" }.to_json)

      envelope = templates.use(
        envelope_id: "envelope_template123",
        recipients: [{ id: 1, email: "jane@example.com", name: "Jane" }],
        distribute: false
      )

      expect(stub).to have_been_requested
      expect(envelope.id).to eq("env_tpl_1")
    end
  end
end
