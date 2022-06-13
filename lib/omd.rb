# rubocop:disable Metrics/ModuleLength

module OMD
  extend self

  def logger
    Simple::CLI.logger
  end

  def root_dir
    __dir__
  end
end

require_relative "omd/deps"

require_relative "omd/utils"
require_relative "omd/h"
require_relative "omd/watcher"
require_relative "omd/cli"
require_relative "omd/loader"

require_relative "omd/core"
require_relative "omd/processors"
