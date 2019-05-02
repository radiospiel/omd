#!/usr/bin/env ruby

require "bundler/inline"

# rubocop:disable Layout/MultilineMethodCallIndentation
# rubocop:disable Style/GuardClause
gemfile do
  source "https://rubygems.org"
  gem "rb-fsevent", require: false
  gem "simple-cli", require: false
end

require "simple-cli"
require "fileutils"
require "benchmark"
require "tmpdir"
require "open3"

module OMD
end

module OMD::CLI
  include ::Simple::CLI

  # Watch src directory, and rebuild into dest directory
  def watch(src, dest, clean: false, display: true)
    # -- check src and dest paths ---------------------------------------------

    raise "#{src}: missing or not a file" unless File.exist?(src) && File.file?(src)
    raise "#{dest}: must be a directory"  if File.exist?(dest) && !File.directory?(dest)

    src = File.expand_path(src)
    dest = File.expand_path(dest)
    FileUtils.rm_rf(dest) if clean
    FileUtils.mkdir_p(dest)

    # -- process once (so that we are up to date)

    dest = File.join dest, File.basename(src)
    OMD.process(src, dest)
    system "open", "-a", "Marked 2", dest if display

    # -- watch directories, and rebuild on changes ----------------------------

    require "rb-fsevent"
    fsevent = FSEvent.new
    fsevent.watch [__dir__, File.dirname(src)], latency: 0.1 do |dirs, event_meta|
      next unless detected_change?(dirs, event_meta, src_dir: File.dirname(src))

      OMD.process(src, dest)
    end
    fsevent.run
  end

  private

  def detected_change?(dirs, _event_meta, src_dir:)
    logger.debug "Detected change in", dirs.join(",")

    if dirs.any? { |dir| dir.start_with?(__dir__) }
      logger.info "reloading", __FILE__
      load __FILE__
      return true
    end

    if dirs.any? { |dir| dir.start_with?(src_dir) }
      return true
    end
  end
end

module OMD
  extend self

  def logger
    OMD::CLI.logger
  end

  class Writer
    def self.open(path)
      writer = new path
      yield writer
    ensure
      writer.close if writer
    end

    def initialize(path)
      @dir = File.dirname(path)
      @fd = File.open path, "w"
    end

    def close
      @fd.close
      @fd = nil
    end

    def line(line)
      @fd.puts line
    end

    def error(body)
      code_block body, lang: "error"
    end

    def code_block(body, lang: nil)
      @fd.puts <<~MD
        ```#{lang}
        #{body.chomp}
        ```
      MD
    end
  end

  # Process one or more input files, put results into dest
  def process(src, dest)
    logger.info "Processing #{src}"

    processing_time = nil

    Writer.open dest do |writer|
      processing_time = Benchmark.realtime do
        input = File.open src

        # read file line by line. Extract and yield omd blocks
        while (line = input.gets)
          unless line =~ /^```{\s*(.*)\s*}\s*$/
            writer.line(line)
            next
          end

          omd_args = Regexp.last_match(1)
          # read until end of omd block
          code_block = []
          while (line = input.gets)
            break if line.start_with?("```")

            code_block << line
          end

          code_block = code_block.join("")
          code_block = unintend(code_block)

          process_omd(omd_args, code_block, writer: writer)
        end
      end
    end

    logger.info "generated #{dest} from #{src}: #{"%.3f secs" % processing_time}"
  end

  def unintend(code_block)
    code_block = code_block
      .split("\n")

    number_of_leading_spaces = code_block
      .map { |line| line =~ /^( +)/ && $1 }
      .map(&:length)
      .min

    code_block
      .map { |line| line =~ /^ / ? l[number_of_leading_spaces..-1] : l }
      .map { |l| "#{l}\n" }.join
  end

  class ShellError < RuntimeError; end

  module H
    extend self

    def sh!(cmd)
      OMD.logger.debug "Running #{cmd}"
      stdout_str, stderr_str, status = Open3.capture3(cmd)
      return stdout_str if status.exitstatus == 0

      raise ShellError, stderr_str
    end
  end

  module Processors
    extend self

    def comment(intro, code_block, writer:); end

    def dot(_intro, code_block, writer:)
      File.open("omd.dot", "w") do |io|
        io.write(code_block)
      end

      H.sh! "dot -Tpng -Gsize=16,16\! -Gdpi=72  -o dot.png omd.dot"

      outpath = "/Users/eno/projects/omd/dest/outpath.png"
      FileUtils.cp "dot.png", outpath
      writer.line "![dot](./outpath.png)"
    end

    def cc(_intro, code_block, writer:)
      writer.code_block code_block, lang: "c"

      File.open("omd.cc", "w") do |io|
        io.write(code_block)
      end

      H.sh! "cc -Wall omd.cc"

      success = H.sh! "./a.out 10"
      writer.code_block success
    end
  end

  def process_omd(intro, code_block, writer:)
    logger.warn "intro", intro

    if Processors.respond_to?(intro)
      Dir.mktmpdir do |tmpdir|
        Dir.chdir tmpdir do
          Processors.send intro, intro, code_block, writer: writer
        rescue ShellError
          writer.error($!.to_s)
        end
      end
    else
      writer.error "Unsupported omd processor #{intro.inspect}"
    end
  end
end

unless $loaded
  $loaded = true
  OMD::CLI.run!(*ARGV)
end
