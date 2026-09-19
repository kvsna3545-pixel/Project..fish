--!strict
-- His_fixed.lua
-- Standard Roblox LocalScript version.
-- Place this in StarterPlayer > StarterPlayerScripts.
-- This version does not require an executor, getgenv, loadstring, or external code.

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CONFIG = {
	AutoRejoin = true,
	StreamerMode = false,
	BlackScreenWhenUnfocused = false,
	RejoinDelay = 5,
}

local connections: { RBXScriptConnection } = {}
local destroyed = false

local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

local function disconnectAll()
	for _, connection in ipairs(connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(connections)
end

local function createOverlay(): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "HisScreenOverlay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Overlay"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	return gui, frame
end

local overlayGui: ScreenGui? = nil
local overlayFrame: Frame? = nil

local function setOverlayVisible(visible: boolean)
	if overlayGui then
		overlayGui.Enabled = visible
	end
end

local function enableStreamerMode()
	if not CONFIG.StreamerMode then
		return
	end

	local function hideName(instance: Instance)
		if not (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then
			return
		end

		if instance.Text:find(player.Name, 1, true) then
			instance.Text = instance.Text:gsub(player.Name, "[Player]")
		end
		if instance.Text:find(player.DisplayName, 1, true) then
			instance.Text = instance.Text:gsub(player.DisplayName, "[Player]")
		end
	end

	for _, instance in ipairs(game:GetDescendants()) do
		hideName(instance)
	end
	connect(game.DescendantAdded, hideName)
end

local function enableFocusOverlay()
	if not CONFIG.BlackScreenWhenUnfocused then
		return
	end

	overlayGui, overlayFrame = createOverlay()

	connect(UserInputService.WindowFocusReleased, function()
		RunService:Set3dRenderingEnabled(false)
		setOverlayVisible(true)
	end)

	connect(UserInputService.WindowFocused, function()
		RunService:Set3dRenderingEnabled(true)
		setOverlayVisible(false)
	end)
end

local function enableAutoRejoin()
	if not CONFIG.AutoRejoin then
		return
	end

	local reconnecting = false

	local function rejoin()
		if reconnecting or destroyed then
			return
		end
		reconnecting = true
		task.wait(CONFIG.RejoinDelay)
		if not destroyed then
			TeleportService:Teleport(game.PlaceId, player)
		end
	end

	connect(TeleportService.TeleportInitFailed, function(failedPlayer: Player)
		if failedPlayer == player then
			task.spawn(rejoin)
		end
	end)

	-- Roblox can show a disconnect prompt without firing TeleportInitFailed.
	-- Listening for the prompt is intentionally avoided because CoreGui is protected
	-- in normal Roblox scripts. Use TeleportInitFailed for supported rejoin handling.
end

local function start()
	enableStreamerMode()
	enableFocusOverlay()
	enableAutoRejoin()

	print("[His_fixed] Initialized for " .. player.Name)
end

local function stop()
	destroyed = true
	disconnectAll()
	if overlayGui then
		overlayGui:Destroy()
		overlayGui = nil
		overlayFrame = nil
	end
	RunService:Set3dRenderingEnabled(true)
end

-- Optional control for another LocalScript:
-- _G.HisFixedStop = stop
_G.HisFixedStop = stop

start()
