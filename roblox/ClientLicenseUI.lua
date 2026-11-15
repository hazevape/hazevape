-- StarterPlayer/StarterPlayerScripts/LicenseUI.client.lua
-- Minimal sample UI to submit a user's own key to the server.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local player = Players.LocalPlayer
local gui = Instance.new('ScreenGui')
gui.Name = 'LicenseInput'
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild('PlayerGui')
local frame = Instance.new('Frame')
frame.Size = UDim2.fromOffset(360, 150)
frame.Position = UDim2.new(0.5,-180,0.5,-75)
frame.BackgroundColor3 = Color3.fromRGB(24, 24, 35)
frame.Parent = gui
local input = Instance.new('TextBox')
input.PlaceholderText = 'Enter your redeemed RBX key'
input.Text = ''
input.Size = UDim2.new(1,-30,0,42)
input.Position = UDim2.fromOffset(15,16)
input.Parent = frame
local button = Instance.new('TextButton')
button.Text = 'Verify License'
button.Size = UDim2.new(1,-30,0,38)
button.Position = UDim2.fromOffset(15,70)
button.Parent = frame
local status = Instance.new('TextLabel')
status.Text = ''
status.TextColor3 = Color3.new(1,1,1)
status.BackgroundTransparency = 1
status.Size = UDim2.new(1,-30,0,28)
status.Position = UDim2.fromOffset(15,116)
status.Parent = frame
button.Activated:Connect(function()
    status.Text = 'Verifying...'
    RS:WaitForChild('SubmitLicenseKey'):FireServer(input.Text)
end)
RS:WaitForChild('LicenseResult').OnClientEvent:Connect(function(valid)
    status.Text = valid and 'License accepted!' or 'License invalid, expired, or unavailable.'
    if valid then input.Text = '' end
end)
