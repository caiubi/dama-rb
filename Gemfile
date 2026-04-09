source "https://rubygems.org"

gemspec

group :development, :test do
  gem "capybara", "~> 3.40", require: false
  gem "chunky_png", "~> 1.4", require: false
  gem "cuprite", "~> 0.17", require: false
  gem "rackup", "~> 2.2", require: false
  gem "rspec", "~> 3.13"
  gem "rubocop", "~> 1.75", require: false
  gem "rubocop-rspec", "~> 3.6", require: false
  gem "ruby_wasm", "~> 2.8"
  gem "simplecov", "~> 0.22", require: false

  # Optional runtime dependencies needed for release packaging and web builds.
  # These are not required by the core gem, only by `dama release` and `dama web`.
  gem "ruby-macho", "~> 5.0"
  gem "rubyzip", "~> 2.4"
  gem "webrick", "~> 1.9"
end
