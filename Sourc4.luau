--[[
	UILibrary  •  v1.1.0  (carregável por loadstring)
	Biblioteca de interface para Roblox (estilo clássico / profissional)

	INSTALAÇÃO (via loadstring)
		1) Hospede ESTE arquivo (somente a library) num link "raw": GitHub raw, Pastebin raw, etc.
		2) No seu script, carregue assim:

			local Library = loadstring(game:HttpGet("https://SEU_LINK_RAW/UILibrary.lua"))()

		O arquivo termina com `return Library`, então o loadstring devolve a API pronta.

	API
	───────────────────────────────────────────────────────────────
	Library:CreateWindow({
		Title     = "Meu Hub",
		Subtitle  = "v1.0",
		Size      = UDim2.fromOffset(580, 390),
		Accent    = Color3.fromRGB(66, 135, 245),
		ToggleKey = Enum.KeyCode.RightShift,
	}) -> Window

	Window:CreateTab(name) -> Tab
	Window:SetTitle(text)
	Window:SetVisible(bool) / Window:Toggle()
	Window:Destroy()

	Tab:CreateSection(name, side?) -> Section      -- side: "Left" | "Right" | nil (auto)

	Section:AddLabel(text)                                       -> { Set(text) }
	Section:AddDivider()
	Section:AddButton({ Name, Callback })                        -> { SetText(text) }
	Section:AddToggle({ Name, Default, Flag, Callback })         -> { Set(bool), Get() }
	Section:AddSlider({ Name, Min, Max, Default, Increment, Suffix, Flag, Callback }) -> { Set(n), Get() }
	Section:AddDropdown({ Name, Options, Default, Multi, Flag, Callback }) -> { Set(v), Get(), Refresh(options) }
	Section:AddTextbox({ Name, Default, Placeholder, ClearOnFocus, Flag, Callback }) -> { Set(text), Get() }
	Section:AddKeybind({ Name, Default, Flag, Callback, OnChange }) -> { Set(KeyCode), Get() }
	Section:AddColorPicker({ Name, Default, Flag, Callback })    -> { Set(Color3), Get() }

	Library:Notify({ Title, Content, Duration, Type })           -- Type: "info" | "success" | "warning" | "error"
	Library:SetAccent(Color3)
	Library.Flags[flag]                                          -- valor atual de qualquer elemento com Flag
	Library:Unload()

	CONFIGS E AUTO SAVE  (arquivos .lua ou .txt)
	───────────────────────────────────────────────────────────────
	Window:CreateSettingsTab({ Name? }) -> Tab      -- aba pronta: tema/cor, tecla, salvar/carregar/excluir config, auto save
	Library:LoadAutoSave()                          -- chame no FIM do seu script: carrega o último estado e liga o auto save
	Library:SaveConfig("config_Tols.lua")           -- -> ok, arquivo|erro   (aceita apenas .lua ou .txt; sem extensão = .lua)
	Library:LoadConfig("config_Tols.txt")           -- -> ok, arquivo|erro
	Library:DeleteConfig(nome)  Library:GetConfigs()
	Library:SetAutoLoad(nome)   Library:ClearAutoLoad()   -- config carregada sempre que o script iniciar
	Library:SetAutoSave(bool)   Library:SetFolder("MeuHub")
	CreateWindow aceita também:  Folder = "MeuHub"  (pasta onde ficam autosave e configs)

	Todo elemento (toggle, slider, dropdown, textbox, keybind, colorpicker) é salvo automaticamente.
	Para excluir um elemento do save use  NoSave = true.  A cor de destaque e a tecla da janela
	(o "estilo" da UI) também são salvas. Sem acesso a arquivos (ex.: Roblox Studio) tudo
	funciona apenas na sessão atual.

	Obs.: o valor inicial (Default) NÃO dispara o Callback; apenas interações do usuário
	      ou chamadas :Set(valor) disparam. Use :Set(valor, true) para definir sem disparar.
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService      = game:GetService("TextService")
local Workspace        = game:GetService("Workspace")

local Library = {
	Flags = {}, Version = "1.1.0",
	_elements = {}, _windows = {},
	Folder = "UILibrary", DefaultExt = "lua",
	NotificationsEnabled = true,
	_autoSave = true, _armed = false, _loading = false,
}
local Window  = {}; Window.__index  = Window
local Tab     = {}; Tab.__index     = Tab
local Section = {}; Section.__index = Section

----------------------------------------------------------------------
-- TEMA
----------------------------------------------------------------------
local Theme = {
	Accent       = Color3.fromRGB(66, 135, 245),
	TitleBar     = Color3.fromRGB(24, 24, 27),
	Background   = Color3.fromRGB(30, 30, 34),
	Surface      = Color3.fromRGB(36, 36, 41),
	Element      = Color3.fromRGB(46, 46, 53),
	ElementHover = Color3.fromRGB(56, 56, 64),
	Border       = Color3.fromRGB(64, 64, 72),
	Text         = Color3.fromRGB(225, 225, 230),
	SubText      = Color3.fromRGB(145, 145, 156),
}
local FONT      = Enum.Font.SourceSans
local FONT_BOLD = Enum.Font.SourceSansSemibold

local NotifyColors = {
	success = Color3.fromRGB(80, 190, 110),
	warning = Color3.fromRGB(230, 170, 60),
	error   = Color3.fromRGB(220, 80, 80),
}

----------------------------------------------------------------------
-- UTILIDADES
----------------------------------------------------------------------
local connections = {}
local accentBinds = {}

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function bindAccent(fn)
	table.insert(accentBinds, fn)
	fn()
end

local function new(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if parent then inst.Parent = parent end
	return inst
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness)
	return new("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function padding(l, r, t, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r),
		PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b),
	})
end

local function listLayout(pad)
	return new("UIListLayout", { Padding = UDim.new(0, pad or 0), SortOrder = Enum.SortOrder.LayoutOrder })
end

local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end
local function isMove(input)
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function nextOrder(sec)
	sec._n += 1
	return sec._n
end

local scheduleSave = function() end   -- definido na seção de configs

local function setFlag(flag, value)
	if flag then
		Library.Flags[flag] = value
		scheduleSave()
	end
end

-- ScreenGui único da biblioteca
local function ensureGui()
	if Library._gui and Library._gui.Parent then return Library._gui end

	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("UILibrary")
	if old then old:Destroy() end

	local g = new("ScreenGui", {
		Name = "UILibrary",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 500,
		Parent = pg,
	})
	Library._gui = g

	Library._notifHolder = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(280, 600),
		BackgroundTransparency = 1,
		ZIndex = 100,
		Parent = g,
	}, {
		new("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, 6),
		}),
	})
	return g
end

local function makeLabel(parent, text, props)
	local p = {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Text = text,
		Font = FONT,
		TextSize = 16,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	}
	for k, v in pairs(props or {}) do p[k] = v end
	return new("TextLabel", p)
end

local function row(section, height)
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(section),
		Parent = section._holder,
	})
end

----------------------------------------------------------------------
-- NOTIFICAÇÕES
----------------------------------------------------------------------
local notifOrder = 0

function Library:Notify(o)
	if not Library.NotificationsEnabled then return end
	ensureGui()
	o = o or {}
	local title    = o.Title or "Aviso"
	local content  = o.Content or ""
	local duration = o.Duration or 4
	local color    = NotifyColors[o.Type or ""] or Theme.Accent

	local width = 270
	local textH = TextService:GetTextSize(content, 15, FONT, Vector2.new(width - 26, 1000)).Y
	local height = 10 + 18 + 2 + textH + 12

	notifOrder += 1
	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		LayoutOrder = notifOrder,
		Parent = Library._notifHolder,
	})
	local toast = new("Frame", {
		Position = UDim2.new(1.2, 0, 0, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = wrap,
	}, { corner(3), stroke(Theme.Border, 1) })

	new("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = toast })
	makeLabel(toast, title, {
		Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -24, 0, 18),
		Font = FONT_BOLD, TextSize = 16,
	})
	makeLabel(toast, content, {
		Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -24, 0, textH),
		TextSize = 15, TextColor3 = Theme.SubText, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.None,
	})
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = color, BackgroundTransparency = 0.4,
		BorderSizePixel = 0, Parent = toast,
	})

	tween(toast, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quart)
	tween(bar, duration, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		if not wrap.Parent then return end
		tween(toast, 0.25, { Position = UDim2.new(1.2, 0, 0, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		task.wait(0.26)
		tween(wrap, 0.2, { Size = UDim2.new(1, 0, 0, 0) })
		task.wait(0.21)
		wrap:Destroy()
	end)
end

----------------------------------------------------------------------
-- ACENTO / UNLOAD
----------------------------------------------------------------------
function Library:SetAccent(color)
	Theme.Accent = color
	for _, fn in ipairs(accentBinds) do fn() end
	scheduleSave()
end

function Library:Unload()
	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)
	table.clear(accentBinds)
	table.clear(Library.Flags)
	table.clear(Library._elements)
	table.clear(Library._windows)
	Library._armed = false
	if Library._gui then Library._gui:Destroy() end
	Library._gui = nil
end

----------------------------------------------------------------------
-- CONFIGS (.lua / .txt) + AUTO SAVE
----------------------------------------------------------------------
local HttpService = game:GetService("HttpService")
local ALLOWED_EXT = { lua = true, txt = true }
local MAX_FILE = 200000
local memFiles = {}   -- usado quando o ambiente não tem acesso a arquivos

-- flag automática: Aba/Seção/Nome (única); NoSave = true exclui do save
local function prepare(section, o, kind)
	if o.NoSave or o.Flag then return end
	local base = section.Tab.Name .. "/" .. section.Name .. "/" .. tostring(o.Name or kind)
	local flag, n = base, 1
	while Library._elements[flag] do
		n += 1
		flag = base .. " #" .. n
	end
	o.Flag = flag
end

local function register(o, obj, kind)
	obj.Kind = kind
	if o.Flag and not o.NoSave then
		Library._elements[o.Flag] = obj
	end
end

-- ===== acesso a arquivos (com fallback em memória) =====
local function fsAvailable()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function Library:HasFileAccess()
	return fsAvailable()
end

local function ensureFolder(path)
	if not (fsAvailable() and type(makefolder) == "function" and type(isfolder) == "function") then return end
	local acc = ""
	for part in path:gmatch("[^/]+") do
		acc = (acc == "") and part or (acc .. "/" .. part)
		local okf, exists = pcall(isfolder, acc)
		if okf and not exists then pcall(makefolder, acc) end
	end
end

local function fileWrite(path, content)
	if fsAvailable() then
		return pcall(writefile, path, content)
	end
	memFiles[path] = content
	return true
end

local function fileRead(path)
	if fsAvailable() then
		local okf, exists = pcall(isfile, path)
		if not (okf and exists) then return nil end
		local ok, res = pcall(readfile, path)
		return ok and res or nil
	end
	return memFiles[path]
end

local function fileDelete(path)
	if fsAvailable() then
		if type(delfile) == "function" then return pcall(delfile, path) end
		return false, "delfile indisponível neste ambiente"
	end
	memFiles[path] = nil
	return true
end

local function fileList(folder)
	if fsAvailable() then
		if type(listfiles) ~= "function" then return {} end
		local ok, res = pcall(listfiles, folder)
		return (ok and type(res) == "table") and res or {}
	end
	local out, prefix = {}, folder .. "/"
	for p in pairs(memFiles) do
		if p:sub(1, #prefix) == prefix then table.insert(out, p) end
	end
	return out
end

-- ===== pastas e nomes =====
local function cfgDir() return Library.Folder .. "/configs" end
local function cfgPath(file) return cfgDir() .. "/" .. file end
local function autoPath() return Library.Folder .. "/autosave.lua" end
local function autoloadPath() return Library.Folder .. "/autoload.txt" end

function Library:SetFolder(path)
	path = tostring(path or ""):gsub("[^%w_%-/ ]", ""):gsub("^/+", ""):gsub("/+$", "")
	if path == "" then path = "UILibrary" end
	Library.Folder = path
end

-- valida o nome: apenas .lua ou .txt (sem extensão = formato padrão)
function Library:ParseConfigName(input)
	input = (tostring(input or ""):gsub("^%s+", ""))
	input = (input:gsub("%s+$", ""))
	if input == "" then return nil, "Digite um nome para a config." end
	local base, ext = input:match("^(.+)%.(%w+)$")
	if not base then base, ext = input, Library.DefaultExt end
	ext = ext:lower()
	if not ALLOWED_EXT[ext] then return nil, "Formato inválido: use apenas .lua ou .txt." end
	if #base > 40 or not base:match("^[%w_%- ]+$") then
		return nil, "Nome inválido (use letras, números, _ - e espaço; máx. 40)."
	end
	if base:lower() == "autosave" then return nil, "O nome \"autosave\" é reservado." end
	return base .. "." .. ext
end

-- ===== serialização =====
local function encodeValue(v)
	local t = typeof(v)
	if t == "Color3" then
		return {
			__t = "Color3",
			r = math.floor(v.R * 255 + 0.5), g = math.floor(v.G * 255 + 0.5), b = math.floor(v.B * 255 + 0.5),
		}
	elseif t == "EnumItem" then
		if v.EnumType == Enum.KeyCode then return { __t = "KeyCode", name = v.Name } end
		return nil
	elseif t == "table" then
		local out = {}
		for i, x in ipairs(v) do out[i] = encodeValue(x) end
		return out
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return 0 end
		return v
	elseif t == "string" or t == "boolean" then
		return v
	end
	return nil
end

local function decodeValue(v)
	if type(v) == "table" then
		if v.__t == "Color3" then
			return Color3.fromRGB(
				math.clamp(tonumber(v.r) or 0, 0, 255), math.clamp(tonumber(v.g) or 0, 0, 255), math.clamp(tonumber(v.b) or 0, 0, 255)
			)
		elseif v.__t == "KeyCode" then
			local ok, key = pcall(function() return Enum.KeyCode[v.name] end)
			return ok and key or nil
		end
		local out = {}
		for i, x in ipairs(v) do out[i] = decodeValue(x) end
		return out
	end
	return v
end

local function luaQuote(s)
	s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
	return '"' .. s .. '"'
end

local function toLua(v, indent)
	indent = indent or 0
	local t = type(v)
	if t == "table" then
		if next(v) == nil then return "{}" end
		local pad, pad2 = string.rep("\t", indent), string.rep("\t", indent + 1)
		local isArray = #v > 0
		if isArray then
			for k in pairs(v) do
				if type(k) ~= "number" then isArray = false; break end
			end
		end
		local lines = {}
		if isArray then
			for _, x in ipairs(v) do
				table.insert(lines, pad2 .. toLua(x, indent + 1) .. ",")
			end
		else
			local keys = {}
			for k in pairs(v) do table.insert(keys, tostring(k)) end
			table.sort(keys)
			for _, k in ipairs(keys) do
				table.insert(lines, pad2 .. "[" .. luaQuote(k) .. "] = " .. toLua(v[k], indent + 1) .. ",")
			end
		end
		return "{\n" .. table.concat(lines, "\n") .. "\n" .. pad .. "}"
	elseif t == "string" then
		return luaQuote(v)
	elseif t == "number" then
		return string.format("%.14g", v)
	elseif t == "boolean" then
		return tostring(v)
	end
	return "nil"
end

-- leitor de tabelas Lua (SOMENTE dados: nunca executa código do arquivo)
local function parseLua(src)
	local pos, len = 1, #src
	local depth = 0
	local function fail(msg) error("posição " .. pos .. ": " .. msg, 0) end

	local function skip()
		while pos <= len do
			local c = src:sub(pos, pos)
			if c:match("%s") then
				pos += 1
			elseif src:sub(pos, pos + 1) == "--" then
				if src:sub(pos, pos + 3) == "--[[" then
					local e = src:find("]]", pos + 4, true)
					pos = e and (e + 2) or (len + 1)
				else
					local e = src:find("\n", pos, true)
					pos = e and (e + 1) or (len + 1)
				end
			else
				break
			end
		end
	end

	local escapes = { n = "\n", r = "\r", t = "\t", ["\\"] = "\\", ['"'] = '"', ["'"] = "'" }
	local function parseString()
		local q = src:sub(pos, pos)
		pos += 1
		local buf = {}
		while true do
			if pos > len then fail("string não fechada") end
			local c = src:sub(pos, pos)
			if c == q then
				pos += 1
				break
			end
			if c == "\\" then
				local n = src:sub(pos + 1, pos + 1)
				if escapes[n] then
					table.insert(buf, escapes[n])
					pos += 2
				else
					local d = src:match("^%d%d?%d?", pos + 1)
					if not d then fail("escape inválido") end
					table.insert(buf, string.char(math.clamp(tonumber(d), 0, 255)))
					pos += 1 + #d
				end
			else
				table.insert(buf, c)
				pos += 1
			end
		end
		return table.concat(buf)
	end

	local function parseNumber()
		local s = src:match("^-?%d+%.?%d*[eE][%+%-]?%d+", pos) or src:match("^-?%d+%.?%d*", pos)
		if not s then fail("número inválido") end
		pos += #s
		return tonumber(s)
	end

	local parseValue
	parseValue = function()
		skip()
		local c = src:sub(pos, pos)
		if c == "{" then
			depth += 1
			if depth > 12 then fail("aninhamento demais") end
			pos += 1
			local t, n = {}, 0
			while true do
				skip()
				local ch = src:sub(pos, pos)
				if ch == "" then fail("tabela não fechada") end
				if ch == "}" then
					pos += 1
					break
				end
				if ch == "[" then
					pos += 1
					local k = parseValue()
					skip()
					if src:sub(pos, pos) ~= "]" then fail("esperado ]") end
					pos += 1
					skip()
					if src:sub(pos, pos) ~= "=" then fail("esperado =") end
					pos += 1
					local v = parseValue()
					if k == nil then fail("chave nula") end
					t[k] = v
				else
					local ident = src:match("^[%a_][%w_]*", pos)
					local isKey = ident and src:match("^%s*=[^=]", pos + #ident)
					if ident and isKey then
						pos += #ident
						skip()
						pos += 1
						t[ident] = parseValue()
					else
						n += 1
						t[n] = parseValue()
					end
				end
				skip()
				local sep = src:sub(pos, pos)
				if sep == "," or sep == ";" then pos += 1 end
			end
			depth -= 1
			return t
		elseif c == '"' or c == "'" then
			return parseString()
		elseif c:match("[%d%-]") then
			return parseNumber()
		end
		local w = src:match("^%a+", pos)
		if w == "true" then pos += 4; return true end
		if w == "false" then pos += 5; return false end
		if w == "nil" then pos += 3; return nil end
		fail("valor inesperado")
	end

	skip()
	if src:sub(pos, pos + 5) ~= "return" then fail("esperado 'return'") end
	pos += 6
	local value = parseValue()
	skip()
	if src:sub(pos, pos) == ";" then
		pos += 1
		skip()
	end
	if pos <= len then fail("conteúdo inesperado após a tabela") end
	return value
end

local function serializeData(data, ext)
	if ext == "txt" then
		return HttpService:JSONEncode(data)
	end
	return "-- UILibrary config (somente dados)\nreturn " .. toLua(data, 0) .. "\n"
end

local function parseData(text, ext)
	if ext == "txt" then
		local ok, res = pcall(function() return HttpService:JSONDecode(text) end)
		if ok and type(res) == "table" then return res end
		return nil, "JSON inválido"
	end
	local ok, res = pcall(parseLua, text)
	if ok and type(res) == "table" then return res end
	return nil, tostring(res)
end

-- ===== coletar / aplicar =====
local function collect()
	local flags = {}
	for flag, obj in pairs(Library._elements) do
		local okv, v = pcall(function() return obj:Get() end)
		if okv then
			if v == nil then v = false end
			flags[flag] = encodeValue(v)
		end
	end
	local style = { Accent = encodeValue(Theme.Accent) }
	local w = Library._windows[1]
	if w and w.ToggleKey then style.ToggleKey = w.ToggleKey.Name end
	return { version = 1, style = style, flags = flags }
end

local function applyData(data)
	if type(data) ~= "table" then return false, "Arquivo inválido." end
	Library._loading = true
	local ok, err = pcall(function()
		local style = data.style
		if type(style) == "table" then
			local a = decodeValue(style.Accent)
			if typeof(a) == "Color3" then Library:SetAccent(a) end
			if type(style.ToggleKey) == "string" then
				local okk, key = pcall(function() return Enum.KeyCode[style.ToggleKey] end)
				if okk and key then
					for _, w in ipairs(Library._windows) do w.ToggleKey = key end
				end
			end
		end
		local flags = type(data.flags) == "table" and data.flags or {}
		for flag, raw in pairs(flags) do
			local obj = Library._elements[flag]
			if obj then
				local v = decodeValue(raw)
				if v == false and (obj.Kind == "Keybind" or obj.Kind == "Dropdown") then v = nil end
				pcall(function() obj:Set(v) end)
			end
		end
	end)
	Library._loading = false
	if Library._syncStyle then pcall(Library._syncStyle) end
	return ok, err
end

-- ===== API pública de configs =====
function Library:GetConfigs()
	local out = {}
	for _, path in ipairs(fileList(cfgDir())) do
		local name = tostring(path):gsub("\\", "/"):match("([^/]+)$")
		if name then
			local ext = name:match("%.(%w+)$")
			if ext and ALLOWED_EXT[ext:lower()] and name:lower() ~= "autosave.lua" then
				table.insert(out, name)
			end
		end
	end
	table.sort(out)
	return out
end

function Library:SaveConfig(input)
	local file, err = Library:ParseConfigName(input)
	if not file then return false, err end
	ensureFolder(cfgDir())
	local ext = file:match("%.(%w+)$")
	local ok, werr = fileWrite(cfgPath(file), serializeData(collect(), ext))
	if not ok then return false, "Falha ao salvar: " .. tostring(werr) end
	return true, file
end

function Library:LoadConfig(input)
	local file, err = Library:ParseConfigName(input)
	if not file then return false, err end
	local text = fileRead(cfgPath(file))
	if not text then return false, "Arquivo não encontrado: " .. file end
	if #text > MAX_FILE then return false, "Arquivo grande demais." end
	local data, perr = parseData(text, file:match("%.(%w+)$"))
	if not data then return false, "Config inválida (" .. tostring(perr) .. ")" end
	local ok, aerr = applyData(data)
	if not ok then return false, "Erro ao aplicar: " .. tostring(aerr) end
	return true, file
end

function Library:DeleteConfig(input)
	local file, err = Library:ParseConfigName(input)
	if not file then return false, err end
	if not fileRead(cfgPath(file)) then return false, "Arquivo não encontrado: " .. file end
	local ok, derr = fileDelete(cfgPath(file))
	if not ok then return false, "Falha ao excluir: " .. tostring(derr) end
	return true, file
end

function Library:GetAutoLoad()
	local text = fileRead(autoloadPath())
	if not text then return nil end
	text = (text:gsub("%s+", ""))
	if text == "" then return nil end
	return text
end

function Library:SetAutoLoad(input)
	local file, err = Library:ParseConfigName(input)
	if not file then return false, err end
	if not fileRead(cfgPath(file)) then return false, "Salve a config antes de definir como auto-load." end
	ensureFolder(Library.Folder)
	local ok, werr = fileWrite(autoloadPath(), file)
	if not ok then return false, tostring(werr) end
	return true, file
end

function Library:ClearAutoLoad()
	return fileDelete(autoloadPath())
end

-- ===== auto save =====
function Library:_writeAutoSave()
	ensureFolder(Library.Folder)
	fileWrite(autoPath(), serializeData(collect(), "lua"))
end

local saveToken = 0
scheduleSave = function()
	if Library._loading or not Library._armed or not Library._autoSave then return end
	saveToken += 1
	local mine = saveToken
	task.delay(0.8, function()
		if mine == saveToken and Library._armed and Library._autoSave and not Library._loading then
			Library:_writeAutoSave()
		end
	end)
end

function Library:SetAutoSave(v)
	Library._autoSave = v and true or false
	if Library._autoSave then scheduleSave() end
end

-- carrega (1) a config de auto-load, senão (2) o último auto save; depois liga o auto save
function Library:LoadAutoSave()
	local loaded
	local al = Library:GetAutoLoad()
	if al then
		local ok = Library:LoadConfig(al)
		if ok then loaded = al end
	end
	if not loaded then
		local text = fileRead(autoPath())
		if text and #text <= MAX_FILE then
			local data = parseData(text, "lua")
			if data then
				local ok = applyData(data)
				if ok then loaded = "autosave" end
			end
		end
	end
	Library._armed = true
	return loaded
end

----------------------------------------------------------------------
-- JANELA
----------------------------------------------------------------------
function Library:CreateWindow(opts)
	opts = opts or {}
	if opts.Folder then Library:SetFolder(opts.Folder) end
	local gui = ensureGui()
	if opts.Accent then Theme.Accent = opts.Accent end

	local self = setmetatable({ Tabs = {}, ActiveTab = nil, Visible = true, Minimized = false }, Window)
	self.ToggleKey = opts.ToggleKey or Enum.KeyCode.RightShift
	local size = opts.Size or UDim2.fromOffset(580, 390)
	self._size = size

	local TITLE_H, SIDE_W = 32, 132

	local main = new("CanvasGroup", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = gui,
	}, { stroke(Theme.Border, 1) })
	self.Main = main

	local scale = new("UIScale", { Parent = main })
	local function calcScale()
		local cam = Workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		return math.clamp(math.min(vp.X / (size.X.Offset + 40), vp.Y / (size.Y.Offset + 40)), 0.5, 1)
	end
	self._scale = scale
	scale.Scale = calcScale()

	-- barra de título
	local titlebar = new("Frame", {
		Size = UDim2.new(1, 0, 0, TITLE_H),
		BackgroundColor3 = Theme.TitleBar,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = main,
	})
	self._title = makeLabel(titlebar, opts.Title or "UILibrary", {
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, 0, 1, 0),
		Font = FONT_BOLD, TextSize = 17, ZIndex = 6,
	})
	if opts.Subtitle then
		local tw = TextService:GetTextSize(opts.Title or "UILibrary", 17, FONT_BOLD, Vector2.new(1000, 32)).X
		makeLabel(titlebar, opts.Subtitle, {
			Position = UDim2.fromOffset(12 + tw + 8, 1), Size = UDim2.new(0.4, 0, 1, 0),
			TextSize = 14, TextColor3 = Theme.SubText, ZIndex = 6,
		})
	end
	local accentLine = new("Frame", {
		Position = UDim2.fromOffset(0, TITLE_H), Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, ZIndex = 5, Parent = main,
	})
	bindAccent(function() accentLine.BackgroundColor3 = Theme.Accent end)

	local function titleButton(text, xOff, hoverColor)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xOff, 0, 0),
			Size = UDim2.fromOffset(TITLE_H, TITLE_H), BackgroundColor3 = hoverColor,
			BackgroundTransparency = 1, AutoButtonColor = false, Text = text,
			Font = FONT_BOLD, TextSize = 18, TextColor3 = Theme.SubText, ZIndex = 6, Parent = titlebar,
		})
		b.MouseEnter:Connect(function()
			tween(b, 0.12, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
		end)
		b.MouseLeave:Connect(function()
			tween(b, 0.12, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
		end)
		return b
	end
	local closeBtn = titleButton("x", 0, Color3.fromRGB(196, 58, 58))
	local minBtn   = titleButton("-", -TITLE_H, Theme.ElementHover)

	-- arrastar
	do
		local dragging, dragStart, startPos = false, nil, nil
		titlebar.InputBegan:Connect(function(input)
			if isPointer(input) then
				dragging, dragStart, startPos = true, input.Position, main.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then dragging = false end
				end)
			end
		end)
		connect(UserInputService.InputChanged, function(input)
			if dragging and isMove(input) then
				local d = (input.Position - dragStart) / scale.Scale
				tween(main, 0.06, {
					Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y),
				})
			end
		end)
	end

	-- sidebar
	local sidebar = new("Frame", {
		Position = UDim2.fromOffset(0, TITLE_H + 2),
		Size = UDim2.new(0, SIDE_W, 1, -(TITLE_H + 2)),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = main,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Parent = sidebar,
	})
	self._tabList = new("Frame", {
		Size = UDim2.new(1, -1, 1, 0), BackgroundTransparency = 1, Parent = sidebar,
	}, { listLayout(2), padding(0, 0, 6, 6) })

	self._content = new("Frame", {
		Position = UDim2.fromOffset(SIDE_W, TITLE_H + 2),
		Size = UDim2.new(1, -SIDE_W, 1, -(TITLE_H + 2)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = main,
	})

	-- botões
	closeBtn.MouseButton1Click:Connect(function()
		self:SetVisible(false)
		Library:Notify({
			Title = "Janela oculta",
			Content = "Pressione " .. self.ToggleKey.Name .. " para reabrir.",
			Duration = 3,
		})
	end)
	minBtn.MouseButton1Click:Connect(function()
		self.Minimized = not self.Minimized
		tween(main, 0.25, {
			Size = self.Minimized and UDim2.new(size.X.Scale, size.X.Offset, 0, TITLE_H + 2) or size,
		}, Enum.EasingStyle.Quart)
	end)

	-- tecla de atalho
	connect(UserInputService.InputBegan, function(input, gpe)
		if gpe then return end
		if input.KeyCode == self.ToggleKey then self:Toggle() end
	end)

	-- botão para celular
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local mb = new("TextButton", {
			Position = UDim2.new(0, 10, 0.5, -20), Size = UDim2.fromOffset(40, 40),
			BackgroundColor3 = Theme.TitleBar, AutoButtonColor = false, Text = "UI",
			Font = FONT_BOLD, TextSize = 16, TextColor3 = Theme.Text, Parent = gui,
		}, { corner(4), stroke(Theme.Border, 1) })
		mb.MouseButton1Click:Connect(function() self:Toggle() end)
	end

	if Workspace.CurrentCamera then
		connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), function()
			if self.Visible then scale.Scale = calcScale() end
		end)
	end
	self._calcScale = calcScale

	table.insert(Library._windows, self)
	task.defer(function() self:SetVisible(true) end)
	return self
end

function Window:SetTitle(text)
	self._title.Text = text
end

function Window:SetVisible(v)
	self.Visible = v
	local main, scale = self.Main, self._scale
	if v then
		main.Visible = true
		scale.Scale = self._calcScale() * 0.96
		tween(scale, 0.2, { Scale = self._calcScale() })
		tween(main, 0.2, { GroupTransparency = 0 })
	else
		tween(scale, 0.15, { Scale = self._calcScale() * 0.96 })
		tween(main, 0.15, { GroupTransparency = 1 })
		task.delay(0.16, function()
			if not self.Visible then main.Visible = false end
		end)
	end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:Destroy()
	Library:Unload()
end

function Window:_select(tab)
	if self.ActiveTab == tab then return end
	local old = self.ActiveTab
	self.ActiveTab = tab

	if old then
		old.Page.Visible = false
		tween(old.Button, 0.15, { BackgroundTransparency = 1, TextColor3 = Theme.SubText })
		tween(old.Bar, 0.15, { Size = UDim2.new(0, 3, 0, 0) })
	end
	tab.Page.Position = UDim2.fromOffset(0, 8)
	tab.Page.Visible = true
	tween(tab.Page, 0.25, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quart)
	tween(tab.Button, 0.15, { BackgroundTransparency = 0, TextColor3 = Theme.Text })
	tween(tab.Bar, 0.2, { Size = UDim2.new(0, 3, 0.7, 0) })
end

----------------------------------------------------------------------
-- ABAS
----------------------------------------------------------------------
function Window:CreateTab(name)
	local tab = setmetatable({ Window = self, Name = name, Sections = {} }, Tab)

	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Element,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = name,
		Font = FONT_BOLD,
		TextSize = 16,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = #self.Tabs + 1,
		Parent = self._tabList,
	}, { padding(14, 6, 0, 0) })
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 3, 0, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = btn,
	})
	bindAccent(function() bar.BackgroundColor3 = Theme.Accent end)
	tab.Button, tab.Bar = btn, bar

	btn.MouseEnter:Connect(function()
		if self.ActiveTab ~= tab then tween(btn, 0.12, { TextColor3 = Theme.Text }) end
	end)
	btn.MouseLeave:Connect(function()
		if self.ActiveTab ~= tab then tween(btn, 0.12, { TextColor3 = Theme.SubText }) end
	end)
	btn.MouseButton1Click:Connect(function() self:_select(tab) end)

	-- página com duas colunas
	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = self._content,
	}, { listLayout(0), padding(10, 10, 10, 10) })
	tab.Page = page

	local cols = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = page,
	})
	local function column(xScale, xOff)
		local c = new("Frame", {
			Position = UDim2.new(xScale, xOff, 0, 0),
			Size = UDim2.new(0.5, -5, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = cols,
		})
		local l = listLayout(10)
		l.Parent = c
		return c, l
	end
	tab._left, tab._leftLayout = column(0, 0)
	tab._right, tab._rightLayout = column(0.5, 5)

	table.insert(self.Tabs, tab)
	if #self.Tabs == 1 then self:_select(tab) end
	return tab
end

----------------------------------------------------------------------
-- SEÇÕES
----------------------------------------------------------------------
function Tab:CreateSection(name, side)
	local col
	if side == "Left" then
		col = self._left
	elseif side == "Right" then
		col = self._right
	else
		col = (self._leftLayout.AbsoluteContentSize.Y <= self._rightLayout.AbsoluteContentSize.Y) and self._left or self._right
	end

	local sec = setmetatable({ Tab = self, Name = name, _n = 0 }, Section)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		LayoutOrder = #self.Sections + 1,
		Parent = col,
	}, { listLayout(0), stroke(Theme.Border, 1) })

	local header = new("Frame", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 1, Parent = frame,
	})
	makeLabel(header, name, {
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
		Font = FONT_BOLD, TextSize = 16,
	})
	new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Parent = header,
	})

	sec._holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = frame,
	}, { listLayout(6), padding(10, 10, 8, 8) })

	table.insert(self.Sections, sec)
	return sec
end

----------------------------------------------------------------------
-- ELEMENTOS
----------------------------------------------------------------------
function Section:AddLabel(text)
	local r = row(self, 20)
	local l = makeLabel(r, text, { TextColor3 = Theme.SubText, TextSize = 15, TextWrapped = false })
	local obj = {}
	function obj:Set(t) l.Text = t end
	return obj
end

function Section:AddDivider()
	local r = row(self, 5)
	new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Border, BorderSizePixel = 0, Parent = r,
	})
end

function Section:AddButton(o)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = o.Name or "Button",
		Font = FONT_BOLD,
		TextSize = 16,
		TextColor3 = Theme.Text,
		LayoutOrder = nextOrder(self),
		Parent = self._holder,
	}, { corner(3) })
	local st = stroke(Theme.Border, 1)
	st.Parent = b

	b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = Theme.ElementHover }) end)
	b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = Theme.Element }) end)
	b.MouseButton1Down:Connect(function() tween(b, 0.06, { BackgroundColor3 = Theme.Surface }) end)
	b.MouseButton1Click:Connect(function()
		st.Color = Theme.Accent
		tween(st, 0.4, { Color = Theme.Border })
		tween(b, 0.12, { BackgroundColor3 = Theme.ElementHover })
		if o.Callback then task.spawn(o.Callback) end
	end)

	local obj = {}
	function obj:SetText(t) b.Text = t end
	return obj
end

function Section:AddToggle(o)
	prepare(self, o, "Toggle")
	local r = row(self, 26)
	local label = makeLabel(r, o.Name or "Toggle", { Size = UDim2.new(1, -28, 1, 0) })
	local box = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0, Parent = r,
	}, { corner(3), stroke(Theme.Border, 1) })
	local mark = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0), BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0, Parent = box,
	}, { corner(2) })
	bindAccent(function() mark.BackgroundColor3 = Theme.Accent end)

	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = r })
	hit.MouseEnter:Connect(function() tween(label, 0.12, { TextColor3 = Color3.new(1, 1, 1) }) end)
	hit.MouseLeave:Connect(function() tween(label, 0.12, { TextColor3 = Theme.Text }) end)

	local obj = { Value = o.Default == true }
	function obj:Set(v, silent)
		self.Value = v and true or false
		tween(mark, 0.15, { Size = self.Value and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0) })
		setFlag(o.Flag, self.Value)
		if not silent and o.Callback then task.spawn(o.Callback, self.Value) end
	end
	function obj:Get() return self.Value end

	hit.MouseButton1Click:Connect(function() obj:Set(not obj.Value) end)
	obj:Set(obj.Value, true)
	register(o, obj, "Toggle")
	return obj
end

function Section:AddSlider(o)
	prepare(self, o, "Slider")
	local min, max = o.Min or 0, o.Max or 100
	local inc = o.Increment or 1
	local suffix = o.Suffix or ""

	local r = row(self, 40)
	makeLabel(r, o.Name or "Slider", { Size = UDim2.new(1, -70, 0, 20) })
	local valueLabel = makeLabel(r, "", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(70, 20), TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.SubText, TextSize = 15,
	})
	local track = new("Frame", {
		Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Theme.Element, BorderSizePixel = 0, Parent = r,
	}, { corner(2), stroke(Theme.Border, 1) })
	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = track,
	}, { corner(2) })
	bindAccent(function() fill.BackgroundColor3 = Theme.Accent end)
	local hit = new("TextButton", {
		Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1, Text = "", Parent = r,
	})

	local obj = { Value = min }
	function obj:Set(v, silent)
		v = math.clamp(v, min, max)
		v = math.floor(v / inc + 0.5) * inc
		v = math.clamp(v, min, max)
		self.Value = v
		local a = (max == min) and 0 or (v - min) / (max - min)
		tween(fill, 0.08, { Size = UDim2.fromScale(a, 1) })
		valueLabel.Text = string.format("%g", v) .. suffix
		setFlag(o.Flag, v)
		if not silent and o.Callback then task.spawn(o.Callback, v) end
	end
	function obj:Get() return self.Value end

	local dragging = false
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:Set(min + (max - min) * a)
	end
	hit.InputBegan:Connect(function(i)
		if isPointer(i) then
			dragging = true
			local sc = self.Tab.Page
			sc.ScrollingEnabled = false
			fromX(i.Position.X)
		end
	end)
	connect(UserInputService.InputChanged, function(i)
		if dragging and isMove(i) then fromX(i.Position.X) end
	end)
	connect(UserInputService.InputEnded, function(i)
		if dragging and isPointer(i) then
			dragging = false
			self.Tab.Page.ScrollingEnabled = true
		end
	end)

	obj:Set(o.Default or min, true)
	register(o, obj, "Slider")
	return obj
end

function Section:AddDropdown(o)
	prepare(self, o, "Dropdown")
	local multi = o.Multi == true
	local options = o.Options or {}
	local OPT_H = 24

	local container = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = nextOrder(self), Parent = self._holder,
	}, { listLayout(0) })

	local head = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "", LayoutOrder = 1, Parent = container,
	}, { corner(3), stroke(Theme.Border, 1) })
	makeLabel(head, o.Name or "Dropdown", {
		Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0.5, -8, 1, 0),
	})
	local valueLabel = makeLabel(head, "", {
		Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -26, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.SubText, TextSize = 15,
	})
	local arrow = makeLabel(head, "+", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.fromOffset(14, 28),
		TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.SubText, Font = FONT_BOLD,
	})
	head.MouseEnter:Connect(function() tween(head, 0.12, { BackgroundColor3 = Theme.ElementHover }) end)
	head.MouseLeave:Connect(function() tween(head, 0.12, { BackgroundColor3 = Theme.Element }) end)

	local list = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Theme.Background, BorderSizePixel = 0,
		ClipsDescendants = true, LayoutOrder = 2, Parent = container,
	})
	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -8),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Border, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), Parent = list,
	}, { listLayout(0) })

	local obj = { Value = multi and {} or nil }
	local selected = {}        -- mapa (multi)
	local buttons = {}
	local open = false

	local function currentList()
		local t = {}
		for _, opt in ipairs(options) do
			if selected[opt] then table.insert(t, opt) end
		end
		return t
	end
	local function render()
		for opt, b in pairs(buttons) do
			local on = multi and selected[opt] or (obj.Value == opt)
			b.TextColor3 = on and Theme.Accent or Theme.SubText
		end
		if multi then
			local l = currentList()
			valueLabel.Text = #l > 0 and table.concat(l, ", ") or "Nenhum"
		else
			valueLabel.Text = obj.Value ~= nil and tostring(obj.Value) or "Nenhum"
		end
	end
	bindAccent(render)

	local function fullHeight()
		return math.min(#options, 6) * OPT_H + 8
	end
	local function setOpen(v)
		open = v
		arrow.Text = v and "-" or "+"
		tween(list, 0.18, { Size = UDim2.new(1, 0, 0, v and fullHeight() or 0) }, Enum.EasingStyle.Quart)
	end

	local function fire()
		local val = multi and currentList() or obj.Value
		setFlag(o.Flag, val)
		if o.Callback then task.spawn(o.Callback, val) end
	end

	local function build()
		for _, b in pairs(buttons) do b:Destroy() end
		table.clear(buttons)
		for i, opt in ipairs(options) do
			local b = new("TextButton", {
				Size = UDim2.new(1, 0, 0, OPT_H), BackgroundColor3 = Theme.ElementHover,
				BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
				Text = tostring(opt), Font = FONT, TextSize = 15, TextColor3 = Theme.SubText,
				TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i, Parent = scroll,
			}, { padding(10, 6, 0, 0) })
			b.MouseEnter:Connect(function() tween(b, 0.1, { BackgroundTransparency = 0.5 }) end)
			b.MouseLeave:Connect(function() tween(b, 0.1, { BackgroundTransparency = 1 }) end)
			b.MouseButton1Click:Connect(function()
				if multi then
					selected[opt] = not selected[opt] or nil
					obj.Value = currentList()
					render()
					fire()
				else
					obj.Value = opt
					render()
					fire()
					setOpen(false)
				end
			end)
			buttons[opt] = b
		end
		render()
		if open then setOpen(true) end
	end

	function obj:Set(v, silent)
		if multi then
			table.clear(selected)
			for _, x in ipairs(v or {}) do selected[x] = true end
			self.Value = currentList()
		else
			self.Value = v
		end
		render()
		setFlag(o.Flag, self.Value)
		if not silent and o.Callback then task.spawn(o.Callback, self.Value) end
	end
	function obj:Get() return self.Value end
	function obj:Refresh(newOptions)
		options = newOptions or {}
		if multi then
			local keep = {}
			for _, x in ipairs(options) do if selected[x] then table.insert(keep, x) end end
			table.clear(selected)
			for _, x in ipairs(keep) do selected[x] = true end
			obj.Value = keep
		elseif not table.find(options, obj.Value) then
			obj.Value = nil
		end
		build()
	end

	head.MouseButton1Click:Connect(function() setOpen(not open) end)

	build()
	if o.Default ~= nil then obj:Set(o.Default, true) end
	register(o, obj, "Dropdown")
	return obj
end

function Section:AddTextbox(o)
	prepare(self, o, "Textbox")
	local r = row(self, 28)
	makeLabel(r, o.Name or "Textbox", { Size = UDim2.new(0.5, -4, 1, 0) })
	local box = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
		Text = o.Default or "", PlaceholderText = o.Placeholder or "", PlaceholderColor3 = Theme.SubText,
		TextColor3 = Theme.Text, Font = FONT, TextSize = 15, ClearTextOnFocus = o.ClearOnFocus == true,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = r,
	}, { corner(3), padding(8, 8, 0, 0) })
	local st = stroke(Theme.Border, 1)
	st.Parent = box

	box.Focused:Connect(function() tween(st, 0.12, { Color = Theme.Accent }) end)

	local obj = { Value = box.Text }
	function obj:Set(t, silent)
		self.Value = tostring(t)
		box.Text = self.Value
		setFlag(o.Flag, self.Value)
		if not silent and o.Callback then task.spawn(o.Callback, self.Value, false) end
	end
	function obj:Get() return self.Value end

	box.FocusLost:Connect(function(enter)
		tween(st, 0.12, { Color = Theme.Border })
		obj.Value = box.Text
		setFlag(o.Flag, obj.Value)
		if o.Callback then task.spawn(o.Callback, obj.Value, enter) end
	end)
	setFlag(o.Flag, obj.Value)
	register(o, obj, "Textbox")
	return obj
end

function Section:AddKeybind(o)
	prepare(self, o, "Keybind")
	local r = row(self, 28)
	makeLabel(r, o.Name or "Keybind", { Size = UDim2.new(1, -90, 1, 0) })
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(84, 24), BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
		AutoButtonColor = false, Text = "", Font = FONT_BOLD, TextSize = 14, TextColor3 = Theme.Text, Parent = r,
	}, { corner(3), stroke(Theme.Border, 1) })
	btn.MouseEnter:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Theme.ElementHover }) end)
	btn.MouseLeave:Connect(function() tween(btn, 0.12, { BackgroundColor3 = Theme.Element }) end)

	local obj = { Value = o.Default }
	local listening = false

	local function refresh()
		btn.Text = obj.Value and obj.Value.Name or "Nenhuma"
		btn.TextColor3 = obj.Value and Theme.Text or Theme.SubText
	end
	function obj:Set(key, silent)
		self.Value = key
		refresh()
		setFlag(o.Flag, key)
		if not silent and o.OnChange then task.spawn(o.OnChange, key) end
	end
	function obj:Get() return self.Value end

	btn.MouseButton1Click:Connect(function()
		listening = true
		btn.Text = "..."
		btn.TextColor3 = Theme.Accent
	end)

	connect(UserInputService.InputBegan, function(input, gpe)
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				listening = false
				if input.KeyCode == Enum.KeyCode.Escape then
					obj:Set(nil)
				else
					obj:Set(input.KeyCode)
				end
			end
			return
		end
		if gpe then return end
		if obj.Value and input.KeyCode == obj.Value and o.Callback then
			task.spawn(o.Callback, obj.Value)
		end
	end)

	refresh()
	setFlag(o.Flag, obj.Value)
	register(o, obj, "Keybind")
	return obj
end

function Section:AddColorPicker(o)
	prepare(self, o, "ColorPicker")
	local color = o.Default or Color3.fromRGB(255, 255, 255)
	local h, s, v = color:ToHSV()
	local PANEL_H = 124

	local container = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, LayoutOrder = nextOrder(self), Parent = self._holder,
	}, { listLayout(0) })

	local head = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "", LayoutOrder = 1, Parent = container,
	})
	makeLabel(head, o.Name or "Cor", { Size = UDim2.new(1, -44, 1, 0) })
	local swatch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(36, 16), BackgroundColor3 = color, BorderSizePixel = 0, Parent = head,
	}, { corner(3), stroke(Theme.Border, 1) })

	local panel = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Theme.Background, BorderSizePixel = 0,
		ClipsDescendants = true, LayoutOrder = 2, Parent = container,
	})
	local inner = new("Frame", {
		Size = UDim2.new(1, 0, 0, PANEL_H), BackgroundTransparency = 1, Parent = panel,
	}, { padding(0, 0, 6, 6) })

	-- quadrado saturação / brilho
	local sv = new("TextButton", {
		Size = UDim2.new(1, -26, 1, 0), BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = inner,
	})
	new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sv,
	}, { new("UIGradient", { Transparency = NumberSequence.new(0, 1) }) })
	new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = sv,
	}, { new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) })
	local svCursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = sv,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), stroke(Color3.new(0, 0, 0), 1.5) })

	-- barra de matiz
	local hue = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 18, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, AutoButtonColor = false, Text = "", Parent = inner,
	}, {
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
				ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
				ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
				ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
				ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
				ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
				ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1)),
			}),
		}),
	})
	local hueCursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 4, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = hue,
	}, { stroke(Color3.new(0, 0, 0), 1) })

	local obj = { Value = color }
	local function update(silent)
		color = Color3.fromHSV(h, s, v)
		obj.Value = color
		swatch.BackgroundColor3 = color
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		setFlag(o.Flag, color)
		if not silent and o.Callback then task.spawn(o.Callback, color) end
	end

	function obj:Set(c, silent)
		h, s, v = c:ToHSV()
		update(silent)
	end
	function obj:Get() return self.Value end

	local dragSV, dragHue = false, false
	local function svFrom(pos)
		s = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
		v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
		update()
	end
	local function hueFrom(pos)
		h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 0.999)
		update()
	end
	sv.InputBegan:Connect(function(i)
		if isPointer(i) then dragSV = true; self.Tab.Page.ScrollingEnabled = false; svFrom(i.Position) end
	end)
	hue.InputBegan:Connect(function(i)
		if isPointer(i) then dragHue = true; self.Tab.Page.ScrollingEnabled = false; hueFrom(i.Position) end
	end)
	connect(UserInputService.InputChanged, function(i)
		if not isMove(i) then return end
		if dragSV then svFrom(i.Position) elseif dragHue then hueFrom(i.Position) end
	end)
	connect(UserInputService.InputEnded, function(i)
		if isPointer(i) and (dragSV or dragHue) then
			dragSV, dragHue = false, false
			self.Tab.Page.ScrollingEnabled = true
		end
	end)

	local open = false
	head.MouseButton1Click:Connect(function()
		open = not open
		tween(panel, 0.18, { Size = UDim2.new(1, 0, 0, open and PANEL_H or 0) }, Enum.EasingStyle.Quart)
	end)

	update(true)
	register(o, obj, "ColorPicker")
	return obj
end

----------------------------------------------------------------------
-- ABA DE CONFIGURAÇÕES PRONTA
----------------------------------------------------------------------
function Window:CreateSettingsTab(opts)
	opts = opts or {}
	local win = self
	local tab = self:CreateTab(opts.Name or "Configurações")

	local function say(msg, kind)
		Library:Notify({ Title = "Configurações", Content = msg, Type = kind or "info", Duration = 3.5 })
	end

	-- ===== Interface =====
	local ui = tab:CreateSection("Interface", "Left")
	local presets = {
		Azul = Color3.fromRGB(66, 135, 245), Verde = Color3.fromRGB(70, 190, 110),
		Vermelho = Color3.fromRGB(220, 70, 70), Roxo = Color3.fromRGB(140, 90, 240),
		Laranja = Color3.fromRGB(240, 150, 50), Rosa = Color3.fromRGB(235, 90, 150),
	}
	local picker, keybind
	ui:AddDropdown({
		Name = "Tema", Options = { "Azul", "Verde", "Vermelho", "Roxo", "Laranja", "Rosa" }, NoSave = true,
		Callback = function(name)
			local c = presets[name]
			if c then
				Library:SetAccent(c)
				if picker then picker:Set(c, true) end
			end
		end,
	})
	picker = ui:AddColorPicker({
		Name = "Cor de destaque", Default = Theme.Accent, NoSave = true,
		Callback = function(c) Library:SetAccent(c) end,
	})
	keybind = ui:AddKeybind({
		Name = "Tecla da janela", Default = win.ToggleKey, NoSave = true,
		OnChange = function(key)
			if key then
				win.ToggleKey = key
				scheduleSave()
			end
		end,
	})
	ui:AddToggle({
		Name = "Notificações", Default = true,
		Callback = function(v) Library.NotificationsEnabled = v end,
	})

	Library._syncStyle = function()
		picker:Set(Theme.Accent, true)
		if win.ToggleKey then keybind:Set(win.ToggleKey, true) end
	end

	-- ===== Configs =====
	local cs = tab:CreateSection("Configs", "Right")
	cs:AddLabel(Library:HasFileAccess() and ("Pasta: " .. Library.Folder .. "/configs") or "Sem acesso a arquivos (só nesta sessão)")

	local nameBox = cs:AddTextbox({ Name = "Nome", Placeholder = "config_Tols.lua ou .txt", NoSave = true })
	cs:AddDropdown({
		Name = "Formato padrão", Options = { ".lua", ".txt" }, Default = ".lua", NoSave = true,
		Callback = function(v) Library.DefaultExt = (tostring(v):gsub("^%.", "")) end,
	})
	local list
	list = cs:AddDropdown({
		Name = "Salvas", Options = Library:GetConfigs(), NoSave = true,
		Callback = function(v) if v then nameBox:Set(v, true) end end,
	})

	local function currentName()
		local n = nameBox:Get()
		if n == nil or n:match("^%s*$") then n = list:Get() end
		return n
	end
	local function refresh(select)
		list:Refresh(Library:GetConfigs())
		if select then list:Set(select, true) end
	end

	cs:AddButton({ Name = "Salvar config", Callback = function()
		local ok, res = Library:SaveConfig(currentName())
		if ok then
			say("Salvo: " .. res, "success")
			refresh(res)
		else
			say(res, "error")
		end
	end })
	cs:AddButton({ Name = "Carregar config", Callback = function()
		local ok, res = Library:LoadConfig(currentName())
		if ok then say("Carregado: " .. res, "success") else say(res, "error") end
	end })
	cs:AddButton({ Name = "Excluir config", Callback = function()
		local ok, res = Library:DeleteConfig(currentName())
		if ok then
			say("Excluído: " .. res, "warning")
			nameBox:Set("", true)
			refresh()
			list:Set(nil, true)
		else
			say(res, "error")
		end
	end })
	cs:AddButton({ Name = "Atualizar lista", Callback = function()
		refresh()
		say(#Library:GetConfigs() .. " config(s) encontrada(s).")
	end })

	cs:AddDivider()
	cs:AddToggle({
		Name = "Auto save", Default = true,
		Callback = function(v)
			if not v then Library:_writeAutoSave() end   -- guarda a preferência "desligado"
			Library:SetAutoSave(v)
		end,
	})
	cs:AddButton({ Name = "Definir como auto-load", Callback = function()
		local ok, res = Library:SetAutoLoad(currentName())
		if ok then say("Auto-load: " .. res, "success") else say(res, "error") end
	end })
	cs:AddButton({ Name = "Limpar auto-load", Callback = function()
		Library:ClearAutoLoad()
		say("Auto-load removido.")
	end })

	return tab
end

return Library
