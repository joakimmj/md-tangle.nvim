local M = {}

-- Create parent directories for path if they don't exist
local function create_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir ~= "" and dir ~= "." then
    vim.fn.mkdir(dir, "p")
  end
end

-- Override the root of every output path with output_dest.
-- Mirrors the Python override_output_dest logic.
-- @param code_blocks table  { path → {blocks} }
-- @param output_dest string
function M.override_output_dest(code_blocks, output_dest)
  local paths = vim.tbl_keys(code_blocks)

  -- Find common path prefix
  local common = paths[1] or ""
  for _, p in ipairs(paths) do
    while common ~= "" and p:sub(1, #common) ~= common do
      common = vim.fn.fnamemodify(common, ":h")
      if common == "." then common = "" end
    end
  end

  local result = {}
  for path, blocks in pairs(code_blocks) do
    local filename = vim.fn.fnamemodify(path, ":t")
    local dir = vim.fn.fnamemodify(path, ":h")
    local new_dir
    if common == "" or common == path then
      new_dir = output_dest
    else
      -- Replace common prefix with output_dest
      new_dir = output_dest .. dir:sub(#common + 1)
    end
    result[new_dir .. "/" .. filename] = blocks
  end
  return result
end

-- Write code_blocks to files.
-- opts:
--   verbose      bool    print output via vim.notify
--   force        bool    skip overwrite prompt
--   block_padding int    N newlines between blocks
--   _pending     table   internal: {path, value} pairs waiting for confirmation
-- Because vim.ui.input is async, we process each file that already doesn't
-- exist synchronously, then process existing files one-by-one via recursion.
local function write_files(entries, opts, index)
  index = index or 1
  if index > #entries then return end

  local entry = entries[index]
  local path = entry.path
  local value = entry.value

  local function do_write()
    create_dir(path)
    local lines = vim.split(value, "\n", { plain = true })
    -- Remove trailing empty string from final newline
    if lines[#lines] == "" then
      table.remove(lines)
    end
    vim.fn.writefile(lines, path)
    if opts.verbose then
      local line_count = #lines
      vim.notify(string.format("%-50s %d lines", path, line_count), vim.log.levels.INFO)
    end
    write_files(entries, opts, index + 1)
  end

  if vim.fn.filereadable(path) == 1 and not opts.force then
    vim.ui.input(
      { prompt = string.format("'%s' already exists. Overwrite? (Y/n) ", path) },
      function(input)
        if input == nil or (input ~= "" and input:lower() ~= "y") then
          write_files(entries, opts, index + 1)
        else
          do_write()
        end
      end
    )
  else
    do_write()
  end
end

-- Entry point: save all code_blocks to their respective files.
-- @param code_blocks table   { path → {block_string, ...} }
-- @param opts table          { verbose, force, block_padding }
function M.save_to_file(code_blocks, opts)
  opts = opts or {}
  local block_padding = opts.block_padding or 0
  local separator = string.rep("\n", block_padding)

  local entries = {}
  for path, blocks in pairs(code_blocks) do
    path = vim.fn.expand(path)
    local value = table.concat(blocks, separator)
    table.insert(entries, { path = path, value = value })
  end

  if #entries == 0 then
    vim.notify("md-tangle: Found no blocks to tangle.", vim.log.levels.WARN)
    return
  end

  write_files(entries, opts, 1)
end

return M
