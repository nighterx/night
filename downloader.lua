local _args = ...
if type(_args) ~= "table" then _args = {} end

local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file) writefile(file, '') end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/nighterx/night/'..readfile('night/profiles/commit.txt')..'/'..select(1, path:gsub('night/', '')), true)
		end)
		if not suc or res == '404: Not Found' then error(res) end
		if path:find('%.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'aerov4', 'night/games', 'night/profiles', 'night/assets', 'night/libraries', 'night/guis'} do
	if not isfolder(folder) then makefolder(folder) end
end

if not isfile('night/profiles/commit.txt') then
	writefile('night/profiles/commit.txt', 'main')
end

local function downloadPremadeProfiles(commit)
	local httpService = game:GetService('HttpService')
	if isfolder('night/profiles/premade') then
		for _, file in listfiles('night/profiles/premade') do
			pcall(function() if isfile(file) then delfile(file) end end)
		end
	else
		makefolder('night/profiles/premade')
	end
	local success, response = pcall(function()
		return game:HttpGet('https://api.github.com/repos/nighterx/night/contents/profiles/premade?ref=' .. commit)
	end)
	if success and response then
		local ok, files = pcall(function() return httpService:JSONDecode(response) end)
		if ok and type(files) == 'table' then
			for _, file in pairs(files) do
				if file.name and file.name:find('.txt') and file.name ~= 'commit.txt' then
					local baseName = (file.name:match('^(.-)%.txt$') or file.name):gsub('%d+$', '')
					local fileId = (game.GameId == 2619619496) and game.GameId or game.PlaceId
					local filePath = 'night/profiles/premade/' .. baseName .. tostring(fileId) .. '.txt'
					local ds, dc = pcall(function() return game:HttpGet(file.download_url, true) end)
					if ds and dc and dc ~= '404: Not Found' then writefile(filePath, dc) end
				end
			end
		end
	end
end

if not shared.VapeDeveloper then
	local commit = isfile('night/profiles/commit.txt') and readfile('night/profiles/commit.txt') or ''
	local latest = isfile('night/profiles/latest.txt') and readfile('night/profiles/latest.txt') or ''
	if #commit ~= 40 then
		local ok, res = pcall(function()
			return game:HttpGet('https://api.github.com/repos/nighterx/night/commits/main', true)
		end)
		if ok and res then
			local h = res:match('"sha":"([a-f0-9]+)"')
			if h and #h == 40 then commit = h end
		end
		if #commit ~= 40 then commit = 'main' end
		latest = commit
		pcall(writefile, 'night/profiles/latest.txt', latest)
	elseif #latest == 40 and latest ~= commit then
		commit = latest
	end
	task.spawn(function()
		local ok, res = pcall(function()
			return game:HttpGet('https://api.github.com/repos/nighterx/night/commits/main', true)
		end)
		if ok and res then
			local h = res:match('"sha":"([a-f0-9]+)"')
			if h and #h == 40 then
				pcall(writefile, 'night/profiles/latest.txt', h)
			end
		end
	end)
	if commit ~= 'main' and (isfile('night/profiles/commit.txt') and readfile('night/profiles/commit.txt') or '') ~= commit then
		wipeFolder('aerov4')
		wipeFolder('night/games')
		wipeFolder('night/guis')
		pcall(function() if isfile('night/guis/new.lua') then delfile('night/guis/new.lua') end end)
		wipeFolder('night/libraries')
		if isfolder('night/profiles/premade') then
			for _, file in listfiles('night/profiles/premade') do
				pcall(function() if isfile(file) then delfile(file) end end)
			end
		end
	end
	local oldCommit = isfile('night/profiles/commit.txt') and readfile('night/profiles/commit.txt') or ''
	writefile('night/profiles/commit.txt', commit)
	local needPremade = (oldCommit ~= commit)
	if not needPremade then
		needPremade = true
		if isfolder('night/profiles/premade') then
			for _ in listfiles('night/profiles/premade') do
				needPremade = false
				break
			end
		end
	end
	if needPremade then
		pcall(downloadPremadeProfiles, commit)
	end
end

return loadstring(downloadFile('night/main.lua'), 'main')({
	Closet = _args.Closet,
})
