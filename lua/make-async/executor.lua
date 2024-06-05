---@class Executor
---@field private clear_func function(): nil Clear QuickFix
---@field private append_func function(title: string, lines: string[]): nil Set title and/or append lines to the QuickFix
---@field private job_id number?
---@field private timer_id number
---@field private keymap_set boolean
---@field private wheel_phase number
---@field private bufnr number QuickFix buffer number
---@field private winnr number QuickFix window number
local Executor = {}
Executor.__index = Executor

---Constructor
---@param clear_func function(): nil Clear QuickFix
---@param append_func function(title: string, lines: string[]): nil Set title and/or append lines to the QuickFix
function Executor.new(clear_func, append_func)
  local self = setmetatable({}, Executor)
  self.clear_func = clear_func
  self.append_func = append_func
  self.job_id = 0
  self.timer_id = -1
  self.keymap_set = false
  self.wheel_phase = 0
  self.bufnr = 0
  return self
end

local function filter_out_controls(line)
    return line:gsub('\x1B[@-_][0-?]*[ -/]*[@-~]', '')
end

---Jump to the bottom of the window if open
function Executor:jump_to_bottom()
  -- If the quickfix window has been closed, check if there's another window with quickfix
  if not vim.api.nvim_win_is_valid(self.winnr) then
    local windows = vim.fn.win_findbuf(self.bufnr)
    if #windows == 0 then return end  -- no quickfix window at the moment
    self.winnr = windows[1]
  end
  -- Put cursor to the end of the quickfix window
  local num_lines = vim.api.nvim_buf_line_count(self.bufnr)
  local _, col = unpack(vim.api.nvim_win_get_cursor(self.winnr))
  vim.api.nvim_win_set_cursor(self.winnr, {num_lines, col})
end

---Stop the job
function Executor:stop_job()
  if self.timer_id >= 0 then
    vim.fn.timer_stop(self.timer_id)
    self.timer_id = -1
  end
  if self.job_id > 0 then
    vim.fn.jobstop(self.job_id)
    self.job_id = 0
    print("Command interrupted")
  end
end

---Set keymap in the QuickFix buffer
---@param finalize_func function(): nil Action to execute after stop_job()
function Executor:set_keymap(finalize_func)
  vim.api.nvim_buf_set_keymap(self.bufnr, 'n', '<c-c>', '', { noremap = true, callback = function() self:stop_job(); finalize_func() end, desc = "Stop 'makeprg'" })
  self.keymap_set = true
end

---Delete buffer keymap
function Executor:del_keymap()
  if self.keymap_set then
    vim.api.nvim_buf_del_keymap(self.bufnr, 'n', '<c-c>')
    self.keymap_set = false
  end
end

local wheel = {'-', '\\', '|', '/'}

---Advance progress, get title with progress indicator
function Executor:get_phase_title(cmd)
  self.wheel_phase = self.wheel_phase % #wheel + 1
  return wheel[self.wheel_phase] .. ' ' .. cmd
end

---Execute command asynchronously
---@param command_provider function(): string Get the command to execute
function Executor:execute(command_provider)
  -- Stop any previous jobs
  if self.job_id > 0 then
    vim.fn.chanclose(self.job_id)
    self.job_id = 0
    self:stop_job()
    self:del_keymap()
  end
  self.wheel_phase = 1

  -- Clear the qf list
  self.clear_func()

  local cmd = command_provider()
  if not cmd then return end

  -- Collect unfinished line, which can be the last and first piece of data
  local partial_chunk = ''

  local function on_event(job_id, data, event)
    if self.job_id ~= job_id then return end

    if event == "stdout" or event == "stderr" then
      -- If only one chunk, it's a part of a line
      if #data == 1 then
        partial_chunk = partial_chunk .. data[1]
      else
        for i, chunk in ipairs(data) do
          -- Take into account potentially unfinished lines in the previous bunch of output
          if i == 1 then
            self.append_func(self:get_phase_title(cmd), {filter_out_controls(partial_chunk .. chunk)})
            partial_chunk = ''
          elseif i == #data then
            -- Just remember the last chunk
            partial_chunk = chunk
          else
            -- Output immediately complete lines
            self.append_func(self:get_phase_title(cmd), {filter_out_controls(chunk)})
          end
        end
      end
      self:jump_to_bottom()
    elseif event == "exit" then
      vim.fn.timer_stop(self.timer_id)
      self.timer_id = -1
      if partial_chunk ~= '' then
        self.append_func(cmd, {filter_out_controls(partial_chunk)})
        self:jump_to_bottom()
      else
        self.append_func(cmd, {})
      end
      self:del_keymap()
      --vim.api.nvim_command("doautocmd QuickFixCmdPost")
    end
  end

  self.job_id = vim.fn.jobstart(cmd, {
      on_stderr = on_event,
      on_stdout = on_event,
      on_exit = on_event,
      stdout_buffered = false,
      stderr_buffered = false,
    })
  if self.job_id > 0 then
    vim.cmd('copen')
    self.winnr = vim.fn.win_getid()
    self.bufnr = vim.api.nvim_win_get_buf(self.winnr)
    self.timer_id = vim.fn.timer_start(500, function() self.append_func(self:get_phase_title(cmd), {}) end, {["repeat"] = -1})
    self:set_keymap(function() self.append_func(cmd, {}) end)
  end
end

return Executor
