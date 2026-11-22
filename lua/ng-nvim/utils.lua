--- Extracts `styleUrl` or `styleUrls` paths from a component TypeScript file.
---@param ts_path string
---@return string[]
local function parse_style_file_urls(ts_path)
	if vim.fn.filereadable(ts_path) ~= 1 then
		return {}
	end
	local content = table.concat(vim.fn.readfile(ts_path), "\n")
	local dir = vim.fs.dirname(ts_path)
	local found = {}
	-- Match singular: styleUrl: './foo.scss' or styleUrl: "./foo.scss"
	local single = content:match("styleUrl%s*:%s*['\"]([^'\"]+)['\"]")
	if single then
		local full = vim.fs.normalize(vim.fs.joinpath(dir, single))
		if vim.fn.filereadable(full) == 1 then
			table.insert(found, full)
		end
	end

	-- Match plural: styleUrls: ['./foo.scss', './bar.css']
	local array_body = content:match("styleUrls%s*:%s*%[(.-)%]")
	if array_body then
		for rel in array_body:gmatch("['\"]([^'\"]+)['\"]") do
			local full = vim.fs.normalize(vim.fs.joinpath(dir, rel))
			if vim.fn.filereadable(full) == 1 and not vim.tbl_contains(found, full) then
				table.insert(found, full)
			end
		end
	end
	return found
end

local STYLE_EXTENSIONS = { "scss", "sass", "css", "less" }
local M = {}

--- Opens an LSP Location or LocationLink, optionally in a vertical/horizontal split.
---@param location lsp.Location | lsp.LocationLink
---@param offset_encoding string
---@param opts? { reuse_win?: boolean, split?: "vsplit" | "split" | "tab split" }
function M.show_document(location, offset_encoding, opts)
	opts = opts or {}
	if opts.split == "vsplit" then
		vim.cmd.vsplit()
	elseif opts.split == "split" then
		vim.cmd.split()
	elseif opts.split == "tab split" then
		vim.cmd("tab split")
	end
	vim.lsp.util.show_document(location, offset_encoding, {
		-- Do not jump back to an old window if the user explicitly asked for a new split
		reuse_win = opts.split == nil and (opts.reuse_win or false) or false,
		focus = true,
	})
end

--- Opens a file or directory path
--- TODO: Custom splits on select
---@param uri string
---@param opts? { reuse_win?: boolean, split?: "vsplit" | "split" | "tab split" }
function M.open_uri(uri, opts)
	opts = opts or {}
	local normalized = vim.fs.normalize(uri)
	local path = vim.fn.fnameescape(normalized)
	-- if opts.split == "vsplit" then
	-- 	vim.cmd.vsplit(path)
	-- 	return
	-- elseif opts.split == "split" then
	-- 	vim.cmd.split(path)
	-- 	return
	-- elseif opts.split == "tab split" then
	-- 	vim.cmd("tab split" .. path)
	-- 	return
	-- end
	-- if opts.reuse_win then
	-- 	local bufnr = vim.fn.bufnr(normalized)
	-- 	if bufnr ~= -1 then
	-- 		local winid = vim.fn.bufwinid(bufnr)
	-- 		if winid ~= -1 then
	-- 			vim.api.nvim_set_current_win(winid)
	-- 			return
	-- 		end
	-- 	end
	-- end
	-- vim.cmd.edit(path)

  ---TODO: for now just open uri in new tab
		vim.cmd("tab split" .. path)
end

--- Finds matching stylesheet file(s) for the given file path.
---@param filepath string
---@return string[]
function M.find_associated_stylesheets(filepath)
	local matches = {}
	-- 1. If current file is a component TS file, inspect `styleUrl` / `styleUrls` first
	if filepath:match("%.ts$") then
		matches = parse_style_file_urls(filepath)
		if #matches > 0 then
			return matches
		end
	end
	-- 2. Check conventional sibling files (e.g. foo.component.scss / foo.scss)
	local base = filepath:gsub("%.component%.[^.]+$", ".component")
	if base == filepath then
		base = filepath:gsub("%.[^.]+$", "")
	end
	for _, ext in ipairs(STYLE_EXTENSIONS) do
		local candidate = base .. "." .. ext
		if vim.fn.filereadable(candidate) == 1 then
			table.insert(matches, candidate)
		end
	end
	-- 3. If started from an HTML template with non-standard names, check sibling .component.ts metadata
	if #matches == 0 and filepath:match("%.html$") then
		local sibling_ts = base .. ".ts"
		matches = parse_style_file_urls(sibling_ts)
	end
	return matches
end

--- Retrieves the active Angular LSP client attached to the given buffer.
---@param bufnr integer
---@return vim.lsp.Client?
function M.get_angular_lsp_client(bufnr)
	local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "angularls" })
	if #clients > 0 then
		return clients[1]
	end
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client.name:find("angular", 1, true) then
			return client
		end
	end
	return nil
end

---@param command string
---@param callback fun(err: lsp.ResponseError?, result: any, client: vim.lsp.Client)
function M.request_client_command(command, callback)
	local bufnr = vim.api.nvim_get_current_buf()
	local client = M.get_angular_lsp_client(bufnr)
	if not client then
		vim.notify("[ng-nvim] No Angular language server attached to current buffer.", vim.log.levels.WARN)
		return
	end
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	client:request(command, params, function(err, result)
		if err then
			vim.notify(string.format("[ng-nvim] %s failed: %s", command, err.message), vim.log.levels.ERROR)
			return
		end
		callback(err, result, client)
	end, bufnr)
end

---@param callback fun()
M.on_angular_workspace = function(callback)
	M.request_client_command("angular/isAngularCoreInOwningProject", function(_, yes_it_is)
		if not yes_it_is then
			vim.notify("[ng-nvim] Current file is not part of an Angular project.", vim.log.levels.INFO)
			return
		end
		callback()
	end)
end

return M
