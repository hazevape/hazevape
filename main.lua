repeat task.wait() until game:IsLoaded()
if shared.haze then shared.haze:Uninject() end

-- why do exploits fail to implement anything correctly? Is it really that hard?
if identifyexecutor then
	if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
		getgenv().setthreadidentity = nil
	end
end

local haze
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and haze then
		haze:CreateNotification('Haze', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local queue_on_teleport = queue_on_teleport or function() end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local cloneref = cloneref or function(obj)
	return obj
end
local playersService = cloneref(game:GetService('Players'))

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/hazevape/hazevape/'..readfile('hazevape/profiles/commit.txt')..'/'..select(1, path:gsub('hazevape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			error(res)
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after haze updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function finishLoading()
	haze.Init = nil
	haze:Load()
	task.spawn(function()
		repeat
			haze:Save()
			task.wait(10)
		until not haze.Loaded
	end)

	local teleportedServers
	haze:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
		if (not teleportedServers) and (not shared.HazeIndependent) then
			teleportedServers = true
			local teleportScript = [[
				shared.hazereload = true
				if shared.HazeDeveloper then
					loadstring(readfile('hazevape/loader.lua'), 'loader')()
				else
					loadstring(game:HttpGet('https://raw.githubusercontent.com/hazevape/hazevape/'..readfile('hazevape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
				end
			]]
			if shared.HazeDeveloper then
				teleportScript = 'shared.HazeDeveloper = true\n'..teleportScript
			end
			if shared.HazeCustomProfile then
				teleportScript = 'shared.HazeCustomProfile = "'..shared.HazeCustomProfile..'"\n'..teleportScript
			end
			haze:Save()
			queue_on_teleport(teleportScript)
		end
	end))

	if not shared.hazereload then
		if not haze.Categories then return end
		if haze.Categories.Main.Options['GUI bind indicator'].Enabled then
			haze:CreateNotification('Finished Loading', haze.HazeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(haze.Keybind, ' + '):upper()..' to open GUI', 5)
		end
	end
end

if not isfile('hazevape/profiles/gui.txt') then
	writefile('hazevape/profiles/gui.txt', 'new')
end
local gui = readfile('hazevape/profiles/gui.txt')

if not isfolder('hazevape/assets/'..gui) then
	makefolder('hazevape/assets/'..gui)
end
haze = loadstring(downloadFile('hazevape/guis/'..gui..'.lua'), 'gui')()
shared.haze = haze

if not shared.HazeIndependent then
	loadstring(downloadFile('hazevape/games/universal.lua'), 'universal')()
	if isfile('hazevape/games/'..game.PlaceId..'.lua') then
		loadstring(readfile('hazevape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
	else
		if not shared.HazeDeveloper then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/hazevape/hazevape/'..readfile('hazevape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
			end)
			if suc and res ~= '404: Not Found' then
				loadstring(downloadFile('hazevape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
			end
		end
	end
	finishLoading()
else
	haze.Init = finishLoading
	return haze
end