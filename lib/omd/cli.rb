require "simple-cli"

module OMD::CLI
  include ::Simple::CLI

  # Process src file, and process into a destination file
  #
  # Flags:
  #
  #   --display           Open the "Marked 2" markdown preview
  #   --clean             Clear cache before running
  #
  # Example:
  #
  # To process "doc/README.omd" (generating "doc/README.md"), using
  # cached results from previous runs:
  #
  #     omd process doc/README.omd
  #
  # To process all files in the "doc" directory, ignoring previously
  # cached results, and open the "Marked 2" markdown viewer:
  #
  #     omd process doc --clean --display
  #
  def process(src = ".", clean: false, display: false)
    file_to_display = nil

    omd_files_newest_first(src).each do |path|
      dest = OMD::Core.process(path, clean: clean)
      file_to_display ||= dest
    end

    if display && file_to_display
      system "open", "-a", "Marked 2", file_to_display
    end
  end

  # Watches one or more source files, rebuilding results whenever sources change
  #
  # Flags:
  #
  #   --display           Open the "Marked 2" markdown preview
  #   --clean             Clear cache before processing
  #
  # Example:
  #
  # To process the doc/README.omd file (generating doc/README.md) run:
  #
  #     omd watch doc/README.omd
  #
  # This will use cached results from previous runs. To ignore everything
  # in the cache, use the --clean flag, like so:
  #
  #     omd watch doc/README.omd --clean --display
  #
  # To watch an entire directory run
  #
  #     omd watch path/to/dir
  #
  def watch(src, clean: false, display: false)
    # process once (so that we are up to date)
    process src, clean: clean, display: display

    # We are watching omd's source dir and the directory of the omd
    # source file. Doing this helps during development, and otherwise
    # doesn't hurt (since omd's installation target directory will
    # rarely see changes.
    dirs_to_watch = []
    dirs_to_watch << (File.directory?(src) ? src : File.dirname(src))
    dirs_to_watch << OMD.root_dir

    loop do
      watched = OMD::Watcher.watch dirs_to_watch, latency: 0.1 do |changed_dirs|
        if changed_dirs.any? { |dir| dir.start_with?(OMD.root_dir) }
          :source_changed
        elsif (changed_file = omd_files_newest_first(src).first)
          process changed_file
          nil
        end
      end

      # Abort on SIGTERM et.al.
      break if watched.nil?

      # reload OMD
      OMD::Loader.reload!
      process src
    end
  end

  private

  def omd_files_newest_first(src)
    if File.directory?(src)
      paths = Dir.glob("#{src}/*.omd")
      paths = paths.sort_by { |path| -File.stat(path).mtime.to_i }
      paths
    elsif File.file?(src)
      [src]
    else
      raise "#{src}: must be a file or a directory."
    end
  end
end
