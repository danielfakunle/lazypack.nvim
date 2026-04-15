local M = {}
local utils = require('lazypack.utils')

--- @param p table
local function ensure_plugin_loaded(p)
  local name = p and p.spec and p.spec.name or nil
  if not name then
    return
  end

  pcall(vim.cmd.packadd, name)
end

--- @param plugin table
--- @return boolean
function M.is_enabled(plugin)
  local enabled = plugin.enabled

  if enabled == nil then
    return true
  end

  if type(enabled) == 'function' then
    local ok, result = pcall(enabled)
    if not ok then
      vim.notify(
        ('Skipping plugin `%s`: enabled() failed: %s'):format(plugin.name or 'unknown plugin', result),
        vim.log.levels.WARN
      )
      return false
    end
    return not not result
  end

  return not not enabled
end

--- @param p table
--- @param data table
--- @return fun()
function M.run_config_once_factory(p, data)
  local configured = false

  return function()
    if configured then
      return
    end

    if data.config == true or data.opts ~= nil then
      ensure_plugin_loaded(p)

      local module_name = utils.resolve_name(p.spec.name)
      local opts = data.opts
      if type(opts) == 'function' then
        opts = opts()
      end

      if opts ~= nil then
        require(module_name).setup(opts)
      else
        require(module_name).setup()
      end
      configured = true
    elseif type(data.config) == 'function' then
      ensure_plugin_loaded(p)

      local ok, err = pcall(data.config)
      if not ok then
        vim.notify(('Config failed for `%s`: %s'):format(p.spec.name or 'unknown plugin', err), vim.log.levels.WARN)
      end
      configured = true
    end
  end
end

return M
