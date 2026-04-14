local M = {}

--- @param plugin table
--- @return string?
local function plugin_id(plugin)
  local spec = plugin and plugin.spec or nil
  if not spec then
    return nil
  end

  return spec.name or spec.src
end

--- @param opts? { force?: boolean }
function M.clean(opts)
  local active = {}
  local unused = {}
  local plugins = vim.pack.get()

  for _, plugin in ipairs(plugins) do
    local id = plugin_id(plugin)
    if id then
      active[id] = plugin.active
    end
  end

  for _, plugin in ipairs(plugins) do
    local id = plugin_id(plugin)
    if id and not active[id] then
      table.insert(unused, id)
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
