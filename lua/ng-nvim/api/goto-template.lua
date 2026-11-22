local Utils = require("ng-nvim.utils")

--- Finds the template for current component under cursor.
---@param opts? { reuse_win?: boolean, split?: "vsplit" | "split" | "tab split" }
local goto_component_template = function(opts)
	opts = opts or {}
	Utils.on_angular_workspace(function()
		Utils.request_client_command("angular/getTemplateLocationForComponent", function(_, result, client)
			if not result then
				vim.notify("[ng-nvim] No template found for component.", vim.log.levels.INFO)
				return
			end
			local target = vim.islist(result) and result[1] or result
			if target then
				Utils.show_document(target, client.offset_encoding, opts)
			end
		end)
	end)
end

return {
	run = goto_component_template,
}
