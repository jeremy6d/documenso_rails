# DocumensoRails Client Rewrite Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite the Documenso Rails gem with a resource-oriented API v2 client, correct download/template flows, green specs, and light install/README polish.

**Architecture:** Layered `Connection` + `Resources::Envelopes` / `Resources::Templates` + `Envelope`/`Recipient` POROs; Model concern orchestrates; webhooks use the new download path. See `docs/plans/2026-11-13-client-rewrite-design.md`.

**Tech Stack:** Ruby ≥ 3.1, Rails ≥ 7 engine, Net::HTTP, ActiveJob, ActiveStorage, RSpec + WebMock

**Reference docs:** https://docs.documenso.com/docs/developers/getting-started/first-api-call , https://docs.documenso.com/docs/developers/api/templates , https://docs.documenso.com/docs/developers/examples/common-workflows

---

### Task 1: Fix dummy Rails app so the suite boots

**Files:**
- Create: `spec/dummy/config.ru`
- Create: `spec/dummy/config/environments/test.rb`
- Modify: `spec/dummy/config/application.rb`
- Create: `spec/dummy/config/storage.yml` (minimal test disk service if needed)

**Step 1: Add config.ru**

```ruby
# spec/dummy/config.ru
require_relative "config/environment"
run Rails.application
```

**Step 2: Set application root and test env**

In `spec/dummy/config/application.rb`, inside `Dummy::Application`:

```ruby
config.root = File.expand_path("..", __dir__)
```

Create `spec/dummy/config/environments/test.rb`:

```ruby
Dummy::Application.configure do
  config.enable_reloading = false
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.allow_forgery_protection = false
  config.active_storage.service = :test
  config.active_job.queue_adapter = :test
end
```

**Step 3: Verify Rails.root**

Run:

```bash
cd /Users/jeremyweiland/src/documenso_rails
bundle exec ruby -e 'ENV["RAILS_ENV"]="test"; require_relative "spec/dummy/config/environment"; puts Rails.root; puts File.exist?(Rails.root.join("config/database.yml"))'
```

Expected: path ends with `spec/dummy` and `true`.

**Step 4: Commit**

```bash
git add spec/dummy
git commit -m "test: fix dummy app so Rails.root resolves"
```

---

### Task 2: Errors + Connection (TDD)

**Files:**
- Create: `lib/documenso_rails/errors.rb`
- Create: `lib/documenso_rails/connection.rb`
- Create: `spec/lib/documenso_rails/connection_spec.rb`
- Modify: `lib/documenso_rails.rb` (require errors)

**Step 1: Write failing connection specs**

```ruby
# spec/lib/documenso_rails/connection_spec.rb
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
```

**Step 2: Run to verify fail**

```bash
bundle exec rspec spec/lib/documenso_rails/connection_spec.rb
```

Expected: fail (uninitialized constant / missing class).

**Step 3: Implement errors + connection**

```ruby
# lib/documenso_rails/errors.rb
module DocumensoRails
  class Error < StandardError; end

  class ApiError < Error
    attr_reader :status_code, :body

    def initialize(message, status_code:, body:)
      super(message)
      @status_code = status_code
      @body = body
    end
  end
end
```

Connection responsibilities:
- `get(path)`, `post_json(path, payload)`, `post_multipart(path, payload_hash, files:)`
- Authorization header = raw api_key
- open_timeout 10, read_timeout 30
- On non-success: raise `ApiError`
- On 429 with Retry-After: sleep (use `0` in tests), retry up to 2 additional attempts
- JSON parse when Content-Type JSON or body looks like JSON; for binary download add `get_raw(path)` returning body string

Also update `lib/documenso_rails.rb`: remove old `Error`/`ApiError` inline defs; `require "documenso_rails/errors"`.

**Step 4: Run specs — pass**

```bash
bundle exec rspec spec/lib/documenso_rails/connection_spec.rb
```

**Step 5: Commit**

```bash
git add lib/documenso_rails/errors.rb lib/documenso_rails/connection.rb lib/documenso_rails.rb spec/lib/documenso_rails/connection_spec.rb
git commit -m "feat: add Connection and typed ApiError"
```

---

### Task 3: Envelope / Recipient POROs (TDD)

**Files:**
- Create: `lib/documenso_rails/envelope.rb`
- Create: `lib/documenso_rails/recipient.rb`
- Create: `spec/lib/documenso_rails/envelope_spec.rb`

**Step 1: Failing spec**

```ruby
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
```

**Step 2: Run — fail; Step 3: implement `from_api`; Step 4: pass; Step 5: commit**

```bash
git commit -m "feat: add Envelope and Recipient value objects"
```

---

### Task 4: Resources::Envelopes (TDD)

**Files:**
- Create: `lib/documenso_rails/resources/envelopes.rb`
- Create: `spec/lib/documenso_rails/resources/envelopes_spec.rb`
- Delete or gut later: old `lib/documenso_rails/client.rb` methods (replaced in Task 6)

**Step 1: Write failing specs covering create / get / distribute / download**

Key assertions:
- `create` POSTs multipart to `/envelope/create` with payload type DOCUMENT, recipients, fields using `positionX`/`positionY`, `identifier: 0`
- `get` GET `/envelope/:id`
- `distribute` POST JSON `{ envelopeId: }` to `/envelope/distribute`, returns Envelope with signing URLs from response
- `download` GET `/envelope/:id` then GET `/envelope/item/:itemId/download?version=signed` using `envelopeItems[0].id`

Example download stubs:

```ruby
stub_request(:get, "https://app.documenso.com/api/v2/envelope/env_1")
  .to_return(body: { id: "env_1", status: "COMPLETED", envelopeItems: [{ id: "item_9" }] }.to_json)
stub_request(:get, "https://app.documenso.com/api/v2/envelope/item/item_9/download?version=signed")
  .to_return(body: "%PDF-signed")
```

**Step 2: Run — fail**

**Step 3: Implement `DocumensoRails::Resources::Envelopes`** taking a `Connection` in `initialize`

**Step 4: Pass; Step 5: Commit**

```bash
git commit -m "feat: add Envelopes resource with correct download path"
```

---

### Task 5: Resources::Templates (TDD)

**Files:**
- Create: `lib/documenso_rails/resources/templates.rb`
- Create: `spec/lib/documenso_rails/resources/templates_spec.rb`

**Step 1: Failing spec**

Assert `POST /envelope/use` is multipart with payload JSON containing:
- `envelopeId` (not `templateId`)
- `recipients` with required `id`, `email`, `name`
- `prefillFields` as `[{ id:, type:, value: }]`
- `distributeDocument: true` when `distribute: true`
- optional `override` / `meta` for title/redirect if supported; prefer documenting `title` via override only if docs require — match Templates API payload fields from design (`title` may live at top level only if still accepted; prefer `envelopeId` + recipients + prefill + distributeDocument as required)

Use WebMock `.with { |req| ... }` to parse multipart body or match Content-Type multipart.

**Step 2–5:** implement, pass, commit

```bash
git commit -m "feat: add Templates#use matching Documenso v2"
```

---

### Task 6: New Client facade + wire requires

**Files:**
- Replace: `lib/documenso_rails/client.rb`
- Modify: `lib/documenso_rails.rb`
- Modify: `lib/documenso_rails/version.rb` → `0.2.0`
- Modify: `documenso_rails.gemspec` (summary, license MIT)
- Update/remove: `spec/lib/documenso_rails/client_spec.rb` → thin facade smoke test or delete in favor of resource specs

**Step 1: Spec**

```ruby
it "exposes envelopes and templates resources" do
  client = DocumensoRails::Client.new(base_url: "...", api_key: "...")
  expect(client.envelopes).to be_a(DocumensoRails::Resources::Envelopes)
  expect(client.templates).to be_a(DocumensoRails::Resources::Templates)
end
```

**Step 2–4:** implement

```ruby
module DocumensoRails
  class Client
    def initialize(base_url:, api_key:)
      @connection = Connection.new(base_url: base_url, api_key: api_key)
    end

    def envelopes
      @envelopes ||= Resources::Envelopes.new(@connection)
    end

    def templates
      @templates ||= Resources::Templates.new(@connection)
    end
  end
end
```

**Step 5: Commit**

```bash
git commit -m "feat: replace Client with resource facade (v0.2.0)"
```

---

### Task 7: Rewrite Model concern (TDD)

**Files:**
- Modify: `lib/documenso_rails/model.rb`
- Modify: `spec/lib/documenso_rails/model_spec.rb`

**Step 1: Update specs first (RED)**

- Missing PDF still raises
- `send_for_signature!` stubs `envelopes.create` + `envelopes.distribute` (or stub HTTP at resource paths)
- Expect return value responds to `id` / is `Envelope`
- Persist `documenso_envelope_id`, `signature_status: "sent"`, `signature_sent_at`
- `send_from_template!` uses templates.use with `envelope_id: template_id`, recipients with ids, prefill array

**Step 2: Run — fail against old model**

**Step 3: Rewrite model** to call new client resources; map DEFAULT_FIELDS to API field hashes with `identifier: 0`

**Step 4: Pass; Step 5: Commit**

```bash
git commit -m "feat: point Model concern at resource client"
```

---

### Task 8: Update webhook job + request specs

**Files:**
- Modify: `app/jobs/documenso_rails/process_webhook_job.rb`
- Modify: `spec/jobs/documenso_rails/process_webhook_job_spec.rb`
- Keep controller unless secure_compare edge cases need touch

**Step 1: Change download stub in job spec** to two-step get + item download (as Task 4)

**Step 2: Run — fail**

**Step 3: Job calls `DocumensoRails.client.envelopes.download(envelope_id)`**

**Step 4: Full suite green**

```bash
bundle exec rspec
```

Expected: all examples pass.

**Step 5: Commit**

```bash
git commit -m "fix: webhook completion download via envelope items"
```

---

### Task 9: Install generator + README

**Files:**
- Modify: `lib/generators/documenso_rails/install_generator.rb`
- Modify: `lib/generators/documenso_rails/templates/initializer.rb.tt` (drop LawPay-specific comment or make generic)
- Modify: `README.md`

**Step 1:** Generator: after migration/route, if `app/models/#{model_name.underscore}.rb` exists, insert `include DocumensoRails::Model` and attachment macros if missing; else `say` instructions.

**Step 2:** README sections: Installation, Configuration, Sending, Templates, Webhooks (`/documenso/webhook`), Return values, Running tests.

**Step 3: Commit**

```bash
git commit -m "docs: README and install generator for rewritten client"
```

---

### Task 10: Final verification

**Step 1:**

```bash
bundle exec rspec
```

All green, pristine output.

**Step 2:** Spot-check no remaining references to old paths:

```bash
rg "envelope/.*/download|templateId|create_and_send" lib app spec
```

Expected: no stale `/envelope/:id/download` or `templateId` in production code.

**Step 3: Final commit if any cleanup**

```bash
git commit -m "chore: remove leftover old client references"
```

---

## Execution notes

- Follow @superpowers:test-driven-development for every task with behavior change.
- Prefer WebMock on HTTP boundaries; avoid mocking internal resource classes in model specs when HTTP stubs suffice.
- Do not add Faraday or cancel/list/resend in this plan.
