class OMD::Core::FileReader
  def self.open(file)
    new file
  end

  class CodeBlock
    START_REGEXP = /^```{\s*(.*)\s*}\s*$/.freeze
    END_REGEXP = /^```\s*$/.freeze

    attr_reader :args, :body

    def initialize(args, body)
      @args = args
      @body = body
    end

    def self.read(file_reader)
      line = file_reader.read_line
      expect! line => START_REGEXP
      line =~ START_REGEXP

      # read a CodeBlock. The current line contains the code block opening,
      # in the form "```{ some omd comment }"
      args = $1

      # read block, until we encounter a code block ending line.
      lines = []

      while (line = file_reader.read_line) && line !~ END_REGEXP
        lines << line
      end

      raise "Open code block input" unless line

      new(args, unintend(lines))
    end

    def self.unintend(lines)
      number_of_leading_spaces = lines
        .grep_v(/^\s*$/)
        .map { |line| line =~ /^( *)/ && $1 }
        .compact
        .map(&:length)
        .min

      lines
        .map { |line| line =~ /^ / ? line[number_of_leading_spaces..-1] : line }
        .map { |line| "#{line}\n" }
        .join
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
