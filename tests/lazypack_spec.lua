local real_vim = vim

local function make_vim_mock()
  local state = {
    augroup_calls = {},
    pack_add_calls = {},
    command_defs = {},
    del_command_calls = {},
    autocmd_calls = {},
    notify_calls = {},
    cmd_calls = {},
    packadd_calls = {},
    getcompletion_calls = {},
    global_commands = {},
    buf_commands = {},
    create_user_command_errors = {},
    packadd_hooks = {},
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
    },
    notify = function(msg, level)
      table.insert(state.notify_calls, { msg = msg, level = level })
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
  return require('lazypack')
end

describe('lazypack.add', function()
  before_each(function()
    _G.vim, _G.__state = make_vim_mock()
  end)

  after_each(function()
    package.loaded.lazypack = nil
    package.loaded['plugin.mod'] = nil
    _G.vim = real_vim
    _G.__state = nil
  end)

  it('adds string plugins directly', function()
    local lazypack = load_module()
    lazypack.add({ 'foo/bar' })

    assert.equals(1, #__state.pack_add_calls)
    assert.same({ 'foo/bar' }, __state.pack_add_calls[1].specs)
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
    assert.equals('foo/bar', call.specs[1].src)
    assert.equals('plugin.mod', call.specs[1].name)
    assert.equals('1.0.0', call.specs[1].version)
    assert.equals('BufReadPost', call.specs[1].data.event)
    assert.equals('MyCmd', call.specs[1].data.cmd)
    assert.is_function(call.opts.load)
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
    assert.same({ 'dep/one' }, __state.pack_add_calls[1].specs)
    assert.equals('foo/bar', __state.pack_add_calls[2].specs[1].src)
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
    assert.same({ 'dep/one' }, __state.pack_add_calls[1].specs)
    assert.same({ 'dep/two' }, __state.pack_add_calls[2].specs)
    assert.equals('foo/bar', __state.pack_add_calls[3].specs[1].src)
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
    assert.same({ 'dep/one' }, __state.pack_add_calls[1].specs)
    assert.equals('foo/bar', __state.pack_add_calls[2].specs[1].src)
    assert.equals(1, #__state.notify_calls)
    assert.equals(vim.log.levels.WARN, __state.notify_calls[1].level)
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

    __state.autocmd_calls[1].opts.callback()

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

    assert.equals(1, #__state.autocmd_calls)
    assert.equals('InsertEnter', __state.autocmd_calls[1].event)
    assert.equals(1, __state.autocmd_calls[1].opts.group)
    assert.equals(true, __state.autocmd_calls[1].opts.once)
    assert.equals('Lazy load plugin.mod on InsertEnter', __state.autocmd_calls[1].opts.desc)
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
end)
