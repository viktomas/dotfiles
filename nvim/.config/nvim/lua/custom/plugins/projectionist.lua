return {
	"tpope/vim-projectionist",
	config = function()
		vim.g.projectionist_heuristics = {
			["*"] = {
				["*.ts"] = {
					alternate = "{}.test.ts",
				},
				["*.test.ts"] = {
					alternate = "{}.ts",
				},
			},
		}
	end,
}
