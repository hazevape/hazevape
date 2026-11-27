-- loader.luau
-- Haze multi-game hotfix loader.
-- Games without an entry in PATCHES run untouched.

local WAIT_TIMEOUT = 15
local deadline = os.clock() + WAIT_TIMEOUT
while not shared.haze and os.clock() < deadline do
	task.wait(0.1)
end

local haze = shared.haze
if not haze then
	warn('haze: shared.haze never appeared, aborting.')
	return
end

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

--[[
	Per-game patches.

	version  - bump whenever you edit replacements or the helper; the on-disk
	           marker includes it, so a bump re-applies on the next run.
	helper   - prepend __hazeUpvalue (only set true if replacements use it).
	replacements - Lua patterns + replacement strings.

	Template:

	[0000000000] = {
		version = 1,
		helper = false,
		replacements = {
			{pattern = 'foo%(', replacement = 'bar('},
		},
	},
]]
local PATCHES = {
	[8768229691] = {
		version = 3,
		helper = true,
		replacements = {
			{
				pattern = 'debug%.getupvalue%(ControllerTable%.ProjectileController%.chargeBow,%s*10%)',
				replacement = "(__hazeUpvalue(ControllerTable.ProjectileController.chargeBow, 'ORIGIN_OFFSET', 10) or {ORIGIN_OFFSET = CFrame.new()})",
			},
			{
				pattern = 'debug%.getupvalue%(ControllerTable%.ProjectileController%.chargeBow,%s*12%)',
				replacement = "(__hazeUpvalue(ControllerTable.ProjectileController.chargeBow, 'WORLD_ACCELERATION', 12) or {WORLD_ACCELERATION = Vector3.new(0, -196.2, 0)})",
			},
			{
				pattern = 'skywars%.TeamController:getTeamColour',
				replacement = 'skywars.TeamController and skywars.TeamController:getTeamColour',
			},
		},
	},
}

local function splitWatermark(src)
	local first = src:match('^([^\n]*)\n')
	if first and first:find('This watermark is used to delete', 1, true) then
		return first, src:sub(#first + 2)
	end
	return nil, src
end

local function prepare(src, patch, place)
	local watermark, body = splitWatermark(src)
	local marker = ('-- __hazeHotfix v%d %d'):format(patch.version, place)

	if body:find(marker, 1, true) then
		return src, true, true
	end

	local applied = 0
	for _, entry in patch.replacements do
		local hits
		body, hits = body:gsub(entry.pattern, entry.replacement)
		applied += hits
	end

	if applied == 0 then
		return src, false, false
	end

	body = (patch.helper and HELPER..'\n' or '')..marker..'\n'..body
	if watermark then
		body = watermark..'\n'..body
	end

	return body, true, false
end

local function execute(src, path, patch, place)
	local chunkName = tostring(place)

	if not patch then
		local chunk = loadstring(src, chunkName)
		if chunk then
			chunk()
		end
		return
	end

	local patched, ok, already = prepare(src, patch, place)

	if not ok then
		haze:CreateNotification('Haze', 'Hotfix v'..patch.version..' for '..place..' did not apply, game code may have changed.', 30, 'alert')
	elseif path and not already then
		writefile(path, patched)
	end

	local chunk = loadstring(patched, chunkName)
	if chunk then
		chunk()
	end
end

local place = haze.Place or game.PlaceId
haze.Place = place

local patch = PATCHES[place]
local path = 'hazevape/games/'..place..'.lua'

if isfile(path) then
	execute(readfile(path), path, patch, place)
else
	if not shared.HazeDeveloper then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/hazevape/hazevape/'..readfile('hazevape/profiles/commit.txt')..'/games/'..place..'.lua', true)
		end)
		if suc and res ~= '404: Not Found' then
			execute(downloadFile(path), path, patch, place)
		end
	end
end
