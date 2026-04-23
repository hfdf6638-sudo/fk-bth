local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:wait()
local humanoid = char:WaitForChild("Humanoid")
local uis = game:GetService("UserInputService")
local rs = game:GetService("RunService")
local ts = game:GetService("TweenService")
local ws = workspace
local cg = game:GetService("CoreGui")
local rep = game:GetService("ReplicatedStorage")
local cam = ws.CurrentCamera

-- المتغيرات العامة
local speed55 = false
local speedSteal = false
local spinbot = false
local autograb = false
local xrayon = false
local antirag = false
local floaton = false
local infjump = false

local target = nil
local floatConn = nil
local floatSpeed = 56.1
local vertSpeed = 35

local xrayOg = {}
local xrayConns = {}
local conns = {}

-- ============ ANTI RAGDOLL ============
local anti = {}
local antiMode = nil
local ragConns = {}
local charCache = {}

local blocked = {
    [Enum.HumanoidStateType.Ragdoll] = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Physics] = true,
    [Enum.HumanoidStateType.Dead] = true
}

local function cacheChar()
    local c = player.Character
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    local r = c:FindFirstChild("HumanoidRootPart")
    if not h or not r then return false end
    charCache = {
        char = c,
        hum = h,
        root = r
    }
    return true
end

local function killConns()
    for _, c in pairs(ragConns) do
        pcall(function() c:Disconnect() end)
    end
    ragConns = {}
end

local function isRagdoll()
    if not charCache.hum then return false end
    local s = charCache.hum:GetState()
    if s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown then
        return true
    end
    local et = player:GetAttribute("RagdollEndTime")
    if et then
        local n = ws:GetServerTimeNow()
        if (et - n) > 0 then
            return true
        end
    end
    return false
end

local function removeCons()
    if not charCache.char then return end
    for _, d in pairs(charCache.char:GetDescendants()) do
        if d:IsA("BallSocketConstraint") or (d:IsA("Attachment") and string.find(d.Name, "RagdollAttachment")) then
            pcall(function() d:Destroy() end)
        end
    end
end

local function forceExit()
    if not charCache.hum or not charCache.root then return end
    pcall(function()
        player:SetAttribute("RagdollEndTime", ws:GetServerTimeNow())
    end)
    if charCache.hum.Health > 0 then
        charCache.hum:ChangeState(Enum.HumanoidStateType.Running)
    end
    charCache.root.Anchored = false
    charCache.root.AssemblyLinearVelocity = Vector3.zero
end

local function antiLoop()
    while antiMode == "v1" and charCache.hum do
        task.wait()
        if isRagdoll() then
            removeCons()
            forceExit()
        end
    end
end

local function setupCam()
    if not charCache.hum then return end
    table.insert(ragConns, rs.RenderStepped:Connect(function()
        if antiMode ~= "v1" then return end
        local c = ws.CurrentCamera
        if c and charCache.hum and c.CameraSubject ~= charCache.hum then
            c.CameraSubject = charCache.hum
        end
    end))
end

local function onChar(c)
    task.wait(0.5)
    if not antiMode then return end
    if cacheChar() then
        if antiMode == "v1" then
            setupCam()
            task.spawn(antiLoop)
        end
    end
end

function anti.Enable(m)
    if m ~= "v1" then return end
    if antiMode == m then return end
    anti.Disable()
    if not cacheChar() then return end
    antiMode = m
    table.insert(ragConns, player.CharacterAdded:Connect(onChar))
    setupCam()
    task.spawn(antiLoop)
end

function anti.Disable()
    if not antiMode then return end
    antiMode = nil
    killConns()
    charCache = {}
end

-- ============ SPINBOT ============
local function spinOn(c)
    local hrp = c:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end
    for _, v in pairs(hrp:GetChildren()) do
        if v:IsA("BodyAngularVelocity") then
            v:Destroy()
        end
    end
    local bv = Instance.new("BodyAngularVelocity")
    bv.MaxTorque = Vector3.new(0, math.huge, 0)
    bv.AngularVelocity = Vector3.new(0, 40, 0)
    bv.Parent = hrp
end

local function spinOff(c)
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, v in pairs(hrp:GetChildren()) do
                if v:IsA("BodyAngularVelocity") then
                    v:Destroy()
                end
            end
        end
    end
end

-- ============ AUTO GRAB ============
local AnimalsData = nil
pcall(function()
    AnimalsData = require(rep:WaitForChild("Datas"):WaitForChild("Animals"))
end)

local animalCache = {}
local promptMem = {}
local stealMem = {}
local lastUid = nil
local lastPos = nil
local radius = 150
local stealing = false
local stealProg = 0
local curTarget = nil
local stealStart = 0
local stealConn = nil
local velConn = nil
local grabUI = nil
local progBar = nil
local dotsFolder = nil

local function hrp()
    local c = player.Character
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso")
end

local function isMyBase(n)
    local p = ws.Plots:FindFirstChild(n)
    if not p then return false end
    local s = p:FindFirstChild("PlotSign")
    if s then
        local y = s:FindFirstChild("YourBase")
        if y and y:IsA("BillboardGui") then
            return y.Enabled == true
        end
    end
    return false
end

local function scanPlot(p)
    if not p or not p:IsA("Model") then return end
    if isMyBase(p.Name) then return end
    local pods = p:FindFirstChild("AnimalPodiums")
    if not pods then return end
    for _, pod in pairs(pods:GetChildren()) do
        if pod:IsA("Model") and pod:FindFirstChild("Base") then
            local name = "Unknown"
            local spawn = pod.Base:FindFirstChild("Spawn")
            if spawn then
                for _, c in pairs(spawn:GetChildren()) do
                    if c:IsA("Model") and c.Name ~= "PromptAttachment" then
                        name = c.Name
                        if AnimalsData and AnimalsData[name] and AnimalsData[name].DisplayName then
                            name = AnimalsData[name].DisplayName
                        end
                        break
                    end
                end
            end
            table.insert(animalCache, {
                name = name,
                plot = p.Name,
                slot = pod.Name,
                pos = pod:GetPivot().Position,
                uid = p.Name .. "_" .. pod.Name,
            })
        end
    end
end

local function setupScanner()
    task.wait(2)
    local plots = ws:WaitForChild("Plots", 10)
    if not plots then return end
    for _, p in pairs(plots:GetChildren()) do
        if p:IsA("Model") then
            scanPlot(p)
        end
    end
    plots.ChildAdded:Connect(function(p)
        if p:IsA("Model") then
            task.wait(0.5)
            scanPlot(p)
        end
    end)
    task.spawn(function()
        while task.wait(5) do
            if autograb then
                animalCache = {}
                for _, p in pairs(plots:GetChildren()) do
                    if p:IsA("Model") then
                        scanPlot(p)
                    end
                end
            end
        end
    end)
end

local function findPrompt(d)
    if not d then return nil end
    local cached = promptMem[d.uid]
    if cached and cached.Parent then
        return cached
    end
    local p = ws.Plots:FindFirstChild(d.plot)
    if not p then return nil end
    local pods = p:FindFirstChild("AnimalPodiums")
    if not pods then return nil end
    local pod = pods:FindFirstChild(d.slot)
    if not pod then return nil end
    local b = pod:FindFirstChild("Base")
    if not b then return nil end
    local s = b:FindFirstChild("Spawn")
    if not s then return nil end
    local a = s:FindFirstChild("PromptAttachment")
    if not a then return nil end
    for _, pr in pairs(a:GetChildren()) do
        if pr:IsA("ProximityPrompt") then
            promptMem[d.uid] = pr
            return pr
        end
    end
    return nil
end

local function updateVel()
    local h = hrp()
    if not h then return end
    local cur = h.Position
    if lastPos then
        lastPos = cur
    else
        lastPos = cur
    end
end

local function shouldSteal(d)
    if not d or not d.pos then return false end
    local h = hrp()
    if not h then return false end
    return (h.Position - d.pos).Magnitude <= radius
end

local function buildCallbacks(p)
    if stealMem[p] then return end
    local data = {hold = {}, trig = {}, ready = true}
    local ok, c = pcall(getconnections, p.PromptButtonHoldBegan)
    if ok and type(c) == "table" then
        for _, con in pairs(c) do
            if type(con.Function) == "function" then
                table.insert(data.hold, con.Function)
            end
        end
    end
    local ok2, c2 = pcall(getconnections, p.Triggered)
    if ok2 and type(c2) == "table" then
        for _, con in pairs(c2) do
            if type(con.Function) == "function" then
                table.insert(data.trig, con.Function)
            end
        end
    end
    if #data.hold > 0 or #data.trig > 0 then
        stealMem[p] = data
    end
end

local function doSteal(p, d)
    local data = stealMem[p]
    if not data or not data.ready then return false end
    data.ready = false
    stealing = true
    stealProg = 0
    curTarget = d
    stealStart = tick()
    task.spawn(function()
        if #data.hold > 0 then
            for _, fn in pairs(data.hold) do
                task.spawn(fn)
            end
        end
        local st = tick()
        while tick() - st < 1.3 do
            stealProg = (tick() - st) / 1.3
            task.wait(0.05)
        end
        stealProg = 1
        if #data.trig > 0 then
            for _, fn in pairs(data.trig) do
                task.spawn(fn)
            end
        end
        task.wait(0.1)
        data.ready = true
        task.wait(0.3)
        stealing = false
        stealProg = 0
        curTarget = nil
    end)
    return true
end

local function attemptSteal(p, d)
    if not p or not p.Parent then return false end
    buildCallbacks(p)
    if not stealMem[p] then return false end
    return doSteal(p, d)
end

local function getNearest()
    local h = hrp()
    if not h then return nil end
    local n = nil
    local md = math.huge
    for _, d in pairs(animalCache) do
        if not isMyBase(d.plot) and d.pos then
            local dist = (h.Position - d.pos).Magnitude
            if dist < md then
                md = dist
                n = d
            end
        end
    end
    return n
end

local function setupGrabUI()
    if grabUI and grabUI.Parent then
        grabUI:Destroy()
    end
    grabUI = Instance.new("ScreenGui")
    grabUI.Name = "GrabUI"
    grabUI.ResetOnSpawn = false
    grabUI.Parent = player:WaitForChild("PlayerGui")
    
    local m = Instance.new("Frame")
    m.Size = UDim2.new(0, 280, 0, 24)
    m.Position = UDim2.new(0.5, -140, 1, -100)
    m.BackgroundColor3 = Color3.fromRGB(15, 0, 35)
    m.BackgroundTransparency = 0.15
    m.BorderSizePixel = 0
    m.Parent = grabUI
    
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = m
    
    local s = Instance.new("UIStroke")
    s.Thickness = 1.5
    s.Color = Color3.fromRGB(170, 0, 255)
    s.Transparency = 0.1
    s.Parent = m
    
    dotsFolder = Instance.new("Folder")
    dotsFolder.Parent = m
    
    for i = 1, 30 do
        local d = Instance.new("Frame")
        d.Size = UDim2.new(0, math.random(2,4), 0, math.random(2,4))
        d.Position = UDim2.new(math.random(), 0, math.random(), 0)
        d.BackgroundColor3 = Color3.fromRGB(200, 0, 255)
        d.BackgroundTransparency = math.random(40,80)/100
        d.BorderSizePixel = 0
        d.Parent = dotsFolder
        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(1,0)
        dc.Parent = d
        d:SetAttribute("Speed", math.random(3,15)/1000)
    end
    
    local pb = Instance.new("Frame")
    pb.Size = UDim2.new(0.92, 0, 0, 10)
    pb.Position = UDim2.new(0.04, 0, 0.5, -5)
    pb.BackgroundColor3 = Color3.fromRGB(30, 0, 60)
    pb.BackgroundTransparency = 0.3
    pb.BorderSizePixel = 0
    pb.Parent = m
    
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = pb
    
    progBar = Instance.new("Frame")
    progBar.Size = UDim2.new(0, 0, 1, 0)
    progBar.BackgroundColor3 = Color3.fromRGB(200, 0, 255)
    progBar.BorderSizePixel = 0
    progBar.Parent = pb
    
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = progBar
end

local function startGrab()
    autograb = true
    setupGrabUI()
    setupScanner()
    if stealConn then stealConn:Disconnect() end
    if velConn then velConn:Disconnect() end
    velConn = rs.Heartbeat:Connect(updateVel)
    stealConn = rs.Heartbeat:Connect(function()
        if not autograb then return end
        if stealing then return end
        local tar = getNearest()
        if not tar then return end
        if not shouldSteal(tar) then return end
        if lastUid ~= tar.uid then
            lastUid = tar.uid
        end
        local p = promptMem[tar.uid]
        if not p or not p.Parent then
            p = findPrompt(tar)
        end
        if p then
            attemptSteal(p, tar)
        end
    end)
end

local function stopGrab()
    autograb = false
    if stealConn then
        stealConn:Disconnect()
        stealConn = nil
    end
    if velConn then
        velConn:Disconnect()
        velConn = nil
    end
    if grabUI then
        grabUI:Destroy()
        grabUI = nil
    end
    progBar = nil
    dotsFolder = nil
    animalCache = {}
    promptMem = {}
    stealMem = {}
end

-- ============ FLOAT NEAREST ============
local function startFloat()
    floaton = true
    if floatConn then floatConn:Disconnect() end
    floatConn = rs.Heartbeat:Connect(function()
        if not floaton then return end
        local c = player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local np = nil
        local nd = math.huge
        for _, p in pairs(game.Players:GetPlayers()) do
            if p ~= player and p.Character then
                local oh = p.Character:FindFirstChild("HumanoidRootPart")
                if oh then
                    local d = (h.Position - oh.Position).Magnitude
                    if d < nd then
                        nd = d
                        np = p
                    end
                end
            end
        end
        if np and np.Character then
            local th = np.Character:FindFirstChild("HumanoidRootPart")
            if th then
                target = np
                local dir = (th.Position - h.Position).Unit
                local hd = th.Position.Y - h.Position.Y
                local hv = dir * floatSpeed
                local vv = 0
                if hd > 2 then
                    vv = vertSpeed
                elseif hd < -2 then
                    vv = -vertSpeed * 0.5
                end
                h.AssemblyLinearVelocity = Vector3.new(hv.X, vv, hv.Z)
            end
        else
            h.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            target = nil
        end
    end)
end

local function stopFloat()
    floaton = false
    target = nil
    if floatConn then
        floatConn:Disconnect()
        floatConn = nil
    end
    local c = player.Character
    if c then
        local h = c:FindFirstChild("HumanoidRootPart")
        if h then
            h.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        end
    end
end

-- ============ X-RAY ============
local function xrayToggle(e)
    xrayon = e
    local function isBase(o)
        if not (o:IsA("BasePart") or o:IsA("MeshPart") or o:IsA("UnionOperation")) then
            return false
        end
        local n = o.Name:lower()
        local p = o.Parent and o.Parent.Name:lower() or ""
        return string.find(n, "base") or string.find(n, "claim") or string.find(p, "base") or string.find(p, "claim")
    end
    if e then
        for _, c in pairs(xrayConns) do
            if c then c:Disconnect() end
        end
        xrayConns = {}
        xrayOg = {}
        for _, o in pairs(ws:GetDescendants()) do
            if isBase(o) then
                xrayOg[o] = o.LocalTransparencyModifier
                o.LocalTransparencyModifier = 0.8
            end
        end
        table.insert(xrayConns, ws.DescendantAdded:Connect(function(o)
            if isBase(o) then
                xrayOg[o] = o.LocalTransparencyModifier
                o.LocalTransparencyModifier = 0.8
            end
        end))
        table.insert(xrayConns, player.CharacterAdded:Connect(function()
            task.wait(0.5)
            for _, o in pairs(ws:GetDescendants()) do
                if isBase(o) then
                    if not xrayOg[o] then
                        xrayOg[o] = o.LocalTransparencyModifier
                    end
                    o.LocalTransparencyModifier = 0.8
                end
            end
        end))
    else
        for o, t in pairs(xrayOg) do
            if o and o.Parent then
                pcall(function() o.LocalTransparencyModifier = t end)
            end
        end
        for _, c in pairs(xrayConns) do
            if c then c:Disconnect() end
        end
        xrayConns = {}
        xrayOg = {}
    end
end

-- ============ SPEED & INF JUMP ============
-- القفز اللانهائي
uis.JumpRequest:Connect(function()
    if infjump and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = player.Character.HumanoidRootPart
        hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 52, hrp.AssemblyLinearVelocity.Z)
    end
end)

-- السرعة
rs.Heartbeat:Connect(function()
    local c = player.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    
    local carry = false
    local a = h:FindFirstChildOfClass("Animator")
    if a then
        for _, t in pairs(a:GetPlayingAnimationTracks()) do
            if string.find(t.Animation.AnimationId, "71186871415348") then
                carry = true
                if speed55 then speed55 = false end
                break
            end
        end
    end
    
    if h.MoveDirection.Magnitude > 0 then
        local vel = (carry and speedSteal and 27) or (speed55 and 55) or 0
        if vel > 0 then
            r.AssemblyLinearVelocity = Vector3.new(h.MoveDirection.X * vel, r.AssemblyLinearVelocity.Y, h.MoveDirection.Z * vel)
        end
    end
end)

-- ============ إنشاء الواجهة ============
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VinomGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 480)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- توهج أزرق
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local shadow = Instance.new("UIStroke")
shadow.Color = Color3.fromRGB(0, 200, 255)
shadow.Thickness = 2
shadow.Transparency = 0.2
shadow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
shadow.Parent = mainFrame

-- عنوان
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 45)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(0, 50, 150)
title.BackgroundTransparency = 0.3
title.Text = "VINOM HUB"
title.TextColor3 = Color3.fromRGB(0, 200, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 12)
titleCorner.Parent = title

-- ScrollingFrame للمحتوى
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -10, 1, -55)
scrollFrame.Position = UDim2.new(0, 5, 0, 50)
scrollFrame.BackgroundTransparency = 1
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 450)
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
scrollFrame.Parent = mainFrame

-- قسم السرعة
local speedSection = Instance.new("Frame")
speedSection.Size = UDim2.new(1, -20, 0, 120)
speedSection.Position = UDim2.new(0, 10, 0, 10)
speedSection.BackgroundColor3 = Color3.fromRGB(0, 30, 60)
speedSection.BackgroundTransparency = 0.5
speedSection.BorderSizePixel = 0
speedSection.Parent = scrollFrame

local speedCorner = Instance.new("UICorner")
speedCorner.CornerRadius = UDim.new(0, 8)
speedCorner.Parent = speedSection

local speedTitle = Instance.new("TextLabel")
speedTitle.Size = UDim2.new(1, 0, 0, 25)
speedTitle.Position = UDim2.new(0, 0, 0, 0)
speedTitle.BackgroundTransparency = 1
speedTitle.Text = "⚡ السرعة"
speedTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
speedTitle.TextSize = 14
speedTitle.Font = Enum.Font.GothamBold
speedTitle.Parent = speedSection

-- زر Speed 55
local speed55Btn = Instance.new("TextButton")
speed55Btn.Size = UDim2.new(0.9, 0, 0, 30)
speed55Btn.Position = UDim2.new(0.05, 0, 0.25, 0)
speed55Btn.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
speed55Btn.Text = "سرعة 55 (بدون سرقة)"
speed55Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
speed55Btn.TextSize = 12
speed55Btn.Font = Enum.Font.Gotham
speed55Btn.Parent = speedSection

local speed55Corner = Instance.new("UICorner")
speed55Corner.CornerRadius = UDim.new(0, 6)
speed55Corner.Parent = speed55Btn

-- زر Speed Steal
local speedStealBtn = Instance.new("TextButton")
speedStealBtn.Size = UDim2.new(0.9, 0, 0, 30)
speedStealBtn.Position = UDim2.new(0.05, 0, 0.6, 0)
speedStealBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
speedStealBtn.Text = "سرعة 27 (مع السرقة)"
speedStealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
speedStealBtn.TextSize = 12
speedStealBtn.Font = Enum.Font.Gotham
speedStealBtn.Parent = speedSection

local speedStealCorner = Instance.new("UICorner")
speedStealCorner.CornerRadius = UDim.new(0, 6)
speedStealCorner.Parent = speedStealBtn

-- قسم المقاتلة
local combatSection = Instance.new("Frame")
combatSection.Size = UDim2.new(1, -20, 0, 120)
combatSection.Position = UDim2.new(0, 10, 0, 140)
combatSection.BackgroundColor3 = Color3.fromRGB(0, 30, 60)
combatSection.BackgroundTransparency = 0.5
combatSection.BorderSizePixel = 0
combatSection.Parent = scrollFrame

local combatCorner = Instance.new("UICorner")
combatCorner.CornerRadius = UDim.new(0, 8)
combatCorner.Parent = combatSection

local combatTitle = Instance.new("TextLabel")
combatTitle.Size = UDim2.new(1, 0, 0, 25)
combatTitle.Position = UDim2.new(0, 0, 0, 0)
combatTitle.BackgroundTransparency = 1
combatTitle.Text = "⚔️ المقاتلة"
combatTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
combatTitle.TextSize = 14
combatTitle.Font = Enum.Font.GothamBold
combatTitle.Parent = combatSection

-- زر Spinbot
local spinbotBtn = Instance.new("TextButton")
spinbotBtn.Size = UDim2.new(0.9, 0, 0, 30)
spinbotBtn.Position = UDim2.new(0.05, 0, 0.25, 0)
spinbotBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
spinbotBtn.Text = "تفعيل Spinbot"
spinbotBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
spinbotBtn.TextSize = 12
spinbotBtn.Font = Enum.Font.Gotham
spinbotBtn.Parent = combatSection

local spinbotCorner = Instance.new("UICorner")
spinbotCorner.CornerRadius = UDim.new(0, 6)
spinbotCorner.Parent = spinbotBtn

-- زر Float
local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0.9, 0, 0, 30)
floatBtn.Position = UDim2.new(0.05, 0, 0.6, 0)
floatBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
floatBtn.Text = "تفعيل الطفو (Float)"
floatBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
floatBtn.TextSize = 12
floatBtn.Font = Enum.Font.Gotham
floatBtn.Parent = combatSection

local floatCorner = Instance.new("UICorner")
floatCorner.CornerRadius = UDim.new(0, 6)
floatCorner.Parent = floatBtn

-- قسم الحماية
local protectionSection = Instance.new("Frame")
protectionSection.Size = UDim2.new(1, -20, 0, 120)
protectionSection.Position = UDim2.new(0, 10, 0, 270)
protectionSection.BackgroundColor3 = Color3.fromRGB(0, 30, 60)
protectionSection.BackgroundTransparency = 0.5
protectionSection.BorderSizePixel = 0
protectionSection.Parent = scrollFrame

local protectionCorner = Instance.new("UICorner")
protectionCorner.CornerRadius = UDim.new(0, 8)
protectionCorner.Parent = protectionSection

local protectionTitle = Instance.new("TextLabel")
protectionTitle.Size = UDim2.new(1, 0, 0, 25)
protectionTitle.Position = UDim2.new(0, 0, 0, 0)
protectionTitle.BackgroundTransparency = 1
protectionTitle.Text = "🛡️ الحماية"
protectionTitle.TextColor3 = Color3.fromRGB(0, 200, 255)
protectionTitle.TextSize = 14
protectionTitle.Font = Enum.Font.GothamBold
protectionTitle.Parent = protectionSection

-- زر Anti Ragdoll
local antiRagBtn = Instance.new("TextButton")
antiRagBtn.Size = UDim2.new(0.9, 0, 0, 30)
antiRagBtn.Position = UDim2.new(0.05, 0, 0.25, 0)
antiRagBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
antiRagBtn.Text = "تفعيل منع السقوط (Anti Ragdoll)"
antiRagBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
antiRagBtn.TextSize = 12
antiRagBtn.Font = Enum.Font.Gotham
antiRagBtn.Parent = protectionSection

local antiRagCorner = Instance.new("UICorner")
antiRagCorner.CornerRadius = UDim.new(0, 6)
antiRagCorner.Parent = antiRagBtn

-- زر X-Ray
local xrayBtn = Instance.new("TextButton")
xrayBtn.Size = UDim2.new(0.9, 0, 0, 30)
xrayBtn.Position = UDim2.new(0.05, 0, 0.6, 0)
xrayBtn.BackgroundColor3 = Color3.fromRGB(0, 80, 200)
xrayBtn.Text = "تفعيل الرؤية (X-Ray)"
xrayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
xrayBtn.TextSize = 12
xrayBtn.Font = Enum.Font.Gotham
xrayBtn.Parent = protectionSection

local xrayCorner = Instance.new("UICorner")
xrayCorner.CornerRadius = UDim.new(0, 6)
xrayCorner.Parent = xrayBtn

-- قسم متنوع
local miscSection = Instance.new("Frame")
miscSection.Size = UDim2.new(1, -20, 0, 150)
miscSection.Position = UDim2.new(0, 10, 0, 400)
miscSection.BackgroundColor3 = Color3.fromRGB(0, 30, 60)
miscSection.BackgroundTransparency = 0.5
miscSection.BorderSizePixel = 0
miscSection.Parent = scrollFrame

local miscCorner = Instance.new("UICorner")
miscCorner.CornerRadius = UDim.new(0, 8)
miscCorner.Parent = miscSection

local miscTitle = Instance.new("TextLabel")
miscTitle.Size = UDim2.new(1, 0, 0, 