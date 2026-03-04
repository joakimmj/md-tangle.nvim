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
      callback = function(ev)
        M.tangle({ filename = ev.file })
      end,
      desc = "md-tangle: auto-tangle on save",
    })
  end
end

--- Tangle a Markdown file.
-- @param opts table  Optional overrides for this call:
--   filename      string   path to file (defaults to current buffer's file)
--   force         bool     force overwrite
--   verbose       bool     show output
--   destination   string   override output root directory
--   include       string   comma-separated tags to include
--   separator     string   separator for tangle destinations
--   block_padding int      N newlines between blocks
function M.tangle(opts)
  opts = vim.tbl_deep_extend("force", M.config, opts or {})

  local filename = opts.filename or vim.api.nvim_buf_get_name(0)
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

return M
