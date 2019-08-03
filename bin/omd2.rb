#!/usr/bin/env ruby

begin
  require "bundler/inline"

  gemfile do
    source "https://rubygems.org"
    gem "rb-fsevent", require: false
    gem "simple-cli", require: false
    gem "expectation", require: false
    gem "ruby-filemagic", require: false
  end
rescue StandardError
  STDERR.puts <<~MSG
    ========================================================================================
    Cannot load some dependencies.

    This script requires a working bundler installation ("gem install bundler"). It also
    requires the presence of the libmagic library ("brew install libmagic"). The original
    error message follows here:
    ========================================================================================
    #{$!}
  MSG

  exit 1
end

require "simple-cli"
require "expectation"

require "fileutils"
require "benchmark"
require "tmpdir"
require "open3"
require "digest"
require "pstore"

# --- various helpers ---------------------------------------------------------

module OMD
  extend self

  def logger
    OMD::CLI.logger
  end

  # various helper functions
  module H
    extend self

    # return the OS type, as a Symbol :windows, :osx, :linux, :unix
    def os
      @os ||= begin
        require "rbconfig"
        host_os = RbConfig::CONFIG["host_os"]
        case host_os
        when /mswin|msys|mingw|cygwin|bccwin|wince|emc/ then :windows
        when /darwin|mac os/                            then :osx
        when /linux/                                    then :linux
        when /solaris|bsd/                              then :unix
        else                                            raise "unsupported OS #{host_os.inspect}"
        end
      end
    end

    # convert a string to a boolean
    def to_b(str)
      case str
      when nil then nil
      when "true", true then true
      when :false, "false", false then false
      else
        expect! str => [nil, "true", "false"]
      end
    end

    def shell_inspect(cmd, *args)
      ([cmd] + args).map { |s| Shellwords.shellescape(s) }.join(" ")
    end

    # run Open3.capture2/capture3, depending on verbosity level.
    #
    # In verbose mode we do not catch stderr, but let it print to the
    # original STDERR instead; i.e. we use capture2. Otherwise we collect
    # STDERR into a variable, and log it if the command fails, but ignore
    # it if all is well.
    def capture3(cmd, *args, env: nil, stdin_data: nil, verbose: OMD.logger.debug?)
      STDERR.puts "> #{shell_inspect cmd, *args}" if verbose

      env ||= {}

      if verbose
        stdout_str, status = Open3.capture2(env, cmd, *args, stdin_data: stdin_data, binmode: true)
        [stdout_str, nil, status]
      else
        Open3.capture3(env, cmd, *args, stdin_data: stdin_data, binmode: true)
      end
    end

    def sh(cmd)
      sh! cmd, raise_on_error: false
    end

    def sh!(cmd, raise_on_error: true)
      stdout_str, stderr_str, status = capture3(cmd)

      return stdout_str if status.exitstatus == 0
      return false unless raise_on_error

      error = "#{cmd} failed with exit status #{status.exitstatus}"
      error += ": error output: #{stderr_str}" if stderr_str != ""
      raise error
    end

    def with_runtime_log(msg)
      OMD.logger.info msg.to_s
      r = nil
      realtime = Benchmark.realtime { r = yield }
      OMD.logger.success "#{msg}: #{"%.3f secs" % realtime}"
      r
    end
  end

  module H
    @@cache = PStore.new(File.join(Dir.getwd, ".omd2.pstore"))
    @@cache.ultra_safe = true
    
    def cached(*keys, &block)
      # key = Digest::MD5.hexdigest(OMD::SourceVersion.source_version + ":" + parts.join(","))
      key = Digest::MD5.hexdigest(keys.join(","))

      @@cache.transaction do
        @@cache[key] ||= yield
      end
    end
  end
end

require "shellwords"

class File
  def self.write(path, body, permissions: nil)
    # [TODO] should this be binary, somehow?
    File.open(path, "w") do |io|
      io.write(body)
    end

    # [TODO] could this be a parameter to File.open above?
    File.chmod(permissions, path) if permissions

    path
  end
end

module Enumerable
  def self.split(enumerable, separator)
    enumerable.each_with_object([[]]) do |e, ary|
      if e == separator
        ary << []
      else
        ary.last << e
      end
    end
  end
end

# --- omd starts here ---------------------------------------------------------

module OMD::CLI
  extend self
  include ::Simple::CLI

  H = OMD::H

  # Process an OMD file
  def process(file)
    data = File.read(file)

    H.with_runtime_log "Processing #{file}" do
      Processors.process_configurations(data)

      missing_modes = Processors.missing_modes(data)
      unless missing_modes.empty?
        die! <<~MSG
          Some modes (#{missing_modes.join(", ")}) are not properly installed, aborting...

          Please run 'omd modes:install #{file}' to install missing modes.
        MSG
      end

      Processors.process(data)
    end
  end

  module Target
    extend self

    def open
      File.open "target.md", "w" do |out|
        @out = out
        @data_dir = "target.md.data"
        FileUtils.mkdir_p @data_dir
        yield
      ensure
        @out = nil
      end
    end

    def write(data)
      @out.puts data
    end

    def add_source(text, source_type:)
      add_text_plain text, source_type: source_type
    end

    def add(mime_type, data, alt:)
      if mime_type == :auto
        mime_type = determine_type(data)
      end

      case mime_type
      when "text/plain"
        add_text_plain(data)
      when "image/png", "image/jpeg"
        dest_path = @data_dir + "/" + Digest::MD5.hexdigest(data) + ".png"
        File.write dest_path, data
        write "![#{alt}](#{dest_path})"
      else
        add_text_plain <<~MARKDOWN
          > Don't know how to embed a #{mime_type.inspect} block.
        MARKDOWN
      end
    end

    def determine_type(data)
      require "filemagic"
      mime_type, _encoding = FileMagic.mime.buffer(data).split(";", 2)
      mime_type
    end

    def add_text_plain(data, source_type: nil)
      data = data.gsub(/\n\z/, "")

      write <<~RESULT
        ```#{source_type}
        #{data}
        ```

      RESULT
    end
  end

  module Runner
    extend self

    def run!(omd_command, body, silent:)
      return if omd_command =~ /^!/

      # print source for block.
      print_block_input(omd_command, body) unless silent

      # run the block.
      result_type, result_data = H.cached(Registry.cache_key, omd_command, body) do
        run_uncached(omd_command, body)
      end

      # print result.
      Target.add(result_type, result_data, alt: omd_command)
    end

    private

    def print_block_input(omd_command, body)
      parts = Shellwords.shellsplit(omd_command)
      pipeline = Enumerable.split(parts, "|")

      mode = Registry[pipeline.first.first]

      #
      # If ignore_empty_lines is set (which is the default), remove all lines
      # starting with "@", then remove all leading and trailing empty lines.
      #
      if mode.flag(:ignore_empty_lines)
        body = body.gsub(/^@.*/, "").gsub(/\A\n*/, "").gsub(/\n*\z/, "")
      end

      #
      # send block to Target
      Target.add_source(body, source_type: mode.flag(:source_type))
    end

    def run_uncached(omd_command, body)
      silence = omd_command.gsub!(/^@/, "") != nil
      return if silence

      # omd_command contains a string with the commands for the omd processing
      # pipe for the current block; for example "@sql | plot lines"; convert
      # this into a pipeline.
      parts = Shellwords.shellsplit(omd_command)
      pipeline = Enumerable.split(parts, "|")

      mode = Registry[pipeline.first.first]

      # To run the pipeline we remove the '@' markers from all lines in the body
      # - but in contrast to echo_body we'll keep the rest of these lines, and
      # we do not skip over empty lines at all.
      input_data = body
      input_data = input_data.gsub(/^@/, "") if mode.flag(:ignore_empty_lines)

      # run the pipeline
      run_pipeline(pipeline, [:auto, input_data])
    end

    def run_pipeline(pipeline, data)
      pipeline.inject(data) do |input, (mode_name, *args)|
        H.with_runtime_log "Running #{H.shell_inspect mode_name, *args}" do
          run_stage mode_name, *args, input: input
        end
      end
    end

    # runs a stage. The stage is defined by the mode_name, optional arguments,
    # and the input data. It returns a result.
    #
    # input and result are a [content_type, blob] tuple. If a stage wants to
    # handle input types they should use the OMD_INPUT_TYPE environment
    # variable.
    #
    def run_stage(mode_name, *args, input:)
      mode = Registry[mode_name]

      in_target_dir(mode) do
        sh_file = File.join Dir.getwd, "omd.sh.#{$$}"

        with_tmp_files([sh_file]) do
          File.write sh_file, mode.command(:run), permissions: 0o700

          input_type, input_data = *input

          env = { "OMD_INPUT_TYPE" => input_type.to_s }

          stdout_str, stderr_str, status = ::OMD::H.capture3("./omd.sh.#{$$}", *args, stdin_data: input_data, env: env)

          if status.exitstatus == 0
            [:auto, stdout_str]
          else
            OMD.logger.error "#{mode} failed with exitstatus #{status.exitstatus}."
            OMD.logger.warn(stderr_str) if stderr_str != ""
            OMD.logger.warn "=== command output:\n#{stdout_str}" if stdout_str != ""

            result = []
            result << "=== #{mode} failed with exitstatus #{status.exitstatus}."
            result << "--- command output:\n#{stdout_str}" if stdout_str != ""
            result << "--- error output:\n#{stderr_str}" if stderr_str != ""
            result << ""
            result = result.join("\n")

            [:auto, result]
          end
        end
      end
    end

    def in_target_dir(mode)
      if mode.flag(:tmp_dir)
        Dir.mktmpdir do |tmpdir|
          OMD.logger.debug "chdir #{tmpdir}"
          Dir.chdir tmpdir do
            yield
          end
        end
      else
        yield
      end
    end

    def with_tmp_files(files)
      yield
    ensure
      files.each do |path|
        File.unlink(path)
      end
    end
  end

  # A Mode description
  #
  # ...collects information about various aspects of a mode.
  #
  # For example, the "cc" default mode (as defined towards the end of this file,
  # see the part after __END__) describes cc mode with these attributes:
  #
  # - <tt>:check</tt>: commands to check that the mode is available: "which cc"
  # - <tt>:install</tt>: commands to install the reprequisites for this mode: "brew install gcc"
  # - <tt>:run</tt>: commands to convert the input data (which has to be read from stdin)
  #          into the result of this mode (in stdout)
  # - <tt>:source_type</tt> a string which will be used to mark the input source
  #
  # A mode can be run via <tt>run_mode(mode, silent)</tt>
  #
  # The mode registry can be viewed via the command line via
  #
  #    omd modes [<name> ..]
  class Mode
    H = ::OMD::H

    attr_reader :name
    attr_reader :flags
    attr_reader :commands

    def initialize(name)
      @name = name
      @commands = {}

      @flags = defaults_flags
    end

    def defaults_flags
      {
        "ignore_empty_lines" => true,
        "tmp_dir" => true,
        "source_type" => name
      }
    end

    def run(command_name)
      H.sh command(command_name)
    end

    def command(name)
      commands["#{name}.#{H.os}"] || commands[name.to_s]
    end

    FLAGS = %w(ignore_empty_lines tmp_dir source_type).freeze

    def flag(name)
      flags[name.to_s]
    end

    def set_flag(name, value)
      expect! name => FLAGS

      value = nil if value == "null"
      value = H.to_b(value) if %w(ignore_empty_lines tmp_dir).include?(name)

      flags[name] = value
    end

    SECTIONS = %w(run check install).freeze

    def set_command(section_name, section)
      expect! section_name.split(".", 2).first => SECTIONS

      section = nil if section == ""
      expect! section_name.split(".", 2).first
      commands[section_name] = section
    end

    def description
      lines = []
      
      lines << "=== #{name} " + "=" * (70 - name.length) + "\n"
      lines << command("run")

      parts = []
      parts << ["omd:flags",    flags.pretty_inspect] unless flags.empty? || flags == defaults_flags
      parts << ["omd:check",    command("check")] if command("check")
      parts << ["omd:install",  command("install")] if command("install")

      parts.each do |section, data|
        lines << "--- #{section} " + "-" * (70 - section.length) + "\n"
        lines << data
      end
      
      lines.join("")
    end

    def print
      puts description
      puts
    end

    def to_s
      name
    end

    def inspect
      keys = (instance_variables - [:@name]).map { |s| s.inspect.gsub(/^:@/, ":") }
      "<Mode: #{name.inspect}, w/#{keys.join(", ")}>"
    end
  end

  module Processors
    extend self

    module Parsers
      extend self

      # Parse an omd data blob. Returns an array of [ omd_mode, data ] tuples
      def parse_omd(data)
        current_mode = "passthrough"
        current_block = []

        data.each_line do |line|
          break if line == "__END__\n"

          # rubocop:disable Style/IfInsideElse
          if current_mode != "passthrough"
            if line =~ /^```\n/
              yield current_mode, current_block.join
              current_block = []
              current_mode = "passthrough"
            else
              current_block << line
            end
          else
            if line =~ /^```{\s*(.*)\s*}\n/
              yield current_mode, current_block.join
              current_block = []
              current_mode = $1
            else
              current_block << line
            end
          end
          # rubocop:enable Style/IfInsideElse
        end

        raise ArgumentError, "current_mode must be 'passthrough', but is #{current_mode.inspect}" if current_mode != "passthrough"

        yield current_mode, current_block.join unless current_block.empty?
      end

      # returns a Mode object
      def parse_configuration(body)
        current_mode = "run"
        current_block = []

        body.each_line do |line|
          case line
          when /^--- omd:(.+)$/
            yield current_mode, current_block.join

            current_mode = $1
            current_block = []
          else
            current_block << line
          end
        end

        yield current_mode, current_block.join
      end
    end

    def referenced_modes(data)
      modes = []

      Parsers.parse_omd(data) do |omd_command, _body|
        omd_mode, *_ = Shellwords.shellsplit omd_command
        next if respond_to?(omd_mode)
        next if omd_mode =~ /^!/

        omd_mode.gsub!(/^@/, "")

        modes << omd_mode
      end

      modes.compact.sort
    end

    def check_mode(mode_name)
      logger = OMD.logger

      unless (mode = Registry[mode_name])
        raise "The input uses a mode without definition: #{mode_name.inspect}"
      end

      if !mode.command(:check) || mode.run(:check)
        logger.debug "#{mode_name}: OK."
        return true
      end

      logger.error "#{mode_name}: check failed."
      false
    end

    def missing_modes(data)
      referenced_modes(data).reject { |mode_name| check_mode(mode_name) }
    end

    def process_configurations(data)
      Parsers.parse_omd(data) do |omd_command, body|
        silent = omd_command.start_with?("@")
        omd_command = omd_command[1..-1] if silent

        omd_mode, *args = Shellwords.shellsplit omd_command
        next unless omd_mode == "configure"

        configure(*args, body, silent: true)
      end
    end

    def process(data)
      Target.open do
        Parsers.parse_omd(data) do |omd_command, body|
          silent = omd_command.start_with?("@")
          omd_command = omd_command[1..-1] if silent

          omd_mode, *args = Shellwords.shellsplit omd_command

          if respond_to?(omd_mode)
            send(omd_mode, *args, body, silent: silent)
          else
            Runner.run!(omd_command, body, silent: silent)
          end
        end
      end
    end

    def passthrough(data, silent:)
      _ = silent
      Target.write data
    end

    # implements the <tt>{@configure|configure mode_name [ option ... ]}</tt>
    # command
    #
    # - mode_name: the name of the mode, e.g. "plantuml"
    # - args: additional flags, e.g. ["ignore_empty_lines:false", "tmp_dir:true"]
    # - body: mode definition, might contain multiple sections, for example
    #
    #               set -eu -o pipefail
    #               plantuml -failfast2 -pipe > omd.png
    #               ls -l $(pwd)
    #               --- omd:check
    #               which plantuml
    #               --- omd:install
    #               which javac || brew cask install adoptopenjdk
    #               brew install plantuml
    #
    def configure(mode_name, *args, body, silent:)
      mode = Mode.new(mode_name)

      unless silent
        Target.write <<~MARKDOWN

              ```{configure #{mode_name}}
          #{body.gsub(/\n\z/, "").gsub(/^/, "    ")}
              ```
        MARKDOWN
      end

      args.each do |arg|
        expect! arg => /.:./
        key, value = arg.split(":", 2)
        mode.set_flag key, value
      end

      # Register configuration sections in mode.
      Parsers.parse_configuration(body) do |section_name, section|
        mode.set_command(section_name, section)
      end
      OMD.logger.debug "parsed #{mode} configuration", mode

      Registry.register mode
    end
  end

  module Registry
    @@registry = {}

    def self.cache_key
      @@registry.values.sort_by(&:name).map(&:description).join(",")
    end

    def self.modes
      @@registry.values
    end

    def self.register(mode)
      @@registry[mode.name] = mode
    end

    def self.[](name)
      @@registry[name.to_s]
    end

    def self.load_embedded_configuration!(file)
      embedded_configuration = File.read(file).split("\n__END__\n").last
      Processors.process_configurations(embedded_configuration)
    end

    load_embedded_configuration! __FILE__
  end

  # print all modes in the Registry
  #
  # When a file is passed to this command, modes that are defined in the file
  # are considered in addition to the modes embedded in omd.
  def modes(file = nil)
    if file
      logger.info "Processing #{file}"
      Processors.process_configurations(File.read(file))
    end

    logger.info "Note that the commands listed below are relevant for the current platform (#{H.os}) only."

    Registry.modes.sort_by(&:name).each(&:print)
  end

  # check modes in a omd file
  #
  # Reads the file, collecting information about all required modes, and checks
  # that all modes are properly installed.
  def modes_check(file)
    data = File.read(file)
    return if Processors.missing_modes(data).empty?

    exit 1
  end

  # install all required modes in a omd file
  #
  # Reads the file, collecting information about all required modes, and installs
  # all missing modes.
  def modes_install(file)
    logger.info "Processing #{file}"
    Processors.process_configurations(File.read(file))

    data = File.read(file)
    Processors.missing_modes(data).each do |mode_name|
      Registry[mode_name].run(:install)
    end
  end
end

OMD::CLI.run!(*ARGV)

__END__

The remaining lines are processed by this script to load a collection of default configurations.

```{@configure cc}
set -eu -o pipefail
cat > omd.cc
cc -Wall -o omd omd.cc
./omd
--- omd:check
which cc
```

```{@configure java}
--- omd:check
which javac
--- omd:install
brew cask install adoptopenjdk
```

```{@configure plantuml ignore_empty_lines:false tmp_dir:true}
set -eu -o pipefail
plantuml -failfast2 -pipe
--- omd:check
which plantuml
--- omd:install.osx
which javac || brew cask install adoptopenjdk
brew install plantuml
```

```{@configure fortune}
fortune
--- omd:check
which fortune
--- omd:install.osx
brew install fortune
```

```{@configure mermaid}
cat > mmdc.css << EOF
* {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
}
EOF

cat > mmdc.in

mmdc -i mmdc.in -o mmdc.png --width 1600 --theme forest --cssFile mmdc.css
cat mmdc.png
--- omd:check
which mmdc
--- omd:install.osx
npm install -g mermaid
```

```{@configure figlet}
figlet
--- omd:check
which svgbob
--- omd:install.osx
brew install figlet
```

```{@configure fviz}
fviz
--- omd:check
which fviz
--- omd:install
set -eu -o pipefail

brew list || grep -w fmt > /dev/null fmt
brew list || grep -w harfbuzz > /dev/null harfbuzz
brew list || grep -w freetype > /dev/null freetype
brew list || grep -w cairo > /dev/null cairo
brew list || grep -w cmake > /dev/null cmake

# arena=$(mktemp -d)
arena=vendor/fviz
mkdir -p "$arena"
cd "$arena"
if [ -d fviz ]; then
  cd fviz
  git pull
else
  git clone https://github.com/asmuth/fviz.git
  cd fviz
fi
cmake .
make -j
make install
```
