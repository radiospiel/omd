module OMD::Core; end

require_relative "core/cache"
require_relative "core/writer"
require_relative "core/file_reader"

module OMD::Core
  extend self

  def dest_data_dir(dest)
    dirname, basename = File.dirname(dest), File.basename(dest)
    File.join(dirname, "#{basename}.data")
  end

  private

  def check_paths(src)
    dest = "#{src.gsub(/\.[^.]*$/, "")}.md"

    raise "#{src} and #{dest} files must differ" unless src != dest
    raise "#{src}: missing or not a file" unless File.exist?(src) && File.file?(src)
    raise "#{dest}: cannot be a directory" if File.exist?(dest) && File.directory?(dest)

    src = File.expand_path(src)
    dest = File.expand_path(dest)

    raise "input and output file must be in the same directory" if File.dirname(src) != File.dirname(dest)

    [src, dest]
  end

  def prepare_destination(dest, clean:)
    FileUtils.rm_rf(dest_data_dir(dest)) if clean
    FileUtils.mkdir_p(dest_data_dir(dest))
  end

  public

  # Process one or more input files, put results into dest
  def process(src, clean:)
    src, dest = check_paths(src)
    prepare_destination(dest, clean: clean)

    return if File.exist?(dest) && File.mtime(src) < File.mtime(dest) && OMD::Loader.mtime < File.mtime(dest)

    processing_time = nil

    Writer.open(dest) do |writer|
      processing_time = Benchmark.realtime do
        file_reader = FileReader.open src

        # read file line by line. Extract and yield omd blocks.
        #
        # omd blocks begin with three backticks, followed by omd arguments
        # in curly braces.
        while (token = file_reader.read_next_token)
          case token
          when FileReader::CodeBlock
            # print code block. If the code block
            print_code_block(token, writer: writer)

            writer.transaction(token) do
              process_code_block(file_reader, token, writer: writer)
            end
          when FileReader::PlainInputLine
            writer.line(token)
          end
        end
      end
    end

    OMD.logger.info "#{File.shortpath src}: generated #{File.shortpath dest}: #{"%.3f secs" % processing_time}"
  rescue StandardError
    OMD.logger.error "#{File.shortpath src}: could not generate #{File.shortpath dest}"
    raise
  end

  class ShellError < RuntimeError; end

  def print_code_block(code_block, writer:)
    omd_args = code_block.args

    return if omd_args =~ /^@/
    return if omd_args =~ /^comment/

    lang = $1 if omd_args =~ /^@?(\S+)/

    # lines starting with "@" will be hidden.
    printable_code_block = code_block.body.gsub(/^@[^\n]*\n/, "")

    # remove leading and trailing empty lines.
    printable_code_block = printable_code_block
      .gsub(/\A\n+/, "")
      .gsub(/\n+\z/, "")

    writer.code_block(printable_code_block, lang: lang)
  end

  def process_in_dir(run_in_tmp_dir:, &block)
    return yield unless run_in_tmp_dir

    Dir.mktmpdir do |tmpdir|
      Dir.chdir tmpdir, &block
    end
  end

  # most languages are running inside a temp dir. bash isn't -
  # because we assume that a bash script might want to access
  # some local resources.
  unless defined?(LANGS_NOT_RUNNING_IN_TMP_DIR)
    LANGS_NOT_RUNNING_IN_TMP_DIR = %w[bash].freeze
  end

  def process_code_block(file_reader, code_block, writer:)
    intro = code_block.args
    intro.gsub!(/^@\s*/, "")
    lang, *filters = intro.split(/\s*\|\s*/)

    if !lang || !OMD::Processors.respond_to?(lang)
      writer.error "#{file_reader.location}: Unsupported omd processor #{lang.inspect}"
      return
    end

    OMD.logger.warn "#{file_reader.location}: processing #{intro.inspect} block"

    # Some commands are running inside a temp dir.
    run_in_tmp_dir = !LANGS_NOT_RUNNING_IN_TMP_DIR.include?(lang)

    process_in_dir(run_in_tmp_dir: run_in_tmp_dir) do
      code = code_block.body.gsub(/^@\s*/, "")
      OMD::Processors.send lang, filters, code, writer: writer
    end
  end
end
