# DocumensoRails

Rails engine and Documenso API v2 client for sending documents for signature, using templates, and receiving webhooks.

## Installation

1. Add the gem to your `Gemfile`:

```ruby
gem "documenso_rails", path: "vendor/gems/documenso_rails"
```

2. Install and generate:

```bash
bundle install
rails g documenso_rails:install LegalDocument
rails db:migrate
```

3. Ensure your model includes the concern and Active Storage attachments (the generator adds these when the model file exists):

```ruby
class LegalDocument < ApplicationRecord
  include DocumensoRails::Model
  has_one_attached :unsigned_pdf
  has_one_attached :signed_pdf
end
```

## Configuration

```ruby
# config/initializers/documenso_rails.rb
DocumensoRails.configure do |config|
  config.base_url = ENV.fetch("DOCUMENSO_API_URL", "https://app.documenso.com/api/v2")
  config.api_key = Rails.application.credentials.dig(:documenso, :api_key)
  config.webhook_secret = Rails.application.credentials.dig(:documenso, :webhook_secret)
  config.model_class_name = "LegalDocument"
end
```

## Sending a document

```ruby
doc.unsigned_pdf.attach(io: File.open("contract.pdf"), filename: "contract.pdf")

envelope = doc.send_for_signature!(
  signer_name: "Jane Client",
  signer_email: "jane@example.com"
)

envelope.id
envelope.recipients.first.signing_url
```

Multiple signers:

```ruby
doc.send_for_multiple_signatures!(
  signers: [
    { name: "Jane", email: "jane@example.com" },
    { name: "Alex", email: "alex@example.com" }
  ],
  fields: [
    { type: "SIGNATURE", page: 1, x: 15, y: 80, signer_index: 0 },
    { type: "SIGNATURE", page: 1, x: 15, y: 60, signer_index: 1 }
  ]
)
```

## Templates

```ruby
envelope = doc.send_from_template!(
  template_id: "envelope_template123", # Documenso template envelope id
  signers: [{ id: 1, name: "Jane Client", email: "jane@example.com" }],
  prefill_fields: [{ id: 101, type: "text", value: "Matter 2026-0041" }]
)
```

## Direct client usage

```ruby
client = DocumensoRails.client
envelope = client.envelopes.create(file_io:, filename:, title:, recipients:)
client.envelopes.distribute(envelope.id)
client.envelopes.get(envelope.id)
client.envelopes.download(envelope.id, version: :signed)
client.templates.use(envelope_id:, recipients:, prefill_fields:, distribute: true)
```

## Webhooks

Mount path: `POST /documenso/webhook`

Point Documenso at that URL and set the same secret as `config.webhook_secret`. Requests must include header `X-Documenso-Secret`.

On `DOCUMENT_COMPLETED`, the gem downloads the signed PDF via the envelope item API and attaches it to your model.

Subscribe to ActiveSupport notifications: `documenso.document_completed`, etc.

## Running tests

```bash
bundle install
bundle exec rspec
```
