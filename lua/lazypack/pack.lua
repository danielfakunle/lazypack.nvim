local M = {}
local warned_missing_name = false

--- @param plugin table
--- @return string?
local function plugin_name(plugin)
  local spec = plugin and plugin.spec or nil
  if not spec then
    return nil
  end

  return spec.name
end

--- @param opts? { force?: boolean }
function M.clean(opts)
  local active = {}
  local unused = {}
  local plugins = vim.pack.get()

  for _, plugin in ipairs(plugins) do
    local name = plugin_name(plugin)
    if name then
      active[name] = plugin.active
    elseif not warned_missing_name then
      warned_missing_name = true
      vim.notify('Skipping plugin without `spec.name` in pack_clean()', vim.log.levels.WARN)
    end
  end

  for _, plugin in ipairs(plugins) do
    local name = plugin_name(plugin)
    if name and not active[name] then
      table.insert(unused, name)
    end
  end

  if #unused == 0 then
    print('No unused plugins.')
    return
  end

  local force = opts and opts.force
  local choice = force and 1 or vim.fn.confirm('Remove unused plugins?', '&Yes\n&No', 2)
  if choice == 1 then
    vim.pack.del(unused)
  end
end

function M.update()
  vim.pack.update()
end

return M
