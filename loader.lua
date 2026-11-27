local haze = shared.haze
local loadstring = function(...)
	local res, err = loadstring(...)
	if err and haze then
		haze:CreateNotification('Haze', 'Failed to load : '..err, 30, 'alert')
	end
	return res
end
local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
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

local PATCH_VERSION = 1

local HELPER = [==[
local __hazeUpvalue = function(func, key, fallback)
	for i = 1, 60 do
		local ok, name, value = pcall(debug.getupvalue, func, i)
		if not ok or name == nil then break end
		if type(value) == 'table' and rawget(value, key) ~= nil then
			return value
		end
	end
	local ok, value = pcall(debug.getupvalue, func, fallback)
	if ok and type(value) == 'table' and rawget(value, key) ~= nil then
		return value
	end
	return nil
end
]==]

local REPLACEMENTS = {
	{
		pattern = 'debug%.getupvalue%(ControllerTable%.ProjectileController%.chargeBow,%s*10%)',
		replacement = "(__hazeUpvalue(ControllerTable.ProjectileController.chargeBow, 'ORIGIN_OFFSET', 10) or {ORIGIN_OFFSET = CFrame.new()})",
	},
	{
		pattern = 'debug%.getupvalue%(ControllerTable%.ProjectileController%.chargeBow,%s*12%)',
		replacement = "(__hazeUpvalue(ControllerTable.ProjectileController.chargeBow, 'WORLD_ACCELERATION', 12) or {WORLD_ACCELERATION = Vector3.new(0, -196.2, 0)})",
	},
}

local function patchSource(src)
	if src:find('__hazeUpvalue', 1, true) then
		return src, true
	end

	local applied = 0
	for _, entry in REPLACEMENTS do
		local hits
		src, hits = src:gsub(entry.pattern, entry.replacement)
		applied += hits
	end

	if applied == 0 then
		return src, false
	end

	return HELPER..'\n'..src, true
end

local function execute(src)
	local patched, ok = patchSource(src)

	if not ok then
		haze:CreateNotification('Haze', 'Skywars hotfix v'..PATCH_VERSION..' did not apply, game code may have changed.', 30, 'alert')
	end

	local chunk = loadstring(patched, 'skywars')
	if chunk then
		chunk()
	end
end

haze.Place = 8768229691

if isfile('hazevape/games/'..haze.Place..'.lua') then
	execute(readfile('hazevape/games/'..haze.Place..'.lua'))
else
	if not shared.HazeDeveloper then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/hazevape/hazevape/'..readfile('hazevape/profiles/commit.txt')..'/games/'..haze.Place..'.lua', true)
		end)
		if suc and res ~= '404: Not Found' then
			execute(downloadFile('hazevape/games/'..haze.Place..'.lua'))
		end
	end
end
