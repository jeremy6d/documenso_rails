require_relative "lib/documenso_rails/version"

Gem::Specification.new do |spec|
  spec.name                  = "documenso_rails"
  spec.version               = DocumensoRails::VERSION
  spec.authors               = ["Jeremy Weiland"]
  spec.summary               = "Production Rails Engine & API v2 client for Documenso Cloud"
  spec.license               = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir["{app,config,lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]
  spec.add_dependency "rails", ">= 7.0"

  spec.add_development_dependency "rspec-rails", "~> 6.1"
  spec.add_development_dependency "sqlite3", ">= 1.4"
  spec.add_development_dependency "webmock", "~> 3.23"
end
