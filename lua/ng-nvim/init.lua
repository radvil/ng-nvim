local M = {}

local config = {
	ignored_dirs = {
		node_modules = true,
		[".git"] = true,
		dist = true,
		[".nx"] = true,
		[".angular"] = true,
	},
}

---@param opts { ignored_dirs: table<string,boolean> }
M.setup = function(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})
	local uc = vim.api.nvim_create_user_command

  -- stylua: ignore start
	uc("Atc", function() require("ng-nvim.api.get-tcb").run() end,                           { desc = "[ng-nvim] Display typecheck block under cursor" })

	uc("At",  function() require("ng-nvim.api.goto-template").run({ reuse_win = true }) end, { desc = "[ng-nvim] Go to template file" })
	uc("Ac",  function() require("ng-nvim.api.goto-class").run({ reuse_win = true }) end,    { desc = "[ng-nvim] Go to component file" })
	uc("As",  function() require("ng-nvim.api.goto-style").run({ reuse_win = true }) end,    { desc = "[ng-nvim] Go to stylesheet file" })
	uc("Ap",  function() require("ng-nvim.api.open-projects").run(opts.ignored_dirs) end, { desc = "[ng-nvim] Select projects" })

	uc("Atv", function() require("ng-nvim.api.goto-template").run({ split = "vsplit" }) end, { desc = "[ng-nvim] Open template file in vertical split" })
	uc("Acv", function() require("ng-nvim.api.goto-class").run({ split = "vsplit" }) end,    { desc = "[ng-nvim] Open component file in vertical split" })
	uc("Asv", function() require("ng-nvim.api.goto-style").run({ split = "vsplit" }) end,    { desc = "[ng-nvim] Open stylesheet file in vertical split" })
	-- stylua: ignore end
end

return M
