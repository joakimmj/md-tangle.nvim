# md-tangle.nvim

A Neovim plugin that implements [md-tangle](https://github.com/joakimmj/md-tangle) — literate programming for Markdown — entirely in Lua. No Python or CLI dependency required.

Tangle code blocks from Markdown files to their destination files, directly from Neovim.

## Features

- Full feature parity with the `md-tangle` CLI
- Supports ` ``` ` and `~~~~` code fence delimiters
- `tangle:<path>` — write block to one or more files
- `tags:<tag>` — conditionally include blocks
- Overwrite prompt via `vim.ui.input`
- Verbose output via `vim.notify`
- Optional auto-tangle on save

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "joakimmj/md-tangle.nvim",
  config = function()
    require("md-tangle").setup()
  end,
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "joakimmj/md-tangle.nvim",
  config = function()
    require("md-tangle").setup()
  end,
}
```

## Configuration

Call `setup()` with any options you want to override. These become the defaults for every `:MdTangle` call.

```lua
require("md-tangle").setup({
  force         = false,   -- overwrite files without prompting
  verbose       = true,    -- show output via vim.notify
  destination   = nil,     -- override output root directory
  include       = "",      -- comma-separated tags to include
  separator     = ",",     -- separator for tangle destinations/tags
  block_padding = 0,       -- N newlines between code blocks in output
  auto_tangle   = false,   -- auto-tangle *.md files on BufWritePost
})
```

## Usage

### Command

```
:MdTangle [options] [filename]
```

Tangles the current buffer's file (or the given `filename`). All options are optional and mirror the CLI flags:

| Option | CLI equivalent | Description |
|---|---|---|
| `-f` / `--force` | `-f` | Force overwrite, skip prompt |
| `-v` / `--verbose` | `-v` | Show output |
| `-d` / `--destination <path>` | `-d` | Override output root directory |
| `-i` / `--include <tags>` | `-i` | Include tagged blocks (comma-separated) |
| `-s` / `--separator <sep>` | `-s` | Separator for destinations/tags (default `,`) |
| `-p` / `--block-padding <N>` | `-p` | Add N newlines between blocks (default `0`) |

**Examples:**

```vim
" Tangle the current file
:MdTangle

" Force-overwrite and show output
:MdTangle -f -v

" Tangle a specific file
:MdTangle ~/docs/setup.md

" Include tagged blocks and write to a different root
:MdTangle -i theme -d /tmp/out

" Use a custom separator
:MdTangle -s |
```

### Lua API

```lua
-- Tangle the current buffer's file with default config
require("md-tangle").tangle()

-- Tangle with per-call overrides
require("md-tangle").tangle({
  filename      = "~/docs/setup.md",
  force         = true,
  verbose       = true,
  include       = "theme,extra",
  block_padding = 1,
})
```

### Keymaps

Use `vim.keymap.set` with `{ buffer = true }` inside a `FileType` autocmd to scope keymaps to Markdown files only.

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    local md = require("md-tangle")

    -- <leader>tt — tangle current file
    vim.keymap.set("n", "<leader>tt", function()
      md.tangle()
    end, { buffer = true, desc = "Tangle current file" })

    -- <leader>tf — force-tangle (skip overwrite prompt)
    vim.keymap.set("n", "<leader>tf", function()
      md.tangle({ force = true })
    end, { buffer = true, desc = "Force-tangle current file" })
  end,
})
```

When using [lazy.nvim](https://github.com/folke/lazy.nvim) the same keymaps can be defined inline:

```lua
{
  "joakimmj/md-tangle.nvim",
  ft = "markdown",
  keys = {
    {
      "<leader>tt",
      function() require("md-tangle").tangle() end,
      ft = "markdown",
      desc = "Tangle current file",
    },
    {
      "<leader>tf",
      function() require("md-tangle").tangle({ force = true }) end,
      ft = "markdown",
      desc = "Force-tangle current file",
    },
  },
  config = function()
    require("md-tangle").setup()
  end,
}
```

### Auto-tangle on save

Enable in `setup()`:

```lua
require("md-tangle").setup({ auto_tangle = true })
```

This adds a `BufWritePost` autocmd for `*.md` files that calls `tangle()` with your configured defaults.

## Markdown syntax

The plugin uses the same syntax as the `md-tangle` CLI.

````markdown
```python tangle:src/hello.py
print("Hello, world")
```

```css tangle:styles/button.css,styles/input.css
/* shared header */
```

```css tangle:styles/theme.css tags:theme
/* only included with -i theme */
```
````

Tangle ` ``` ` or `~~~~` fences are both supported.

## License

MIT
