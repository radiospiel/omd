# rubocop:disable Metrics/ModuleLength

module OMD
  extend self

  def logger
    Simple::CLI.logger
  end
end

require_relative "omd/utils"
require_relative "omd/h"
require_relative "omd/deps"
require_relative "omd/cli"
require_relative "omd/source_version"

require_relative "omd/core"
require_relative "omd/processors"

$loaded ||= true
