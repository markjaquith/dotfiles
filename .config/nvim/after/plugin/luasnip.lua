local ls = require 'luasnip'
local s = ls.snippet
local sn = ls.snippet_node
local isn = ls.indent_snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local events = require 'luasnip.util.events'
local ai = require 'luasnip.nodes.absolute_indexer'
local extras = require 'luasnip.extras'
local l = extras.lambda
local rep = extras.rep
local p = extras.partial
local m = extras.match
local n = extras.nonempty
local dl = extras.dynamic_lambda
local fmt = require('luasnip.extras.fmt').fmt
local fmta = require('luasnip.extras.fmt').fmta
local conds = require 'luasnip.extras.expand_conditions'
local postfix = require('luasnip.extras.postfix').postfix
local types = require 'luasnip.util.types'
local parse = require('luasnip.util.parser').parse_snippet
local ms = ls.multi_snippet
local k = require('luasnip.nodes.key_indexer').new_key

ls.add_snippets('all', {
  s('#dq', fmt([[“{}”]], { i(1) })),
  s('#sq', fmt([[‘{}’]], { i(1) })),
  s('#apost', t '’'),
  s('#mdash', t '—'),
  s('#ndash', t '–'),
})

---------------
-- SvelteKit --
---------------

-- +page.ts
ls.add_snippets('typescript', {
  s(
    '+page.ts',
    fmt(
      [[
import type {{ PageLoad }} from './$types'

export const load: PageLoad = ({{ params }}) => {{
	return {{
		{}
	}}
}}
]],
      {
        i(1, '// Return data'),
      }
    )
  ),
})

-- +page.server.ts
ls.add_snippets('typescript', {
  s(
    '+page.server.ts',
    fmt(
      [[
import type {{ PageServerLoad, Actions }} from './$types'

export const load: PageServerLoad = ({{ params }}) => {{
	return {{
		{}
	}}
}}

export const actions = {{
  default: async (event) => {{
    {}
  }}
}} satisfies Actions
]],
      {
        i(1, '// Return data'),
        i(2, '// Handle action'),
      }
    )
  ),
})

-- +layout.ts
ls.add_snippets('typescript', {
  s(
    '+layout.ts',
    fmt(
      [[
import type {{ LayoutLoad }} from './$types'

export const load: LayoutLoad = ({{ params }}) => {{
	return {{
		{}
	}}
}}
]],
      {
        i(1, '// Return data'),
      }
    )
  ),
})

-- +layout.server.ts
ls.add_snippets('typescript', {
  s(
    '+layout.ts',
    fmt(
      [[
import type {{ LayoutServerLoad }} from './$types'

export const load: LayoutServerLoad = ({{ params }}) => {{
	return {{
		{}
	}}
}}
]],
      {
        i(1, '// Return data'),
      }
    )
  ),
})
