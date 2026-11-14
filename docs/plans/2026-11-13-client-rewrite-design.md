# DocumensoRails Client Rewrite Design

**Date:** 2026-11-13  
**Status:** Approved  
**Scope:** Full rewrite of the API client layer (approach 2), plus critical API correctness, test harness, light install/README fixes. Version bump to `0.2.0`.

## Goal

Replace the flat, partially incorrect `Client` with a resource-oriented Documenso API v2 client that matches official docs, returns typed results (including signing URLs), and ships with a green RSpec suite.

## Architecture

```
DocumensoRails.configure { ... }
DocumensoRails.client                    # Client
  ├── connection                         # Connection (Net::HTTP)
  ├── envelopes                          # Resources::Envelopes
  └── templates                          # Resources::Templates
```

Layers:

1. **Connection** — HTTP transport only: auth, timeouts, JSON and multipart, `429` retry when `Retry-After` present, raises `ApiError` with status + body.
2. **Resources::Envelopes** — `create`, `get`, `distribute`, `download` (signed via envelope item id).
3. **Resources::Templates** — `use` against `POST /envelope/use` with correct multipart payload.
4. **Envelope / Recipient POROs** — parse JSON; expose `id`, `status`, `signing_url`, etc.
5. **Model concern** — orchestration only; persists tracking columns; returns `Envelope`.
6. **Webhooks** — existing controller/job; completed path uses `client.envelopes.download`.

Out of scope: cancel/resend/list endpoints, multi-model registry, Faraday/HTTParty.

## Public API

### Configuration

Unchanged shape: `base_url`, `api_key`, `webhook_secret`, `model_class_name`, `unsigned_attachment_name`, `signed_attachment_name`, `redirect_url`.

### Client

```ruby
client.envelopes.create(file_io:, filename:, title:, recipients:, redirect_url: nil)
client.envelopes.get(id)
client.envelopes.distribute(id)
client.envelopes.download(id, version: :signed)

client.templates.use(
  envelope_id:,
  recipients:,          # [{ id:, email:, name: }]
  prefill_fields: [],   # [{ id:, type:, value: }]
  title: nil,
  redirect_url: nil,
  distribute: true
)
```

Field mapping: Ruby `position_x` / `position_y` → API `positionX` / `positionY`. Field `identifier` defaults to `0` (file index), not signer index.

### Model

```ruby
send_for_signature!(...)
send_for_multiple_signatures!(...)
send_from_template!(template_id:, ...)  # template_id maps to envelopeId
```

Each returns an `Envelope` (breaking vs bare id string). Persist `documenso_envelope_id` + `signature_status` / timestamps as today.

## Errors

- `DocumensoRails::Error` base
- `DocumensoRails::ApiError` with `status_code`, `body`
- Retry up to 2 times on `429` when `Retry-After` is present
- Model raises if unsigned attachment missing when sending from PDF

## Webhooks

- Route: `POST /documenso/webhook`
- Header: `X-Documenso-Secret`
- Status map unchanged (`DOCUMENT_*` → local statuses)
- `DOCUMENT_COMPLETED`: download signed PDF via envelopes resource, attach, set completed timestamp
- Instrument `documenso.<event>`

## Install generator

- Initializer, migration, mount engine (existing)
- When model file exists, ensure `include DocumensoRails::Model` and Active Storage attachments; otherwise document in README

## Testing

- Fix dummy app (`config.ru`, `config.root`, `environments/test.rb`) so `Rails.root` is `spec/dummy`
- Specs assert real Documenso request shapes
- Cover connection errors, envelope CRUD-ish flow, template use, model, webhook request + job

## Packaging / docs

- Version `0.2.0`
- Gemspec: remove “Production” claim; add MIT license
- README: configure, send, templates, webhook URL, return values

## Breaking changes

- Send methods return `Envelope` instead of id string
- Template / prefill argument shapes align to API v2
- Intended for pre-1.0 rewrite
