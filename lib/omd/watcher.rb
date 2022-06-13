module OMD::Watcher
  extend self

  def watch(dirs, options)
    require "rb-fsevent"
    fsevent = FSEvent.new

    result = nil
    fsevent.watch dirs, options do |changed_dirs, _event_meta|
      changed_dirs = changed_dirs.uniq
      result = yield changed_dirs
      unless result.nil?
        fsevent.stop
      end
    end
    fsevent.run
    result
  end
end
