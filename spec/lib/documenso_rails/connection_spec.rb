require "rails_helper"

RSpec.describe DocumensoRails::Connection do
  subject(:conn) do
    described_class.new(base_url: "https://app.documenso.com/api/v2", api_key: "api_test")
  end

  it "parses JSON GET success" do
    stub_request(:get, "https://app.documenso.com/api/v2/envelope/env_1")
      .with(headers: { "Authorization" => "api_test" })
      .to_return(status: 200, body: { id: "env_1" }.to_json, headers: { "Content-Type" => "application/json" })

    expect(conn.get("/envelope/env_1")).to eq("id" => "env_1")
  end

  it "raises ApiError with status on failure" do
    stub_request(:get, "https://app.documenso.com/api/v2/envelope/x")
      .to_return(status: 404, body: { error: "not found" }.to_json)

    expect { conn.get("/envelope/x") }.to raise_error(DocumensoRails::ApiError) { |e|
      expect(e.status_code).to eq(404)
    }
  end

  it "retries once on 429 when Retry-After is present" do
    stub_request(:get, "https://app.documenso.com/api/v2/envelope/r")
      .to_return(
        { status: 429, body: "slow", headers: { "Retry-After" => "0" } },
        { status: 200, body: { id: "r" }.to_json }
      )

    expect(conn.get("/envelope/r")).to eq("id" => "r")
  end
end
