-- ============================================================
-- NATSUMI LAG CLIENT v6.3 - WEAPON REACH ANTI-SIT BUG FIX
-- - Auto Aimbot (NPC)
-- - Manual Aimbot (Player) + Manual Aimbot (NPC/Dummy by name)
-- - ESP (NPC, Player) - Clean UI
-- - Hitbox Expand (YOUR WEAPON/ARMS ONLY)
-- - ANTI-SIT ADDED: Prevents teleporting to seats when hitboxes are giant!
-- - Reach Range (slider)
-- - LowSpec / LowFly (toggles & levels)
-- - Auto Farm, Auto Revive, Auto Emote Dash, Anti-AFK
-- ============================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Services
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Local player / GUI parent
local LocalPlayer = Players.LocalPlayer
local TargetGui = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if gethui then
        TargetGui = gethui()
    elseif CoreGui then
        TargetGui = CoreGui
    end
end)

-- Preserve originals for restore
local Original = {
    GlobalShadows = Lighting.GlobalShadows,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    QualityLevel = settings().Rendering.QualityLevel
}

-- =========================
-- GLOBAL STATE & CONFIG
-- =========================
local CurrentBoost = 0
local UIVisible = true
local UIMinimized = false
local CurrentFPS = 0
local AllConns = {}
local ParticleConns = {}
local SavedParts = {}
local SavedMeshes = {}
local SavedDecals = {}
local TextureRemoved = false
local FLAT_COLOR = Color3.fromRGB(140, 140, 140)

-- ESP state
local ESPEnabled = false
local ESPPlayerOn = false
local ESPNPCOnly = false
local ESPNameOn = true
local ESPDistOn = true
local ESPBoxOn = true
local ESPHighlightOn = true
local ESPObjects = {}
local ESPWatcher = nil
local ESPLoop = nil

-- Aimbot state
local AutoAimbotOn = false
local PlayerAimbotOn = false
local ManualPlayerAimbotOn = false
local ManualNPCAimbotOn = false
local IgnoreTeammates = true
local SelectedTargetName = ""
local AimTarget = nil
local AimScanConn = nil
local AimCamConn = nil
local TargetCache = {}

-- Hitbox (Weapon Reach)
local HitboxExpandOn = false
local HitboxSize = Vector3.new(10, 10, 10)
local ReachRange = 400
local ReachMin = 50
local ReachMax = 1200

-- LowSpec / LowFly
local LowSpecOn = false
local LowSpecLevel = 0
local AutoFarmOn = false
local AutoReviveOn = false
local AutoEmoteDashOn = false

local function Track(c)
    table.insert(AllConns, c)
    return c
end

local function CleanAll()
    for _, c in pairs(AllConns) do
        if c then c:Disconnect() end
    end
end

do
    local fCount = 0
    local lTime = tick()
    Track(RunService.RenderStepped:Connect(function()
        fCount = fCount + 1
        if tick() - lTime >= 0.5 then
            CurrentFPS = math.floor(fCount / (tick() - lTime))
            fCount = 0
            lTime = tick()
        end
    end))
end

local function GetPing()
    local ok, v = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and math.floor(v) or 0
end

-- =========================
-- AUTO FEATURES
-- =========================
local function ToggleAutoFarm(state)
    AutoFarmOn = state
    if not state then return end
    task.spawn(function()
        while AutoFarmOn do
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = CFrame.new(root.Position.X, 300, root.Position.Z)
                root.Velocity = Vector3.new(0,0,0)
            end
            task.wait()
        end
    end)
end

local function ToggleAutoRevive(state)
    AutoReviveOn = state
    if not state then return end
    task.spawn(function()
        while AutoReviveOn do
            for _, p in pairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:GetAttribute("Downed") then
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
                    if root and targetRoot then
                        local oldPos = root.CFrame
                        root.CFrame = targetRoot.CFrame
                        task.wait(0.2)
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait(0.1)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                        root.CFrame = oldPos
                        task.wait(0.5)
                    end
                end
            end
            task.wait(0.5)
        end
    end)
end

-- =========================
-- GRAPHICS REDUCTION
-- =========================
local ParticleWatcher = nil
local FlatWatcher = nil

local function ToggleParticles(enable)
    if ParticleWatcher then ParticleWatcher:Disconnect() ParticleWatcher = nil end
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") then pcall(function() o.Enabled = enable end) end
    end
    if not enable then
        ParticleWatcher = Track(Workspace.DescendantAdded:Connect(function(o)
            if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") then pcall(function() o.Enabled = false end) end
        end))
    end
end

local function TogglePostFX(enable)
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("DepthOfFieldEffect") then
            pcall(function() e.Enabled = enable end)
        end
    end
end

local function FlattenObj(o)
    if o:IsA("BasePart") and not o:IsA("Terrain") then
        if not SavedParts[o] then SavedParts[o] = { M = o.Material, C = o.Color, S = o.CastShadow } end
        pcall(function() o.Material = Enum.Material.SmoothPlastic o.Color = FLAT_COLOR o.CastShadow = false end)
    elseif o:IsA("SpecialMesh") then
        if not SavedMeshes[o] then SavedMeshes[o] = o.TextureId end
        pcall(function() o.TextureId = "" end)
    elseif o:IsA("Texture") or o:IsA("Decal") then
        if not SavedDecals[o] then SavedDecals[o] = o.Transparency end
        pcall(function() o.Transparency = 1 end)
    end
end

local function RemoveTextures()
    if TextureRemoved then return end
    TextureRemoved = true
    for _, o in ipairs(Workspace:GetDescendants()) do FlattenObj(o) end
    FlatWatcher = Track(Workspace.DescendantAdded:Connect(function(o) task.wait() FlattenObj(o) end))
end

local function RestoreTextures()
    if not TextureRemoved then return end
    TextureRemoved = false
    if FlatWatcher then FlatWatcher:Disconnect() FlatWatcher = nil end
    for o, d in pairs(SavedParts) do if o and o.Parent then pcall(function() o.Material = d.M o.Color = d.C o.CastShadow = d.S end) end end
    for o, d in pairs(SavedMeshes) do if o and o.Parent then pcall(function() o.TextureId = d end) end end
    for o, d in pairs(SavedDecals) do if o and o.Parent then pcall(function() o.Transparency = d end) end end
    SavedParts, SavedMeshes, SavedDecals = {}, {}, {}
end

local function SetLowSpec(enable, level)
    if not enable then
        RestoreTextures() ToggleParticles(true) TogglePostFX(true)
        Lighting.GlobalShadows = Original.GlobalShadows
        Lighting.FogEnd, Lighting.FogStart = Original.FogEnd, Original.FogStart
        Lighting.Brightness, Lighting.ClockTime = Original.Brightness, Original.ClockTime
        settings().Rendering.QualityLevel = Original.QualityLevel
        CurrentBoost = 0 LowSpecOn = false LowSpecLevel = 0
        return
    end
    LowSpecOn = true LowSpecLevel = level or 100
    ToggleParticles(true) TogglePostFX(true) RestoreTextures()
    Lighting.GlobalShadows = Original.GlobalShadows
    Lighting.FogEnd, Lighting.FogStart = Original.FogEnd, Original.FogStart
    settings().Rendering.QualityLevel = Original.QualityLevel
    CurrentBoost = 0
    if LowSpecLevel >= 25 then Lighting.GlobalShadows = false Lighting.FogEnd = 900 settings().Rendering.QualityLevel = Enum.QualityLevel.Level04 CurrentBoost = 25 end
    if LowSpecLevel >= 50 then ToggleParticles(false) Lighting.FogEnd = 600 settings().Rendering.QualityLevel = Enum.QualityLevel.Level02 CurrentBoost = 50 end
    if LowSpecLevel >= 75 then TogglePostFX(false) Lighting.FogEnd = 350 CurrentBoost = 75 end
    if LowSpecLevel >= 100 then RemoveTextures() Lighting.Brightness = 2 Lighting.ClockTime = 14 Lighting.FogEnd = 250 settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 CurrentBoost = 100 end
end

local function ApplyBoost(level) SetLowSpec(true, level) end

-- =========================
-- ESP
-- =========================
local function IsPlayerChar(m)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == m and p ~= LocalPlayer then return true end
    end
    return false
end

local function IsNPC(m) return not IsPlayerChar(m) and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") end
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    if player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
    return true
end

local function AddESP(m)
    if ESPObjects[m] then return end
    local root = m:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local isPlayer = IsPlayerChar(m)
    local espColor = isPlayer and Color3.fromRGB(50, 255, 255) or Color3.fromRGB(255, 50, 50)
    if isPlayer then
        local plr = Players:GetPlayerFromCharacter(m)
        if plr and IsEnemy(plr) then espColor = Color3.fromRGB(255, 50, 50) end
    end

    local hl = Instance.new("Highlight")
    hl.FillColor = espColor hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.4 hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = ESPHighlightOn hl.Parent = m

    local box = Instance.new("BoxHandleAdornment")
    box.Size = Vector3.new(4, 5.5, 2) box.Adornee = root box.AlwaysOnTop = true box.ZIndex = 10
    box.Color3 = espColor box.Transparency = 0.4 box.Visible = ESPBoxOn box.Parent = TargetGui

    local bb = Instance.new("BillboardGui")
    bb.Adornee = root bb.Size = UDim2.new(0, 120, 0, 36) bb.StudsOffset = Vector3.new(0, 3.5, 0)
    bb.AlwaysOnTop = true bb.MaxDistance = 500 bb.Parent = TargetGui

    local nl = Instance.new("TextLabel")
    nl.Parent = bb nl.Size = UDim2.new(1, 0, 0.55, 0) nl.BackgroundTransparency = 1 nl.Text = m.Name
    nl.TextColor3 = Color3.fromRGB(255, 255, 255) nl.TextSize = 13 nl.Font = Enum.Font.GothamBold nl.TextStrokeTransparency = 0 nl.Visible = ESPNameOn

    local dl = Instance.new("TextLabel")
    dl.Parent = bb dl.Size = UDim2.new(1, 0, 0.45, 0) dl.Position = UDim2.new(0, 0, 0.55, 0) dl.BackgroundTransparency = 1
    dl.Text = "0m" dl.TextColor3 = espColor dl.TextSize = 11 dl.Font = Enum.Font.Gotham dl.Visible = ESPDistOn

    ESPObjects[m] = { HL = hl, BOX = box, BB = bb, NL = nl, DL = dl }
    m.AncestryChanged:Connect(function()
        if not m.Parent and ESPObjects[m] then
            pcall(function() if ESPObjects[m].HL then ESPObjects[m].HL:Destroy() end if ESPObjects[m].BOX then ESPObjects[m].BOX:Destroy() end if ESPObjects[m].BB then ESPObjects[m].BB:Destroy() end end)
            ESPObjects[m] = nil
        end
    end)
end

local function ScanESP()
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("Model") and o:FindFirstChild("HumanoidRootPart") then
            if ESPNPCOnly and IsNPC(o) then AddESP(o) elseif not ESPNPCOnly then if IsNPC(o) then AddESP(o) elseif ESPPlayerOn and IsPlayerChar(o) then AddESP(o) end end
        end
    end
end

local function StopESP()
    ESPEnabled = false
    for m, d in pairs(ESPObjects) do
        pcall(function() if d.HL then d.HL:Destroy() end if d.BOX then d.BOX:Destroy() end if d.BB then d.BB:Destroy() end end)
    end
    ESPObjects = {}
    if ESPWatcher then ESPWatcher:Disconnect() ESPWatcher = nil end
    if ESPLoop then ESPLoop:Disconnect() ESPLoop = nil end
end

local function StartESP()
    StopESP() ESPEnabled = true task.spawn(ScanESP)
    ESPWatcher = Track(Workspace.DescendantAdded:Connect(function(o)
        if not o then return end
        if o:IsA("Model") then
            task.wait(0.5)
            if o:FindFirstChild("HumanoidRootPart") then
                if ESPNPCOnly and IsNPC(o) then AddESP(o) elseif not ESPNPCOnly then if IsNPC(o) then AddESP(o) elseif ESPPlayerOn and IsPlayerChar(o) then AddESP(o) end end
            end
        end
    end))
    ESPLoop = Track(RunService.Heartbeat:Connect(function()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        for m, d in pairs(ESPObjects) do
            local hum = m:FindFirstChildOfClass("Humanoid")
            local nRoot = m:FindFirstChild("HumanoidRootPart")
            if not m.Parent or not nRoot or (hum and hum.Health <= 0) then
                pcall(function() if d.HL then d.HL:Destroy() end if d.BOX then d.BOX:Destroy() end if d.BB then d.BB:Destroy() end end)
                ESPObjects[m] = nil continue
            end
            if nRoot.Transparency == 1 then nRoot.Transparency = 0.99 end
            if d.HL then d.HL.Enabled = ESPHighlightOn end
            if d.BOX then d.BOX.Visible = ESPBoxOn end
            if d.NL then d.NL.Visible = ESPNameOn end
            if d.DL then d.DL.Visible = ESPDistOn end
            if myRoot and d.DL and nRoot then d.DL.Text = math.floor((myRoot.Position - nRoot.Position).Magnitude) .. "m" end
        end
    end))
end

-- =========================
-- AIMBOT
-- =========================
local lastCacheUpdate = 0
local function UpdateAimbotState()
    local anyOn = AutoAimbotOn or PlayerAimbotOn or ManualPlayerAimbotOn or ManualNPCAimbotOn
    if not anyOn then
        if AimScanConn then AimScanConn:Disconnect() AimScanConn = nil end
        if AimCamConn then AimCamConn:Disconnect() AimCamConn = nil end
        AimTarget = nil TargetCache = {} return
    end
    if AimScanConn then AimScanConn:Disconnect() AimScanConn = nil end
    if AimCamConn then AimCamConn:Disconnect() AimCamConn = nil end

    AimScanConn = Track(RunService.Heartbeat:Connect(function()
        if tick() - lastCacheUpdate > 0.3 then
            lastCacheUpdate = tick()
            local newCache, added = {}, {}
            local function AddTargetSafe(root) if root and not added[root] then added[root] = true table.insert(newCache, root) end end

            if PlayerAimbotOn or ManualPlayerAimbotOn then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and p.Character then
                        if not (IgnoreTeammates and not IsEnemy(p)) then
                            local root = p.Character:FindFirstChild("HumanoidRootPart")
                            local hum = p.Character:FindFirstChildOfClass("Humanoid")
                            if root and hum and hum.Health > 0 then AddTargetSafe(root) end
                        end
                    end
                end
            end
            if ManualNPCAimbotOn and SelectedTargetName ~= "" then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and string.find(string.lower(obj.Name), string.lower(SelectedTargetName)) then
                        local root = obj:FindFirstChild("HumanoidRootPart")
                        local hum = obj:FindFirstChildOfClass("Humanoid")
                        if root and hum and hum.Health > 0 then AddTargetSafe(root) end
                    end
                end
            end
            if AutoAimbotOn then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj:IsA("Model") and IsNPC(obj) then
                        local root = obj:FindFirstChild("HumanoidRootPart")
                        local hum = obj:FindFirstChildOfClass("Humanoid")
                        if root and hum and hum.Health > 0 then AddTargetSafe(root) end
                    end
                end
            end
            TargetCache = newCache
        end
    end))

    AimCamConn = Track(RunService.RenderStepped:Connect(function()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local nearestDistance, nearestTarget = ReachRange + 1, nil
        for _, rootPart in ipairs(TargetCache) do
            if rootPart and rootPart.Parent then
                local hum = rootPart.Parent:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    local dist = (myRoot.Position - rootPart.Position).Magnitude
                    if dist <= ReachRange and dist < nearestDistance then
                        nearestDistance = dist
                        nearestTarget = rootPart
                    end
                end
            end
        end
        AimTarget = nearestTarget
        if AimTarget and Workspace.CurrentCamera then
            Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame:Lerp(
                CFrame.new(Workspace.CurrentCamera.CFrame.Position, AimTarget.Position), 0.25
            )
        end
    end))
end

-- =========================
-- HITBOX EXPAND (WEAPON REACH) + ANTI-SIT FIX
-- =========================
local function UpdateHitbox()
    if not HitboxExpandOn then 
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end
        return 
    end

    task.spawn(function()
        while HitboxExpandOn do
            local char = LocalPlayer.Character
            if char then
                -- ANTI-SIT: Vô hiệu hóa chức năng Ngồi của nhân vật để tránh bị hút vào ghế
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
                    if hum.Sit then hum.Sit = false end
                end

                -- 1. Ưu tiên tìm Vũ Khí đang cầm (Tool)
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then
                    for _, v in pairs(tool:GetDescendants()) do
                        if v:IsA("BasePart") or v:IsA("Part") then
                            pcall(function()
                                v.Size = Vector3.new(HitboxSize.X, HitboxSize.Y, HitboxSize.Z)
                                v.Transparency = 1 -- Tàng hình
                                v.CanCollide = false
                                v.Massless = true
                            end)
                        end
                    end
                else
                    -- 2. Nếu đánh chay (không cầm vũ khí), phóng to 2 tay
                    local rArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
                    local lArm = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftHand")
                    
                    if rArm then pcall(function() rArm.Size = Vector3.new(HitboxSize.X, HitboxSize.Y, HitboxSize.Z) rArm.Transparency = 1 rArm.CanCollide=false rArm.Massless=true end) end
                    if lArm then pcall(function() lArm.Size = Vector3.new(HitboxSize.X, HitboxSize.Y, HitboxSize.Z) lArm.Transparency = 1 lArm.CanCollide=false lArm.Massless=true end) end
                end
            end
            task.wait(0.2)
        end
        
        -- Khôi phục chức năng ngồi khi tắt
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end
    end)
end

-- =========================
-- AUTO EMOTE DASH
-- =========================
local EmoteDashConn = nil
local function ToggleEmoteDash(state)
    AutoEmoteDashOn = state
    if not state then
        if EmoteDashConn then EmoteDashConn:Disconnect() EmoteDashConn = nil end
        return
    end
    EmoteDashConn = Track(RunService.Heartbeat:Connect(function()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game) task.wait(0.01) VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game) task.wait(0.01) VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) task.wait(0.05)
        end
    end))
end

-- =========================
-- UI CREATION
-- =========================
local function SmoothTween(obj, props, time) TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play() end
local function Create(class, parent, props) local i = Instance.new(class, parent) for k, v in pairs(props or {}) do i[k] = v end return i end
local function Corner(p, r) Create("UICorner", p, { CornerRadius = UDim.new(0, r or 8) }) end
local function AddGradient(parent) local g = Create("UIGradient", parent, {}) g.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 170)), ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 255))} return g end

local MainGui = Create("ScreenGui", TargetGui, { Name = "NatsumiLag", ResetOnSpawn = false, DisplayOrder = 100 })
local C = { BG = Color3.fromRGB(15, 15, 20), Panel = Color3.fromRGB(24, 24, 30), Tab = Color3.fromRGB(30, 30, 38), Text = Color3.fromRGB(245, 245, 250), TextDim = Color3.fromRGB(130, 130, 150), Topbar = Color3.fromRGB(10, 10, 14) }

local Main = Create("Frame", MainGui, { Size = UDim2.new(0, 380, 0, 520), Position = UDim2.new(0.7, 0, 0.2, 0), BackgroundColor3 = C.BG, ClipsDescendants = true })
Corner(Main, 14) Create("UIStroke", Main, { Thickness = 1.5 })

-- Topbar & Window Controls (WINDOWS STYLE UI UPDATE)
local Topbar = Create("Frame", Main, { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.Topbar, BorderSizePixel = 0 })
local TitleText = Create("TextLabel", Topbar, { Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = "NATSUMI LAG CLIENT v6.3", TextColor3 = C.Text, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
local ControlsContainer = Create("Frame", Topbar, { Size = UDim2.new(0, 135, 1, 0), Position = UDim2.new(1, -135, 0, 0), BackgroundTransparency = 1 })
Create("UIListLayout", ControlsContainer, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center })

local function CreateWinBtn(parent, drawFunc, isClose)
    local btn = Create("TextButton", parent, { Size = UDim2.new(0, 45, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false })
    drawFunc(btn)
    btn.MouseEnter:Connect(function() SmoothTween(btn, { BackgroundColor3 = isClose and Color3.fromRGB(220,50,50) or Color3.fromRGB(50,50,60), BackgroundTransparency = 0 }, 0.15) end)
    btn.MouseLeave:Connect(function() SmoothTween(btn, { BackgroundTransparency = 1 }, 0.15) end)
    return btn
end

local BtnMin = CreateWinBtn(ControlsContainer, function(p)
    Create("Frame", p, { Size = UDim2.new(0, 10, 0, 1), Position = UDim2.new(0.5, -5, 0.5, 0), BackgroundColor3 = C.Text, BorderSizePixel = 0 })
end, false)

local BtnMax = CreateWinBtn(ControlsContainer, function(p)
    local sq1 = Create("Frame", p, { Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0.5, -2, 0.5, -6), BackgroundTransparency = 1, BorderColor3 = C.Text, BorderSizePixel = 1 })
    local sq2 = Create("Frame", p, { Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0.5, -6, 0.5, -2), BackgroundColor3 = C.Topbar, BorderColor3 = C.Text, BorderSizePixel = 1 })
    p.MouseEnter:Connect(function() sq2.BackgroundColor3 = Color3.fromRGB(50,50,60) end)
    p.MouseLeave:Connect(function() sq2.BackgroundColor3 = C.Topbar end)
end, false)

local BtnClose = CreateWinBtn(ControlsContainer, function(p)
    Create("Frame", p, { Size = UDim2.new(0, 12, 0, 1), Position = UDim2.new(0.5, -6, 0.5, 0), BackgroundColor3 = C.Text, BorderSizePixel = 0, Rotation = 45 })
    Create("Frame", p, { Size = UDim2.new(0, 12, 0, 1), Position = UDim2.new(0.5, -6, 0.5, 0), BackgroundColor3 = C.Text, BorderSizePixel = 0, Rotation = -45 })
end, true)

do
    local drag, dStart, sPos = false, nil, nil
    Topbar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true dStart = i.Position sPos = Main.Position end end)
    Topbar.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then local d = i.Position - dStart Main.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y) end end)
    Topbar.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
end

local TabBar = Create("Frame", Main, { Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 0, 30), BackgroundColor3 = C.Tab })
Create("UIListLayout", TabBar, { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) })
local Content = Create("Frame", Main, { Size = UDim2.new(1, 0, 1, -66), Position = UDim2.new(0, 0, 0, 66), BackgroundColor3 = C.BG })

BtnMin.MouseButton1Click:Connect(function() UIMinimized = not UIMinimized SmoothTween(Main, { Size = UIMinimized and UDim2.new(0, 380, 0, 30) or UDim2.new(0, 380, 0, 520) }) TabBar.Visible, Content.Visible = not UIMinimized, not UIMinimized end)
BtnMax.MouseButton1Click:Connect(function() SmoothTween(Main, { Size = UDim2.new(0, 380, 0, 520) }, 0.2) UIMinimized = false TabBar.Visible, Content.Visible = true, true end)
BtnClose.MouseButton1Click:Connect(function() CleanAll() StopESP() SetLowSpec(false, 0) MainGui:Destroy() end)

local tabs, tabBtns, orderCounter = {}, {}, 0
local function GetOrder() orderCounter = orderCounter + 1 return orderCounter end
local function AddTab(name, icon)
    local sf = Create("ScrollingFrame", Content, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 2, Visible = false, AutomaticCanvasSize = Enum.AutomaticSize.Y })
    Create("UIListLayout", sf, { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder })
    Create("UIPadding", sf, { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 15) })
    local btn = Create("TextButton", TabBar, { Size = UDim2.new(0, 82, 1, -6), BackgroundColor3 = C.Tab, Text = icon .. "\n" .. name, TextColor3 = C.TextDim, Font = Enum.Font.GothamBold, TextSize = 9 }) Corner(btn, 6)
    btn.MouseButton1Click:Connect(function() for i, s in pairs(tabs) do s.Visible = false SmoothTween(tabBtns[i], { BackgroundColor3 = C.Tab, TextColor3 = C.TextDim }, 0.2) end sf.Visible = true SmoothTween(btn, { BackgroundColor3 = Color3.fromRGB(45, 45, 55), TextColor3 = C.Text }, 0.2) end)
    table.insert(tabs, sf) table.insert(tabBtns, btn) return sf
end

local T_Stats = AddTab("Trang Chủ", "🏠")
local T_Boost = AddTab("Giảm Lag", "⚡")
local T_ESP = AddTab("Combat", "🎯")
local T_Vis = AddTab("Bản Đồ", "🌍")
local T_Util = AddTab("Tiện Ích", "🛠")
tabs[1].Visible = true tabBtns[1].BackgroundColor3 = Color3.fromRGB(45, 45, 55) tabBtns[1].TextColor3 = C.Text

local function MakeTitle(parent, text) Create("TextLabel", parent, { LayoutOrder = GetOrder(), Size = UDim2.new(0, 340, 0, 24), BackgroundTransparency = 1, Text = text, TextColor3 = C.TextDim, Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left }) end
local function MakeBtn(parent, text, cb) local btn = Create("TextButton", parent, { LayoutOrder = GetOrder(), Size = UDim2.new(0, 340, 0, 36), BackgroundColor3 = C.Panel, Text = text, TextColor3 = C.Text, Font = Enum.Font.GothamBold, TextSize = 12 }) Corner(btn, 8) btn.MouseEnter:Connect(function() SmoothTween(btn, { BackgroundColor3 = Color3.fromRGB(40,40,50) }) end) btn.MouseLeave:Connect(function() SmoothTween(btn, { BackgroundColor3 = C.Panel }) end) btn.MouseButton1Click:Connect(function() local r = Create("Frame", btn, { BackgroundColor3 = C.Text, BackgroundTransparency = 0.8, Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5) }) Corner(r, 100) SmoothTween(r, { Size = UDim2.new(1, 0, 2, 0), BackgroundTransparency = 1 }, 0.3) task.wait(0.3) r:Destroy() if cb then cb() end end) return btn end
local function MakeToggle(parent, text, default, cb) local row = Create("Frame", parent, { LayoutOrder = GetOrder(), Size = UDim2.new(0, 340, 0, 40), BackgroundColor3 = C.Panel }) Corner(row, 8) Create("TextLabel", row, { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 14, 0, 0), BackgroundTransparency = 1, Text = text, TextColor3 = C.Text, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }) local trk = Create("Frame", row, { Size = UDim2.new(0, 44, 0, 22), Position = UDim2.new(1, -54, 0.5, -11), BackgroundColor3 = default and Color3.fromRGB(255,255,255) or Color3.fromRGB(50,50,65) }) Corner(trk, 12) local trkGrad = AddGradient(trk) trkGrad.Enabled = default local knb = Create("Frame", trk, { Size = UDim2.new(0, 18, 0, 18), Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9), BackgroundColor3 = default and C.BG or C.Text }) Corner(knb, 10) local s = default or false local btn = Create("TextButton", row, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "" }) btn.MouseButton1Click:Connect(function() s = not s trkGrad.Enabled = s SmoothTween(knb, { Position = s and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9), BackgroundColor3 = s and C.BG or C.Text }, 0.2) SmoothTween(trk, { BackgroundColor3 = s and Color3.fromRGB(255,255,255) or Color3.fromRGB(50,50,65) }, 0.2) if cb then cb(s) end end) return btn end
local function MakeInput(parent, label, placeholder, cb) local frame = Create("Frame", parent, { LayoutOrder = GetOrder(), Size = UDim2.new(0, 340, 0, 36), BackgroundColor3 = C.Panel }) Corner(frame, 8) Create("TextLabel", frame, { Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = label, TextColor3 = C.Text, Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }) local tb = Create("TextBox", frame, { Size = UDim2.new(0.45, -10, 0.8, 0), Position = UDim2.new(0.5, 0, 0.1, 0), PlaceholderText = placeholder, Text = "", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.Text, BackgroundColor3 = Color3.fromRGB(40, 40, 45) }) Corner(tb, 6) tb.FocusLost:Connect(function() if cb then cb(tb.Text or "") end end) return tb end
local function MakeSlider(parent, label, minV, maxV, defaultV, callback) local frame = Create("Frame", parent, { LayoutOrder = GetOrder(), Size = UDim2.new(0, 340, 0, 48), BackgroundColor3 = C.Panel }) Corner(frame, 8) Create("TextLabel", frame, { Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 0, 6), BackgroundTransparency = 1, Text = label, TextColor3 = C.Text, Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left }) local bar = Create("Frame", frame, { Size = UDim2.new(0, 300, 0, 12), Position = UDim2.new(0, 20, 0, 26), BackgroundColor3 = Color3.fromRGB(50, 50, 65) }) Corner(bar, 6) local rel = (defaultV - minV) / (maxV - minV) local fill = Create("Frame", bar, { Size = UDim2.new(rel, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(0, 200, 150) }) Corner(fill, 6) local handle = Create("Frame", bar, { Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(rel, -6, 0, 0), BackgroundColor3 = Color3.fromRGB(245, 245, 250) }) Corner(handle, 20) local valLabel = Create("TextLabel", frame, { Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -70, 0, 6), BackgroundTransparency = 1, Text = tostring(defaultV), TextColor3 = C.Text, Font = Enum.Font.Gotham, TextSize = 12 }) local dragging = false local function updateFromPos(x) local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1) fill.Size = UDim2.new(rel, 0, 1, 0) handle.Position = UDim2.new(rel, -6, 0, 0) local v = math.floor(minV + rel * (maxV - minV)) valLabel.Text = tostring(v) if callback then callback(v) end end handle.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end) handle.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end) bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then updateFromPos(i.Position.X) dragging = true end end) UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then updateFromPos(i.Position.X) end end) return frame, valLabel end

-- =========================
-- BUILD UI
-- =========================
-- T_Stats
MakeTitle(T_Stats, "THÔNG SỐ HỆ THỐNG")
local stFrame = Create("Frame", T_Stats, { LayoutOrder = GetOrder(), Size = UDim2.new(0, 340, 0, 36), BackgroundColor3 = C.Panel }) Corner(stFrame, 8)
local stFPS = Create("TextLabel", stFrame, { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = C.Text, Font = Enum.Font.GothamBold, TextSize = 13 })
local stPing = Create("TextLabel", Create("Frame", T_Stats, { LayoutOrder = GetOrder(), Size = UDim2.new(0, 340, 0, 36), BackgroundColor3 = C.Panel }), { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, TextColor3 = C.Text, Font = Enum.Font.GothamBold, TextSize = 13 }) Corner(stPing.Parent, 8)
Track(RunService.Heartbeat:Connect(function() stFPS.Text = " 🖥 FPS Hiện Tại: " .. CurrentFPS stPing.Text = " 📡 Độ Trễ (Ping): " .. GetPing() .. " ms" end))
MakeBtn(T_Stats, "🚀 Tối Ưu Mạng & Giảm Delay", function() for _, v in ipairs(Workspace:GetDescendants()) do if v.Name == "Debris" or (v:IsA("Tool") and not v.Parent:FindFirstChild("Humanoid")) then pcall(function() v:Destroy() end) end end end)
MakeToggle(T_Stats, "Hiện FPS Mini", false, function(v) if _G.NF then _G.NF.Enabled = v end end)

-- T_Boost
MakeTitle(T_Boost, "CHỈNH ĐỒ HỌA MỨC %")
MakeBtn(T_Boost, "Khôi Phục Gốc (0%)", function() SetLowSpec(false, 0) end)
MakeBtn(T_Boost, "Tắt Bóng Đổ (25%)", function() ApplyBoost(25) end)
MakeBtn(T_Boost, "Tắt Sương, Bầu Trời (75%)", function() ApplyBoost(75) end)
MakeBtn(T_Boost, "Chế Độ Low-Poly (100%)", function() ApplyBoost(100) end)
MakeToggle(T_Boost, "🔻 LowFly Mode", false, function(v) SetLowSpec(v, 100) end)

-- T_ESP
MakeTitle(T_ESP, "🔥 AIMBOT & ESP")
MakeToggle(T_ESP, "🤝 Bỏ Qua Đồng Đội", true, function(v) IgnoreTeammates = v end)
MakeToggle(T_ESP, "👤 Aimbot PvP (Auto)", false, function(v) PlayerAimbotOn = v UpdateAimbotState() end)
MakeToggle(T_ESP, "🤖 Aimbot Auto (NPC)", false, function(v) AutoAimbotOn = v UpdateAimbotState() end)

MakeTitle(T_ESP, "🎯 AIMBOT THỦ CÔNG")
MakeToggle(T_ESP, "Aimbot Player (Manual)", false, function(v) ManualPlayerAimbotOn = v UpdateAimbotState() end)
MakeInput(T_ESP, "Tên NPC / Dummy", "ví dụ: dummy, zombi", function(txt) SelectedTargetName = txt end)
MakeToggle(T_ESP, "Aimbot NPC (Theo tên)", false, function(v) ManualNPCAimbotOn = v UpdateAimbotState() end)

MakeTitle(T_ESP, "🌐 ESP MODES")
MakeBtn(T_ESP, "Bật ESP: NPC / Dummy", function() ESPNPCOnly = true ESPPlayerOn = false StartESP() end)
MakeBtn(T_ESP, "Bật ESP: Player", function() ESPPlayerOn = true ESPNPCOnly = false StartESP() end)
MakeBtn(T_ESP, "Tắt ESP", function() StopESP() end)
MakeToggle(T_ESP, "📦 Hiện Hộp 3D", true, function(v) ESPBoxOn = v end)
MakeToggle(T_ESP, "✨ Hiện Ánh Sáng", true, function(v) ESPHighlightOn = v end)
MakeToggle(T_ESP, "Tên & Khoảng Cách", true, function(v) ESPNameOn = v ESPDistOn = v end)

MakeTitle(T_ESP, "TẦM & MỞ RỘNG VŨ KHÍ CỦA BẠN (REACH)")
local _, reachVal = MakeSlider(T_ESP, "Tầm Nhắm Aimbot (m)", ReachMin, ReachMax, ReachRange, function(v) ReachRange = v end)
local _, hitVal = MakeSlider(T_ESP, "Độ To Của Vũ Khí/Tay", 1, 100, HitboxSize.X, function(v) HitboxSize = Vector3.new(v, v, v) end)
MakeToggle(T_ESP, "🟠 Bật Đánh Xa (Weapon Reach)", false, function(v) HitboxExpandOn = v UpdateHitbox() end)

-- T_Vis
MakeTitle(T_Vis, "TÙY CHỈNH THẾ GIỚI")
MakeToggle(T_Vis, "Sáng Hoàn Toàn", false, function(v) Lighting.Brightness = v and 5 or Original.Brightness Lighting.GlobalShadows = not v Lighting.ClockTime = v and 14 or Original.ClockTime end)
MakeToggle(T_Vis, "Xóa Sương Mù", false, function(v) Lighting.FogEnd = v and 100000 or Original.FogEnd end)

-- T_Util
MakeTitle(T_Util, "HỖ TRỢ & EVADE")
MakeToggle(T_Util, "Bật Chống Văng", false, function(v) if v then _G.AntiAFK = Track(LocalPlayer.Idled:Connect(function() pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end) end)) else if _G.AntiAFK then _G.AntiAFK:Disconnect() _G.AntiAFK = nil end end end)
MakeToggle(T_Util, "🏃 Auto Emote Dash", false, function(v) ToggleEmoteDash(v) end)
MakeToggle(T_Util, "💎 Auto Farm (Safe Spot)", false, function(v) ToggleAutoFarm(v) end)
MakeToggle(T_Util, "🏥 Auto Revive (Cứu Xa)", false, function(v) ToggleAutoRevive(v) end)

-- Hide UI
local HideGui = Create("ScreenGui", TargetGui, { DisplayOrder = 200 })
local HBtn = Create("TextButton", HideGui, { Size = UDim2.new(0, 85, 0, 28), AnchorPoint = Vector2.new(1,0), Position = UDim2.new(1, -10, 0, 10), BackgroundColor3 = C.Panel, Text = "👁 Ẩn UI", TextColor3 = C.Text, Font = Enum.Font.GothamBold, TextSize = 12 }) Corner(HBtn, 6)
HBtn.MouseButton1Click:Connect(function() UIVisible = not UIVisible Main.Visible = UIVisible HBtn.Text = UIVisible and "👁 Ẩn UI" or "✨ Hiện UI" end)
Track(UserInputService.InputBegan:Connect(function(i, g) if not g and i.KeyCode == Enum.KeyCode.RightShift then UIVisible = not UIVisible Main.Visible = UIVisible HBtn.Text = UIVisible and "👁 Ẩn UI" or "✨ Hiện UI" end end))

-- FPS mini
local FGui = Create("ScreenGui", TargetGui, { DisplayOrder = 150, Enabled = false }) _G.NF = FGui
local FF = Create("Frame", FGui, { Size = UDim2.new(0, 105, 0, 30), Position = UDim2.new(0, 10, 0, 10), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.2 }) Corner(FF, 8)
local FT = Create("TextLabel", FF, { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, TextColor3 = C.Text, Font = Enum.Font.GothamBlack, TextSize = 13 })
Track(RunService.Heartbeat:Connect(function() if FGui.Enabled then FT.Text = "⚡ " .. CurrentFPS .. " FPS" end end))

print("✅ Natsumi Lag v6.3 - ANTI-SIT BUG FIX loaded!")
