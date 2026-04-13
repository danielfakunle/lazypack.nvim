local M = {}
local augroup = vim.api.nvim_create_augroup('lazypack', { clear = false })

--- @param value string|string[]
--- @return string[]
local function to_list(value)
  return type(value) == 'table' and value or { value }
end

--- @param p table
--- @param data table
--- @return fun()
local function run_config_once_factory(p, data)
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

--- @param p table
--- @param data table
--- @param run_config_once fun()
local function register_cmd_lazy_load(p, data, run_config_once)
  if not data.cmd then
    return
  end

  local cmds = to_list(data.cmd)

  for _, cmd in ipairs(cmds) do
    local ok, err = pcall(vim.api.nvim_create_user_command, cmd, function(event)
      local command = {
        cmd = cmd,
        bang = event.bang or nil,
        mods = event.smods,
        args = event.fargs,
        count = event.count >= 0 and event.range == 0 and event.count or nil,
      }

      if event.range == 1 then
        command.range = { event.line1 }
      elseif event.range == 2 then
        command.range = { event.line1, event.line2 }
      end

      vim.cmd.packadd(p.spec.name)
      run_config_once()

      pcall(vim.api.nvim_del_user_command, cmd)

      ---@diagnostic disable-next-line: redundant-parameter
      local info = vim.api.nvim_get_commands({})[cmd] or vim.api.nvim_buf_get_commands(0, {})[cmd]
      if not info then
        vim.schedule(function()
          vim.notify(('Command `%s` not found after loading `%s`'):format(cmd, p.spec.name), vim.log.levels.ERROR)
        end)
        return
      end

      command.nargs = info.nargs
      if event.args and event.args ~= '' and info.nargs and info.nargs:find('[1?]') then
        command.args = { event.args }
      end

      vim.cmd(command)
    end, {
      bang = true,
      range = true,
      nargs = '*',
      desc = ('Lazy load %s on %s'):format(p.spec.name, cmd),
      complete = function(_, line)
        vim.cmd.packadd(p.spec.name)
        run_config_once()
        pcall(vim.api.nvim_del_user_command, cmd)
        return vim.fn.getcompletion(line, 'cmdline')
      end,
    })

    if not ok then
      vim.schedule(function()
        vim.notify(
          ('Skipping lazy command `%s` for `%s`: %s'):format(cmd, p.spec.name, err),
          vim.log.levels.WARN
        )
      end)
    end
  end
end

--- @param p table
--- @param data table
--- @param run_config_once fun()
local function register_event_lazy_load(p, data, run_config_once)
  if not data.event then
    return
  end

  local events = to_list(data.event)

  for _, event in ipairs(events) do
    vim.api.nvim_create_autocmd(event, {
      group = augroup,
      once = true,
      desc = ('Lazy load %s on %s'):format(p.spec.name, event),
      callback = function()
        vim.cmd.packadd(p.spec.name)
        run_config_once()
      end,
    })
  end
end

--- @alias AddOpts (string | PluginSpec)[]

--- @class PluginSpec
--- @field src string
---@diagnostic disable-next-line: undefined-doc-name
--- @field version? string|vim.version.range
--- @field name? string
--- @field init? fun()
--- @field config? boolean|fun()
--- @field opts? table|fun():table
--- @field event? string|string[]
--- @field cmd? string|string[]
--- @field dependencies? string|string[]

--- @param plugins AddOpts
function M.add(plugins)
  for _, plugin in ipairs(plugins) do
    if type(plugin) == 'string' then
      vim.pack.add({ plugin })
    elseif type(plugin) == 'table' then
      if plugin.dependencies then
        local dependencies = to_list(plugin.dependencies)
        for _, dependency in ipairs(dependencies) do
          if type(dependency) == 'string' then
            vim.pack.add({ dependency })
          else
            vim.notify(
              ('Skipping dependency for `%s`: expected string, got %s'):format(
                plugin.name or plugin.src or 'unknown plugin',
                type(dependency)
              ),
              vim.log.levels.WARN
            )
          end
        end
      end

      vim.pack.add({
        {
          src = plugin.src,
          name = plugin.name,
          version = plugin.version,
          data = {
            init = plugin.init,
            config = plugin.config,
            opts = plugin.opts,
            event = plugin.event,
            cmd = plugin.cmd,
          },
        },
      }, {
        load = function(p)
          local data = p.spec.data or {}
          local run_config_once = run_config_once_factory(p, data)

          if type(data.init) == 'function' then
            data.init()
          end

          register_cmd_lazy_load(p, data, run_config_once)
          register_event_lazy_load(p, data, run_config_once)

          if not data.event and not data.cmd and data.config then
            run_config_once()
          end
        end,
      })
    end
  end
end

return M
