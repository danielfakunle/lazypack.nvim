local M = {}

local github_prefix = 'https://github.com/'

--- @param value string|string[]
--- @return string[]
function M.to_list(value)
  return type(value) == 'table' and value or { value }
end

--- @param source string
--- @return string
function M.normalize_source(source)
  if source:find('https', 1, true) then
    return source
  end

  return github_prefix .. source
end

--- @param name string?
--- @return string?
function M.resolve_name(name)
  if not name then
    return nil
  end

  return (name:gsub('%.nvim$', ''))
end

--- @param plugins any
--- @return table
function M.normalize_plugins_input(plugins)
  if type(plugins) == 'string' then
    return { plugins }
  end

  if type(plugins) ~= 'table' then
    return {}
  end

  if plugins.src or plugins.name or plugins.version or plugins.config or plugins.opts then
    return { plugins }
  end

  return plugins
end

return M
