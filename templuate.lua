#!/usr/bin/env lua
--[[
templuate, a tiny lua text template engine

Options:
   -D <var=value> Add variable 'var' to the global table.
                  Multiple calls with the same variable will
                  join them as table.
   --list <var> <items...> <;> Add variable 'var' as list to the global table.
                               All sucessive arguments are added until ';' occurs.

Template Syntax:
   - <% [lua code] %>
   - {{ lua code that emmits a value }}
   - Everything else is output at text
   - For escaping the template syntax use
     - {{, }}: escape.var_begin, escape.var_end
     - <%, %>: escape.block_begin, escape.block_end

Example:
   template:
     This is {{var}} test!

   run:
     lua templuate.lua -D var=123 < template.txt

   output:
     This is 123 test!
]]--

local br_open = '[==['
local br_close = ']==]'

local function code_block(str)
   return { kind = 'code', contents = str }
end

local function content_block(str)
   str = str:gsub('%]==%]', br_close..'.."'..br_close..'"..'..br_open)
   str = str:gsub('{{%s*(.-)%s*}}', function(match)
      return br_close..'..put_value('..tostring(match)..')..'..br_open
   end)

   return { kind = 'content', contents = str }
end

local function parse_template(input)
   local blocks = {}
   local offset = 1

   local function emit_content(end_position)
      if not end_position or end_position >= offset then
         local str = input:sub(offset, end_position)
         if str and str:len() > 0 then
            table.insert(blocks, content_block(str))
         end
      end
   end

   local function emit_code(start_position, end_position)
      if start_position <= end_position then
         local str = input:sub(start_position, end_position)
         if str and str:len() > 0 then
            table.insert(blocks, code_block(str))
         end
      end
   end

   while true do
      local i, j = input:find('<%%', offset)
      if i then
         emit_content(i - 1)

         local k, l = input:find('%%>', j)
         if k then
            emit_code(j + 1, k - 1)
            offset = l + 1
         else
            error("Missing closing tag %>. Start tag at " .. i)
         end
      else
         emit_content(nil)
         break
      end
   end
   return blocks
end

local function eval_blocks(blocks)
   local code = ''
   for _, block in ipairs(blocks) do
      if block.kind == 'code' then
         code = code .. block.contents .. '; '
      else
         code = code .. 'put_block('..br_open..block.contents..br_close..'); '
      end
   end
   return code
end

-- Execution environment
local env = {
   escape = {
      block_end = "%>",
      block_begin = "<%",
      var_begin = "{{",
      var_end = "}}",
   }
}

-- Parse cli args
local function shift()
   table.remove(arg, 1)
   return arg[1]
end

local function define_global(str)
   local var, val = str:match('([%w_]+)%s*=(.*)')
   if var and val then
      if not env[var] then
         env[var] = val
      end
   else
      error('Failed to set variable "'..str..'"')
   end
end

local function define_global_list(name)
   env[name] = env[name] or {}
   return env[name]
end

local options = {}
local input = io.stdin ---@type file*|nil
local output = io.stdout ---@type file*|nil

while true do
   local a = arg[1]
   if a == '-h' or a == '--help' then
      print([[templuate]

templuate [options] FILE

Options:
  -D var=value       Set var to value in global scope
  -L var value... ;  Set var to list of values
  -i                 Enable interactive mode
  -o FILE            Set output file
  FILE               Input file
]])
      return
   elseif a == '--def' or a == '-D' then
      -- --def <var=val>
      -- -D <var=val>
      define_global(shift())
   elseif a == '--list' or a == '-L' then
      -- --list <var> <val>... <;>
      local l = define_global_list(shift())
      while true do
         local item = shift()
         if item == ';' then break end
         table.insert(l, item)
      end
   elseif a == '-i' or a == '--interactive' then
      options.interactive = true
   elseif a == '-o' then
      output = io.open(shift(), "w")
   elseif a == '--' then
      input = io.open(shift(), "r")
      break
   elseif a[1] ~= '-' then
      input = io.open(a, "r")
   end
   if not shift() then break end
end

assert(input, "Could not open input for reading")
assert(output, "Could not open output for writing")


-- Register io functions
function env.put_block(...)
   output:write(...)
end

function env.put_value(value)
   if type(value) == 'table' and #value > 0 then
      value = table.concat(value, ', ')
   end
   return tostring(value)
end

if options.interactive then
  function env.input(prompt)
     io.stderr:write(prompt)
     return io.stdin:read() or ""
  end
else
  function env.input()
     error("Interactive mode is disabled!")
  end
end

function env.print(text)
   env.put_block(tostring(text) .. "\n")
end

local allowed = {
   "math", "string", "table", "utf8",
   "next", "ipairs", "pairs",
   "pcall", "xpcall", "select",
   "tonumber", "tostring", "type",
   "error", "assert", "_VERSION",
}
for _, f in ipairs(allowed) do
   env[f] = _G[f]
end

local fn, err = load(eval_blocks(parse_template(input:read("*all"))), "template", "t", env)
if fn then
   fn()
   output:write('\n')
else
   io.stderr:write('Error: ' .. err .. '\n')
end
