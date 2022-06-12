class OMD::FileReader
  def self.open(file)
    new file
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

  def gets
    @line += 1
    @fd.gets
  end
end
