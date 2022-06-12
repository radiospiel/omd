class OMD::Writer
  def self.open(path)
    # tmp_name = "#{path}.#{$$}"
    writer = new(OMD.dest_data_dir(path), path)
    yield writer
    # File.rename(tmp_name, path)
  ensure
    if writer
      writer.close
    end
  end

  def initialize(dir, path)
    @fd = File.open(path, "w")
    @dir = dir
    @changes = []
    @cache = ::OMD::Cache.new(@dir)
  end

  def close
    apply_changes

    @fd.close
    @fd = nil
  end

  def transaction(*args)
    apply_changes

    begin
      changes = @cache.cached(*args) do
        yield
        @changes
      end
      @changes = changes
    rescue IncompleteTransaction
      @changes = []
      yield
      @changes = changes
    end

    apply_changes
  end

  # -- basic ops ------------------------------------------------------------
  # basic ops are caught in the transaction.

  def line(line)
    @changes << [:line, line]
  end

  def code_block(body, lang: nil)
    @changes << [:code_block, body, lang]
  end

  # -- secondary ops --------------------------------------------------------
  # secondary ops are built off basic ops

  class IncompleteTransaction < RuntimeError; end

  def copy_file(path)
    unless File.exist?(path)
      raise IncompleteTransaction, "copy_file: missing file #{path}"
    end

    digest = Digest::MD5.hexdigest File.read(path)
    dest_file = File.join(@dir, "#{digest}#{File.extname(path)}")
    FileUtils.mkdir_p @dir
    FileUtils.cp(path, dest_file)
    OMD.logger.debug "copy_file #{path} -> #{dest_file}"

    File.join(File.basename(@dir), File.basename(dest_file))
  end

  def image(src, alt: nil)
    OMD.logger.debug "image #{src.inspect}"

    dest_path = copy_file(src)
    line "![#{alt}](./#{dest_path})"
  end

  def error(body)
    code_block body, lang: "error"
  end

  def table(csv, separator:)
    csv.chomp!
    csv = "|#{csv.gsub("\n", "|\n|")}|"
    csv = csv.gsub(separator, " | ")

    # | Tables   |      Are      |  Cool |
    # |----------|:-------------:|------:|
    #
    # | col 1 is |  left-aligned | $1600 |
    # | col 2 is |    centered   |   $12 |
    # | col 3 is | right-aligned |    $1 |

    header, rest = csv.split("\n", 2)
    line(header)
    sep = header.gsub(/./) { |ch| ch == "|" ? "|" : "-" }
    line(sep)

    line(rest)
  end

  private

  # this method is used for transaction.
  def apply_changes
    @changes.each do |change, *args|
      case change
      when :line
        line, = *args
        @fd.puts line
      when :code_block
        body, lang = *args
        @fd.puts <<~MD
          ```#{lang}
          #{body.chomp}
          ```
        MD
      end
    end
    @changes = []
  end
end
