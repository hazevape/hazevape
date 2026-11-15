-- ServerScriptService/LicenseServer.lua
-- In your OWN Roblox experience, enable Game Settings > Security > Allow HTTP Requests.
-- Players submit their own redeemed keys; never trust the client's claim to be licensed.
local HttpService = game:GetService('HttpService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local API_URL = 'https://roblox-license-api.YOUR_SUBDOMAIN.workers.dev/api/verify'

local submit = Instance.new('RemoteEvent')
submit.Name = 'SubmitLicenseKey'
submit.Parent = ReplicatedStorage
local resultEvent = Instance.new('RemoteEvent')
resultEvent.Name = 'LicenseResult'
resultEvent.Parent = ReplicatedStorage
local lastAttempt = {}
local licensed = {}

submit.OnServerEvent:Connect(function(player, key)
    if typeof(key) ~= 'string' or #key > 50 then return end
    if lastAttempt[player] and os.clock() - lastAttempt[player] < 5 then return end
    lastAttempt[player] = os.clock()
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = API_URL,
            Method = 'POST',
            Headers = {['Content-Type'] = 'application/json'},
            Body = HttpService:JSONEncode({key = key, robloxUserId = tostring(player.UserId)}),
        })
    end)
    local valid = false
    if success and response.Success then
        local parsed, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        valid = parsed and data.valid == true
    end
    licensed[player] = valid
    resultEvent:FireClient(player, valid)
    if valid then
        print('License verified for', player.Name)
        -- Enable your server-authoritative licensed functionality here.
        -- Reverify on joining next time; keys can be revoked or expire.
    end
end)

Players.PlayerRemoving:Connect(function(player)
    licensed[player] = nil
    lastAttempt[player] = nil
end)
