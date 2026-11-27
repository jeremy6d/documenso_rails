ENV["RAILS_ENV"] = "test"
require_relative "dummy/config/environment"
require "rspec/rails"
require "spec_helper"

ActiveRecord::Schema.define do
  create_table :active_storage_blobs, force: true do |t|
    t.string   :key,          null: false
    t.string   :filename,     null: false
    t.string   :content_type
    t.text     :metadata
    t.string   :service_name, null: false
    t.bigint   :byte_size,    null: false
    t.string   :checksum
    t.datetime :created_at,   null: false
    t.index [:key], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string     :name,     null: false
    t.references :record,   null: false, polymorphic: true, index: false
    t.references :blob,     null: false
    t.datetime   :created_at, null: false
    t.index [:record_type, :record_id, :name, :blob_id], name: :index_active_storage_attachments_uniqueness, unique: true
  end

  create_table :active_storage_variant_records, force: true do |t|
    t.belongs_to :blob, null: false, index: false
    t.string :variation_digest, null: false
    t.index [:blob_id, :variation_digest], name: :index_active_storage_variant_records_uniqueness, unique: true
  end

  create_table :legal_documents, force: true do |t|
    t.string   :title
    t.string   :documenso_envelope_id
    t.string   :signing_url
    t.string   :signature_status, default: "draft", null: false
    t.datetime :signature_sent_at
    t.datetime :signature_completed_at
    t.timestamps
  end
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.include ActiveJob::TestHelper

  config.before(:each) do
    ActiveStorage::Current.url_options = { host: "https://example.com" }
    DocumensoRails.configure do |c|
      c.base_url                 = "https://app.documenso.com/api/v2"
      c.api_key                  = "api_test_token_123"
      c.webhook_secret           = "super_secret_webhook_token"
      c.model_class_name         = "LegalDocument"
      c.unsigned_attachment_name = :unsigned_pdf
      c.signed_attachment_name   = :signed_pdf
      c.redirect_url             = nil
    end
  end
end
