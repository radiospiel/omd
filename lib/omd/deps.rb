require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "rb-fsevent", "~> 0.11", ">= 0.11.1", require: false
  gem "simple-cli", "~> 0.4", require: false
end

require "fileutils"
require "benchmark"
require "tmpdir"
require "open3"
require "digest"
require "pstore"
