-- ============================================================
-- NATSUMI LAG CLIENT v5.2 - PREMIUM + ANTI INVISIBLE
-- (Giao diện Gradient Siêu Mượt + Tối ưu Network/Ping + Box Chống Tàng Hình)
-- ============================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players          = game:GetService("Players")
local Lighting         = game:GetService("Lighting")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

local TargetGui = LocalPlayer:WaitForChild("PlayerGui")
pcall(function() if gethui then TargetGui = gethui() elseif CoreGui then TargetGui = CoreGui end end)

local Original = {
    GlobalShadows = Lighting.GlobalShadows, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, QualityLevel = settings().Rendering.QualityLevel
}

local CurrentBoost, UIVisible, FPSVisible, CurrentFPS = 0, true, false, 0
local AllConns, ParticleConns, SavedParts, SavedMeshes, SavedDecals = {}, {}, {}, {}, {}
local TextureRemoved, FLAT_COLOR = false, Color3.fromRGB(140, 140, 140)

local ESPEnabled, ESPPlayerOn, ESPNameOn, ESPDistOn = false, false, true, true
local ESPObjects, ESPWatcher, ESPLoop = {}, nil, nil
local AimbotOn, SelectedMobName, AimTarget = false, "", nil
local AimScanConn, AimCamConn = nil, nil
local TargetCache = {}

local function Track(c) table.insert(AllConns, c) return c end

local fCount, lTime = 0, tick()
Track(RunService.RenderStepped:Connect(function()
    fCount = fCount + 1
    if tick() - lTime >= 0.5 then CurrentFPS = math.floor(fCount / (tick() - lTime)) fCount = 0 lTime = tick() end
end))
local function GetPing() local ok, v = pcall(function() return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() end) return ok and math.floor(v) or 0 end

-- ================== CHỨC NĂNG GIẢM LAG & PING ==================
local function OptimizePing()
    for _, v in ipairs(Workspace:GetChildren()) do
        if v.Name == "Debris" or (v:IsA("Tool") and not v.Parent:FindFirstChild("Humanoid")) then
            pcall(function() v:Destroy() end)
        end
    end
    for i=1, 5 do task.spawn(function() local a={} setmetatable(a,{__mode="v"}) end) end
end

local function SetParticles(on)
    for _, c in ipairs(ParticleConns) do c:Disconnect() end ParticleConns = {}
    for _, o in ipairs(Workspace:GetDescendants()) do if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") then o.Enabled = on end end
    if not on then table.insert(ParticleConns, Track(Workspace.DescendantAdded:Connect(function(o) if o:IsA("ParticleEmitter") or o:IsA("Fire") then o.Enabled = false end end))) end
end

local function SetPostFX(on)
    for _, e in ipairs(Lighting:GetChildren()) do if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect") then e.Enabled = on end end
end

local FlatWatcher = nil
local function FlattenObj(o)
    for _, p in ipairs(Players:GetPlayers()) do if p.Character and o:IsDescendantOf(p.Character) then return end end
    if o:IsA("BasePart") and not o:IsA("Terrain") then
        if not SavedParts[o] then SavedParts[o] = { M = o.Material, C = o.Color, S = o.CastShadow } end
        o.Material = Enum.Material.SmoothPlastic o.Color = FLAT_COLOR o.CastShadow = false
    elseif o:IsA("SpecialMesh") then
        if not SavedMeshes[o] then SavedMeshes[o] = o.TextureId end o.TextureId = ""
    elseif o:IsA("Texture") or o:IsA("Decal") then
        if not SavedDecals[o] then SavedDecals[o] = o.Transparency end o.Transparency = 1
    end
end

local function RemoveTextures()
    if TextureRemoved then return end TextureRemoved = true
    for _, o in ipairs(Workspace:GetDescendants()) do FlattenObj(o) end
    FlatWatcher = Track(Workspace.DescendantAdded:Connect(function(o) task.wait() FlattenObj(o) end))
end

local function RestoreTextures()
    if not TextureRemoved then return end TextureRemoved = false
    if FlatWatcher then FlatWatcher:Disconnect() FlatWatcher = nil end
    for o, d in pairs(SavedParts) do if o and o.Parent then o.Material = d.M o.Color = d.C o.CastShadow = d.S end end
    for o, d in pairs(SavedMeshes) do if o and o.Parent then o.TextureId = d end end
    for o, d in pairs(SavedDecals) do if o and o.Parent then o.Transparency = d end end
    SavedParts, SavedMeshes, SavedDecals = {}, {}, {}
end

local function ApplyBoost(level)
    RestoreTextures() SetParticles(true) SetPostFX(true)
    Lighting.GlobalShadows = Original.GlobalShadows Lighting.FogEnd = Original.FogEnd Lighting.FogStart = Original.FogStart settings().Rendering.QualityLevel = Original.QualityLevel CurrentBoost = 0
    if level >= 25 then Lighting.GlobalShadows = false Lighting.FogEnd = 900 settings().Rendering.QualityLevel = Enum.QualityLevel.Level04 CurrentBoost = 25 end
    if level >= 50 then SetParticles(false) Lighting.FogEnd = 600 settings().Rendering.QualityLevel = Enum.QualityLevel.Level02 CurrentBoost = 50 end
    if level >= 75 then SetPostFX(false) Lighting.FogEnd = 350 CurrentBoost = 75 end
    if level == 100 then RemoveTextures() Lighting.Brightness = 2 Lighting.ClockTime = 14 Lighting.FogEnd = 250 settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 CurrentBoost = 100 end
end

-- ================== ESP & AIMBOT (BOX CHỐNG TÀNG HÌNH & ÉP SÁNG) ==================
local function IsPlayerChar(m) for _, p in ipairs(Players:GetPlayers()) do if p.Character == m and p ~= LocalPlayer then return true end end return false end
local function IsNPC(m) return not IsPlayerChar(m) and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") end

local function AddESP(m)
    if ESPObjects[m] then return end 
    local root = m:FindFirstChild("HumanoidRootPart") 
    if not root then return end
    
    local isPlayer = IsPlayerChar(m)
    local espColor = isPlayer and Color3.fromRGB(50,255,50) or Color3.fromRGB(255,50,50)

    -- Ánh sáng viền (Có ép sáng người tàng hình)
    local hl = Instance.new("Highlight") 
    hl.FillColor = espColor 
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.FillTransparency = 0.4 
    hl.OutlineTransparency = 0 
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = m
    
    -- Khối hộp 3D dự phòng xuyên tường
    local box = Instance.new("BoxHandleAdornment")
    box.Size = Vector3.new(4, 5.5, 2)
    box.Adornee = root
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = espColor
    box.Transparency = 0.4
    box.Parent = TargetGui

    -- Tên và Khoảng cách
    local bb = Instance.new("BillboardGui") 
    bb.Adornee = root 
    bb.Size = UDim2.new(0,120,0,36) 
    bb.StudsOffset = Vector3.new(0,3.5,0) 
    bb.AlwaysOnTop = true 
    bb.MaxDistance = 500
    bb.Parent = TargetGui
    
    local nl = Instance.new("TextLabel", bb) 
    nl.Size = UDim2.new(1,0,0.55,0) 
    nl.BackgroundTransparency = 1 
    nl.Text = m.Name 
    nl.TextColor3 = Color3.fromRGB(255,255,255) 
    nl.TextSize = 13 
    nl.Font = Enum.Font.GothamBold 
    nl.TextStrokeTransparency = 0 
    nl.Visible = ESPNameOn
    
    local dl = Instance.new("TextLabel", bb) 
    dl.Size = UDim2.new(1,0,0.45,0) 
    dl.Position = UDim2.new(0,0,0.55,0) 
    dl.BackgroundTransparency = 1 
    dl.Text = "0m" 
    dl.TextColor3 = espColor
    dl.TextSize = 11 
    dl.Font = Enum.Font.Gotham 
    dl.Visible = ESPDistOn
    
    ESPObjects[m] = {HL=hl, BOX=box, BB=bb, NL=nl, DL=dl}
    m.AncestryChanged:Connect(function() 
        if not m.Parent and ESPObjects[m] then 
            pcall(function() hl:Destroy() box:Destroy() bb:Destroy() end) 
            ESPObjects[m] = nil 
        end 
    end)
end

local function ScanESP() for _, o in ipairs(Workspace:GetDescendants()) do if o:IsA("Model") and (IsNPC(o) or (ESPPlayerOn and IsPlayerChar(o))) then AddESP(o) end end end

local function StopESP() 
    ESPEnabled = false 
    for m, d in pairs(ESPObjects) do pcall(function() d.HL:Destroy() if d.BOX then d.BOX:Destroy() end d.BB:Destroy() end) end 
    ESPObjects = {} 
    if ESPWatcher then ESPWatcher:Disconnect() ESPWatcher=nil end 
    if ESPLoop then ESPLoop:Disconnect() ESPLoop=nil end 
end

local function StartESP()
    ESPEnabled = true ScanESP()
    ESPWatcher = Track(Workspace.DescendantAdded:Connect(function(o) if o:IsA("Model") then task.wait(0.5) if IsNPC(o) or (ESPPlayerOn and IsPlayerChar(o)) then AddESP(o) end end end))
    ESPLoop = Track(RunService.Heartbeat:Connect(function()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        for m, d in pairs(ESPObjects) do
            local hum = m:FindFirstChildOfClass("Humanoid") 
            local nRoot = m:FindFirstChild("HumanoidRootPart")
            
            if not m.Parent or not nRoot or (hum and hum.Health <= 0) then 
                pcall(function() d.HL:Destroy() if d.BOX then d.BOX:Destroy() end d.BB:Destroy() end) 
                ESPObjects[m] = nil 
                continue 
            end
            
            -- [MẸO ÉP ÁNH SÁNG HIỂN THỊ TRÊN NGƯỜI TÀNG HÌNH]
            if nRoot.Transparency == 1 then nRoot.Transparency = 0.99 end
            
            if myRoot and d.DL then d.DL.Text = math.floor((myRoot.Position - nRoot.Position).Magnitude).."m" d.DL.Visible = ESPDistOn end
            if d.NL then d.NL.Visible = ESPNameOn end
        end
    end))
end

local lastCacheUpdate = 0
local function ToggleAimbot(state)
    AimbotOn = state
    if not state then 
        if AimScanConn then AimScanConn:Disconnect() AimScanConn = nil end
        if AimCamConn then AimCamConn:Disconnect() AimCamConn = nil end
        AimTarget = nil return 
    end
    AimScanConn = Track(RunService.Heartbeat:Connect(function()
        if tick() - lastCacheUpdate > 1 then
            lastCacheUpdate = tick()
            local newCache = {}
            if SelectedMobName ~= "" then
                for _, o in ipairs(Workspace:GetDescendants()) do
                    if o:IsA("Model") and o.Name == SelectedMobName then
                        local r = o:FindFirstChild("HumanoidRootPart") local h = o:FindFirstChildOfClass("Humanoid")
                        if r and h and h.Health > 0 then table.insert(newCache, r) end
                    end
                end
            end
            TargetCache = newCache
        end
    end))
    AimCamConn = Track(RunService.RenderStepped:Connect(function()
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local nearestDist = 5000 local nearestTgt = nil
        for _, rootPart in ipairs(TargetCache) do
            if rootPart and rootPart.Parent then
                local h = rootPart.Parent:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    local d = (myRoot.Position - rootPart.Position).Magnitude
                    if d < nearestDist then nearestDist = d nearestTgt = rootPart end
                end
            end
        end
        AimTarget = nearestTgt
        if AimTarget and Workspace.CurrentCamera then
            Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame:Lerp(CFrame.new(Workspace.CurrentCamera.CFrame.Position, AimTarget.Position), 0.3)
        end
    end))
end

-- ================== GIAO DIỆN PREMIUM ==================
local MainGui = Instance.new("ScreenGui") MainGui.Name = "NatsumiLag" MainGui.ResetOnSpawn = false MainGui.DisplayOrder = 100 MainGui.Parent = TargetGui

local C = { 
    BG = Color3.fromRGB(15, 15, 20), Panel = Color3.fromRGB(24, 24, 30), Tab = Color3.fromRGB(30, 30, 38),
    Text = Color3.fromRGB(245, 245, 250), TextDim = Color3.fromRGB(130, 130, 150), 
    Grad1 = Color3.fromRGB(0, 255, 170), Grad2 = Color3.fromRGB(0, 170, 255)
}

local function SmoothTween(obj, props, time) TweenService:Create(obj, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play() end
local function Create(class, parent, props) local i = Instance.new(class, parent) for k,v in pairs(props or {}) do i[k]=v end return i end
local function Corner(p, r) Create("UICorner", p, {CornerRadius=UDim.new(0, r or 8)}) end
local function AddGradient(parent) 
    local g = Create("UIGradient", parent) 
    g.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, C.Grad1), ColorSequenceKeypoint.new(1, C.Grad2)}
    return g
end

local Main = Create("Frame", MainGui, {Size=UDim2.new(0,350,0,460), Position=UDim2.new(0.5,-175,0.5,-230), BackgroundColor3=C.BG, ClipsDescendants=true}) Corner(Main, 14)
local Outline = Create("UIStroke", Main, {Thickness=1.5}) AddGradient(Outline)

local drag, dStart, sPos Main.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=true dStart=i.Position sPos=Main.Position end end)
Main.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then local d=i.Position-dStart Main.Position=UDim2.new(sPos.X.Scale, sPos.X.Offset+d.X, sPos.Y.Scale, sPos.Y.Offset+d.Y) end end)
Main.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end end)

local TitleBar = Create("Frame", Main, {Size=UDim2.new(1,0,0,40), BackgroundColor3=C.Panel, BackgroundTransparency=0.5})
local TitleText = Create("TextLabel", TitleBar, {Size=UDim2.new(1,-80,1,0), Position=UDim2.new(0,16,0,0), BackgroundTransparency=1, Text="Natsumi Client v5.2", Font=Enum.Font.GothamBlack, TextSize=15, TextXAlignment=Enum.TextXAlignment.Left})
AddGradient(TitleText)

local CloseBtn = Create("TextButton", TitleBar, {Size=UDim2.new(0,28,0,28), Position=UDim2.new(1,-34,0.5,-14), BackgroundColor3=Color3.fromRGB(35,35,45), Text="✕", TextColor3=C.Text, Font=Enum.Font.GothamBold}) Corner(CloseBtn, 8)
CloseBtn.MouseButton1Click:Connect(function() SmoothTween(Main, {Size=UDim2.new(0,0,0,0)}, 0.3) task.wait(0.3) Main.Visible=false UIVisible=false end)

local TabBar = Create("Frame", Main, {Size=UDim2.new(1,0,0,36), Position=UDim2.new(0,0,0,40), BackgroundColor3=C.Panel}) Create("UIListLayout", TabBar, {FillDirection=Enum.FillDirection.Horizontal, HorizontalAlignment=Enum.HorizontalAlignment.Center, Padding=UDim.new(0,4)})
local Content = Create("Frame", Main, {Size=UDim2.new(1,0,1,-80), Position=UDim2.new(0,0,0,80), BackgroundColor3=C.BG})

local orderCounter = 0
local function GetOrder() orderCounter = orderCounter + 1 return orderCounter end

local tabs, tabBtns = {}, {}
local function MakeTab(name, icon)
    local sf = Create("ScrollingFrame", Content, {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, ScrollBarThickness=2, Visible=false, AutomaticCanvasSize=Enum.AutomaticSize.Y}) 
    Create("UIListLayout", sf, {Padding=UDim.new(0,8), HorizontalAlignment=Enum.HorizontalAlignment.Center, SortOrder=Enum.SortOrder.LayoutOrder}) 
    Create("UIPadding", sf, {PaddingTop=UDim.new(0,10), PaddingBottom=UDim.new(0,15)})
    
    local btn = Create("TextButton", TabBar, {Size=UDim2.new(0,62,1,-6), Position=UDim2.new(0,0,0,3), BackgroundColor3=C.Tab, Text=icon.."\n"..name, TextColor3=C.TextDim, Font=Enum.Font.GothamBold, TextSize=9}) Corner(btn, 6)
    
    btn.MouseButton1Click:Connect(function() 
        for i, s in pairs(tabs) do s.Visible=false SmoothTween(tabBtns[i], {BackgroundColor3=C.Tab, TextColor3=C.TextDim}, 0.2) end 
        sf.Visible=true 
        SmoothTween(btn, {BackgroundColor3=Color3.fromRGB(45,45,55), TextColor3=C.Text}, 0.2) 
    end)
    table.insert(tabs, sf) table.insert(tabBtns, btn) return sf
end

local function MakeTitle(parent, text) Create("TextLabel", parent, {LayoutOrder=GetOrder(), Size=UDim2.new(0,320,0,24), BackgroundTransparency=1, Text=text, TextColor3=C.TextDim, Font=Enum.Font.GothamBold, TextSize=11, TextXAlignment=Enum.TextXAlignment.Left}) end

local function MakeBtn(parent, text, cb)
    local btn = Create("TextButton", parent, {LayoutOrder=GetOrder(), Size=UDim2.new(0,320,0,36), BackgroundColor3=C.Panel, Text=text, TextColor3=C.Text, Font=Enum.Font.GothamBold, TextSize=12}) Corner(btn,8)
    btn.MouseEnter:Connect(function() SmoothTween(btn, {BackgroundColor3=Color3.fromRGB(40,40,50)}) end)
    btn.MouseLeave:Connect(function() SmoothTween(btn, {BackgroundColor3=C.Panel}) end)
    btn.MouseButton1Click:Connect(function() 
        local ripple = Create("Frame", btn, {BackgroundColor3=C.Text, BackgroundTransparency=0.8, Size=UDim2.new(0,0,0,0), Position=UDim2.new(0.5,0,0.5,0), AnchorPoint=Vector2.new(0.5,0.5)}) Corner(ripple, 100)
        SmoothTween(ripple, {Size=UDim2.new(1,0,2,0), BackgroundTransparency=1}, 0.3) task.wait(0.3) ripple:Destroy()
        if cb then cb() end 
    end) return btn
end

local function MakeToggle(parent, text, default, cb)
    local row = Create("Frame", parent, {LayoutOrder=GetOrder(), Size=UDim2.new(0,320,0,40), BackgroundColor3=C.Panel}) Corner(row,8)
    Create("TextLabel", row, {Size=UDim2.new(1,-70,1,0), Position=UDim2.new(0,14,0,0), BackgroundTransparency=1, Text=text, TextColor3=C.Text, Font=Enum.Font.GothamMedium, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left})
    local trk = Create("Frame", row, {Size=UDim2.new(0,44,0,22), Position=UDim2.new(1,-54,0.5,-11), BackgroundColor3=default and Color3.fromRGB(255,255,255) or Color3.fromRGB(50,50,65)}) Corner(trk,12)
    local trkGrad = AddGradient(trk) trkGrad.Enabled = default
    local knb = Create("Frame", trk, {Size=UDim2.new(0,18,0,18), Position=default and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9), BackgroundColor3=default and C.BG or C.Text}) Corner(knb,10)
    local s = default or false local btn = Create("TextButton", row, {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text=""})
    btn.MouseButton1Click:Connect(function() 
        s = not s trkGrad.Enabled = s
        SmoothTween(knb, {Position=s and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9), BackgroundColor3=s and C.BG or C.Text}, 0.2) 
        SmoothTween(trk, {BackgroundColor3=s and Color3.fromRGB(255,255,255) or Color3.fromRGB(50,50,65)}, 0.2) 
        if cb then cb(s) end 
    end)
end

local T_Stats = MakeTab("Trang Chủ", "🏠") local T_Boost = MakeTab("Giảm Lag", "⚡") local T_ESP = MakeTab("Combat", "🎯") local T_Vis = MakeTab("Bản Đồ", "🌍") local T_Util = MakeTab("Tiện Ích", "🛠")
tabs[1].Visible=true tabBtns[1].BackgroundColor3=Color3.fromRGB(45,45,55) tabBtns[1].TextColor3=C.Text

-- 1. TRANG CHỦ & TỐI ƯU
MakeTitle(T_Stats, "THÔNG SỐ HỆ THỐNG")
local stFPS = Create("TextLabel", Create("Frame", T_Stats, {LayoutOrder=GetOrder(), Size=UDim2.new(0,320,0,32), BackgroundColor3=C.Panel}), {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, TextColor3=C.Text, Font=Enum.Font.GothamBold, TextSize=13}) Corner(stFPS.Parent, 8)
local stPing = Create("TextLabel", Create("Frame", T_Stats, {LayoutOrder=GetOrder(), Size=UDim2.new(0,320,0,32), BackgroundColor3=C.Panel}), {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, TextColor3=C.Text, Font=Enum.Font.GothamBold, TextSize=13}) Corner(stPing.Parent, 8)
Track(RunService.Heartbeat:Connect(function() stFPS.Text=" 🖥 FPS Hiện Tại: "..CurrentFPS stPing.Text=" 📡 Độ Trễ (Ping): "..GetPing().." ms" end))
MakeTitle(T_Stats, "TỐI ƯU HÓA")
MakeBtn(T_Stats, "🚀 Tối Ưu Mạng & Giảm Delay (Clear Debris)", function() OptimizePing() end)
MakeToggle(T_Stats, "Hiện FPS Mini trên Màn Hình", false, function(v) FPSVisible=v if _G.NF then _G.NF.Enabled=v end end)

-- 2. TAB GIẢM LAG
MakeTitle(T_Boost, "CHỈNH ĐỒ HỌA MỨC %")
MakeBtn(T_Boost, "Khôi Phục Gốc (0%)", function() ApplyBoost(0) end) 
MakeBtn(T_Boost, "Tắt Bóng Đổ (25%)", function() ApplyBoost(25) end) 
MakeBtn(T_Boost, "Tắt Hiệu Ứng Skill/Mưa (50%)", function() ApplyBoost(50) end) 
MakeBtn(T_Boost, "Tắt Sương, Bầu Trời (75%)", function() ApplyBoost(75) end) 
MakeBtn(T_Boost, "Chế Độ Low-Poly (100%)", function() ApplyBoost(100) end)
MakeTitle(T_Boost, "ĐỔI MÀU LOW-POLY")
local colors = { {"Trắng Xám", Color3.fromRGB(200,200,200)}, {"Xanh Rêu", Color3.fromRGB(100,160,100)}, {"Màu Đất", Color3.fromRGB(200,185,155)}, {"Màu Đen Ám", Color3.fromRGB(30,30,35)} }
for _, c in ipairs(colors) do MakeBtn(T_Boost, c[1], function() FLAT_COLOR = c[2] if TextureRemoved then for o in pairs(SavedParts) do if o and o.Parent and o:IsA("BasePart") then SmoothTween(o, {Color=FLAT_COLOR}) end end end end) end

-- 3. TAB COMBAT
MakeTitle(T_ESP, "QUÉT MỤC TIÊU AIMBOT")
local SelectedLbl = Create("TextLabel", Create("Frame", T_ESP, {LayoutOrder=GetOrder(), Size=UDim2.new(0,320,0,28), BackgroundColor3=C.Panel}), {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="Mục tiêu: Đang Trống", TextColor3=C.Grad1, Font=Enum.Font.GothamBold, TextSize=13}) Corner(SelectedLbl.Parent, 8)
local MobListContainer = Create("Frame", T_ESP, {LayoutOrder=GetOrder(), Size=UDim2.new(0,320,0,140), BackgroundColor3=C.Panel}) Corner(MobListContainer, 8)
local MobScroll = Create("ScrollingFrame", MobListContainer, {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, ScrollBarThickness=3, AutomaticCanvasSize=Enum.AutomaticSize.Y}) 
Create("UIListLayout", MobScroll, {Padding=UDim.new(0,6), HorizontalAlignment=Enum.HorizontalAlignment.Center}) 
Create("UIPadding", MobScroll, {PaddingTop=UDim.new(0,8), PaddingBottom=UDim.new(0,8)})

MakeBtn(T_ESP, "🔍 Quét Toàn Bộ Map Tìm Quái/Boss", function()
    for _, c in ipairs(MobScroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local foundNames = {}
    for _, o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("Model") and o:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(o) then 
            local n = o.Name
            if not foundNames[n] then
                foundNames[n] = true
                local b = Create("TextButton", MobScroll, {Size=UDim2.new(0,290,0,32), BackgroundColor3=Color3.fromRGB(35,35,45), Text=n, TextColor3=C.Text, Font=Enum.Font.GothamMedium, TextSize=12}) Corner(b, 6)
                b.MouseButton1Click:Connect(function() SelectedMobName = n SelectedLbl.Text = "Mục tiêu: " .. n TargetCache = {} end)
            end
        end
    end
end)
MakeToggle(T_ESP, "🎯 Bật Khóa Mục Tiêu (Aimbot)", false, ToggleAimbot)
MakeTitle(T_ESP, "HIỂN THỊ XUYÊN TƯỜNG (ESP)")
MakeToggle(T_ESP, "Bật ESP (Có Box Chống Tàng Hình)", false, function(v) if v then StartESP() else StopESP() end end)
MakeToggle(T_ESP, "Hiển Thị Cả Người Chơi", false, function(v) ESPPlayerOn=v if ESPEnabled then StopESP() StartESP() end end)

-- 4. TAB BẢN ĐỒ
MakeTitle(T_Vis, "TÙY CHỈNH THẾ GIỚI")
MakeToggle(T_Vis, "Fullbright (Sáng Hoàn Toàn)", false, function(v) Lighting.Brightness = v and 5 or Original.Brightness Lighting.GlobalShadows = not v Lighting.ClockTime = v and 14 or Original.ClockTime end)
MakeToggle(T_Vis, "Xóa Sương Mù Bức Tử", false, function(v) Lighting.FogEnd = v and 9999 or Original.FogEnd Lighting.FogStart = v and 9998 or 0 end)
MakeToggle(T_Vis, "Tắt Ánh Sáng Chói Mắt", false, function(v) SetPostFX(not v) end)

-- 5. TAB TIỆN ÍCH
MakeTitle(T_Util, "HỖ TRỢ TREO MÁY")
MakeToggle(T_Util, "Bật Chống Văng (Anti-AFK)", false, function(v)
    if v then _G.AntiAFK = Track(LocalPlayer.Idled:Connect(function() VirtualUser:Button2Down(Vector2.new(0,0), Workspace.CurrentCamera.CFrame) task.wait(0.1) VirtualUser:Button2Up(Vector2.new(0,0), Workspace.CurrentCamera.CFrame) end))
    else if _G.AntiAFK then _G.AntiAFK:Disconnect() _G.AntiAFK = nil end end
end)
MakeTitle(T_Util, "PHÍM TẮT")
Create("TextLabel", T_Util, {LayoutOrder=GetOrder(), Size=UDim2.new(1,0,0,20), BackgroundTransparency=1, Text="Bấm [RightShift] trên phím để Ẩn/Hiện Menu", TextColor3=C.TextDim, Font=Enum.Font.GothamMedium, TextSize=11, TextXAlignment=Enum.TextXAlignment.Center})

-- NÚT ẨN UI (GÓC PHẢI)
local HideGui = Create("ScreenGui", TargetGui, {DisplayOrder=200})
local HBtn = Create("TextButton", HideGui, {Size=UDim2.new(0,85,0,28), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-10,0,10), BackgroundColor3=C.Panel, Text="👁 Ẩn UI", TextColor3=C.Text, Font=Enum.Font.GothamBold, TextSize=12}) Corner(HBtn,6) 
local HBtnStroke = Create("UIStroke", HBtn, {Thickness=1.5}) AddGradient(HBtnStroke)
HBtn.MouseButton1Click:Connect(function() 
    UIVisible = not UIVisible 
    if UIVisible then Main.Visible = true SmoothTween(Main, {Size=UDim2.new(0,350,0,460)}, 0.3) else SmoothTween(Main, {Size=UDim2.new(0,0,0,0)}, 0.3) task.wait(0.3) Main.Visible = false end
    HBtn.Text = UIVisible and "👁 Ẩn UI" or "✨ Hiện UI" 
end)
Track(UserInputService.InputBegan:Connect(function(i,g) if not g and i.KeyCode==Enum.KeyCode.RightShift then 
    UIVisible = not UIVisible 
    if UIVisible then Main.Visible = true SmoothTween(Main, {Size=UDim2.new(0,350,0,460)}, 0.3) else SmoothTween(Main, {Size=UDim2.new(0,0,0,0)}, 0.3) task.wait(0.3) Main.Visible = false end
    HBtn.Text = UIVisible and "👁 Ẩn UI" or "✨ Hiện UI" 
end end))

-- FPS MINI GÓC TRÁI
local FGui = Create("ScreenGui", TargetGui, {DisplayOrder=150, Enabled=false}) _G.NF = FGui
local FF = Create("Frame", FGui, {Size=UDim2.new(0,105,0,30), Position=UDim2.new(0,10,0,10), BackgroundColor3=C.Panel, BackgroundTransparency=0.2}) Corner(FF,8)
local FFStroke = Create("UIStroke", FF, {Thickness=1.5}) AddGradient(FFStroke)
local FT = Create("TextLabel", FF, {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, TextColor3=C.Text, Font=Enum.Font.GothamBlack, TextSize=13})
Track(RunService.Heartbeat:Connect(function() if FGui.Enabled then FT.Text="⚡ "..CurrentFPS.." FPS" end end))

LocalPlayer.AncestryChanged:Connect(function() for _, c in ipairs(AllConns) do if typeof(c)=="RBXScriptConnection" then c:Disconnect() end end pcall(function() MainGui:Destroy() HideGui:Destroy() FGui:Destroy() end) ApplyBoost(0) end)

Main.Size = UDim2.new(0,0,0,0) SmoothTween(Main, {Size=UDim2.new(0,350,0,460)}, 0.5)

print("✅ Natsumi Lag v5.2 (Perfect ESP) Loaded!")
