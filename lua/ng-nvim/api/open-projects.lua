local Utils = require("ng-nvim.utils")

--- Finds the Nx workspace root starting from `start_path`.
---@param start_path string
---@return string?
local function find_nx_root(start_path)
	local search_start = start_path
	if search_start == "" then
		search_start = vim.fn.getcwd()
	elseif vim.fn.isdirectory(search_start) == 0 then
		search_start = vim.fs.dirname(search_start)
	end
	local nx_marker = vim.fs.find({ "nx.json", "angular.json" }, {
		path = search_start,
		upward = true,
		limit = 1,
	})[1]
	if not nx_marker then
		return nil
	end
	return vim.fs.dirname(nx_marker)
end

--- Safely decodes a JSON file into a Lua table.
---@param filepath string
---@return table?
local function read_json_file(filepath)
	if vim.fn.filereadable(filepath) ~= 1 then
		return nil
	end
	local raw = table.concat(vim.fn.readfile(filepath), "\n")
	if raw == "" then
		return nil
	end
	local ok, decoded = pcall(vim.json.decode, raw)
	if ok and type(decoded) == "table" then
		return decoded
	end
	return nil
end

--- Collects Nx projects from `project.json` files (and `angular.json` if present).
---@param root string
---@param ignored_dirs table<string,boolean>
---@return { name: string, path: string, rel_path: string, project_type: string }[]
local function discover_nx_projects(root, ignored_dirs)
	local projects = {}
	local seen_paths = {}

	local function scan_dir(dir)
		for name, entry_type in vim.fs.dir(dir) do
			if not ignored_dirs[name] then
				local full_path = vim.fs.joinpath(dir, name)
				if entry_type == "directory" then
					scan_dir(full_path)
				elseif entry_type == "file" and name == "project.json" then
					local data = read_json_file(full_path)
					local proj_dir = dir
					local target_path = proj_dir

					if data and type(data.sourceRoot) == "string" and data.sourceRoot ~= "" then
						local candidate_source = vim.fs.normalize(vim.fs.joinpath(root, data.sourceRoot))
						if vim.fn.isdirectory(candidate_source) == 1 then
							target_path = candidate_source
						end
					end

					target_path = vim.fs.normalize(target_path)
					if not seen_paths[target_path] then
						seen_paths[target_path] = true
						local proj_name = (data and type(data.name) == "string" and data.name ~= "") and data.name
							or vim.fs.basename(proj_dir)
						local proj_type = (data and type(data.projectType) == "string" and data.projectType ~= "")
								and data.projectType
							or "project"

						local rel_path = vim.fs.relpath(root, target_path) or target_path
						table.insert(projects, {
							name = proj_name,
							path = target_path,
							rel_path = rel_path,
							project_type = proj_type,
						})
					end
				end
			end
		end
	end

	scan_dir(root)

	-- Fallback/supplement from angular.json if no project.json files were found
	if #projects == 0 then
		local angular_json = read_json_file(vim.fs.joinpath(root, "angular.json"))
		if angular_json and type(angular_json.projects) == "table" then
			for proj_name, proj_cfg in pairs(angular_json.projects) do
				if type(proj_cfg) == "table" then
					local sub_path = proj_cfg.sourceRoot or proj_cfg.root
					if type(sub_path) == "string" and sub_path ~= "" then
						local full_path = vim.fs.normalize(vim.fs.joinpath(root, sub_path))
						if vim.fn.isdirectory(full_path) == 1 and not seen_paths[full_path] then
							seen_paths[full_path] = true
							table.insert(projects, {
								name = proj_name,
								path = full_path,
								rel_path = vim.fs.relpath(root, full_path) or full_path,
								project_type = proj_cfg.projectType or "project",
							})
						end
					end
				end
			end
		end
	end

	table.sort(projects, function(a, b)
		if a.project_type ~= b.project_type then
			return a.project_type < b.project_type
		end
		return a.name:lower() < b.name:lower()
	end)

	return projects
end

local M = {}

---@param ignored_dirs table<string,boolean>
M.run = function(ignored_dirs)
	local current_path = vim.api.nvim_buf_get_name(0)
	local opts = find_nx_root(current_path)
	if not opts then
		vim.notify("[ng-nvim] No Nx/Angular workspace root found.", vim.log.levels.INFO)
		return
	end
	local projects = discover_nx_projects(opts, ignored_dirs)
	if #projects == 0 then
		vim.notify("[ng-nvim] No projects found in Nx workspace.", vim.log.levels.INFO)
		return
	end
	vim.ui.select(projects, {
		prompt = "Select project:",
		format_item = function(proj)
			return string.format("%s  [%s] — %s", proj.name, proj.project_type, proj.rel_path)
		end,
	}, function(choice)
		if choice and choice.path then
			vim.schedule(function()
				Utils.open_uri(choice.path)
			end)
		end
	end)
end

return M
