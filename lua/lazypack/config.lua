local M = {}

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

    if data.config == true then
      local opts = data.opts
      if type(opts) == 'function' then
        opts = opts()
      end

      if opts ~= nil then
        require(p.spec.name).setup(opts)
      else
        require(p.spec.name).setup()
      end
      configured = true
    elseif type(data.config) == 'function' then
      data.config()
      configured = true
    end
  end
end

return M
