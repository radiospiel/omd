class OMD::Core::Cache
  SELF = self

  def self.key(*parts)
    source_version = OMD::SourceVersion.source_version
    Digest::SHA1.hexdigest("#{source_version}:#{parts.join(",")}")
  end

  def initialize(dir)
    @store = PStore.new(File.join(dir, ".omd.pstore"))
    @store.ultra_safe = true
  end

  def cached(*keys)
    key = SELF.key(*keys)

    @store.transaction do
      @store[key] ||= yield
    end
  end
end
