local Executor = require'make-async.executor'

local function qf_clear()
  vim.fn.setqflist({}, "r")
end

local function qf_append(title, lines)
  vim.fn.setqflist({}, "a", { title = title, lines = lines, })
end

local MakeAsync = {}

MakeAsync.qf = Executor.new(qf_clear, qf_append)

function MakeAsync.get_make_cmd()
  local makeprg = vim.o.makeprg
  if not makeprg then return "" end
  return vim.fn.expandcmd(makeprg)
end

function MakeAsync.make()
  MakeAsync.qf:execute(function()
    return MakeAsync.get_make_cmd()
  end)
end

function MakeAsync.setup()
  vim.api.nvim_set_keymap('n', '<leader>mm', '', { noremap = true, callback = MakeAsync.make, desc = "Run 'makeprg' asynchronously and populate quickfix" })
  vim.api.nvim_create_user_command('X',
    function(a) MakeAsync.qf:execute(function() return a.args end) end,
    {nargs = "+", complete = "shellcmd", force = true, desc = 'Execute command asynchronously'})
  vim.api.nvim_create_user_command('Make',
    function(a) MakeAsync.qf:execute(function() return MakeAsync.get_make_cmd() .. ' ' .. a.args end) end,
    {nargs = "*", force = true, desc = 'Make asynchronously'})
end

return MakeAsync
