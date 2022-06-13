class OMD::Core::Cache
  SELF = self unless defined?(SELF)

  def initialize(dir)
    @store = PStore.new(File.join(dir, ".omd.pstore"))
    @store.ultra_safe = true

    roots = @store.transaction do
      @store.roots
    end
  end

  def cached(*keys)
    key = calculate_key(*keys)

    @store.transaction do
      @store[key] ||= begin
        yield
      end
    end
  end

  private

  def calculate_key(*parts)
    source_version = OMD::Loader.source_version
    Digest::SHA1.hexdigest("#{source_version}:#{parts.join(",")}")
  end
end
