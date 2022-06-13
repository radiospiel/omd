class OMD::Core::FileReader
  def self.open(file)
    new file
  end

  class CodeBlock
    START_REGEXP = /^```{\s*(.*)\s*}\s*$/.freeze
    END_REGEXP = /^```\s*$/.freeze

    attr_reader :args, :body, :code, :embedded_files

    def initialize(args, body, code, embedded_files)
      @args = args
      @body = body
      @code = code
      @embedded_files = embedded_files
    end

    def self.read(file_reader)
      # The first line contains the code block opening, in the form
      # "```{ some omd comment }". The following lines are body lines;
      # these are potentially separated by embedded file lines.
      #
      # An embedded file starts with an opening (--- filename.txt), followed
      # by the actual file data.

      # verify opening line
      opening_line = file_reader.read_line
      expect! opening_line => START_REGEXP

      # extract args
      opening_line =~ START_REGEXP
      args = $1

      # read the entire body
      lines = read_body_lines(file_reader)

      # extract embedded files and code part of the body.
      code, embedded_files = extract_code_and_embedded_files(lines)

      # build CodeBlock
      new(args, join_lines(lines), code, embedded_files)
    end

    # read lines from the file_reader, until we encounter a code block ending line.
    private_class_method def self.read_body_lines(file_reader)
      lines = []

      while (line = file_reader.read_line) && line !~ END_REGEXP
        lines << line
      end

      # we have either a line matching END_REGEXP, or nil (i.e. end-of-file)
      raise "Open code block input" unless line

      unintend(lines)
    end

    # run through the list of lines, separated by "--- filename" lines.
    # extract those into a hash of embedded_files.
    private_class_method def self.extract_code_and_embedded_files(body)
      current_file = :code
      embedded_files = {
        current_file => []
      }

      body.each do |line|
        if line =~ /^---\s+(.*)\s*$/
          current_file = $1
          embedded_files[current_file] = []
        else
          embedded_files[current_file] << line
        end
      end

      code = embedded_files.delete(:code)
      code = join_lines(code)

      embedded_files = embedded_files.transform_values { |lines| join_lines(lines) }

      [code, embedded_files]
    end

    private_class_method def self.join_lines(lines)
      lines.join("\n") + "\n"
    end

    private_class_method def self.unintend(lines)
      number_of_leading_spaces = lines
        .grep_v(/^\s*$/)
        .map { |line| line =~ /^( *)/ && $1 }
        .compact
        .map(&:length)
        .min

      lines
        .map { |line| line =~ /^ / ? line[number_of_leading_spaces..-1] : line }
        .map { |line| line.to_s }
    end
  end

  class PlainInputLine
    attr_reader :body

    def initialize(body)
      @body = body
    end

    def to_s
      @body
    end
  end

  def read_next_token
    case peek_line
    when CodeBlock::START_REGEXP
      CodeBlock.read(self)
    when String
      PlainInputLine.new(read_line)
    end
  end

  def initialize(file)
    @file = file
    @fd = File.open(file)
    @line = 0
  end

  def location
    @shortpath ||= File.shortpath(@file)
    "#{@shortpath}:#{@line}"
  end

  def read_line
    @peek_line || gets
  ensure
    @peek_line = nil
  end

  private

  def peek_line
    raise "Can only peek one line" if @peek_line

    @peek_line = gets
  end

  def gets
    @line += 1
    @fd.gets&.chomp
  end
end
