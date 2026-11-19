require "rails_helper"

RSpec.describe DocumensoRails::Resources::Envelopes do
  let(:connection) do
    DocumensoRails::Connection.new(
      base_url: "https://app.documenso.com/api/v2",
      api_key: "api_test"
    )
  end
  subject(:envelopes) { described_class.new(connection) }

  describe "#create" do
    it "uploads a multipart DOCUMENT envelope" do
      stub = stub_request(:post, "https://app.documenso.com/api/v2/envelope/create")
        .with(headers: { "Authorization" => "api_test" })
        .to_return(status: 200, body: { id: "env_1", status: "DRAFT" }.to_json)

      envelope = envelopes.create(
        file_io: StringIO.new("%PDF-1.4"),
        filename: "retainer.pdf",
        title: "Client Retainer",
        recipients: [
          {
            email: "jane@example.com",
            name: "Jane Client",
            role: "SIGNER",
            fields: [{ type: "SIGNATURE", page: 1, position_x: 15, position_y: 80, width: 25, height: 6 }]
          }
        ]
      )

      expect(stub).to have_been_requested
      expect(envelope).to be_a(DocumensoRails::Envelope)
      expect(envelope.id).to eq("env_1")
    end

    it "maps field positions to positionX/Y with identifier 0" do
      connection = instance_double(DocumensoRails::Connection)
      resource = described_class.new(connection)

      expect(connection).to receive(:post_multipart) do |path, payload:, files:|
        expect(path).to eq("/envelope/create")
        expect(payload[:type]).to eq("DOCUMENT")
        field = payload[:recipients].first[:fields].first
        expect(field).to include(identifier: 0, positionX: 15, positionY: 80)
        expect(files.first[:filename]).to eq("retainer.pdf")
        { "id" => "env_1", "status" => "DRAFT" }
      end

      resource.create(
        file_io: StringIO.new("%PDF"),
        filename: "retainer.pdf",
        title: "Retainer",
        recipients: [
          {
            email: "jane@example.com",
            name: "Jane",
            fields: [{ type: "SIGNATURE", page: 1, position_x: 15, position_y: 80 }]
          }
        ]
      )
    end
  end

  describe "#get" do
    it "fetches an envelope by id" do
      stub_request(:get, "https://app.documenso.com/api/v2/envelope/env_1")
        .to_return(status: 200, body: { id: "env_1", status: "PENDING" }.to_json)

      envelope = envelopes.get("env_1")
      expect(envelope.id).to eq("env_1")
      expect(envelope.status).to eq("PENDING")
    end
  end

  describe "#distribute" do
    it "distributes and returns recipients with signing urls" do
      stub_request(:post, "https://app.documenso.com/api/v2/envelope/distribute")
        .with(
          headers: { "Authorization" => "api_test", "Content-Type" => "application/json" },
          body: { envelopeId: "env_1" }.to_json
        )
        .to_return(
          status: 200,
          body: {
            id: "env_1",
            status: "PENDING",
            recipients: [
              { id: 1, email: "jane@example.com", name: "Jane", signingUrl: "https://sign/abc" }
            ]
          }.to_json
        )

      envelope = envelopes.distribute("env_1")
      expect(envelope.id).to eq("env_1")
      expect(envelope.recipients.first.signing_url).to eq("https://sign/abc")
    end
  end

  describe "#download" do
    it "downloads the signed PDF via the envelope item path" do
      stub_request(:get, "https://app.documenso.com/api/v2/envelope/env_1")
        .to_return(
          status: 200,
          body: {
            id: "env_1",
            status: "COMPLETED",
            envelopeItems: [{ id: "item_9" }]
          }.to_json
        )
      download_stub = stub_request(
        :get,
        "https://app.documenso.com/api/v2/envelope/item/item_9/download?version=signed"
      ).to_return(status: 200, body: "%PDF-signed")

      pdf = envelopes.download("env_1", version: :signed)

      expect(download_stub).to have_been_requested
      expect(pdf).to eq("%PDF-signed")
    end
  end
end
