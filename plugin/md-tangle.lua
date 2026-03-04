-- md-tangle.nvim — command registration
-- Loaded automatically by Neovim from the plugin/ directory.

local md_tangle = require("md-tangle")

--- Parse :MdTangle arguments into an opts table.
-- Supported flags (mirror the md-tangle CLI):
--   -f / --force
--   -v / --verbose
--   -d / --destination <path>
--   -i / --include <tags>
--   -s / --separator <sep>
--   -p / --block-padding <N>
--   <filename>   (positional, optional)
local function parse_args(fargs)
  local opts = {}
  local i = 1
  while i <= #fargs do
    local arg = fargs[i]
    if arg == "-f" or arg == "--force" then
      opts.force = true
    elseif arg == "-v" or arg == "--verbose" then
      opts.verbose = true
    elseif arg == "-d" or arg == "--destination" then
      i = i + 1
      opts.destination = fargs[i]
    elseif arg == "-i" or arg == "--include" then
      i = i + 1
      opts.include = fargs[i]
    elseif arg == "-s" or arg == "--separator" then
      i = i + 1
      opts.separator = fargs[i]
    elseif arg == "-p" or arg == "--block-padding" then
      i = i + 1
      opts.block_padding = tonumber(fargs[i])
    else
      -- Positional: treat as filename
      opts.filename = arg
    end
    i = i + 1
  end
  return opts
end

vim.api.nvim_create_user_command("MdTangleInsert", function()
  md_tangle.insert_block()
end, {
  nargs = 0,
  desc = "Interactively insert a new tangle code block",
})

vim.api.nvim_create_user_command("MdTangle", function(cmd)
  local opts = parse_args(cmd.fargs)
  md_tangle.tangle(opts)
end, {
  nargs = "*",
  complete = "file",
  desc = "Tangle code blocks from the current (or given) Markdown file",
})
