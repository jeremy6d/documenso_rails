require "rails_helper"

RSpec.describe DocumensoRails::Envelope do
  it "parses id, status, and recipients with signing_url" do
    envelope = described_class.from_api(
      "id" => "env_1",
      "status" => "PENDING",
      "recipients" => [
        { "id" => 1, "email" => "a@b.com", "name" => "A", "signingUrl" => "https://sign/x" }
      ]
    )

    expect(envelope.id).to eq("env_1")
    expect(envelope.status).to eq("PENDING")
    expect(envelope.recipients.first.signing_url).to eq("https://sign/x")
  end
end
