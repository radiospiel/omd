require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "rb-fsevent", require: false
  gem "simple-cli", "~> 0.3.13", require: false
end

require "fileutils"
require "benchmark"
require "tmpdir"
require "open3"
require "digest"
require "pstore"
