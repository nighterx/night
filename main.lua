repeat task.wait() until game:IsLoaded()
if shared.vape then shared.vape:Uninject() end

local LOADER_URL = "https://raw.githubusercontent.com/nighterx/night/main/downloader.lua" 
local _initArgs = ...
if type(_initArgs) ~= "table" then _initArgs = {} end
shared.aerov4User = "my cutie <3"

if identifyexecutor then
	if table.find({'Wave', 'Seliware', 'Volt'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local args = _initArgs
if type(args) == "table" and args.Closet then
	getgenv().Closet = true
else
	if getgenv().Closet == nil then
		getgenv().Closet = false
	end
end

local vape
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and vape then
		vape:CreateNotification('Vape', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local clear_teleport_queue = clear_teleport_queue or clearteleportqueue or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end

if identifyexecutor and table.find({'Madium', 'Medium'}, ({identifyexecutor()})[1]) then
	local realgca = getcustomasset or getsynasset
	if realgca then
		getgenv().getcustomasset = function(path, ...)
			local args = {...}
			local function try()
				if not isfile(path) then return nil end
				local ok, res = pcall(function() return realgca(path, table.unpack(args)) end)
				if ok and res and res ~= '' then return res end
				return nil
			end
			local res = try()
			if res then return res end
			for _ = 1, 60 do
				task.wait(0.05)
				res = try()
				if res then return res end
			end
			return 'rbxassetid://0'
		end
	end
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))
local httpService = cloneref(game:GetService('HttpService'))
local teleportService = cloneref(game:GetService('TeleportService'))

-- Whitelist.
local AUTH_URL = 'https://nightdream-bot-production.up.railway.app/api/auth'
local AUTH_FAIL_OPEN = false

local authDetail = 'n/a'

local function checkWhitelist()
	-- The key comes from the loadstring the Discord panel hands out, or the saved copy.
	local keyFile = 'night/profiles/key.txt'
	local key = getgenv().script_key or shared.script_key or script_key
	if (type(key) ~= 'string' or key == '') and isfile(keyFile) then
		key = readfile(keyFile)
	end
	if type(key) ~= 'string' or key == '' then authDetail = 'no key' return false end
	getgenv().script_key = key
	pcall(writefile, keyFile, key)

	local nonce = httpService:GenerateGUID(false)

	-- gethwid can return nothing right after a teleport, so retry.
	local hwid
	for _ = 1, 20 do
		if gethwid then
			local suc, res = pcall(gethwid)
			if suc and type(res) == 'string' and res ~= '' then hwid = res break end
		end
		task.wait(0.25)
	end
	if not hwid then authDetail = 'no hwid' return nil end

	local suc, response = pcall(request, {
		Url = AUTH_URL,
		Method = 'POST',
		Headers = {['Content-Type'] = 'application/json'},
		Body = httpService:JSONEncode({
			key = key,
			hwid = hwid,
			nonce = nonce,
		}),
	})

	-- nil means the auth server could not be reached or replied with garbage.
	if not suc or type(response) ~= 'table' then authDetail = 'request failed' return nil end
	if response.StatusCode == 403 then
		authDetail = '403'
		local ok, data = pcall(function()
			return httpService:JSONDecode(response.Body)
		end)
		return false, ok and type(data) == 'table' and data.expired == true
	end
	if response.StatusCode ~= 200 then authDetail = 'status ' .. tostring(response.StatusCode) return nil end

	local ok, data = pcall(function()
		return httpService:JSONDecode(response.Body)
	end)
	if not ok or type(data) ~= 'table' then authDetail = 'bad body' return nil end

	if data.nonce ~= nonce then authDetail = 'nonce' end
	return data.whitelisted == true and data.nonce == nonce
end

local whitelisted, expired = checkWhitelist()
if whitelisted == nil and AUTH_FAIL_OPEN then whitelisted = true end
if not whitelisted then
	local reason = '[nightdream] Invalid or missing key. Redeem one in our Discord.'
	if whitelisted == nil then
		reason = '[nightdream] Auth server unreachable, try again later.'
	elseif expired then
		reason = '[nightdream] Your key expired. Redeem a new one in our Discord.'
	end
	pcall(function() playersService.LocalPlayer:Kick(reason .. ' [' .. authDetail .. ']') end)
	do return end
end


local function downloadFile(path, func)
	if not isfile(path) then
		local res
		local success = false
		for attempt = 1, 3 do
			local suc, result = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/nighterx/night/' .. readfile('night/profiles/commit.txt') .. '/' .. select(1, path:gsub('night/', '')), true)
			end)
			if suc and result ~= '404: Not Found' then
				res = result
				success = true
				break
			end
			task.wait(1)
		end
		if not success then
			error('Failed to download ' .. path .. ' after 3 attempts')
		end
		if path:find('%.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function migrateProfiles()
	if isfile('night/profiles/migrated_placeid.txt') then return end

	local oldId = tostring(game.GameId)
	local newId = tostring(game.PlaceId)

	if oldId == newId then
		pcall(writefile, 'night/profiles/migrated_placeid.txt', 'done')
		return
	end

	local suffix = oldId .. '.txt'
	for _, path in ipairs(listfiles('night/profiles')) do
		local name = path:gsub('\\', '/')
		if name:sub(-#suffix) == suffix then
			local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
			if not isfile(newPath) then
				pcall(function() writefile(newPath, readfile(path)) end)
			end
		end
	end

	if isfolder('night/profiles/premade') then
		for _, path in ipairs(listfiles('night/profiles/premade')) do
			local name = path:gsub('\\', '/')
			if name:sub(-#suffix) == suffix then
				local newPath = name:sub(1, -#suffix - 1) .. newId .. '.txt'
				if not isfile(newPath) then
					pcall(function() writefile(newPath, readfile(path)) end)
				end
			end
		end
	end

	pcall(writefile, 'night/profiles/migrated_placeid.txt', 'done')
end

pcall(migrateProfiles)

local function finishLoading()
	vape.Init = nil
	if not vape.Load then
		warn('[night] vape.Load is nil skipping load')
		return
	end
	vape:Load()
	vape:Clean(task.spawn(function()
		repeat
			pcall(vape.Save, vape)
			task.wait(10)
		until vape.Loaded == nil
	end))

	local function buildTeleportScript()
		if shared.VapeIndependent then return nil end

		local closetArg = getgenv().Closet and '({Closet=true})' or '()'
		local teleportScript = 'shared.vapereload = true\nloadstring(game:HttpGet("' .. LOADER_URL .. '", true), "loader")' .. closetArg

		-- Keep the key across teleports so the whitelist check passes again.
		if type(getgenv().script_key) == 'string' then
			teleportScript = 'getgenv().script_key = "' .. getgenv().script_key .. '"\n' .. teleportScript
		end

		if identifyexecutor and ({identifyexecutor()})[1] == 'Potassium' then
			teleportScript = 'task.wait(12)\n' .. teleportScript
		end
		if shared.VapeDeveloper then
			teleportScript = 'shared.VapeDeveloper = true\n' .. teleportScript
		end
		if shared.VapeCustomProfile then
			teleportScript = 'shared.VapeCustomProfile = "' .. shared.VapeCustomProfile .. '"\n' .. teleportScript
		end
		return teleportScript
	end

	local function queueTeleport()
		local teleportScript = buildTeleportScript()
		if not teleportScript then return end
		pcall(clear_teleport_queue)
		pcall(queue_on_teleport, teleportScript)
	end

	queueTeleport()

	vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function(state)
		if state == Enum.TeleportState.Failed then return end
		pcall(function() vape:Save() end)
		queueTeleport()
	end))

	vape:Clean(function()
		pcall(clear_teleport_queue)
	end)

	if not shared.vapereload then
		if not vape.Categories then return end
		if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
			vape:CreateNotification('[night] Finished Loading', 'wsg ' .. shared.aerov4User .. ' ' .. (vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press ' .. table.concat(vape.Keybind, ' + '):upper() .. ' to open GUI'), 5)
		end
	end
end

if not isfile('night/profiles/gui.txt') then
	writefile('night/profiles/gui.txt', 'new')
end
local gui = readfile('night/profiles/gui.txt')

if not isfolder('night/assets/' .. gui) then
	makefolder('night/assets/' .. gui)
end

local guiSource = downloadFile('night/guis/' .. gui .. '.lua')
local guiFunc, guiErr = loadstring(guiSource, 'gui')
if not guiFunc then
	local errMsg = tostring(guiErr)
	local lineNum = errMsg:match(':(%d+):')
	local context = ''
	if lineNum then
		local n = tonumber(lineNum)
		local lines = guiSource:split('\n')
		local from = math.max(1, n - 2)
		local to   = math.min(#lines, n + 2)
		local parts = {}
		for i = from, to do
			local marker = i == n and '>>> ' or '    '
			table.insert(parts, marker .. i .. ': ' .. (lines[i] or ''))
		end
		context = '\n\nContext:\n' .. table.concat(parts, '\n')
	end
	error('[night] syntax error in ' .. gui .. '.lua' .. '\n' .. errMsg .. context)
end
vape = guiFunc()
if not vape then
	error('[night] GUI returned nil file may be corrupted try deleting night/guis/' .. gui .. '.lua and reinjecting.')
end
if not vape.Load then
	if delfile then pcall(function() delfile('night/guis/' .. gui .. '.lua') end) end
	error('[night] gui file corrupted (missing load) reinject..')
end
if not vape.Init and not vape.Load then
	error('[night] failed to initialize properly reinject to fix this bs')
end
shared.vape = vape
task.wait(0.1)

if getgenv().Closet then
	local LogService = cloneref(game:GetService('LogService'))
	local originals = {}
	local function hook(funcName)
		if typeof(getgenv()[funcName]) == 'function' then
			local original = hookfunction(getgenv()[funcName], function() end)
			originals[funcName] = original
		end
	end
	hook('print')
	hook('warn')
	hook('error')
	hook('info')
	pcall(function() LogService:ClearOutput() end)
	local conn = LogService.MessageOut:Connect(function()
		LogService:ClearOutput()
	end)
	getgenv()._vape_log_connection = conn
	getgenv()._vape_originals = originals
end

if not shared.VapeIndependent then
	loadstring(downloadFile('night/games/universal.lua'), 'universal')()
	local gameFileId = (game.GameId == 2619619496) and (game.PlaceId == 6872265039 and 6872265039 or 6872274481) or (game.GameId == 10516888336 and 10516888336 or game.PlaceId)

	if isfile('night/games/' .. gameFileId .. '.lua') then
		local gameSrc = downloadFile('night/games/' .. gameFileId .. '.lua')
		local gameFunc, gameErr = loadstring(gameSrc, tostring(gameFileId))
		if not gameFunc then
			local msg = tostring(gameErr)
			local ln = msg:match(':(%d+):')
			local ctx = ''
			if ln then
				local n = tonumber(ln)
				local ls = gameSrc:split('\n')
				local parts = {}
				for i = math.max(1, n - 3), math.min(#ls, n + 3) do
					table.insert(parts, (i == n and '>>> ' or '    ') .. i .. ': ' .. (ls[i] or ''))
				end
				ctx = '\n\nContext:\n' .. table.concat(parts, '\n')
			end
			error('[night] syntax error in ' .. gameFileId .. '.lua\n' .. msg .. ctx)
		end
		gameFunc(...)
	else
		if not shared.VapeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/nighterx/night/' .. readfile('night/profiles/commit.txt') .. '/games/' .. gameFileId .. '.lua', true)
			end)
			if suc and res and res ~= '404: Not Found' then
				local path = 'night/games/' .. gameFileId .. '.lua'
				if not isfile(path) then
					writefile(path, '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res)
				end
				loadstring(readfile(path), tostring(gameFileId))(...)
			end
		end
	end
	finishLoading()
else
	vape.Init = finishLoading
	return vape
end
