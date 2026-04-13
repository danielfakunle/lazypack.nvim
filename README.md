# LazyPack

> [!WARNING]
> Just for fun, do not expect full Lazy.nvim compatibility.

This plugin is a small wrapper around Neovim's native package manager
`vim.pack` that lets you register plugins using a Lazy.nvim-style spec.
It focuses on simple lazy-loading workflows (`event` and `cmd`) while staying
close to native `vim.pack.add`.

> [!IMPORTANT]
> This is not a full replacement for Lazy.nvim. Lazy.nvim provides a lot more
> than loading triggers, and LazyPack intentionally supports only a subset of
> the spec.

## Usage

```lua
-- in your init.lua file
vim.pack.add({ { src = 'https://github.com/danielfakunle/lazypack.nvim' } })

require('lazypack').add({
  {
    src = 'https://github.com/folke/trouble.nvim',
    name = 'trouble',
    dependencies = {
      'https://github.com/nvim-tree/nvim-web-devicons',
    },
    event = 'VeryLazy',
    config = true,
    opts = {},
  },
  {
    src = 'https://github.com/nvim-treesitter/nvim-treesitter',
    version = 'master',
    cmd = { 'TSInstall', 'TSUpdate' },
    config = function()
      require('nvim-treesitter.configs').setup({
        highlight = { enable = true },
      })
    end,
  },
  'https://github.com/nvim-lua/plenary.nvim',
})
```

## Features

Table legend:

- `✅`: Implemented
- `➖`: Not implemented yet, possible future work
- `❌`: Out of scope

| Spec Property  | Implemented | Details                                                                           |
| -------------- | ----------- | --------------------------------------------------------------------------------- |
| `[1]`          | ❌          | Table specs must use `src`; positional repo string inside table is not supported. |
| `src`          | ✅          | Passed through to `vim.pack.Spec.src`.                                            |
| `name`         | ✅          | Passed through to `vim.pack.Spec.name`.                                           |
| `version`      | ✅          | Passed through to `vim.pack.Spec.version`.                                        |
| `init`         | ✅          | Runs in `load` callback.                                                          |
| `config`       | ✅          | Supports `true` (calls `require(name).setup(opts)`) or function.                  |
| `opts`         | ✅          | Used when `config = true`; supports table or function returning table.            |
| `event`        | ✅          | Registers one-shot autocmd(s) to `packadd` then configure.                        |
| `cmd`          | ✅          | Registers user command proxy/proxies to `packadd` then forward invocation.        |
| `dependencies` | ✅          | Supports string or string[]; each dependency runs through `vim.pack.add`.         |
| `ft`           | ❌          | Not currently handled by LazyPack.                                                |
| `keys`         | ❌          | Not currently handled by LazyPack.                                                |
| `build`        | ➖          | Not currently implemented.                                                        |
| `lazy`         | ❌          | Not modeled; lazy behavior is defined by `event`/`cmd` usage.                     |

## Disclaimer

This project is not affiliated with
[Lazy.nvim](https://github.com/folke/lazy.nvim). Credit for the spec design
goes to @folke.
