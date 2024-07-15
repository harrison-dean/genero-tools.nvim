--
-- Module definition ==========================================================
--
local GeneroTools = {}
local H = {}

--- Module main code ==========================================================

GeneroTools.ns = vim.api.nvim_create_namespace("genero-tools")

--- Module setup
---
---@param config table|nil module options table
---
---@usage `require('genero-tools').setup({})` (replace `{}` with your `config` table)
GeneroTools.setup = function(config)
	-- export module
	_G.GeneroTools = GeneroTools

	-- setup config
	config = H.setup_config(config)

	-- apply config
	H.apply_config(config)

end

GeneroTools.config = {
	options = {
		heart = false,
		hover_define = true,
		hover_define_insert = false,
	},
	mappings = {
		basic = true,
	}
}

H.default_config = vim.deepcopy(GeneroTools.config)

H.setup_config = function(config)
	vim.validate({ config = { config, 'table', true } })
	config = vim.tbl_deep_extend('force', vim.deepcopy(H.default_config), config or {})

	vim.validate({
		options = { config.options, 'table' },
		mappings = { config.mappings, 'table' },
	})

	vim.validate({
		['options.heart'] = { config.options.heart, 'boolean' },
		['options.hover_define'] = { config.options.hover_define, 'boolean' },
		['options.hover_define_insert'] = { config.options.hover_define_insert, 'boolean' },
		['mappings.basic'] = { config.mappings.basic, 'boolean' },
	})

	-- custom mappings
	if not config.mappings.basic then
		-- TODO med: get from config
	end

	return config
end

H.apply_config = function(config)
  GeneroTools.config = config

  H.apply_options(config)
  H.apply_mappings(config)
  H.apply_autocommands(config)
end

-- Options --------------------------------------------------------------------
H.apply_options = function(config)
	-- TODO low: what options? highlights?
end

-- Mappings -------------------------------------------------------------------
H.apply_mappings = function(config)
	local map = H.keymap_set
	-- build temporary code tag
	local temp_code_tag = "#TMP"
	if os.getenv("USER") ~= nil then
		temp_code_tag = temp_code_tag .. string.upper(string.sub(tostring(os.getenv("USER")), 1, 2))
	end
	temp_code_tag = temp_code_tag

	-- use default or custom mappings
	if config.mappings.basic then
		--- setup default mappings
		map("n", "key", function() H.get_ekey() end,
			{ desc = "Get elec_[key] value of input key" })
		map("n", ".", "/" .. temp_code_tag .. "<CR>",
			{desc = "Next TMP tag" })
		map("n", ",", "?" .. temp_code_tag .. "<CR>",
			{desc = "Prev TMP tag" })
		map("n", "<F1>", function() H.write_line(temp_code_tag) end,
			{ desc = "Insert TMP tag" })
		map("n", "<F2>", function() H.write_debug("display") end,
			{ desc = "Insert display for variable" })
		map("n", "<F3>", function() H.write_debug("str") end,
			{ desc = "Insert CALL elt_debug([input str])"})
		map("n", "<F4>", function() H.write_debug("var") end,
			{ desc = "Insert lines to CALL elt_debug variable value" })
		map("n", "<F5>", function() H.compile_and_capture(true) end,
			{ desc = "Compile + show and capture diagnostics" })

		map("n", "<Space>d", function() H.define_under_cursor(true) end,
			{ desc = "Find where word under cursor is defined" })
	else
		--TODO low priority: get custom mappings from config
	end
end

-- Autocommands ---------------------------------------------------------------
H.apply_autocommands = function(config)
	local augroup = vim.api.nvim_create_augroup("GeneroTools", { clear = true })
	local au = function(event, pattern, callback, desc)
		vim.api.nvim_create_autocmd(event, { group = augroup, pattern = pattern, callback = callback, desc = desc })
	end

	-- compile and capture diagnostics after buffer opened
	au({"BufReadPost", "BufWritePost"}, "*.4gl,*.per", function() H.compile_and_capture(false) end, "Generate diagnostics from compile results when buffer read/opened")

	-- autocmd to close popups
	au({"CursorMoved", "CursorMovedI"}, "*.4gl,*.per", function() H.close_popups() end, "Automatically close genero-tools popups when cursor moves")

	if config.options.hover_define then
		au("CursorHold", "*.4gl,*.per", function() H.define_under_cursor(false) end, "Automatically open popup definition of word under cursor when cursor held in normal mode")
	end
	if config.options.hover_define_insert then
		au("CursorHoldI", "*.4gl,*.per", function() H.define_under_cursor(false) end, "Automatically open popup definition of word under cursor when cursor held in insert mode")
	end
end

-- Utilities ------------------------------------------------------------------
H.map = function(mode, lhs, rhs, opts)
  if lhs == '' then return end
  opts = vim.tbl_deep_extend('force', { silent = true }, opts or {})
  vim.keymap.set(mode, lhs, rhs, opts)
end

H.keymap_set = function(modes, lhs, rhs, opts)
  -- NOTE: use `<C-H>`, `<C-Up>`, `<M-h>` casing (instead of `<C-h>`, `<C-up>`,
  -- `<M-H>`) to match the `lhs` of keymap info. Otherwise it will say that
  -- mapping doesn't exist when in fact it does.
  if type(modes) == 'string' then modes = { modes } end

  for _, mode in ipairs(modes) do
    -- don't map if mapping is already set **globally**
    local map_info = H.get_map_info(mode, lhs)
    if not H.is_default_keymap(mode, lhs, map_info) then return end

    -- Map
    H.map(mode, lhs, rhs, opts)
  end
end

H.get_map_info = function(mode, lhs)
  local keymaps = vim.api.nvim_get_keymap(mode)
  for _, info in ipairs(keymaps) do
    if info.lhs == lhs then return info end
  end
end

H.is_default_keymap = function(mode, lhs, map_info)
  if map_info == nil then return true end
  local rhs, desc = map_info.rhs or '', map_info.desc or ''

  -- Some mappings are set by default in Neovim
  if mode == 'n' and lhs == '<C-L>' then return rhs:find('nohl') ~= nil end
  if mode == 'i' and lhs == '<C-S>' then return desc:find('signature') ~= nil end
  if mode == 'x' and lhs == '*' then return rhs == [[y/\V<C-R>"<CR>]] end
  if mode == 'x' and lhs == '#' then return rhs == [[y?\V<C-R>"<CR>]] end
end

H.get_ekey = function()
	local key = vim.fn.input("elec_key = ")
	local cmd = "!fglrun getekey -D " .. key .. " | tail -n 5"
	vim.api.nvim_command(cmd)
end

H.compile_and_capture = function(popup)
	local filetype = vim.bo.filetype
	local compiled_file = string.sub(vim.fn.expand("%"), 1, -4)
	local compile_cmd = " " .. vim.fn.expand("%")

	-- write file so we can compile
	vim.cmd("write")

	-- ensure we only try compiling and capturing diagnostics for 4gl/per
	-- and set appropriate compile file/cmds
	if filetype == "fgl" then
		compiled_file = compiled_file .. "42m"
		compile_cmd = "fglcomp -M -W all" .. compile_cmd
	elseif filetype == "per" then
		compiled_file = compiled_file .. "42f"

		-- cannot include -W flag in BDS form compiler
		if string.find(vim.fn.systemlist("fglform -V")[2], "Genero") then
			compile_cmd = "fglform -M -W all" .. compile_cmd
		else
			compile_cmd = "fglform -M" .. compile_cmd
		end
	else
		return
	end

	-- ensure any existing compiled file is removed
	vim.fn.system("rm" .. compiled_file)

	local compile_output = vim.fn.systemlist(compile_cmd)

	-- parse and set diagnostics from compile output
	local diagnostics = H.parse_compile_output(compile_output)

	GeneroTools.diagnostics = diagnostics

	vim.diagnostic.set(GeneroTools.ns, vim.api.nvim_get_current_buf(), diagnostics)

	-- display compile output in floating window
	if popup then
		H.open_center_popup(compile_output)
	end
end

H.open_center_popup = function(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	local compiled = true

	-- if error exists in diagnostics then compile failed
	for _, diagnostic in ipairs(GeneroTools.diagnostics) do
		if diagnostic.severity == vim.diagnostic.severity.ERROR then
			compiled = false
			break
		end
	end

	if GeneroTools.config.options.heart then
		vim.api.nvim_buf_set_lines(buf, 0, -1, true, H.heart)
	end

	-- write compile output to popup window
	for _, line in ipairs(lines) do
		local line_count = vim.api.nvim_buf_line_count(buf)
		vim.api.nvim_buf_set_lines(buf, line_count, -1, true, {line})
	end

	-- display corresponding big ascii compiler result
	if compiled then
		vim.api.nvim_buf_set_lines(buf, vim.api.nvim_buf_line_count(buf), -1, true, H.success)
	else
		vim.api.nvim_buf_set_lines(buf, vim.api.nvim_buf_line_count(buf), -1, true, H.failure)
	end

	-- set floating window opts
	-- TODO low: get from config
	local opts = {
		relative = "win",
		--TODO low: make not full width and center? hard maths..
		width = vim.fn.winwidth(0),
		height = vim.api.nvim_buf_line_count(buf),
		row = vim.fn.winheight(0) / 2,
		col = vim.fn.winwidth(0),
		style = "minimal",
		border = "rounded",
		-- title hl group so we can identify our windows later
		title = { { "Compiler Results", "genero-tools" } },
		title_pos = "center",
		zindex = 51,	-- define popups = 50
	}

	-- open floating window
	local win = vim.api.nvim_open_win(buf, false, opts)
	-- make popup text coloured by compile result
	if compiled then
		vim.api.nvim_win_set_option(win, "winhl", "NormalFloat:String")
	else
		vim.api.nvim_win_set_option(win, "winhl", "NormalFloat:ErrorMsg")
	end

	-- make transparent
	vim.api.nvim_win_set_option(win, "winbl", 20)

	-- set nowrap on lines
	vim.api.nvim_win_set_option(win, "wrap", false)

	return win
end

H.parse_compile_output = function(output)
	local diagnostics = {}
	for line_num, line in ipairs(output) do
		-- ignore lines e.g. ignoring CSCMENU from .per
		if string.find(line, "%*%*%*") then
			break
		end

		local diagnostic = {}
		-- only parse lines containing error/warning (for Genero)
		if string.find(line, ":warning:") or string.find(line, ":error:") then
			-- match parts of output string
			local pattern = "%w+%.%w+:(%d+):(%d+):(%d+):(%d+):(%w+):%((-?%d+)%) (.*)$"
			local startline, startcol, endline,
				endcol, type, errcode, errdesc = string.match(line, pattern)

			if type == "error" then
				type = vim.diagnostic.severity.ERROR
			elseif type == "warning" then
				type = vim.diagnostic.severity.WARN
				errcode = line_num
			else
				type = vim.diagnostic.severity.INFO
			end

			if startline ~= nil then
				-- build diagnostic and add to table of diagnostics
				diagnostic = {lnum=tonumber(startline)-1, col=tonumber(startcol)-1,
					end_lnum=tonumber(endline)-1, end_col=tonumber(endcol),
					code=errcode, message=errdesc, severity=type}

				-- build table of diagnostics
				table.insert(diagnostics, diagnostic)
			end
		else
			-- must be BDS compiler output, can't match as much info
			local pattern = "%w+%.%w+:(%d+): (.+)"
			local startline, errdesc = string.match(line, pattern)

			local type = vim.diagnostic.severity.WARN
			if string.find(line, "error") then
				type = vim.diagnostic.severity.ERROR
			end

			if startline ~= nil then
				-- build diagnostic and add to table of diagnostics
				diagnostic = {lnum=tonumber(startline)-1, col=0, end_col=#line, message=errdesc, severity=type}

				-- build table of diagnostics
				table.insert(diagnostics, diagnostic)
			end
		end

	end

	return diagnostics
end

H.write_line = function(line)
	local cur_line = vim.fn.getline(".")
	local cur_col = vim.fn.col(".")
	local indent_width = 4
	local indent = string.rep(" ", (cur_col))
	vim.fn.setline(vim.fn.line("."), cur_line)
	vim.api.nvim_buf_set_lines(0, vim.fn.line(".")-1, vim.fn.line(".")-1, false, { indent .. line})
end

H.write_debug = function(type)
	local line = ""

	if type == "str" then
		line = "CALL elt_debug(\"" ..  vim.fn.input("debug str = ") .. "\")"
	elseif type == "var" then
		local var = vim.fn.input("debug var = ")
		line = "LET l_debug_str = \"" .. var .. " = \", " .. var
		H.write_line(line)
		line = "CALL elt_debug(l_debug_str)"
	elseif type == "display" then
		local var = vim.fn.input("display var = ")
		line = "display \"" .. var .. " = \", " .. var
	end
	H.write_line(line)
end

H.define_under_cursor = function(external_funcs)
	local cur_word = vim.fn.expand("<cword>")
	local cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
	local syntax = vim.inspect_pos().syntax
	local pattern
	local dir = "b" -- backwards search by default to find last definition
	local wrap = true
	local lines_around = 0

	-- skip anything that has no syntax match
	if next(syntax) ~= nil then
		if H.syntax_exists(syntax, "fglFunc") then
			pattern = "^s*FUNCTION%s+" .. cur_word .. "%s*"
			lines_around = 2
		elseif H.syntax_exists(syntax, {"fglVarM", "fglVarL", "fglVarP"}) then
			pattern = "%s*DEFINE%s+" .. cur_word .. "%s+"
		elseif H.syntax_exists(syntax, "fglCurs") then
			pattern = "&%s*DECLARE%s+" .. cur_word .. "%s+"
			lines_around = 5
		elseif H.syntax_exists(syntax, "fglTable") then
			return H.open_table_popup(cur_word)
		end
	end

	-- if pattern set, do search thru buffer
	if pattern ~= nil then
		local buf = vim.api.nvim_get_current_buf()
		local found_line_num = H.search(buf, pattern, cur_row, dir, wrap)
		local lines

		if found_line_num > 0 then
			-- extract and parse full function lines if fglFunc,
			-- otherwise get matching line and lines around
			if H.syntax_exists(syntax, "fglFunc") then
				lines = H.parse_function(cur_word, found_line_num, buf)
			else
				lines = vim.api.nvim_buf_get_lines(buf, found_line_num-lines_around, found_line_num+lines_around+1, false)
				if #lines > 0 then
					-- append key value if current word is an EK variable
					if string.find(cur_word, "_EK_") then
						local key = string.sub(cur_word, 6)
						local key_value = H.get_ekey_value(key)
						lines[1] = lines[1] .. "\t\tVal: " .. key_value
					end

				end
			end
			return H.open_cursor_popup(-3, 0, "", lines)
		elseif H.syntax_exists(syntax, "fglFunc") and external_funcs == true then
			-- use telescope to find function definition in all files
			require("telescope.builtin").grep_string({search="FUNCTION "..cur_word})
		end
	end
end

H.parse_function = function(func, startline, buf)
	-- extract function lines
	local endline = H.search(buf, "^END FUNCTION", startline, "f", false)
	local func_lines = vim.api.nvim_buf_get_lines(buf, startline, endline+1, false)
	local func_buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_buf_set_lines(func_buf, 0, #func_lines, false, func_lines)

	local params = {}
	local returns = {}


	for _, line in ipairs(func_lines) do
		if string.find(line, "DEFINE p_") then
			local pattern = "%w+%s+([%w_]+)%s+(.*)"
			local param = {
				name = nil,
				type = nil,
			}

			param.name, param.type = string.match(line, pattern)
			table.insert(params, param)
		elseif string.find(line, "RETURN ") then
			local pattern = "%w+%s+(.*)"
			local thisreturn = {
				name = nil,
				type = nil,
			}
			thisreturn.name = string.match(line, pattern)
			-- try to find return variable type if only one return value at a time
			if not string.find(thisreturn.name, ",") then
				local pattern2 = "%s*DEFINE%s+" .. thisreturn.name .. "%s+"
				local define_line = H.search(func_buf, pattern2, 2, "f", false)
				if define_line > 0 then
					thisreturn.type = string.match(func_lines[define_line], "%w+%s+[%w_]+%s+(.*)")
				end

			else
				-- TODO: handle type fetch when multiple return values
			end
			table.insert(returns, thisreturn)
		end
	end

	-- clean up, delete temp buffer
	vim.api.nvim_buf_delete(func_buf, {force=true})

	-- build output lines
	local output = {}
	-- table.insert(output, func)
	for num, param in ipairs(params) do
		local line = ""
		if num == 1 then
			line = "Params : " .. param.name .. " : " .. param.type
		else
			line = "         " .. param.name .. " : " .. param.type
		end
		table.insert(output, line)
	end

	for num, ret in ipairs(returns) do
		local line = ""
		if num == 1 then
			line = "Returns: " .. ret.name
		else
			line = "         " .. ret.name
		end
		if ret.type ~= nil then
			line = line .. " : " .. ret.type
		end
		table.insert(output, line)
	end

	return output
end

H.get_ekey_value = function(key)
	local cmd = "fglrun getekey " .. key
	local value = vim.fn.systemlist(cmd)[1]

	return value
end

H.syntax_exists = function(syntaxes, hlgroup)
	local found = false
	for _, entry in ipairs(syntaxes) do
		if type(hlgroup) == "table" then
			for _, group in ipairs(hlgroup) do
				if entry.hl_group == group then
					found = true
				end
			end
		elseif type(hlgroup) == "string" then
			if entry.hl_group == hlgroup then
				found = true
			end
		end
	end
	return found
end

H.database_types = function(type)
	local types = {}
	types["0"] = "CHAR"
	types["1"] = "SMALLINT"
	types["2"] = "INTEGER"
	types["3"] = "FLOAT"
	types["4"] = "SMALLFLOAT"
	types["5"] = "DECIMAL"
	types["6"] = "SERIAL 1"
	types["7"] = "DATE"
	types["8"] = "MONEY"
	types["9"] = "NULL"
	types["10"] = "DATETIME"
	types["11"] = "BYTE"
	types["12"] = "TEXT"
	types["13"] = "VARCHAR"
	types["14"] = "INTERVAL"
	types["15"] = "NCHAR"
	types["16"] = "NVARCHAR"
	types["17"] = "INT8"
	types["18"] = "SERIAL8 1"
	types["19"] = "SET"
	types["20"] = "MULTISET"
	types["21"] = "LIST"
	types["22"] = "ROW (unnamed)"
	types["23"] = "COLLECTION"
	types["40"] = "LVARCHAR fixed-length opaque types 2"
	types["41"] = "BLOB, BOOLEAN, CLOB variable-length opaque types 2"
	types["43"] = "LVARCHAR (client-side only)"
	types["45"] = "BOOLEAN"
	types["52"] = "BIGINT"
	types["53"] = "BIGSERIAL 1"
	types["262"] = "SERIAL"
	types["2061"] = "IDSSECURITYLABEL 2, 3"
	types["4118"] = "ROW (named)"

	if types[type] ~= nil then
		return types[type]
	else
		return "UNK:" .. type
	end
end


H.parse_sqlout = function(sql)
	local lines = 0
	local newsql = {}
	local parsed = {}
	local cnt = 0
	local newline = ""

	newsql = sql

	for i=2,#newsql-5,1 do
		local line = newsql[i]
		if #line ~= 0 then
			lines = lines + 1
			local key = line:sub(1,9)
			local value = line:sub(12)

			if key:match("name") then
				cnt = cnt + 1
				newline = value
			elseif key:match("type") then
				newline = newline .. ": " .. H.database_types(value)
			elseif key:match("length") then
				if newline:match("CHAR") or newline:match("STRING") then
					newline = newline .. "(" .. value .. ")"
				end
				table.insert(parsed, newline)
				newline = ""
			end

		end
	end

	return parsed
end

H.open_cursor_popup = function(row, col, title, text)
	local buf = vim.api.nvim_create_buf(false, true)

	-- set content of popup, strip tabs
	local max_len = 1
	local lines = 1
	for line_num, line in ipairs(text) do
		lines = line_num
		local line_len = #line
		if line_len > max_len then
			max_len = line_len
		end
		line = line:gsub("\t", " ")
		vim.api.nvim_buf_set_lines(buf, line_num-1, -1, true, {line})
	end

	-- cursor float options
	-- TODO: allow cursor_popup_opts in config?
	local opts = {
		relative = "cursor",
		width = max_len,
		height = lines,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		focusable = false,
		-- title hl group so we can identify our windows later
		title = { { title, "genero-tools" } },
	}

	-- create popup
	local win = vim.api.nvim_open_win(buf, false, opts)

	-- make transparent
	vim.api.nvim_win_set_option(win, "winbl", 20)

	return win
end

H.ToInteger = function(number)
    return math.floor(tonumber(number) or error("Could not cast '" .. tostring(number) .. "' to number.'"))
end

H.success = {
	"                            _______ _______ ______ ______ _______ _______ _______ ",
	"                           |     __|   |   |      |      |    ___|     __|     __|",
	"                           |__     |   |   |   ---|   ---|    ___|__     |__     |",
	"                           |_______|_______|______|______|_______|_______|_______|"
}

H.failure = {
	"                                      _______ _______ _______ _____   ",
	"                                     |    ___|   _   |_     _|     |_ ",
	"                                     |    ___|       |_|   |_|       |",
	"                                     |___|   |___|___|_______|_______|"

}

H.heart = {
	"                                          ▓▓▓▓▓▓▓            ▒▒▒▒▒▒",
	"                                        ▓▓▒▒▒▒▒▒▒▓▓        ▒▒░░░░░░▒▒",
	"                                      ▓▓▒▒▒▒▒▒▒▒▒▒▒▓▓    ▒▒░░░░░░░░░▒▒▒",
	"                                     ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▒▒░░░░░░░░░░░░░░▒",
	"                                    ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░▒",
	"                                    ▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░▒",
	"                                   ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░▒",
	"                                  ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░▒",
	"                                  ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░▒",
	"                                  ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░▒",
	"                                  ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░▒",
	"                                  ▓▓▒▒▒▒▒SAMANTHA▒▒▒▒▒▒░░░░░░CHARLIE░░░░░░▒",
	"                                   ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░▒",
	"                                    ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░▒",
	"                                     ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░▒",
	"                                      ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░▒▒",
	"                                       ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░▒▒",
	"                                        ▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░▒▒",
	"                                         ▓▓▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░▒▒",
	"                                          ▓▓▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░▒▒",
	"                                            ▓▓▒▒▒▒▒▒▒▒▒░░░░░░░░▒▒",
	"                                             ▓▓▒▒▒▒▒▒▒▒░░░░░░░▒▒",
	"                                               ▓▓▒▒▒▒▒▒░░░░░▒▒",
	"                                                 ▓▓▒▒▒▒░░░░▒▒",
	"                                                  ▓▓▒▒▒░░░▒▒",
	"                                                    ▓▓▓▒▒▒",
	""
}

H.close_popups = function()
	-- check every window for title highlight group "genero-tools" and close them
	local all_wins = vim.api.nvim_list_wins()

	-- do not proceed if only one window open 
	-- TODO med: splits count as more windows..
	if #all_wins == 1 then
		return
	end
	for _, win in ipairs(all_wins) do
		local title = vim.api.nvim_win_get_config(win).title
		if title ~= nil then
			local title_hl = title[1][2]
			if title_hl == "genero-tools" then
				vim.api.nvim_win_close(win, true)
			end
		end
	end

end

-- dir = direction: b = backwards
--					f = forwards
H.search = function(buffer, pattern, start_row, dir, wrap)
	local found_line = 0
	local line_count = vim.api.nvim_buf_line_count(buffer)
	local line_start, line_end, line_step, wrap_start
	-- set directional loop vars
	if dir == "b" then
		line_start = start_row
		line_end = 1
		line_step = -1
		wrap_start = line_count
	elseif dir == "f" then
		line_start = start_row
		line_end = line_count
		line_step = 1
		wrap_start = 1
	end

	-- loop to search lines from start to end line num
	for i = line_start, line_end, line_step do
		local line = vim.api.nvim_buf_get_lines(buffer, i, i+1, false)[1]
		if line ~= nil then
			if string.match(line, pattern) then
				found_line = i
				break
			end
		end
	end

	-- if search is wrapped and no match already found
	if wrap and (found_line == 0) then
		-- search opposite to handle wrapping search
		for i = wrap_start-1, line_end, line_step do
			local line = vim.api.nvim_buf_get_lines(buffer, i, i+1, false)[1]
			if string.match(line, pattern) then
				found_line = i
				break
			end
		end
	end

	-- if found at current line then do not return
	if found_line+1 == start_row then
		return 0
	else
		return found_line
	end
end

H.open_table_popup = function(tablename)
	local filename = "t_definetable.sql"
	local sqlfile = io.open(filename, "w")
	local sql = "SELECT colname, coltype, collength FROM syscolumns WHERE tabid = (SELECT tabid FROM systables WHERE tabname = '" .. tablename .. "');"

	if sqlfile ~= nil then
		io.output(sqlfile)
		io.write(sql)
		io.close()
	end

	-- run dbaccess on current word to get columns in this table
	local cmd = "dbaccess trunkdev@electra_ids " .. filename
	local sqlout = vim.fn.systemlist(cmd)

	-- remove temporary sql file
	os.remove(filename)


	local popup_win = H.open_cursor_popup(0,0, tablename, H.parse_sqlout(sqlout))

	return popup_win
end

return GeneroTools
