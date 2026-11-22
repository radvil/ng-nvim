local Utils = require("ng-nvim.utils")

--- Finds components which reference an external template in their `templateUrl`s.
---@param opts? { reuse_win?: boolean, split?: "vsplit" | "split" }
local goto_component_class = function(opts)
	opts = opts or {}
	Utils.on_angular_workspace(function()
		Utils.request_client_command("angular/getComponentsWithTemplateFile", function(_, result, client)
			if not result or #result == 0 then
				vim.notify("[ng-nvim] No component found referencing this template.", vim.log.levels.INFO)
				return
			end
			if #result == 1 then
				Utils.show_document(result[1], client.offset_encoding, opts)
			else
				vim.fn.setqflist({}, " ", {
					title = "Angular Components",
					items = vim.lsp.util.locations_to_items(result, client.offset_encoding),
				})
				vim.cmd.copen()
			end
		end)
	end)
end

return {
	run = goto_component_class,
}
