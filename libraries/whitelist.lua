local Whitelist = {}

Whitelist.Users = {
    [123456789] = "OWNER",
    [987654321] = "TESTER"
}

function Whitelist:GetRole(player)
    return self.Users[player.UserId] or "DEFAULT"
end

function Whitelist:IsWhitelisted(player)
    return self.Users[player.UserId] ~= nil
end

return Whitelist
