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

haze.Place = 6872274481
if isfile('hazevape/games/'..haze.Place..'.lua') then
	loadstring(readfile('hazevape/games/'..haze.Place..'.lua'), 'bedwars')()
else
	if not shared.HazeDeveloper then
		local suc, res = pcall(function() 
			return game:HttpGet('https://raw.githubusercontent.com/hazevape/hazevape/'..readfile('hazevape/profiles/commit.txt')..'/games/'..haze.Place..'.lua', true) 
		end)
		if suc and res ~= '404: Not Found' then
			loadstring(downloadFile('hazevape/games/'..haze.Place..'.lua'), 'bedwars')()
		end
	end
end