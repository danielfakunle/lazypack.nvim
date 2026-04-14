local config = require('lazypack.config')
local cmd = require('lazypack.cmd')
local events = require('lazypack.events')
local utils = require('lazypack.utils')

local M = {}
local augroup = vim.api.nvim_create_augroup('lazypack', { clear = false })

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
--- @field enabled? boolean|fun():boolean

--- @param plugins AddOpts
function M.add(plugins)
  events.ensure_event_bridges(augroup)

  for _, plugin in ipairs(plugins) do
    if type(plugin) == 'string' then
      vim.pack.add({ utils.normalize_source(plugin) })
    elseif type(plugin) == 'table' then
      if config.is_enabled(plugin) then
        if plugin.dependencies then
          local dependencies = utils.to_list(plugin.dependencies)
          for _, dependency in ipairs(dependencies) do
            if type(dependency) == 'string' then
              vim.pack.add({ utils.normalize_source(dependency) })
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
            src = utils.normalize_source(plugin.src),
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
            local run_config_once = config.run_config_once_factory(p, data)

            if type(data.init) == 'function' then
              data.init()
            end

            cmd.register_cmd_lazy_load(p, data, run_config_once)
            events.register_event_lazy_load(p, data, run_config_once, augroup)

            if not data.event and not data.cmd and data.config then
              run_config_once()
            end
          end,
        })
      end
    end
  end
end

return M
