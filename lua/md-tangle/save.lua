local M = {}

-- Create parent directories for path if they don't exist
local function create_dir(path)
  local dir = vim.fn.fnamemodify(path, ":h")
  if dir ~= "" and dir ~= "." then
    vim.fn.mkdir(dir, "p")
  end
end

-- Override the root of every output path with output_dest.
-- @param sources     table  { blocks = { path → {blocks} }, copy = [{source,destinations,tags}] }
-- @param output_dest string
function M.override_output_dest(sources, output_dest)
  local paths = vim.tbl_keys(sources.blocks)
  for _, op in ipairs(sources.copy) do
    for _, dest in ipairs(op.destinations) do
      table.insert(paths, dest)
    end
  end

  -- Find common path prefix
  local common = paths[1] or ""
  for _, p in ipairs(paths) do
    while common ~= "" and p:sub(1, #common) ~= common do
      common = vim.fn.fnamemodify(common, ":h")
      if common == "." then
        common = ""
      end
    end
  end

  local function remap(path)
    local filename = vim.fn.fnamemodify(path, ":t")
    local dir = vim.fn.fnamemodify(path, ":h")
    local new_dir
    if common == "" or common == path then
      new_dir = output_dest
    else
      -- Replace common prefix with output_dest
      new_dir = output_dest .. dir:sub(#common + 1)
    end
    return new_dir .. "/" .. filename
  end

  local new_blocks = {}
  for path, blocks in pairs(sources.blocks) do
    new_blocks[remap(path)] = blocks
  end

  local new_copy = {}
  for _, op in ipairs(sources.copy) do
    local new_dests = {}
    for _, dest in ipairs(op.destinations) do
      table.insert(new_dests, remap(dest))
    end
    table.insert(new_copy, { source = op.source, destinations = new_dests, tags = op.tags })
  end

  return { blocks = new_blocks, copy = new_copy }
end

-- Write code_blocks to files.
-- opts:
--   verbose      bool    print output via vim.notify
--   force        bool    skip overwrite prompt
--   block_padding int    N newlines between blocks
-- Because vim.ui.input is async, files are processed one-by-one via recursion.
local function write_files(entries, opts, index)
  index = index or 1
  if index > #entries then
    return
  end

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
      vim.notify(string.format("%-50s %d lines", vim.fn.fnamemodify(path, ":~:."), #lines), vim.log.levels.INFO)
    end
    write_files(entries, opts, index + 1)
  end

  if vim.fn.filereadable(path) == 1 and not opts.force then
    vim.ui.input({ prompt = string.format("'%s' already exists. Overwrite? (Y/n) ", vim.fn.fnamemodify(path, ":~:.")) }, function(input)
      if input == nil or (input ~= "" and input:lower() ~= "y") then
        write_files(entries, opts, index + 1)
      else
        do_write()
      end
    end)
  else
    do_write()
  end
end

-- Returns true if a block should be written given the tags_to_include list.
-- Untagged blocks are always included.
local function should_include(block, tags_to_include)
  if #block.tags == 0 then
    return true
  end
  for _, tag in ipairs(block.tags) do
    if vim.tbl_contains(tags_to_include, tag) then
      return true
    end
  end
  return false
end

-- Copy files, one-by-one via recursion (mirrors write_files).
local function do_copy_files(entries, opts, index)
  index = index or 1
  if index > #entries then
    return
  end

  local entry = entries[index]
  local src = entry.src
  local dest = entry.dest

  local function do_copy()
    if vim.fn.filereadable(src) ~= 1 then
      vim.notify(string.format("cp %s -> %s failed", vim.fn.fnamemodify(src, ":t"), vim.fn.fnamemodify(dest, ":~:.")), vim.log.levels.ERROR)
      do_copy_files(entries, opts, index + 1)
      return
    end
    create_dir(dest)
    local uv = vim.uv or vim.loop
    local ok, err = uv.fs_copyfile(src, dest)
    if not ok then
      vim.notify(string.format("cp %s -> %s failed",
        vim.fn.fnamemodify(src, ":t"),
        vim.fn.fnamemodify(dest, ":~:.")), vim.log.levels.ERROR)
    elseif opts.verbose then
      vim.api.nvim_echo({{ string.format("cp %s -> %s",
        vim.fn.fnamemodify(src, ":t"),
        vim.fn.fnamemodify(dest, ":~:.")) }}, false, {})
    end
    do_copy_files(entries, opts, index + 1)
  end

  if vim.fn.filereadable(dest) == 1 and not opts.force then
    vim.ui.input({ prompt = string.format("cp %s -> %s. Already exists. Overwrite? (Y/n) ",
      vim.fn.fnamemodify(src, ":t"),
      vim.fn.fnamemodify(dest, ":~:.")) }, function(input)
      if input == nil or (input ~= "" and input:lower() ~= "y") then
        do_copy_files(entries, opts, index + 1)
      else
        do_copy()
      end
    end)
  else
    do_copy()
  end
end

-- Entry point: save all code_blocks to their respective files.
-- @param code_blocks table   { path → { {content, tags}, ... } }
-- @param opts table          { verbose, force, block_padding, tags_to_include }
function M.save_blocks(code_blocks, opts)
  opts = opts or {}
  local tags_to_include = opts.tags_to_include or {}
  local block_padding = opts.block_padding or 0
  local separator = string.rep("\n", block_padding)

  local entries = {}
  for path, blocks in pairs(code_blocks) do
    path = vim.fn.expand(path)
    local filtered = {}
    for _, block in ipairs(blocks) do
      if should_include(block, tags_to_include) then
        table.insert(filtered, block.content)
      end
    end
    if #filtered > 0 then
      table.insert(entries, { path = path, value = table.concat(filtered, separator) })
    end
  end

  if #entries == 0 then
    vim.notify("md-tangle: Found no blocks to tangle.", vim.log.levels.WARN)
    return
  end

  write_files(entries, opts, 1)
end

-- Copy files to their destinations, in document order.
-- @param copy_ops table  { { source, destinations, tags }, ... }
-- @param opts     table  { verbose, force, tags_to_include }
function M.copy_files(copy_ops, opts)
  opts = opts or {}
  local tags_to_include = opts.tags_to_include or {}

  local entries = {}
  for _, op in ipairs(copy_ops) do
    if should_include(op, tags_to_include) then
      for _, dest in ipairs(op.destinations) do
        table.insert(entries, { src = op.source, dest = vim.fn.expand(dest) })
      end
    end
  end

  if #entries == 0 then
    return
  end

  do_copy_files(entries, opts, 1)
end

return M
