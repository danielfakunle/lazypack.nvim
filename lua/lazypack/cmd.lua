local utils = require('lazypack.utils')

local M = {}

--- @param p table
--- @param data table
--- @param run_config_once fun()
function M.register_cmd_lazy_load(p, data, run_config_once)
  if not data.cmd then
    return
  end

  local cmds = utils.to_list(data.cmd)

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

return M
