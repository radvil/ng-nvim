local Utils = require("ng-nvim.utils")

--- Finds and opens the stylesheet(s) (scss/sass/css/less)
--- for the current component or template.
---@param opts? { reuse_win?: boolean, split?: "vsplit" | "split" | "tab split" }
local goto_component_stylesheet = function(opts)
	opts = opts or {}
	local current_path = vim.api.nvim_buf_get_name(0)
	if current_path == "" then
		vim.notify("[ng-nvim] Current buffer has no file path.", vim.log.levels.WARN)
		return
	end

	local styles = Utils.find_associated_stylesheets(current_path)
	if #styles == 0 then
		vim.notify("[ng-nvim] No stylesheet found.", vim.log.levels.INFO)
		return
	end

	if #styles == 1 then
		Utils.open_uri(styles[1], opts)
	else
		vim.ui.select(styles, {
			prompt = "Select stylesheet:",
			format_item = function(item)
				return vim.fn.fnamemodify(item, ":t")
			end,
		}, function(choice)
			if choice then
				Utils.open_uri(choice, opts)
			end
		end)
	end
end

return {
	run = goto_component_stylesheet,
}
