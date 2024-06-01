return {
	"git@gitlab.com:gitlab-org/editor-extensions/gitlab.vim.git",
	dev = true,
	event = { "BufReadPre", "BufNewFile" }, -- Activate when a file is created/opened
	ft = { "go", "javascript", "python", "ruby" }, -- Activate when a supported filetype is open
	cond = function()
		-- temporarily disable
		return false
		-- return vim.env.GITLAB_TOKEN ~= nil and vim.env.GITLAB_TOKEN ~= "" -- Only activate is token is present in environment variable (remove to use interactive workflow)
	end,
	opts = {
		statusline = {
			enabled = true, -- Hook into the builtin statusline to indicate the status of the GitLab Duo Code Suggestions integration
		},
	},
}
