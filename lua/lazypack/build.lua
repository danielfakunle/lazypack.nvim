local M = {}

local build_hooks_registered = false
local warned_missing_name = false

--- @param command string|string[]
--- @param cwd? string
--- @param name string
local function run_system_sync(command, cwd, name)
  local result = vim.system(command, { cwd = cwd }):wait()
  if result and result.code and result.code ~= 0 then
    local stderr = result.stderr and result.stderr:gsub('%s+$', '') or ''
    local suffix = stderr ~= '' and (': ' .. stderr) or ''
    vim.notify(('Build failed for `%s` (exit %d)%s'):format(name, result.code, suffix), vim.log.levels.WARN)
  end
end

--- @param spec table?
--- @return string?
local function spec_name(spec)
  return spec and spec.name or nil
end

--- @param ev table
--- @param name string
--- @param step any
local function run_build_step(ev, name, step)
  if type(step) == 'function' then
    local ok, err = pcall(step, ev)
    if not ok then
      vim.notify(('Build function failed for `%s`: %s'):format(name, err), vim.log.levels.WARN)
    end
    return
  end

  if type(step) == 'string' then
    local trimmed = step:gsub('^%s+', '')
    if trimmed:sub(1, 1) == ':' then
      if ev.data and not ev.data.active then
        vim.cmd.packadd(name)
      end

      local ok, err = pcall(vim.cmd, trimmed:sub(2))
      if not ok then
        vim.notify(('Build command failed for `%s`: %s'):format(name, err), vim.log.levels.WARN)
      end
      return
    end

    run_system_sync({ vim.o.shell, vim.o.shellcmdflag, step }, ev.data and ev.data.path or nil, name)
    return
  end

  vim.notify(
    ('Skipping build step for `%s`: expected function or string'):format(name),
    vim.log.levels.WARN
  )
end

--- @param build any
--- @return table?
local function normalize_build_steps(build)
  if type(build) == 'function' or type(build) == 'string' then
    return { build }
  end

  if type(build) == 'table' then
    return build
  end

  return nil
end

--- @param ev table
--- @param name string
--- @param build any
local function run_build(ev, name, build)
  local steps = normalize_build_steps(build)
  if not steps then
    vim.notify(
      ('Skipping build for `%s`: expected function, string, or list of build steps'):format(name),
      vim.log.levels.WARN
    )
    return
  end

  for _, step in ipairs(steps) do
    run_build_step(ev, name, step)
  end
end

--- @param augroup integer
function M.ensure_build_hooks(augroup)
  if build_hooks_registered then
    return
  end

  build_hooks_registered = true

  vim.api.nvim_create_autocmd('PackChanged', {
    group = augroup,
    desc = 'Run build hook after install/update',
    callback = function(ev)
      local data = ev and ev.data or nil
      local kind = data and data.kind or nil
      if kind ~= 'install' and kind ~= 'update' then
        return
      end

      local spec = data and data.spec or nil
      local name = spec_name(spec)
      if not name then
        if not warned_missing_name then
          warned_missing_name = true
          vim.notify('Skipping build: PackChanged event is missing `spec.name`', vim.log.levels.WARN)
        end
        return
      end

      local spec_data = spec and spec.data or nil
      local build = spec_data and spec_data.build or nil
      if build == nil then
        return
      end

      run_build(ev, name, build)
    end,
  })
end

return M
