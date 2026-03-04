local tangle = require("md-tangle.tangle")
local save = require("md-tangle.save")

local M = {}

--- Default configuration
M.config = {
  force = false,
  verbose = true,
  destination = nil,
  include = "",
  separator = ",",
  block_padding = 0,
  auto_tangle = false,
}

--- Setup the plugin with user configuration.
-- @param opts table  Partial config table (merged with defaults)
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  if M.config.auto_tangle then
    vim.api.nvim_create_autocmd("BufWritePost", {
      group = vim.api.nvim_create_augroup("MdTangle", { clear = true }),
      pattern = { "*.md" },
      callback = function()
        M.tangle()
      end,
      desc = "md-tangle: auto-tangle on save",
    })
  end
end

--- Tangle the current buffer's Markdown file.
-- @param opts table  Optional overrides for this call:
--   force         bool     force overwrite
--   verbose       bool     show output
--   destination   string   override output root directory
--   include       string   comma-separated tags to include
--   separator     string   separator for tangle destinations
--   block_padding int      N newlines between blocks
function M.tangle(opts)
  opts = vim.tbl_deep_extend("force", M.config, opts or {})

  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" then
    vim.notify("md-tangle: No file associated with buffer.", vim.log.levels.ERROR)
    return
  end

  local tags_to_include = {}
  if opts.include and opts.include ~= "" then
    tags_to_include = vim.split(opts.include, ",", { plain = true })
  end

  local blocks = tangle.map_md_to_code_blocks(filename, opts.separator, tags_to_include)

  if vim.tbl_isempty(blocks) then
    vim.notify("md-tangle: Found no blocks to tangle.", vim.log.levels.WARN)
    return
  end

  if opts.destination then
    blocks = save.override_output_dest(blocks, opts.destination)
  end

  save.save_to_file(blocks, {
    verbose = opts.verbose,
    force = opts.force,
    block_padding = opts.block_padding,
  })
end

--- Interactively insert a new tangle code block at the current cursor position.
-- Prompts for: language, tangle destination(s), and optional tags.
-- The block is inserted after the current line with the cursor placed inside it.
function M.insert_block()
  local buf = vim.api.nvim_get_current_buf()

  local function do_insert(lang, destinations, tags)
    -- Build the opening fence info string
    local info = (lang ~= "" and lang .. " " or "")
      .. "tangle:" .. destinations
      .. (tags ~= "" and " tags:" .. tags or "")

    local lines = {
      "```" .. info,
      "",
      "```",
    }

    local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-based
    vim.api.nvim_buf_set_lines(buf, row, row, false, lines)
    -- Place cursor on the empty line inside the block
    vim.api.nvim_win_set_cursor(0, { row + 2, 0 })
    vim.cmd("startinsert")
  end

  -- Chain prompts: language → destinations → tags
  vim.ui.input({ prompt = "Language: " }, function(lang)
    if lang == nil then return end -- cancelled
    lang = vim.trim(lang)

    vim.ui.input({ prompt = "Tangle destination(s): " }, function(destinations)
      if destinations == nil or vim.trim(destinations) == "" then return end
      destinations = vim.trim(destinations)

      vim.ui.input({ prompt = "Tags (optional): " }, function(tags)
        if tags == nil then return end -- cancelled
        tags = vim.trim(tags)
        do_insert(lang, destinations, tags)
      end)
    end)
  end)
end

return M
