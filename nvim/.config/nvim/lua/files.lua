local M = {}

-- Default options
local defaults = {
	fzf_cmd = "fzf",
	find_cmd = 'find . -type f -not -path "*/\\.*" -not -path "*/node_modules/*"',
	preview_cmd = "cat {}",
	window_layout = "floating", -- 'floating' or 'split'
	window_height = 0.8,
	window_width = 0.8,
}

local config = vim.deepcopy(defaults)

-- Configure the plugin
function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
end

-- Create the floating window
local function create_floating_window()
	local width = math.floor(vim.o.columns * config.window_width)
	local height = math.floor(vim.o.lines * config.window_height)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local opts = {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
	}

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, opts)

	return buf, win
end

-- Handle FZF selection
local function on_fzf_selection(selected)
	if selected and #selected > 0 then
		local filename = selected[1]
		-- Trim any trailing newlines
		filename = filename:gsub("\n$", "")

		-- Open the selected file
		vim.cmd("edit " .. vim.fn.fnameescape(filename))
	end
end

function M.find_files(opts)
	opts = opts or {}
	local find_cmd = opts.find_cmd or config.find_cmd

	-- Create a temporary file to store FZF results
	local temp_file = vim.fn.tempname()

	-- Build the FZF command with the preview
	local preview_opt = '--preview="' .. (opts.preview_cmd or config.preview_cmd) .. '"'
	local cmd = find_cmd .. " | " .. config.fzf_cmd .. " " .. preview_opt .. " > " .. temp_file

	-- Create floating window
	local buf, win
	if config.window_layout == "floating" then
		buf, win = create_floating_window()
		-- Add a message to indicate FZF is running
		vim.api.nvim_buf_set_lines(
			buf,
			0,
			-1,
			false,
			{ "Running FZF...", "", "If this message stays, check if FZF is installed." }
		)
	end

	-- Execute the command in a terminal buffer
	local terminal_cmd = "terminal " .. cmd
	vim.cmd(terminal_cmd)

	-- Set up autocmd to handle FZF completion
	vim.cmd([[
    augroup FzfPickerTemp
      autocmd!
      autocmd TermClose * lua require('fzf_picker').handle_fzf_exit()
    augroup END
  ]])

	-- Store state for the callback
	M._state = {
		temp_file = temp_file,
		buf = buf,
		win = win,
	}
end

-- Handle FZF exit
function M.handle_fzf_exit()
	-- Clean up autocmd
	vim.cmd([[
    augroup FzfPickerTemp
      autocmd!
    augroup END
  ]])

	-- Process result
	if M._state and M._state.temp_file then
		local lines = {}
		local file = io.open(M._state.temp_file, "r")
		if file then
			local content = file:read("*all")
			file:close()

			-- Remove temp file
			os.remove(M._state.temp_file)

			-- Process selection
			if content and content ~= "" then
				-- Remove trailing newline if present
				content = content:gsub("\n$", "")

				-- Open the selected file
				vim.cmd("edit " .. vim.fn.fnameescape(content))
			end
		end

		-- Clean up windows
		if M._state.win and vim.api.nvim_win_is_valid(M._state.win) then
			vim.api.nvim_win_close(M._state.win, true)
		end
		if M._state.buf and vim.api.nvim_buf_is_valid(M._state.buf) then
			vim.api.nvim_buf_delete(M._state.buf, { force = true })
		end

		M._state = nil
	end
end

-- Search in git repositories
function M.git_files()
	M.find_files({
		find_cmd = "git ls-files",
	})
end

-- Search with ripgrep
function M.live_grep()
	local input = vim.fn.input("Search for > ")
	if input and input ~= "" then
		M.find_files({
			find_cmd = 'rg --line-number --column --no-heading --color=never "' .. input .. '"',
			preview_cmd = "bat --style=numbers --color=always --highlight-line {2} {1}",
		})
	end
end

return M
