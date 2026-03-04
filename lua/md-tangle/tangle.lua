local M = {}

local TANGLE_KEYWORD = "tangle:"
local TAGS_KEYWORD = "tags:"

-- Returns true if the line is a standalone code fence (``` or ~~~~)
local function contains_code_block_separator(line)
  local stripped = line:match("^%s*(.-)%s*$")
  -- Must start with ``` or ~~~~
  local fence = stripped:match("^(`+)") or stripped:match("^(~+)")
  if not fence then return false end
  if #fence < 3 then return false end
  -- For backtick fences the opening must be exactly one run (no closing ``` on same line unless it's an info string)
  -- Count total occurrences of the fence char to detect inline code like `code`
  -- We allow info strings after the fence, so just check it starts with the fence
  return true
end

-- Extract options after a keyword (e.g. "tangle:foo,bar" → {"foo", "bar"})
local function get_cmd_options(line, keyword, separator)
  local pattern = keyword .. "([^%s]+)"
  local match = line:match(pattern)
  if not match then return nil end
  local options = vim.split(match, separator, { plain = true })
  return options
end

-- Returns tangle options table or nil if no tangle keyword
local function get_tangle_options(line, separator)
  local locations = get_cmd_options(line, TANGLE_KEYWORD, separator)
  if locations == nil then return nil end
  local tags = get_cmd_options(line, TAGS_KEYWORD, separator) or {}
  return { locations = locations, tags = tags }
end

-- Returns true if the block should be included given the tags_to_include list
local function should_include_block(tags_to_include, options)
  local tags = options.tags
  if not tags or #tags == 0 then return true end
  for _, tag in ipairs(tags) do
    for _, include in ipairs(tags_to_include) do
      if tag == include then return true end
    end
  end
  return false
end

-- Accumulate a code block into code_blocks
local function add_codeblock(code_blocks, options, current_block)
  if options == nil or current_block == "" then return end
  for _, location in ipairs(options.locations) do
    if not code_blocks[location] then
      code_blocks[location] = {}
    end
    table.insert(code_blocks[location], current_block)
  end
end

-- Parse a Markdown file and return a table of { path → {block, ...} }
-- @param filename string
-- @param separator string  separator for tangle destinations (default ",")
-- @param tags_to_include table   list of tags to include
function M.map_md_to_code_blocks(filename, separator, tags_to_include)
  local lines = vim.fn.readfile(filename)
  local options = nil
  local code_blocks = {}
  local current_block = ""
  local in_block = false

  for _, line in ipairs(lines) do
    if contains_code_block_separator(line) then
      if in_block then
        -- closing fence
        add_codeblock(code_blocks, options, current_block)
        current_block = ""
        options = nil
        in_block = false
      else
        -- opening fence
        options = get_tangle_options(line, separator)
        in_block = true
      end
    elseif in_block and options ~= nil and should_include_block(tags_to_include, options) then
      current_block = current_block .. line .. "\n"
    end
  end

  -- Handle unclosed block
  add_codeblock(code_blocks, options, current_block)

  return code_blocks
end

return M
