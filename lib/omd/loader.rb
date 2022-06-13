# rubocop:disable Style/ClassVars

module OMD::Loader
  extend self

  def reload!
    OMD.logger.info "Reload omd source code from #{OMD.root_dir}"

    ruby_sources.sort.each do |path|
      load path
    end
  rescue SyntaxError
    OMD.logger.error "Failure to reload OMD source file. See info below:"
    STDERR.puts $!.to_s
  end

  def source_version
    (mtime.to_f * 1000).to_i.to_s
  end

  @@mtime = nil

  def mtime
    # since on each source code change we reload the entire source code tree,
    # including this class, this also resets the @@mtime class var.
    @@mtime ||= ruby_sources.map { |path| File.stat(path).mtime }.max
  end

  private

  def ruby_sources
    Dir.glob("#{OMD.root_dir}/**/*.rb")
  end
end
