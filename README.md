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
    src = 'folke/trouble.nvim',
    name = 'trouble',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
    event = 'VeryLazy',
    config = true,
    opts = {},
  },
  {
    src = 'nvim-treesitter/nvim-treesitter',
    version = 'master',
    cmd = { 'TSInstall', 'TSUpdate' },
    config = function()
      require('nvim-treesitter.configs').setup({
        highlight = { enable = true },
      })
    end,
  },
  'nvim-lua/plenary.nvim',
})
```

## Plugin Spec

| Property | Type | Description |
| -------- | ---- | ----------- |
| `src` | `string` | Plugin source (`owner/repo` or full `https` URL) passed to `vim.pack.Spec.src`. |
| `name` | `string?` | Optional plugin name passed to `vim.pack.Spec.name`. |
| `version` | `string?` | Optional version/tag/branch/commit passed to `vim.pack.Spec.version`. |
| `dependencies` | `string|string[]` | A list of dependency sources (`owner/repo` or full `https` URL). Each dependency is added with `vim.pack.add` before the main plugin spec. |
| `init` | `fun()?` | Runs in the plugin `load` callback before lazy handlers are registered. |
| `config` | `boolean? or fun()?` | `true` calls `require(name).setup(opts)`, or you can provide a custom config function. |
| `opts` | `table? or fun():table` | Used when `config = true`; supports table or function returning table. |
| `event` | `string|string[]` | Lazy-load on native autocmd events and lazy-style user events (`VeryLazy`, `LazyInstall`, `LazyUpdate`, `LazyClean`, and `*Pre`). |
| `cmd` | `string|string[]` | Lazy-load on command execution with command forwarding after `packadd`. |
| `enabled` | `boolean? or fun():boolean` | When `false` (or function returns `false`), the plugin is skipped and not added. |

## User Events

The following user events are currently triggered by LazyPack:

- `LazyInstall`: after an install (`PackChanged` with `kind = "install"`)
- `LazyUpdate`: after an update (`PackChanged` with `kind = "update"`)
- `LazyClean`: after a clean/delete (`PackChanged` with `kind = "delete"`)
- `LazyInstallPre`: before an install (`PackChangedPre` with `kind = "install"`)
- `LazyUpdatePre`: before an update (`PackChangedPre` with `kind = "update"`)
- `LazyCleanPre`: before a clean/delete (`PackChangedPre` with `kind = "delete"`)
- `VeryLazy`: triggered once after `VimEnter` (scheduled)

## Disclaimer

This project is not affiliated with
[Lazy.nvim](https://github.com/folke/lazy.nvim). Credit for the spec design
goes to @folke.
