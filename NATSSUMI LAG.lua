-- ============================================================
-- NATSUMI HUB v6.10 - FPS OPTIMIZED (NO COMPRESSION)
-- Fix triệt để Hitbox trắng/xám, Ép nhỏ ESP Box, Chống kẹt xác
-- ============================================================

if not game:IsLoaded() then game.Loaded:Wait() end

-- =========================
-- SERVICES & TÀI NGUYÊN
-- =========================
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Original = {
    GlobalShadows = Lighting.GlobalShadows,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    QualityLevel = settings().Rendering.QualityLevel
}

-- Trạng thái ESP
local ESP_Player = false
local ESP_NPC = false
local ESP_Box = true
local ESP_Highlight = true
local ESP_BoxWidth = 1.2  -- Mặc định đã được thu siêu nhỏ
local ESP_BoxHeight = 2.5 -- Mặc định đã được thu gọn chiều cao
local ESP_Objects = {}

local TeamkillEnabled = false

-- Trạng thái Aimbot
local AimbotOn = false
local AimbotMode = "Player"
local AimbotTargetPlayer = "Tự Động Gần Nhất"
local AimbotTargetNPC = "Tự Động Gần Nhất"

local AutoFarmOn = false
local AutoReviveOn = false

-- Wallbang / Hitbox Địch
local HitboxPlayerOn = false
local HitboxNPCOn = false
local HitboxSize = 25

-- =========================
-- DIỆT VỆT TRẮNG (ACRYLIC BUG FIXER)
-- =========================
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            for _, gui in pairs(CoreGui:GetChildren()) do
                if gui:IsA("ScreenGui") and gui.Name ~= "NatsumiOverlay" then
                    for _, v in pairs(gui:GetDescendants()) do
                        if v.Name == "Acrylic" or v.Name == "BlurContext" or (v:IsA("Frame") and v.BackgroundTransparency > 0.01 and v.BackgroundTransparency < 1 and v.BackgroundColor3 == Color3.fromRGB(255, 255, 255)) then
                            v.BackgroundTransparency = 1
                            if v:IsA("ImageLabel") then v.ImageTransparency = 1 end
                        end
                    end
                end
            end
        end)
    end
end)

-- =========================
-- UI NÚT SKIBIDI & FPS (NGOÀI MÀN HÌNH)
-- =========================
local NatsumiGui = Instance.new("ScreenGui")
NatsumiGui.Name = "NatsumiOverlay"
NatsumiGui.Parent = CoreGui
NatsumiGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Parent = NatsumiGui
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Position = UDim2.new(0.05, 0, 0.15, 0)
ToggleBtn.Size = UDim2.new(0, 45, 0, 45)
ToggleBtn.Active = true
ToggleBtn.Draggable = true
ToggleBtn.Image = "http://www.roblox.com/asset/?id=97209899743108"

ToggleBtn.MouseButton1Click:Connect(function()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.End, false, game)
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.End, false, game)
end)

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Parent = NatsumiGui
FPSLabel.BackgroundTransparency = 1
FPSLabel.Position = UDim2.new(0, 10, 0, 10)
FPSLabel.Size = UDim2.new(0, 100, 0, 20)
FPSLabel.Font = Enum.Font.GothamBold
FPSLabel.TextSize = 14
FPSLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
FPSLabel.TextStrokeTransparency = 0.5
FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
FPSLabel.Visible = false

local frameCount, lastTime = 0, tick()
RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    if tick() - lastTime >= 1 then
        FPSLabel.Text = "FPS: " .. frameCount
        frameCount = 0
        lastTime = tick()
    end
end)

-- =========================
-- KIỂM TRA ĐỒNG ĐỘI (TEAMKILL CHECK)
-- =========================
local function IsEnemy(plr)
    if plr == LocalPlayer then return false end
    if TeamkillEnabled then return true end
    if plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then return false end
    return true
end

-- =========================
-- HỆ THỐNG BẮN XUYÊN TƯỜNG (FIX HỘP XÁM TRẮNG)
-- =========================
task.spawn(function()
    while task.wait(0.2) do
        -- Hitbox Player
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") then
                local root = plr.Character.HumanoidRootPart
                local hum = plr.Character.Humanoid
                
                -- Phải còn sống mới hiện Hitbox
                if hum.Health > 0 and HitboxPlayerOn and (TeamkillEnabled or IsEnemy(plr)) then
                    root.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                    root.Transparency = 1 -- FIX HỘP XÁM: Tàng hình 100%
                    root.CanCollide = false
                else
                    if root.Size.X > 5 then
                        root.Size = Vector3.new(2, 2, 1)
                        root.Transparency = 1
                    end
                end
            end
        end

        -- Hitbox NPC/Quái
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("HumanoidRootPart") and obj:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(obj) then
                local root = obj.HumanoidRootPart
                local hum = obj.Humanoid
                
                if hum.Health > 0 and HitboxNPCOn then
                    root.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                    root.Transparency = 1 -- FIX HỘP XÁM: Tàng hình 100%
                    root.CanCollide = false
                else
                    if root.Size.X > 5 then
                        root.Size = Vector3.new(2, 2, 1)
                        root.Transparency = 1
                    end
                end
            end
        end
    end
end)

-- =========================
-- HỆ THỐNG ESP (BOX + HIGHLIGHT)
-- =========================
local function CreateESP(model, isPlayer)
    if not model:FindFirstChild("HumanoidRootPart") then return end
    if ESP_Objects[model] then return end

    local color = Color3.fromRGB(255, 50, 50)
    if isPlayer then
        local plr = Players:GetPlayerFromCharacter(model)
        if plr and not IsEnemy(plr) then
            color = Color3.fromRGB(50, 255, 50)
        end
    end

    local root = model:FindFirstChild("HumanoidRootPart")

    local box = Instance.new("BoxHandleAdornment")
    box.Size = Vector3.new(ESP_BoxWidth, ESP_BoxHeight, ESP_BoxWidth)
    box.Adornee = root
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = color
    box.Transparency = 0.5
    box.Visible = ESP_Box
    box.Parent = CoreGui

    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = ESP_Highlight
    hl.Parent = model

    ESP_Objects[model] = { Box = box, Highlight = hl }

    model.AncestryChanged:Connect(function()
        if not model.Parent and ESP_Objects[model] then
            if ESP_Objects[model].Box then ESP_Objects[model].Box:Destroy() end
            if ESP_Objects[model].Highlight then ESP_Objects[model].Highlight:Destroy() end
            ESP_Objects[model] = nil
        end
    end)
end

local function ClearESP()
    for model, data in pairs(ESP_Objects) do
        if data.Box then data.Box:Destroy() end
        if data.Highlight then data.Highlight:Destroy() end
    end
    ESP_Objects = {}
end

-- Vòng lặp dọn dẹp xác chết & Cập nhật ESP
task.spawn(function()
    while task.wait(0.5) do
        if ESP_Player then
            for _, plr in pairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0 then
                    if TeamkillEnabled or IsEnemy(plr) then
                        CreateESP(plr.Character, true)
                    else
                        if ESP_Objects[plr.Character] then
                            ESP_Objects[plr.Character].Box:Destroy()
                            ESP_Objects[plr.Character].Highlight:Destroy()
                            ESP_Objects[plr.Character] = nil
                        end
                    end
                end
            end
        end

        if ESP_NPC then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                    if not Players:GetPlayerFromCharacter(obj) and obj.Humanoid.Health > 0 then
                        CreateESP(obj, false)
                    end
                end
            end
        end

        for model, data in pairs(ESP_Objects) do
            -- CHỐNG KẸT XÁC: Phải còn máu (Health > 0) thì mới hiển thị Box
            if model and model.Parent and model:FindFirstChild("Humanoid") and model.Humanoid.Health > 0 then
                if data.Box then 
                    data.Box.Visible = ESP_Box 
                    data.Box.Size = Vector3.new(ESP_BoxWidth, ESP_BoxHeight, ESP_BoxWidth)
                end
                if data.Highlight then data.Highlight.Enabled = ESP_Highlight end
            else
                if data.Box then data.Box:Destroy() end
                if data.Highlight then data.Highlight:Destroy() end
                ESP_Objects[model] = nil
            end
        end
    end
end)

-- =========================
-- HỆ THỐNG AIMBOT
-- =========================
RunService.RenderStepped:Connect(function()
    if not AimbotOn then return end

    local closestTarget = nil
    local shortestDistance = math.huge
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    
    if not myRoot then return end

    local function CheckTarget(model)
        if model and model:FindFirstChild("HumanoidRootPart") and model:FindFirstChild("Humanoid") and model.Humanoid.Health > 0 then
            local dist = (myRoot.Position - model.HumanoidRootPart.Position).Magnitude
            if dist < shortestDistance then
                shortestDistance = dist
                closestTarget = model.HumanoidRootPart
            end
        end
    end

    if AimbotMode == "Player" then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                if AimbotTargetPlayer == "Tự Động Gần Nhất" then
                    if TeamkillEnabled or IsEnemy(plr) then
                        CheckTarget(plr.Character)
                    end
                elseif plr.Name == AimbotTargetPlayer then
                    CheckTarget(plr.Character)
                end
            end
        end
    elseif AimbotMode == "NPC" then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(obj) then
                if AimbotTargetNPC == "Tự Động Gần Nhất" then
                    CheckTarget(obj)
                elseif obj.Name == AimbotTargetNPC then
                    CheckTarget(obj)
                end
            end
        end
    end

    if closestTarget and Camera then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, closestTarget.Position)
    end
end)

-- =========================
-- AUTO FARM & EVADE (V6.3)
-- =========================
task.spawn(function()
    while task.wait(0.5) do
        if AutoFarmOn then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = CFrame.new(root.Position.X, 300, root.Position.Z)
                root.Velocity = Vector3.new(0,0,0)
            end
        end

        if AutoReviveOn then
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
        end
    end
end)

-- =========================
-- GIẢM LAG ĐỒ HỌA (V6.3)
-- =========================
local SavedParts, SavedMeshes, SavedDecals = {}, {}, {}
local FLAT_COLOR = Color3.fromRGB(140, 140, 140)

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

local function ApplyBoost(level)
    if level == 0 then
        for o, d in pairs(SavedParts) do if o and o.Parent then pcall(function() o.Material = d.M o.Color = d.C o.CastShadow = d.S end) end end
        for o, d in pairs(SavedMeshes) do if o and o.Parent then pcall(function() o.TextureId = d end) end end
        for o, d in pairs(SavedDecals) do if o and o.Parent then pcall(function() o.Transparency = d end) end end
        SavedParts, SavedMeshes, SavedDecals = {}, {}, {}
        Lighting.GlobalShadows = Original.GlobalShadows
        Lighting.FogEnd = Original.FogEnd
        settings().Rendering.QualityLevel = Original.QualityLevel
    elseif level == 1 then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 900
    elseif level == 2 then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 350
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level02
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") then pcall(function() o.Enabled = false end) end
        end
    elseif level == 3 then
        for _, o in ipairs(Workspace:GetDescendants()) do FlattenObj(o) end
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 250
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end
end

-- =========================
-- KHỞI TẠO GIAO DIỆN FLUENT (THEME ĐEN)
-- =========================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Natsumi Hub",
    SubTitle = "v6.10 - FPS Clean UI",
    TabWidth = 140,
    Size = UDim2.fromOffset(480, 320),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.End
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat & Hack", Icon = "swords" }),
    Aim = Window:AddTab({ Title = "Aimbot", Icon = "crosshair" }),
    Util = Window:AddTab({ Title = "Farm & Lag", Icon = "wrench" }),
    Settings = Window:AddTab({ Title = "Cài Đặt", Icon = "settings" })
}

-- MỤC COMBAT & XUYÊN TƯỜNG
local WallbangSection = Tabs.Combat:AddSection("Bắn / Đánh Xuyên Tường (Wallbang)")
WallbangSection:AddToggle("T_WbPlayer", { Title = "Xuyên tường bắn Player", Default = false, Callback = function(v) HitboxPlayerOn = v end })
WallbangSection:AddToggle("T_WbNPC", { Title = "Xuyên tường bắn NPC/Quái", Default = false, Callback = function(v) HitboxNPCOn = v end })
WallbangSection:AddSlider("S_WbSize", { Title = "Kích Thước Xuyên Tường", Default = 25, Min = 5, Max = 100, Rounding = 1, Callback = function(v) HitboxSize = v end })

local ESPSection = Tabs.Combat:AddSection("Tùy Chỉnh ESP")
ESPSection:AddToggle("T_ESPPlayer", { Title = "Bật ESP Người Chơi", Default = false, Callback = function(v) ESP_Player = v if not v then ClearESP() end end })
ESPSection:AddToggle("T_ESPNPC", { Title = "Bật ESP Quái / NPC", Default = false, Callback = function(v) ESP_NPC = v if not v then ClearESP() end end })
ESPSection:AddToggle("T_Teamkill", { Title = "Bật Teamkill (Bắn/Nhìn Xuyên Cả Đồng đội)", Default = false, Callback = function(v) TeamkillEnabled = v end })
ESPSection:AddToggle("T_Box", { Title = "Hiện Hộp 3D ESP", Default = true, Callback = function(v) ESP_Box = v end })
ESPSection:AddToggle("T_Hl", { Title = "Hiện Viền Tàng Hình (Highlight)", Default = true, Callback = function(v) ESP_Highlight = v end })

-- SLIDER TÙY CHỈNH KÍCH THƯỚC HỘP ESP
ESPSection:AddSlider("S_ESPWidth", { Title = "Chiều rộng Hộp ESP", Default = 1.2, Min = 0.5, Max = 10, Rounding = 1, Callback = function(v) ESP_BoxWidth = v end })
ESPSection:AddSlider("S_ESPHeight", { Title = "Chiều cao Hộp ESP", Default = 2.5, Min = 0.5, Max = 10, Rounding = 1, Callback = function(v) ESP_BoxHeight = v end })

-- MỤC AIMBOT
local AimSection = Tabs.Aim:AddSection("Cấu Hình Khóa Mục Tiêu")
AimSection:AddToggle("T_Aim", { Title = "BẬT KHÓA MỤC TIÊU", Default = false, Callback = function(v) AimbotOn = v end })
AimSection:AddDropdown("AimType", { Title = "Chế độ nhắm", Values = {"Player", "NPC"}, Multi = false, Default = 1, Callback = function(v) AimbotMode = v end })

local PlayerList = {"Tự Động Gần Nhất"}
for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(PlayerList, p.Name) end end
local AimPlayerDrop = AimSection:AddDropdown("AimPlayerDrop", { Title = "Chọn Tên Player", Values = PlayerList, Multi = false, Default = 1, Callback = function(v) AimbotTargetPlayer = v end })
AimSection:AddButton({ Title = "Làm mới danh sách Player", Callback = function()
    local NewList = {"Tự Động Gần Nhất"}
    for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(NewList, p.Name) end end
    AimPlayerDrop:SetValues(NewList)
end})

local function GetNPCList()
    local hash = {}
    local list = {"Tự Động Gần Nhất"}
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChild("Humanoid") and not Players:GetPlayerFromCharacter(obj) then
            if not hash[obj.Name] then
                hash[obj.Name] = true
                table.insert(list, obj.Name)
            end
        end
    end
    return list
end

local AimNPCDrop = AimSection:AddDropdown("AimNPCDrop", { Title = "Chọn Tên Quái / NPC", Values = {"Tự Động Gần Nhất"}, Multi = false, Default = 1, Callback = function(v) AimbotTargetNPC = v end })
AimSection:AddButton({ Title = "Làm mới danh sách Quái/NPC", Callback = function()
    AimNPCDrop:SetValues(GetNPCList())
end})

-- TIỆN ÍCH & GIẢM LAG
local EvadeSection = Tabs.Util:AddSection("Treo Máy & Hỗ Trợ")
EvadeSection:AddToggle("T_EvadeFarm", { Title = "Auto Farm (Bay treo trên cao)", Default = false, Callback = function(v) AutoFarmOn = v end })
EvadeSection:AddToggle("T_EvadeRevive", { Title = "Auto Cứu Xa Đồng Đội", Default = false, Callback = function(v) AutoReviveOn = v end })

local LagSection = Tabs.Util:AddSection("Fix Lag V6.3")
LagSection:AddButton({ Title = "Khôi phục gốc (0%)", Callback = function() ApplyBoost(0) end })
LagSection:AddButton({ Title = "Tắt Bóng Đổ (25%)", Callback = function() ApplyBoost(1) end })
LagSection:AddButton({ Title = "Tắt Hiệu Ứng (75%)", Callback = function() ApplyBoost(2) end })
LagSection:AddButton({ Title = "Xóa Texture Đồ Họa (100%)", Callback = function() ApplyBoost(3) end })

-- CÀI ĐẶT
Tabs.Settings:AddToggle("T_FPS", { Title = "Bật thông số FPS trên góc", Default = false, Callback = function(v) FPSLabel.Visible = v end })

Fluent:Notify({ Title = "Natsumi Hub v6.10", Content = "Đã fix hộp trắng và tối ưu màn hình!", Duration = 5 })
