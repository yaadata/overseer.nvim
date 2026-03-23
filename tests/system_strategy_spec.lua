local overseer = require("overseer")
local SystemStrategy = require("overseer.strategy.system")

local function flush_scheduled()
  local done = false
  vim.schedule(function()
    done = true
  end)
  assert(vim.wait(1000, function()
    return done
  end, 10))
end

describe("system strategy", function()
  local original_system

  before_each(function()
    original_system = overseer.builtin.system
  end)

  after_each(function()
    overseer.builtin.system = original_system
  end)

  it("dispatches output after the buffer is wiped", function()
    local callbacks = {}
    local handle = {
      wait = function()
        return { code = 0 }
      end,
    }
    overseer.builtin.system = function(_, opts, on_exit)
      callbacks.opts = opts
      callbacks.on_exit = on_exit
      return handle
    end

    local events = {}
    local task = {
      name = "system test",
      cmd = { "echo", "hello" },
      cwd = vim.fn.getcwd(),
      dispatch = function(_, event, data)
        table.insert(events, { event = event, data = data })
      end,
      on_exit = function() end,
    }

    local strategy = SystemStrategy.new()
    strategy:start(task)
    vim.api.nvim_buf_delete(strategy.bufnr, { force = true })

    callbacks.opts.stdout(nil, "hello\n")
    flush_scheduled()

    assert.are.same("on_output", events[1].event)
    assert.are.same({ "hello", "" }, events[1].data)
    assert.are.same("on_output_lines", events[2].event)
    assert.are.same({ "hello" }, events[2].data)
  end)

  it("completes cleanly after the buffer is wiped", function()
    local callbacks = {}
    local handle = {
      wait = function()
        return { code = 0 }
      end,
    }
    overseer.builtin.system = function(_, opts, on_exit)
      callbacks.opts = opts
      callbacks.on_exit = on_exit
      return handle
    end

    local exit_codes = {}
    local task = {
      name = "system test",
      cmd = { "echo", "hello" },
      cwd = vim.fn.getcwd(),
      dispatch = function() end,
      on_exit = function(_, code)
        table.insert(exit_codes, code)
      end,
    }

    local strategy = SystemStrategy.new()
    strategy:start(task)
    vim.api.nvim_buf_delete(strategy.bufnr, { force = true })

    callbacks.on_exit({ code = 7 })
    -- on_exit schedules work that triggers a second scheduled output flush.
    flush_scheduled()
    flush_scheduled()

    assert.is_nil(strategy.handle)
    assert.are.same({ 7 }, exit_codes)
  end)
end)
