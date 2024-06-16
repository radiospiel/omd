module OMD::H
  extend self

  class ShellError < RuntimeError; end

  def sh(cmd)
    sh! cmd, raise_on_error: false
  end

  def which(binary)
    sh!("type -p #{binary}", quiet: true)
  rescue ShellError
    nil
  end

  def which!(binary, hint = nil)
    return if which(binary)

    warn "This omd file requires a #{binary} installation."

    if hint
      warn <<~MSG
        Try to run

        #{installation}

        to install it on your local machine.
      MSG
    end

    exit 1
  end

  def sh!(cmd, raise_on_error: true, quiet: false)
    OMD.logger.debug "Running '#{cmd}'" unless quiet
    stdout_str, stderr_str, status = Open3.capture3(cmd)


    return stdout_str if status.exitstatus == 0
    return stdout_str unless raise_on_error
    OMD.logger.warn "Running #{cmd} failed w/exit status #{status}"
    if stderr_str != ""
    OMD.logger.info stderr_str
    end

    raise ShellError, stderr_str if raise_on_error
  end
end
