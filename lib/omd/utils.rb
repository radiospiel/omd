def File.write(path, body = nil, permissions: nil, &block)
  if block
    body = [body, yield].compact.join("\n")
  end

  File.open(path, "w") do |io|
    io.write(body)
  end

  File.chmod permissions, path if permissions

  path
end

def File.__path_relative_to__(path, dir)
  if path.start_with?("#{dir}/")
    path[dir.length + 1..-1]
  end
end

def File.shortpath(path)
  if (shortpath = __path_relative_to__(path, Dir.getwd))
    shortpath
  elsif (shortpath = __path_relative_to__(path, ENV["HOME"]))
    "~/#{shortpath}"
  else
    path
  end
end
