local M = {}

local function git_cmd(args)
	local cmd = "git -C " .. vim.fn.shellescape(vim.fn.expand("%:p:h")) .. " " .. args
	local result = vim.fn.system(cmd):gsub("\n", "")
	return result
end

-- Function to generate a GitLab permalink for the current line and file
function M.gitlab_permalink()
	local git_root = git_cmd("rev-parse --show-toplevel")
	if git_root == "" or git_root:match("fatal:") then
		print("not in a git repository")
		return
	end

	local file_path = vim.fn.expand("%:p")
	local relative_path = git_cmd("ls-files --full-name -- " .. file_path)
	if relative_path == "" then
		print("File not tracked by git")
		return
	end

	local line = vim.fn.line(".")

	local commit_hash = git_cmd('log -n 1 --pretty=format:"%H" -- ' .. vim.fn.shellescape(file_path))

	if commit_hash == "" then
		print("failed to get the last commit for a file, maybe it's not committed yet.")
		return
	end

	local remote_url = git_cmd("remote get-url origin")

	if remote_url == "" then
		print("Error: No remote URL found for origin")
		return
	end

	local web_url
	if remote_url:match("^git@") then
		-- SSH format: git@gitlab.com:username/repo.git
		web_url = remote_url:gsub("git@([^:]+):", "https://%1/"):gsub("%.git$", "")
	elseif remote_url:match("^https://") then
		-- HTTPS format: https://gitlab.com/username/repo.git
		web_url = remote_url:gsub("%.git$", "")
	else
		print("Unsupported remote URL format: " .. remote_url)
		return
	end

	local blob = "/blob/"
	if web_url:match("gitlab.com") then
		blob = "/-/blob/"
	end

	local permalink = web_url .. blob .. commit_hash .. "/" .. relative_path .. "#L" .. line

	vim.fn.setreg("+", permalink)
	print("Permalink copied to clipboard: " .. permalink)
end

-- Register the user command
vim.api.nvim_create_user_command("GitPermalink", M.gitlab_permalink, {})

return M

-- Optional: Add a mapping
