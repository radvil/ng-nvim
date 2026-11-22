local Utils = require("ng-nvim.utils")

-- Type-Check Block content provider
local provider = {
	uri = nil,
	bufnr = nil,
	namespace = vim.api.nvim_create_namespace("ng-nvim"),

	update = function(self, uri, content)
		if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
			self.bufnr = vim.api.nvim_create_buf(false, true)
			vim.bo[self.bufnr].buftype = "nofile"
			vim.bo[self.bufnr].bufhidden = "hide"
			vim.bo[self.bufnr].swapfile = false
			vim.bo[self.bufnr].filetype = "typescript"
		end
		local normalized = tostring(uri):gsub("^file:///", "ng:///")
		if self.uri ~= normalized then
			self.uri = normalized
			local buf_id = vim.fn.bufnr(self.uri)
			if buf_id ~= -1 and buf_id ~= self.bufnr and vim.api.nvim_buf_is_valid(buf_id) then
				vim.api.nvim_buf_delete(buf_id, { force = true })
			end
			vim.api.nvim_buf_set_name(self.bufnr, self.uri)
		end
		vim.bo[self.bufnr].modifiable = true
		local lines = vim.split(content or "", "\n", { plain = true })
		vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
		vim.bo[self.bufnr].modifiable = false
		vim.bo[self.bufnr].modified = false
	end,

	show = function(self, ranges)
		if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
			return
		end
		local buf_win_id = vim.fn.bufwinid(self.bufnr)
		if buf_win_id ~= -1 then
			vim.api.nvim_set_current_win(buf_win_id)
		else
			vim.cmd.tabnew()
			vim.api.nvim_win_set_buf(0, self.bufnr)
		end
		vim.api.nvim_buf_clear_namespace(self.bufnr, self.namespace, 0, -1)
		if ranges and #ranges > 0 then
			for _, range in ipairs(ranges) do
				vim.hl.range(
					self.bufnr,
					self.namespace,
					"Visual",
					{ range.start.line, range.start.character },
					{ range["end"].line, range["end"].character }
				)
			end
			local col = ranges[1].start
			local lines_total = vim.api.nvim_buf_line_count(self.bufnr)
			local row = math.min(col.line + 1, lines_total)
			vim.api.nvim_win_set_cursor(0, { row, col.character })
		end
	end,
}

--- Displays a typecheck block for the template under the cursor or selection.
local get_tcb_in_template = function()
	Utils.on_angular_workspace(function()
		Utils.request_client_command("angular/getTcb", function(_, result)
			if not result or not result.content then
				vim.notify("[ng-nvim] No template typecheck block available here.", vim.log.levels.INFO)
				return
			end
			provider:update(result.uri, result.content)
			provider:show(result.selections)
		end)
	end)
end

return { run = get_tcb_in_template }
