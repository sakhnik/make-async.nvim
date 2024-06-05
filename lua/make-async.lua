local Executor = require'make-async.executor'

local function qf_clear()
  vim.fn.setqflist({}, "r")
end

local function qf_append(title, lines)
  vim.fn.setqflist({}, "a", { title = title, lines = lines, })
end

local MakeAsync = {}

MakeAsync.qf = Executor.new(qf_clear, qf_append)

function MakeAsync.make()
  MakeAsync.qf:execute(function()
    local makeprg = vim.o.makeprg
    if not makeprg then return "" end
    return vim.fn.expandcmd(makeprg)
  end)
end

function MakeAsync.setup()
  vim.api.nvim_set_keymap('n', '<leader>mm', '', { noremap = true, callback = MakeAsync.make, desc = "Run 'makeprg' asynchronously and populate quickfix" })
  vim.api.nvim_create_user_command('X',
    function(a) MakeAsync.qf:execute(function() return a.args end) end,
    {nargs = "+", complete = "shellcmd", force = true, desc = 'Execute command asynchronously'})
end

return MakeAsync
