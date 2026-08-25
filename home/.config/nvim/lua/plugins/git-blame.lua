-- PLUGIN: Git Blame shows the git blame info in the virtual text.
return {
  'f-person/git-blame.nvim',
  -- load the plugin at startup
  event = 'VeryLazy',
  opts = {
    enabled = false, -- start not showing git blame info
    message_template = ' <summary> • <date> • <author> • <<sha>>', -- template for the blame message, check the Message template section for more options
    date_format = '%m-%d-%Y %H:%M:%S', -- template for the date, check Date format section for more options
    virtual_text_column = 1, -- virtual text start column, check Start virtual text at column section for more options
  },
}
