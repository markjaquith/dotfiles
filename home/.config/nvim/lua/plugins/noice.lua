-- PLUGIN: Noice is a plugin that shows messages in a nice way.
return {
  'folke/noice.nvim',
  event = 'VeryLazy',
  opts = {
    messages = {
      enabled = true, -- enables the Noice messages UI
      view = 'notify', -- default view for messages
      view_error = 'notify', -- view for errors
      view_warn = 'notify', -- view for warnings
      view_history = 'messages', -- view for :messages
      view_search = false, -- view for search count messages. Set to `false` to disable
    },
    routes = {
      { filter = { find = 'E162' }, view = 'mini' },
      { filter = { find = 'E486' }, view = 'mini' },
      { filter = { event = 'msg_show', kind = '', find = 'written' }, view = 'mini' },
      { filter = { event = 'msg_show', find = 'search hit BOTTOM' }, skip = true },
      { filter = { event = 'msg_show', find = 'search hit TOP' }, skip = true },
      { filter = { event = 'emsg', find = 'E23' }, skip = true },
      { filter = { event = 'emsg', find = 'E20' }, skip = true },
      { filter = { find = 'No signature help' }, skip = true },
      { filter = { find = 'E37' }, skip = true },
      { filter = { find = 'change; before' }, view = 'mini' },
      { filter = { find = 'change; after' }, view = 'mini' },
      { filter = { any = { { find = 'Recording @' } } }, view = 'mini' },
      { filter = { any = { { find = 'Recorded @' } } }, view = 'mini' },
    },
  },
  dependencies = {
    'MunifTanjim/nui.nvim',
    -- 'rcarriga/nvim-notify',
  },
}
