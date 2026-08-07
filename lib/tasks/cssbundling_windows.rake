module Cssbundling
  module Tasks
    private

    def tool_exists?(tool)
      if Gem.win_platform?
        system "where #{tool} > nul 2>&1"
      else
        system "command -v #{tool} > /dev/null"
      end
    end
  end
end