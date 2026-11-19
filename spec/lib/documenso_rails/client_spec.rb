require "rails_helper"

RSpec.describe DocumensoRails::Client do
  subject(:client) do
    described_class.new(base_url: "https://app.documenso.com/api/v2", api_key: "api_test")
  end

  it "exposes envelopes and templates resources" do
    expect(client.envelopes).to be_a(DocumensoRails::Resources::Envelopes)
    expect(client.templates).to be_a(DocumensoRails::Resources::Templates)
  end
end
