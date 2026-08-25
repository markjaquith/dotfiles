require 'settings' -- Must be first
require 'utils'

-- NOTE: Mappings
-- All my mappings are in the `mappings.lua` file.
-- This is a bit more work, but it means that truly there is one file for all of them.
local mappings = require 'mappings'
mappings.define_general_mappings()

require 'autocommands'

-- NOTE: Sets up Lazy
require 'lazyinit'

-- NOTE: Configures Lazy plugins
require('lazy').setup 'plugins'

require 'colors'
