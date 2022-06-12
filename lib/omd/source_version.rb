module OMD::SourceVersion
  extend self

  def reset!
    OMD.logger.debug "reset source_version"
    @source_version = nil
  end

  reset!

  def reloaded?
    reloaded = @previous_source_version != OMD::SourceVersion.source_version
    @previous_source_version = OMD::SourceVersion.source_version
    reloaded
  end

  def source_version
    return @source_version if @source_version

    @source_version = Digest::MD5.hexdigest(File.read(__FILE__))
    OMD.logger.debug "source_version", @source_version
    @source_version
  end
end
