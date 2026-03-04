local M = {}

local TANGLE_KEYWORD = "tangle:"
local TAGS_KEYWORD = "tags:"

-- Returns true if the line is a standalone code fence (``` or ~~~~)
local function contains_code_block_separator(line)
  local stripped = line:match("^%s*(.-)%s*$")
  local fence = stripped:match("^(`+)") or stripped:match("^(~+)")
  return fence ~= nil and #fence >= 3
end

-- Extract options after a keyword (e.g. "tangle:foo,bar" → {"foo", "bar"})
local function get_cmd_options(line, keyword, separator)
  local pattern = keyword .. "([^%s]+)"
  local match = line:match(pattern)
  if not match then
    return nil
  end
  local options = vim.split(match, separator, { plain = true })
  return options
end

-- Returns tangle options table or nil if no tangle keyword
local function get_tangle_options(line, separator)
  local locations = get_cmd_options(line, TANGLE_KEYWORD, separator)
  if locations == nil then
    return nil
  end
  local tags = get_cmd_options(line, TAGS_KEYWORD, separator) or {}
  return { locations = locations, tags = tags }
end

-- Accumulate a code block into code_blocks
local function add_codeblock(code_blocks, options, current_block)
  if options == nil or current_block == "" then
    return
  end
  for _, location in ipairs(options.locations) do
    if not code_blocks[location] then
      code_blocks[location] = {}
    end
    table.insert(code_blocks[location], { content = current_block, tags = options.tags })
  end
end

-- Collect all unique tags present in parsed code blocks (sorted).
-- @param code_blocks table  { path → { {content, tags}, ... } }
-- @return table  sorted list of unique tag strings
function M.collect_tags(code_blocks)
  local seen = {}
  local tags = {}
  for _, blocks in pairs(code_blocks) do
    for _, block in ipairs(blocks) do
      for _, tag in ipairs(block.tags) do
        if tag ~= "" and not seen[tag] then
          seen[tag] = true
          table.insert(tags, tag)
        end
      end
    end
  end
  table.sort(tags)
  return tags
end

-- Parse a Markdown file and return a table of { path → { {content, tags}, ... } }
-- All blocks are returned regardless of tags; filtering is left to the caller.
-- @param filename  string
-- @param separator string  separator for tangle destinations/tags
function M.map_md_to_code_blocks(filename, separator)
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
    elseif in_block and options ~= nil then
      current_block = current_block .. line .. "\n"
    end
  end

  -- Handle unclosed block
  add_codeblock(code_blocks, options, current_block)

  return code_blocks
end

return M
