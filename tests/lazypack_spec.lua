local real_vim = vim
local real_print = print

local function make_vim_mock()
  local state = {
    augroup_calls = {},
    pack_add_calls = {},
    command_defs = {},
    del_command_calls = {},
    autocmd_calls = {},
    exec_autocmd_calls = {},
    notify_calls = {},
    cmd_calls = {},
    packadd_calls = {},
    getcompletion_calls = {},
    global_commands = {},
    buf_commands = {},
    create_user_command_errors = {},
    packadd_hooks = {},
    pack_get_result = {},
    pack_del_calls = {},
    pack_update_calls = {},
    confirm_calls = {},
    confirm_result = 2,
    print_calls = {},
    system_calls = {},
    system_wait_calls = {},
  }

  local cmd = {}
  setmetatable(cmd, {
    __call = function(_, arg)
      table.insert(state.cmd_calls, arg)
    end,
  })

  function cmd.packadd(name)
    table.insert(state.packadd_calls, name)
    local hook = state.packadd_hooks[name]
    if hook then
      hook()
    end
  end

  local vim_mock = {
    pack = {
      add = function(specs, opts)
        table.insert(state.pack_add_calls, { specs = specs, opts = opts })
      end,
      get = function()
        return state.pack_get_result
      end,
      del = function(specs)
        table.insert(state.pack_del_calls, specs)
      end,
      update = function()
        table.insert(state.pack_update_calls, true)
      end,
    },
    cmd = cmd,
    api = {
      nvim_create_augroup = function(name, opts)
        table.insert(state.augroup_calls, { name = name, opts = opts })
        return #state.augroup_calls
      end,
      nvim_create_user_command = function(name, callback, opts)
        local err = state.create_user_command_errors[name]
        if err then
          error(err)
        end
        state.command_defs[name] = { callback = callback, opts = opts }
      end,
      nvim_del_user_command = function(name)
        table.insert(state.del_command_calls, name)
        state.command_defs[name] = nil
      end,
      nvim_create_autocmd = function(event, opts)
        table.insert(state.autocmd_calls, { event = event, opts = opts })
      end,
      nvim_exec_autocmds = function(event, opts)
        table.insert(state.exec_autocmd_calls, { event = event, opts = opts })
      end,
      nvim_get_commands = function()
        return state.global_commands
      end,
      nvim_buf_get_commands = function()
        return state.buf_commands
      end,
    },
    fn = {
      getcompletion = function(line, kind)
        table.insert(state.getcompletion_calls, { line = line, kind = kind })
        return { 'ok' }
      end,
      confirm = function(msg, choices, default)
        table.insert(state.confirm_calls, { msg = msg, choices = choices, default = default })
        return state.confirm_result
      end,
    },
    notify = function(msg, level)
      table.insert(state.notify_calls, { msg = msg, level = level })
    end,
    system = function(command, opts, on_exit)
      local call = { command = command, opts = opts }
      table.insert(state.system_calls, call)
      if type(on_exit) == 'function' then
        on_exit({ code = 0, stderr = '' })
      end
      return {
        wait = function()
          table.insert(state.system_wait_calls, call)
          return { code = 0, stderr = '' }
        end,
      }
    end,
    schedule = function(fn)
      fn()
    end,
    log = real_vim.log or { levels = { ERROR = 'ERROR', WARN = 'WARN' } },
  }

  vim_mock.api = setmetatable(vim_mock.api, { __index = real_vim.api })
  vim_mock.fn = setmetatable(vim_mock.fn, { __index = real_vim.fn })
  vim_mock.pack = setmetatable(vim_mock.pack, { __index = (real_vim.pack or {}) })

  setmetatable(vim_mock, { __index = real_vim })

  return vim_mock, state
end

local function load_module()
  package.loaded.lazypack = nil
  package.loaded['lazypack.events'] = nil
  package.loaded['lazypack.cmd'] = nil
  package.loaded['lazypack.config'] = nil
  package.loaded['lazypack.build'] = nil
  package.loaded['lazypack.pack'] = nil
  package.loaded['lazypack.utils'] = nil
  return require('lazypack')
end

local function find_autocmd(event, pattern)
  for _, autocmd in ipairs(__state.autocmd_calls) do
    if autocmd.event == event and autocmd.opts.pattern == pattern then
      return autocmd
    end
  end
end

local function count_autocmds(event)
  local count = 0
  for _, autocmd in ipairs(__state.autocmd_calls) do
    if autocmd.event == event then
      count = count + 1
    end
  end
  return count
end

local function run_autocmds(event, ev)
  for _, autocmd in ipairs(__state.autocmd_calls) do
    if autocmd.event == event then
      autocmd.opts.callback(ev)
    end
  end
end

local function gh(path)
  return 'https://github.com/' .. path
end

describe('lazypack.add', function()
  before_each(function()
    _G.vim, _G.__state = make_vim_mock()
    _G.print = function(...)
      local parts = {}
      for i = 1, select('#', ...) do
        parts[i] = tostring(select(i, ...))
      end
      table.insert(__state.print_calls, table.concat(parts, '\t'))
    end
  end)

  after_each(function()
    package.loaded.lazypack = nil
    package.loaded['lazypack.events'] = nil
    package.loaded['lazypack.cmd'] = nil
    package.loaded['lazypack.config'] = nil
    package.loaded['lazypack.build'] = nil
    package.loaded['lazypack.pack'] = nil
    package.loaded['lazypack.utils'] = nil
    package.loaded['plugin.mod'] = nil
    _G.vim = real_vim
    _G.print = real_print
    _G.__state = nil
  end)

  it('adds string plugins directly', function()
    local lazypack = load_module()
    lazypack.add({ 'foo/bar' })

    assert.equals(1, #__state.pack_add_calls)
    assert.same({ gh('foo/bar') }, __state.pack_add_calls[1].specs)
  end)

  it('keeps full https source for string plugins', function()
    local lazypack = load_module()
    lazypack.add({ 'https://github.com/foo/bar' })

    assert.equals(1, #__state.pack_add_calls)
    assert.same({ 'https://github.com/foo/bar' }, __state.pack_add_calls[1].specs)
  end)

  it('registers spec plugin with expected data', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        name = 'plugin.mod',
        version = '1.0.0',
        event = 'BufReadPost',
        cmd = 'MyCmd',
      },
    })

    local call = __state.pack_add_calls[1]
    assert.equals(gh('foo/bar'), call.specs[1].src)
    assert.equals('plugin.mod', call.specs[1].name)
    assert.equals('1.0.0', call.specs[1].version)
    assert.equals('BufReadPost', call.specs[1].data.event)
    assert.equals('MyCmd', call.specs[1].data.cmd)
    assert.is_nil(call.specs[1].data.build)
    assert.is_function(call.opts.load)
  end)

  it('stores build in plugin data', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        build = 'make',
      },
    })

    local call = __state.pack_add_calls[1]
    assert.equals('make', call.specs[1].data.build)
  end)

  it('adds string dependency before plugin spec', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        dependencies = 'dep/one',
      },
    })

    assert.equals(2, #__state.pack_add_calls)
    assert.same({ gh('dep/one') }, __state.pack_add_calls[1].specs)
    assert.equals(gh('foo/bar'), __state.pack_add_calls[2].specs[1].src)
  end)

  it('adds multiple string dependencies', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        dependencies = { 'dep/one', 'dep/two' },
      },
    })

    assert.equals(3, #__state.pack_add_calls)
    assert.same({ gh('dep/one') }, __state.pack_add_calls[1].specs)
    assert.same({ gh('dep/two') }, __state.pack_add_calls[2].specs)
    assert.equals(gh('foo/bar'), __state.pack_add_calls[3].specs[1].src)
  end)

  it('keeps full https source for dependencies and spec src', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'https://github.com/foo/bar',
        dependencies = 'https://github.com/dep/one',
      },
    })

    assert.equals(2, #__state.pack_add_calls)
    assert.same({ 'https://github.com/dep/one' }, __state.pack_add_calls[1].specs)
    assert.equals('https://github.com/foo/bar', __state.pack_add_calls[2].specs[1].src)
  end)

  it('warns and skips non-string dependency entries', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        name = 'plugin.mod',
        dependencies = { 'dep/one', { src = 'dep/two' } },
      },
    })

    assert.equals(2, #__state.pack_add_calls)
    assert.same({ gh('dep/one') }, __state.pack_add_calls[1].specs)
    assert.equals(gh('foo/bar'), __state.pack_add_calls[2].specs[1].src)
    assert.equals(1, #__state.notify_calls)
    assert.equals(vim.log.levels.WARN, __state.notify_calls[1].level)
  end)

  it('skips plugin when enabled is false', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        enabled = false,
      },
    })

    assert.equals(0, #__state.pack_add_calls)
  end)

  it('adds plugin when enabled is true', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        enabled = true,
      },
    })

    assert.equals(1, #__state.pack_add_calls)
    assert.equals(gh('foo/bar'), __state.pack_add_calls[1].specs[1].src)
  end)

  it('uses enabled function result', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        enabled = function()
          return false
        end,
      },
      {
        src = 'foo/baz',
        enabled = function()
          return true
        end,
      },
    })

    assert.equals(1, #__state.pack_add_calls)
    assert.equals(gh('foo/baz'), __state.pack_add_calls[1].specs[1].src)
  end)

  it('warns and skips plugin when enabled function errors', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        enabled = function()
          error('boom')
        end,
      },
    })

    assert.equals(0, #__state.pack_add_calls)
    assert.equals(1, #__state.notify_calls)
    assert.equals(vim.log.levels.WARN, __state.notify_calls[1].level)
  end)

  it('does not add dependencies when plugin is disabled', function()
    local lazypack = load_module()
    lazypack.add({
      {
        src = 'foo/bar',
        dependencies = { 'dep/one', 'dep/two' },
        enabled = false,
      },
    })

    assert.equals(0, #__state.pack_add_calls)
  end)

  it('calls setup with table opts when config=true', function()
    local lazypack = load_module()
    local seen_opts
    package.loaded['plugin.mod'] = {
      setup = function(opts)
        seen_opts = opts
      end,
    }

    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      config = true,
      opts = { alpha = 1 },
    } })

    local call = __state.pack_add_calls[1]
    call.opts.load({ spec = call.specs[1] })

    assert.same({ alpha = 1 }, seen_opts)
  end)

  it('calls opts function and setup once across cmd and event', function()
    local lazypack = load_module()
    local setup_calls = 0
    local opts_calls = 0

    package.loaded['plugin.mod'] = {
      setup = function(opts)
        setup_calls = setup_calls + 1
        assert.same({ beta = true }, opts)
      end,
    }

    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      config = true,
      opts = function()
        opts_calls = opts_calls + 1
        return { beta = true }
      end,
      cmd = 'MyCmd',
      event = 'BufReadPost',
    } })

    local call = __state.pack_add_calls[1]
    call.opts.load({ spec = call.specs[1] })

    __state.packadd_hooks['plugin.mod'] = function()
      __state.global_commands.MyCmd = { nargs = '*' }
    end

    __state.command_defs.MyCmd.callback({
      bang = false,
      smods = {},
      fargs = {},
      count = -1,
      range = 0,
      args = '',
    })

    local event_autocmd = find_autocmd('BufReadPost', nil)
    assert.is_table(event_autocmd)
    event_autocmd.opts.callback()

    assert.equals(1, setup_calls)
    assert.equals(1, opts_calls)
  end)

  it('forwards command with recursion guard', function()
    local lazypack = load_module()
    package.loaded['plugin.mod'] = { setup = function() end }

    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      config = true,
      cmd = 'MyCmd',
    } })

    local call = __state.pack_add_calls[1]
    call.opts.load({ spec = call.specs[1] })

    __state.packadd_hooks['plugin.mod'] = function()
      __state.global_commands.MyCmd = { nargs = '*' }
    end

    __state.command_defs.MyCmd.callback({
      bang = true,
      smods = { silent = true },
      fargs = { 'x' },
      count = 2,
      range = 0,
      args = 'x',
    })

    assert.equals('MyCmd', __state.del_command_calls[1])
    assert.is_table(__state.cmd_calls[1])
    assert.equals('MyCmd', __state.cmd_calls[1].cmd)
  end)

  it('creates once autocmd with lazypack group and desc', function()
    local lazypack = load_module()
    package.loaded['plugin.mod'] = { setup = function() end }

    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      config = true,
      event = 'InsertEnter',
    } })

    local call = __state.pack_add_calls[1]
    call.opts.load({ spec = call.specs[1] })

    local event_autocmd = find_autocmd('InsertEnter', nil)
    assert.is_table(event_autocmd)
    assert.equals(1, event_autocmd.opts.group)
    assert.equals(true, event_autocmd.opts.once)
    assert.equals('Lazy load plugin.mod on InsertEnter', event_autocmd.opts.desc)
  end)

  it('maps lazy style events to User autocmd pattern', function()
    local lazypack = load_module()
    package.loaded['plugin.mod'] = { setup = function() end }

    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      config = true,
      event = 'LazyInstall',
    } })

    local call = __state.pack_add_calls[1]
    call.opts.load({ spec = call.specs[1] })

    local event_autocmd = find_autocmd('User', 'LazyInstall')
    assert.is_table(event_autocmd)
    assert.equals('Lazy load plugin.mod on LazyInstall', event_autocmd.opts.desc)
  end)

  it('bridges PackChanged and PackChangedPre to lazy user events', function()
    local lazypack = load_module()
    lazypack.add({ 'foo/bar' })

    local pack_changed_pre = find_autocmd('PackChangedPre', nil)
    local pack_changed = find_autocmd('PackChanged', nil)
    assert.is_table(pack_changed_pre)
    assert.is_table(pack_changed)

    local install_data = { kind = 'install', spec = { name = 'foo' }, active = true, path = '/tmp/foo' }
    local update_data = { kind = 'update', spec = { name = 'foo' }, active = true, path = '/tmp/foo' }
    local delete_data = { kind = 'delete', spec = { name = 'foo' }, active = false, path = '/tmp/foo' }

    pack_changed_pre.opts.callback({ data = install_data })
    pack_changed_pre.opts.callback({ data = update_data })
    pack_changed_pre.opts.callback({ data = delete_data })
    pack_changed.opts.callback({ data = install_data })
    pack_changed.opts.callback({ data = update_data })
    pack_changed.opts.callback({ data = delete_data })

    assert.equals(6, #__state.exec_autocmd_calls)
    assert.equals('User', __state.exec_autocmd_calls[1].event)
    assert.equals('LazyInstallPre', __state.exec_autocmd_calls[1].opts.pattern)
    assert.same(install_data, __state.exec_autocmd_calls[1].opts.data)
    assert.equals('LazyUpdatePre', __state.exec_autocmd_calls[2].opts.pattern)
    assert.equals('LazyCleanPre', __state.exec_autocmd_calls[3].opts.pattern)
    assert.equals('LazyInstall', __state.exec_autocmd_calls[4].opts.pattern)
    assert.equals('LazyUpdate', __state.exec_autocmd_calls[5].opts.pattern)
    assert.equals('LazyClean', __state.exec_autocmd_calls[6].opts.pattern)
  end)

  it('emits VeryLazy after VimEnter', function()
    local lazypack = load_module()
    lazypack.add({ 'foo/bar' })

    local vim_enter = find_autocmd('VimEnter', nil)
    assert.is_table(vim_enter)
    vim_enter.opts.callback()

    assert.equals(1, #__state.exec_autocmd_calls)
    assert.equals('User', __state.exec_autocmd_calls[1].event)
    assert.equals('VeryLazy', __state.exec_autocmd_calls[1].opts.pattern)
  end)

  it('registers bridge autocmds only once', function()
    local lazypack = load_module()
    lazypack.add({ 'foo/bar' })
    lazypack.add({ 'foo/baz' })

    assert.equals(1, count_autocmds('PackChangedPre'))
    assert.equals(2, count_autocmds('PackChanged'))
    assert.equals(1, count_autocmds('VimEnter'))
  end)

  it('warns and continues on user command collision', function()
    local lazypack = load_module()
    __state.create_user_command_errors.MyCmd = 'E174: Command already exists'

    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      cmd = 'MyCmd',
      config = true,
    } })

    local call = __state.pack_add_calls[1]
    call.opts.load({ spec = call.specs[1] })

    assert.equals(1, #__state.notify_calls)
    assert.equals(vim.log.levels.WARN, __state.notify_calls[1].level)
  end)

  it('runs string build asynchronously on install and update', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = 'make',
    } })

    local data = { kind = 'install', spec = { name = 'plugin.mod', data = { build = 'make' } }, path = '/tmp/foo' }
    run_autocmds('PackChanged', { data = data })
    data.kind = 'update'
    run_autocmds('PackChanged', { data = data })

    assert.equals(2, #__state.system_calls)
    assert.same({ vim.o.shell, vim.o.shellcmdflag, 'make' }, __state.system_calls[1].command)
    assert.equals('/tmp/foo', __state.system_calls[1].opts.cwd)
  end)

  it('runs list build asynchronously in order', function()
    local lazypack = load_module()
    local seen
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = {
        ':TSUpdate',
        'make arg',
        function()
          seen = 'ok'
        end,
      },
    } })

    run_autocmds('PackChanged', {
      data = {
        kind = 'install',
        active = false,
        spec = {
          name = 'plugin.mod',
          data = {
            build = {
              ':TSUpdate',
              'make arg',
              function()
                seen = 'ok'
              end,
            },
          },
        },
        path = '/tmp/foo',
      },
    })

    assert.equals('plugin.mod', __state.packadd_calls[1])
    assert.equals('TSUpdate', __state.cmd_calls[1])
    assert.equals(1, #__state.system_calls)
    assert.same({ vim.o.shell, vim.o.shellcmdflag, 'make arg' }, __state.system_calls[1].command)
    assert.equals('/tmp/foo', __state.system_calls[1].opts.cwd)
    assert.equals('ok', seen)
  end)

  it('runs vim command build for colon-prefixed string', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = ':TSUpdate',
    } })

    run_autocmds('PackChanged', {
      data = { kind = 'install', active = false, spec = { name = 'plugin.mod', data = { build = ':TSUpdate' } }, path = '/tmp/foo' },
    })

    assert.equals('plugin.mod', __state.packadd_calls[1])
    assert.equals('TSUpdate', __state.cmd_calls[1])
    assert.equals(0, #__state.system_calls)
  end)

  it('does not packadd before colon build when already active', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = ':TSUpdate',
    } })

    run_autocmds('PackChanged', {
      data = { kind = 'update', active = true, spec = { name = 'plugin.mod', data = { build = ':TSUpdate' } }, path = '/tmp/foo' },
    })

    assert.equals(0, #__state.packadd_calls)
    assert.equals('TSUpdate', __state.cmd_calls[1])
  end)

  it('runs build function with event data', function()
    local lazypack = load_module()
    local seen
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = function(ev)
        seen = ev
      end,
    } })

    local data = {
      kind = 'install',
      spec = {
        name = 'plugin.mod',
        data = {
          build = function(ev)
            seen = ev
          end,
        },
      },
      path = '/tmp/foo',
    }
    run_autocmds('PackChanged', { data = data })

    assert.is_table(seen)
    assert.same(data, seen.data)
  end)

  it('resumes yielded build function on next tick', function()
    local lazypack = load_module()
    local calls = {}
    local yielded_build = function()
      table.insert(calls, 'start')
      coroutine.yield('progress')
      table.insert(calls, 'done')
    end
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = yielded_build,
    } })

    run_autocmds('PackChanged', {
      data = { kind = 'install', spec = { name = 'plugin.mod', data = { build = yielded_build } }, path = '/tmp/foo' },
    })

    assert.same({ 'start', 'done' }, calls)
  end)

  it('does not run build on delete', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = 'make',
    } })

    run_autocmds('PackChanged', {
      data = { kind = 'delete', spec = { name = 'plugin.mod', data = { build = 'make' } }, path = '/tmp/foo' },
    })

    assert.equals(0, #__state.system_calls)
  end)

  it('runs build using spec.name and ignores src-only spec', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = 'make',
    } })

    run_autocmds('PackChanged', {
      data = { kind = 'install', spec = { src = gh('foo/bar'), data = { build = 'make' } }, path = '/tmp/foo' },
    })

    assert.equals(0, #__state.system_calls)
    assert.equals(1, #__state.notify_calls)

    run_autocmds('PackChanged', {
      data = { kind = 'install', spec = { name = 'plugin.mod', data = { build = 'make' } }, path = '/tmp/foo' },
    })

    assert.equals(1, #__state.system_calls)
  end)

  it('warns only once when PackChanged event has no spec.name', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = 'make',
    } })

    local ev = { data = { kind = 'install', spec = { src = gh('foo/bar'), data = { build = 'make' } }, path = '/tmp/foo' } }
    run_autocmds('PackChanged', ev)
    run_autocmds('PackChanged', ev)

    assert.equals(1, #__state.notify_calls)
  end)

  it('warns and skips unsupported build type', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = 42,
    } })

    run_autocmds('PackChanged', {
      data = { kind = 'install', spec = { name = 'plugin.mod', data = { build = 42 } }, path = '/tmp/foo' },
    })

    assert.equals(1, #__state.notify_calls)
    assert.equals(vim.log.levels.WARN, __state.notify_calls[1].level)
    assert.equals(0, #__state.system_calls)
  end)

  it('warns and continues when build list has invalid step', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      build = { ':TSUpdate', 123, 'make arg' },
    } })

    run_autocmds('PackChanged', {
      data = {
        kind = 'install',
        active = false,
        spec = { name = 'plugin.mod', data = { build = { ':TSUpdate', 123, 'make arg' } } },
        path = '/tmp/foo',
      },
    })

    assert.equals('TSUpdate', __state.cmd_calls[1])
    assert.equals(1, #__state.system_calls)
    assert.equals(1, #__state.notify_calls)
    assert.equals(vim.log.levels.WARN, __state.notify_calls[1].level)
  end)

  it('does not run build for disabled plugins', function()
    local lazypack = load_module()
    lazypack.add({ {
      src = 'foo/bar',
      name = 'plugin.mod',
      enabled = false,
      build = 'make',
    } })

    run_autocmds('PackChanged', {
      data = { kind = 'install', spec = { name = 'plugin.mod' }, path = '/tmp/foo' },
    })

    assert.equals(0, #__state.system_calls)
  end)

  it('exposes pack_update and calls vim.pack.update', function()
    local lazypack = load_module()

    lazypack.pack_update()

    assert.equals(1, #__state.pack_update_calls)
  end)

  it('pack_clean prints when there are no unused plugins', function()
    local lazypack = load_module()
    __state.pack_get_result = {
      { spec = { name = 'used' }, active = true },
    }

    lazypack.pack_clean()

    assert.equals(1, #__state.print_calls)
    assert.equals('No unused plugins.', __state.print_calls[1])
    assert.equals(0, #__state.confirm_calls)
    assert.equals(0, #__state.pack_del_calls)
  end)

  it('pack_clean deletes unused plugins when confirmed', function()
    local lazypack = load_module()
    __state.confirm_result = 1
    __state.pack_get_result = {
      { spec = { name = 'used' }, active = true },
      { spec = { name = 'unused' }, active = false },
    }

    lazypack.pack_clean()

    assert.equals(1, #__state.confirm_calls)
    assert.equals(1, #__state.pack_del_calls)
    assert.same({ 'unused' }, __state.pack_del_calls[1])
  end)

  it('warns once when pack_clean sees plugins without spec.name', function()
    local lazypack = load_module()
    __state.pack_get_result = {
      { spec = { src = gh('owner/a') }, active = false },
      { spec = { src = gh('owner/b') }, active = false },
    }

    lazypack.pack_clean()
    lazypack.pack_clean()

    assert.equals(1, #__state.notify_calls)
    assert.equals(vim.log.levels.WARN, __state.notify_calls[1].level)
  end)

  it('pack_clean does not delete when confirmation is rejected', function()
    local lazypack = load_module()
    __state.confirm_result = 2
    __state.pack_get_result = {
      { spec = { name = 'unused' }, active = false },
    }

    lazypack.pack_clean()

    assert.equals(1, #__state.confirm_calls)
    assert.equals(0, #__state.pack_del_calls)
  end)
end)
