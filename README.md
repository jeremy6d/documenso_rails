# DocumensoRails

A mountable Rails Engine and API v2 client for integrating Documenso (Cloud or self-hosted) into a Ruby on Rails application.

## Installation

1. Add `documenso_rails` to your `Gemfile` (e.g., placed inside `vendor/gems/documenso_rails`):
   ```ruby
   gem "documenso_rails", path: "vendor/gems/documenso_rails"
   ```
2. Run the generator:
   ```bash
   bundle install
   rails g documenso_rails:install LegalDocument
   rails db:migrate
   ```
3. Include `DocumensoRails::Model` in your model:
   ```ruby
   class LegalDocument < ApplicationRecord
     include DocumensoRails::Model
     has_one_attached :unsigned_pdf
     has_one_attached :signed_pdf
   end
   ```

## Running Tests

```bash
bundle install
bundle exec rspec
```
