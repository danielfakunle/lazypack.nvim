local utils = require('lazypack.utils')

local M = {}
local events_bridged = false

local lazy_user_event_aliases = {
  LazyInstall = true,
  LazyUpdate = true,
  LazyClean = true,
  LazyInstallPre = true,
  LazyUpdatePre = true,
  LazyCleanPre = true,
  VeryLazy = true,
}

local pack_changed_pre_event_by_kind = {
  install = 'LazyInstallPre',
  update = 'LazyUpdatePre',
  delete = 'LazyCleanPre',
}

local pack_changed_event_by_kind = {
  install = 'LazyInstall',
  update = 'LazyUpdate',
  delete = 'LazyClean',
}

--- @param pattern string
--- @param data? table
local function emit_user_event(pattern, data)
  vim.api.nvim_exec_autocmds('User', {
    pattern = pattern,
    data = data,
  })
end

--- @param augroup integer
function M.ensure_event_bridges(augroup)
  if events_bridged then
    return
  end

  events_bridged = true

  vim.api.nvim_create_autocmd('PackChangedPre', {
    group = augroup,
    desc = 'Bridge PackChangedPre to lazy-style User events',
    callback = function(ev)
      local data = ev and ev.data or nil
      local kind = data and data.kind or nil
      local pattern = kind and pack_changed_pre_event_by_kind[kind] or nil
      if pattern then
        emit_user_event(pattern, data)
      end
    end,
  })

  vim.api.nvim_create_autocmd('PackChanged', {
    group = augroup,
    desc = 'Bridge PackChanged to lazy-style User events',
    callback = function(ev)
      local data = ev and ev.data or nil
      local kind = data and data.kind or nil
      local pattern = kind and pack_changed_event_by_kind[kind] or nil
      if pattern then
        emit_user_event(pattern, data)
      end
    end,
  })

  vim.api.nvim_create_autocmd('VimEnter', {
    group = augroup,
    once = true,
    desc = 'Emit VeryLazy user event',
    callback = function()
      vim.schedule(function()
        emit_user_event('VeryLazy')
      end)
    end,
  })
end

--- @param p table
--- @param data table
--- @param run_config_once fun()
--- @param augroup integer
function M.register_event_lazy_load(p, data, run_config_once, augroup)
  if not data.event then
    return
  end

  local events = utils.to_list(data.event)

  for _, event in ipairs(events) do
    local autocmd_event = event
    local pattern = nil
    if lazy_user_event_aliases[event] then
      autocmd_event = 'User'
      pattern = event
    end

    vim.api.nvim_create_autocmd(autocmd_event, {
      group = augroup,
      once = true,
      pattern = pattern,
      desc = ('Lazy load %s on %s'):format(p.spec.name, event),
      callback = function()
        vim.cmd.packadd(p.spec.name)
        run_config_once()
      end,
    })
  end
end

return M
