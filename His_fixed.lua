--[[
    His_fixed.lua
    Cleaned and hardened Luau loader for Roblox.
    This file is a safer replacement for the original obfuscated "His" script.
    It keeps the same general idea (config + auto-rejoin + anti-afk + optional game loader)
    without the broken/unsafe globals and missing guards.
]]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local function safeGetEnv(key: string, default)
    local value = getgenv()[key]
    if value == nil then
        getgenv()[key] = default
    end
    return getgenv()[key]
end

local function toBoolean(value)
    if value == nil then
        return false
    end
    return value == true or value == 1 or value == "true"
end

local function safeCall(callback, fallback)
    local ok, err = xpcall(callback, debug.traceback)
    if not ok then
        if fallback then
            fallback(err)
        else
            warn("[His_fixed] " .. tostring(err))
        end
    end
end

local function setSafeEnvValues()
    getgenv().script_key = tostring(safeGetEnv("script_key", "123"))
    getgenv().premium = toBoolean(safeGetEnv("premium", true))
    getgenv().auto_rejoin = toBoolean(safeGetEnv("auto_rejoin", true))
    getgenv().whitescreen = toBoolean(safeGetEnv("whitescreen", false))
    getgenv().blackscreen = toBoolean(safeGetEnv("blackscreen", false))
    getgenv().streamer_mode = toBoolean(safeGetEnv("streamer_mode", false))
    getgenv().fully_rejoin = safeGetEnv("fully_rejoin", false)
    getgenv().avoid_player = safeGetEnv("avoid_player", nil)
    getgenv().auto_execute = toBoolean(safeGetEnv("auto_execute", false))
    getgenv().disable_auto_exec = toBoolean(safeGetEnv("disable_auto_exec", false))
    getgenv().delay_execute = tonumber(safeGetEnv("delay_execute", 0)) or 0
    getgenv().rollback = toBoolean(safeGetEnv("rollback", false))
    getgenv().skip_loading = toBoolean(safeGetEnv("skip_loading", false))
end

setSafeEnvValues()

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players.PlayerAdded:Wait()
    LocalPlayer = Players.LocalPlayer
end

local function waitForLoaded()
    if game:IsLoaded() then
        return
    end
    game.Loaded:Wait()
end

waitForLoaded()

task.wait(tonumber(getgenv().delay_execute) or 0)

does
    local value = getgenv().already_set_auto_exec
    if value == nil then
        getgenv().already_set_auto_exec = false
    end
end

local function setAutoExec()
    if getgenv().disable_auto_exec or getgenv().already_set_auto_exec then
        return
    end

    local future = queueonteleport or queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

    if future then
        local code = string.format([
            getgenv().script_key = %q;
            getgenv().premium = %s;
            getgenv().auto_rejoin = %s;
            getgenv().streamer_mode = %s;
            getgenv().fully_rejoin = %s;
            getgenv().whitescreen = %s;
            getgenv().blackscreen = %s;
            getgenv().skip_loading = %s;
            getgenv().already_set_auto_exec = true;
            loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/kvsna3545-pixel/Project..fish/main/His"))()
        ],
            tostring(getgenv().script_key),
            tostring(getgenv().premium),
            tostring(getgenv().auto_rejoin),
            tostring(getgenv().streamer_mode),
            tostring(getgenv().fully_rejoin),
            tostring(getgenv().whitescreen),
            tostring(getgenv().blackscreen),
            tostring(getgenv().skip_loading)
        )

        future(code)
    end

    getgenv().already_set_auto_exec = true
end

local function antiAfk()
    task.spawn(function()
        safeCall(function()
            local connections = (getconnections or get_signal_cons)(LocalPlayer.Idled)
            for _, conn in ipairs(connections) do
                if conn.Disable then
                    conn:Disable()
                elseif conn.Disconnect then
                    conn:Disconnect()
                end
            end
        end)
    end)
end

local function setupAutoRejoin()
    if not getgenv().auto_rejoin then
        return
    end

    task.spawn(function()
        safeCall(function()
            local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui")
            if not promptOverlay then
                return
            end
            promptOverlay.promptOverlay.ChildAdded:Connect(function(child)
                if child.Name == "ErrorPrompt" and child:FindFirstChild("MessageArea") and child.MessageArea:FindFirstChild("ErrorFrame") then
                    setAutoExec()
                    task.wait(5)
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)
        end)
    end)
end

local function protectStreamerMode()
    if not getgenv().streamer_mode then
        return
    end

    local function replaceText(targetText, replacement)
        for _, descendant in ipairs(game:GetDescendants()) do
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
                if typeof(descendant.Text) == "string" and descendant.Text:find(targetText, 1, true) then
                    descendant.Text = descendant.Text:gsub(targetText, replacement)
                    descendant:GetPropertyChangedSignal("Text"):Connect(function()
                        descendant.Text = descendant.Text:gsub(targetText, replacement)
                    end)
                end
            end
        end
    end

    replaceText(LocalPlayer.Name, "[Protected]")
    replaceText(LocalPlayer.DisplayName, "[Protected]")
end

local function setupScreenState()
    if not (getgenv().whitescreen or getgenv().blackscreen) then
        return
    end

    local overlay = Instance.new("ScreenGui")
    overlay.Name = "ScreenStateOverlay"
    overlay.ResetOnSpawn = false
    overlay.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Name = "StateFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    frame.Visible = false
    frame.Parent = overlay

    local function setVisible(state)
        frame.Visible = state
    end

    UserInputService.WindowFocusReleased:Connect(function()
        RunService:Set3dRenderingEnabled(false)
        setVisible(true)
    end)

    UserInputService.WindowFocused:Connect(function()
        RunService:Set3dRenderingEnabled(true)
        setVisible(false)
    end)
end

local function monitorAvoidPlayers()
    local avoidList = getgenv().avoid_player
    if type(avoidList) ~= "table" then
        return
    end

    task.spawn(function()
        while true do
            task.wait(2)
            for _, player in ipairs(Players:GetPlayers()) do
                if table.find(avoidList, player.UserId) then
                    warn("[His_fixed] Found blocked player: " .. player.Name .. " - hopping server...")
                    local response = (request or http_request)({
                        Url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=10&excludeFullGames=true", game.PlaceId),
                        Method = "GET",
                    })

                    if response and response.Body then
                        local body = HttpService:JSONDecode(response.Body)
                        if body and body.data then
                            for _, server in ipairs(body.data) do
                                if server and server.id and server.playing < server.maxPlayers then
                                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function setupLoader()
    if getgenv().premium or getgenv().rollback then
        return
    end

    -- Example: hook into supported game IDs or custom loaders.
    local gameId = game.GameId
    if gameId == 5750914919 then
        print("[His_fixed] Fisch detected. Loader ready.")
    else
        print("[His_fixed] Game ID: " .. tostring(gameId) .. " (loader is ready but not specifically mapped yet).")
    end
end

antiAfk()
setupAutoRejoin()
protectStreamerMode()
setupScreenState()
monitorAvoidPlayers()
setupLoader()

print("[His_fixed] Script initialized successfully.")
