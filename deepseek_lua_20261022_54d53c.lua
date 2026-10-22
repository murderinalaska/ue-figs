-- Axiom's Hybrid NPC Slayer (v71 - Infinite Yield Freecam)
local repS = cloneref(game:GetService("ReplicatedStorage"))
local plrs = cloneref(game:GetService("Players"))
local runS = cloneref(game:GetService("RunService"))
local ws = cloneref(game:GetService("Workspace"))
local UIS = cloneref(game:GetService("UserInputService"))
local lplr = plrs.LocalPlayer
local httpS = game:GetService("HttpService")

local util, enum, FighterController, CameraController
pcall(function()
    util = require(repS.Modules.Utility)
    enum = require(repS.Modules.EnumLibrary)
    FighterController = require(lplr.PlayerScripts.Controllers.FighterController)
    CameraController = require(lplr.PlayerScripts.Controllers.CameraController)
end)

-- ==========================================
-- 0. CONFIG & FOLDER SETUP
-- ==========================================
getgenv().Config = {
    Enabled = true,
    AutoMode = true,
    ManualMode = "Orbit",
    Noclip = true,
    AutoPickup = true,
    MeleeExpand = true,
    BounceEnabled = true,
    PostAttackTeleport = false,
    SpinEnabled = true,
    UndergroundMode = false,
    FreecamEnabled = false,
    NPCScannerEnabled = true,
    TargetCycleTime = 0.3,
    OffsetFlipTime = 1.0,
    PostAttackDelay = 0.3,
    PostHideTime = 0.2,
    AboveHeight = 7,
    BelowDepth = 7,
    SpinRadius = 5,
    SpinSpeed = 3,
    UndergroundDepth = 7,
    FreecamSpeed = 100,
    HH2_FOV = 90,
    TargetFilterMode = "All",
    LiveOnly = true
}

getgenv().SelectedNPCs = {}
getgenv().AllKnownNPCs = {}
getgenv().NPCPriorities = {}
getgenv().StarredNPCs = {}
getgenv().LiveNPCs = {}
getgenv().ActiveESPs = {}

local ConfigDir = "tower"
pcall(function()
    if not isfolder(ConfigDir) then makefolder(ConfigDir) end
end)

local StarredFile = ConfigDir .. "/StarredNPCs.json"

local function LoadStarred()
    pcall(function()
        if isfile(StarredFile) then
            local decoded = httpS:JSONDecode(readfile(StarredFile))
            for _, name in ipairs(decoded) do
                getgenv().StarredNPCs[name] = true
            end
        end
    end)
end

local function SaveStarred()
    pcall(function()
        local list = {}
        for name, _ in pairs(getgenv().StarredNPCs) do
            table.insert(list, name)
        end
        writefile(StarredFile, httpS:JSONEncode(list))
    end)
end

LoadStarred()

local NPCTemplates = Instance.new("Folder")
NPCTemplates.Name = "AxiomNPCTemplates"
NPCTemplates.Parent = game.Workspace

-- ==========================================
-- SPIN HELPER
-- ==========================================
local function getSpinOffset(y_offset)
    if not getgenv().Config.SpinEnabled then return Vector3.zero end
    if not getgenv().Config.UndergroundMode and y_offset <= 0 then return Vector3.zero end
    
    local t = tick() * getgenv().Config.SpinSpeed
    local r = getgenv().Config.SpinRadius
    return Vector3.new(math.cos(t) * r, 0, math.sin(t) * r)
end

-- ==========================================
-- ESP UPDATE FUNCTION
-- ==========================================
local function UpdateESPColors()
    for npc, esp in pairs(getgenv().ActiveESPs) do
        if npc and npc.Parent then
            local priority = getgenv().NPCPriorities[npc.Name]
            if priority == "Green" then
                esp.FillColor = Color3.fromRGB(0, 255, 0)
                esp.OutlineColor = Color3.fromRGB(0, 255, 0)
            elseif priority == "Yellow" then
                esp.FillColor = Color3.fromRGB(255, 255, 0)
                esp.OutlineColor = Color3.fromRGB(255, 255, 0)
            elseif priority == "Red" then
                esp.FillColor = Color3.fromRGB(255, 0, 0)
                esp.OutlineColor = Color3.fromRGB(255, 0, 0)
            else
                esp.FillColor = Color3.fromRGB(255, 255, 255)
                esp.OutlineColor = Color3.fromRGB(255, 255, 255)
            end
        end
    end
end

-- ==========================================
-- INFINITE YIELD STYLE FREECAM
-- ==========================================
local fcEnabled = false
local fcConnection = nil
local fcPart = nil
local fcSpeed = 100 -- Base speed, can be adjusted

local function MoveCam()
    if fcConnection then fcConnection:Disconnect() end
    fcConnection = runS.RenderStepped:Connect(function(dt)
        if not fcEnabled or not fcPart or not fcPart.Parent then return end
        
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero
        
        if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        
        if moveDir.Magnitude > 0 then
            fcPart.CFrame = fcPart.CFrame + (moveDir.Unit * fcSpeed * dt)
        end
        
        -- Update mouse look
        local delta = UIS:GetMouseDelta()
        if delta.Magnitude > 0 then
            local sens = 0.003
            local rx, ry, rz = fcPart.CFrame:ToEulerAnglesYXZ()
            local newRx = math.clamp(rx - delta.Y * sens, -math.rad(89), math.rad(89))
            local newRy = ry - delta.X * sens
            fcPart.CFrame = CFrame.new(fcPart.Position) * CFrame.fromEulerAnglesYXZ(newRx, newRy, 0)
        end
    end)
end

local function ToggleFreecam()
    fcEnabled = not fcEnabled
    getgenv().Config.FreecamEnabled = fcEnabled
    
    if fcEnabled then
        -- Create the xFC part (Infinite Yield style)
        local char = lplr.Character
        if char and not char:FindFirstChild('xFC') then
            local fc = Instance.new('Part', char)
            fc.CanCollide = false
            fc.Anchored = true
            fc.Transparency = 1
            fc.Size = Vector3.new(1, 1, 1)
            fc.Name = 'xFC'
            fc.CFrame = char.Head.CFrame
            fcPart = fc
            
            local cam = workspace.CurrentCamera
            cam.CameraSubject = fc
            cam.CameraType = 'Custom'
            
            -- Disable character controls (IY style)
            local controls = lplr.PlayerScripts:FindFirstChild("ControlScript")
            if controls then controls.Disabled = true end
            
            MoveCam()
        end
    else
        -- Cleanup
        if fcConnection then fcConnection:Disconnect() end
        if fcPart then fcPart:Destroy() end
        
        local char = lplr.Character
        if char and char:FindFirstChild('xFC') then
            char:FindFirstChild('xFC'):Destroy()
        end
        
        local cam = workspace.CurrentCamera
        cam.CameraSubject = lplr.Character and lplr.Character:FindFirstChildWhichIsA("Humanoid")
        cam.CameraType = 'Custom'
        
        -- Re-enable controls
        local controls = lplr.PlayerScripts:FindFirstChild("ControlScript")
        if controls then controls.Disabled = false end
    end
    
    local uiBtn = UIElements and UIElements.Toggles and UIElements.Toggles["FreecamEnabled"]
    if uiBtn then
        uiBtn.BackgroundColor3 = fcEnabled and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
        local ind = uiBtn:FindFirstChild("Indicator")
        if ind then ind.BackgroundColor3 = fcEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0) end
    end
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Y then
        ToggleFreecam()
    elseif input.KeyCode == Enum.KeyCode.C then
        getgenv().Config.Enabled = not getgenv().Config.Enabled
        local uiBtn = UIElements and UIElements.Toggles and UIElements.Toggles["Enabled"]
        if uiBtn then
            uiBtn.BackgroundColor3 = getgenv().Config.Enabled and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
            local ind = uiBtn:FindFirstChild("Indicator")
            if ind then ind.BackgroundColor3 = getgenv().Config.Enabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0) end
        end
    end
end)

-- ==========================================
-- 1. MAIN GUI & TABS
-- ==========================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AxiomSlayer"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 320, 0, 700)
Main.Position = UDim2.new(0, 50, 0, 50)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Main.BorderSizePixel = 1
Main.BorderColor3 = Color3.fromRGB(200, 60, 60)
Main.Active = true
Main.Draggable = true
Main.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Title.BorderSizePixel = 0
Title.Text = "Axiom's Slayer (v71)"
Title.TextColor3 = Color3.fromRGB(255, 80, 80)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.Parent = Main

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, 0, 0, 25)
TabContainer.Position = UDim2.new(0, 0, 0, 30)
TabContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = Main

local MainTabBtn = Instance.new("TextButton")
MainTabBtn.Size = UDim2.new(0.5, -5, 1, 0)
MainTabBtn.Position = UDim2.new(0, 5, 0, 0)
MainTabBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
MainTabBtn.BorderSizePixel = 1
MainTabBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
MainTabBtn.Text = "Main Settings"
MainTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MainTabBtn.Font = Enum.Font.Gotham
MainTabBtn.TextSize = 12
MainTabBtn.Parent = TabContainer

local TargetTabBtn = Instance.new("TextButton")
TargetTabBtn.Size = UDim2.new(0.5, -5, 1, 0)
TargetTabBtn.Position = UDim2.new(0.5, 0, 0, 0)
TargetTabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
TargetTabBtn.BorderSizePixel = 1
TargetTabBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
TargetTabBtn.Text = "NPC Manager"
TargetTabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetTabBtn.Font = Enum.Font.Gotham
TargetTabBtn.TextSize = 12
TargetTabBtn.Parent = TabContainer

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -100)
Scroll.Position = UDim2.new(0, 10, 0, 60)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollBarThickness = 2
Scroll.ScrollBarImageColor3 = Color3.fromRGB(200, 60, 60)
Scroll.Parent = Main

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.Parent = Scroll

local TargetScroll = Instance.new("ScrollingFrame")
TargetScroll.Size = UDim2.new(1, -20, 1, -100)
TargetScroll.Position = UDim2.new(0, 10, 0, 60)
TargetScroll.BackgroundTransparency = 1
TargetScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TargetScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TargetScroll.ScrollBarThickness = 2
TargetScroll.ScrollBarImageColor3 = Color3.fromRGB(200, 60, 60)
TargetScroll.Visible = false
TargetScroll.Parent = Main

local TargetUIListLayout = Instance.new("UIListLayout")
TargetUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
TargetUIListLayout.Padding = UDim.new(0, 6)
TargetUIListLayout.Parent = TargetScroll

local function SwitchTab(tab)
    if tab == "Main" then
        Scroll.Visible = true
        TargetScroll.Visible = false
        MainTabBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
        TargetTabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    else
        Scroll.Visible = false
        TargetScroll.Visible = true
        MainTabBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        TargetTabBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
        BuildNPCList()
    end
end

MainTabBtn.MouseButton1Click:Connect(function() SwitchTab("Main") end)
TargetTabBtn.MouseButton1Click:Connect(function() SwitchTab("Targets") end)

-- ==========================================
-- MAIN TAB UI
-- ==========================================
local ModeButtons = {}
local UIElements = { Toggles = {}, Inputs = {} }

local function RefreshModeUI(activeMode)
    for mode, btn in pairs(ModeButtons) do
        if getgenv().Config.AutoMode then
            if mode == activeMode then
                btn.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
            else
                btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            end
        else
            if mode == getgenv().Config.ManualMode then
                btn.BackgroundColor3 = Color3.fromRGB(30, 80, 30)
            else
                btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            end
        end
    end
end

local function UpdateUIFromConfig()
    for name, btn in pairs(UIElements.Toggles) do
        local val = getgenv().Config[name]
        btn.BackgroundColor3 = val and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
        local ind = btn:FindFirstChild("Indicator")
        if ind then ind.BackgroundColor3 = val and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0) end
    end
    for name, box in pairs(UIElements.Inputs) do
        box.Text = tostring(getgenv().Config[name])
    end
    RefreshModeUI(getgenv().Config.ManualMode)
end

local function CreateToggle(name, default, parent)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = getgenv().Config[name] and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
    Btn.BorderSizePixel = 1
    Btn.BorderColor3 = Color3.fromRGB(100, 100, 100)
    Btn.Text = "   " .. name
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 13
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Parent = parent

    local Indicator = Instance.new("Frame")
    Indicator.Name = "Indicator"
    Indicator.Size = UDim2.new(0, 10, 0, 10)
    Indicator.Position = UDim2.new(1, -20, 0.5, -5)
    Indicator.BackgroundColor3 = getgenv().Config[name] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    Indicator.Parent = Btn

    UIElements.Toggles[name] = Btn

    Btn.MouseButton1Click:Connect(function()
        if name == "FreecamEnabled" then
            ToggleFreecam()
            return
        end
        
        getgenv().Config[name] = not getgenv().Config[name]
        Btn.BackgroundColor3 = getgenv().Config[name] and Color3.fromRGB(30, 60, 30) or Color3.fromRGB(60, 30, 30)
        Indicator.BackgroundColor3 = getgenv().Config[name] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        
        if name == "AutoMode" then
            if not getgenv().Config.AutoMode then
                getgenv().Config.ManualMode = "Orbit"
                RefreshModeUI("Orbit")
            else
                RefreshModeUI("")
            end
        end
    end)
end

CreateToggle("Enabled", true, Scroll)
CreateToggle("AutoMode", true, Scroll)
CreateToggle("Noclip", true, Scroll)
CreateToggle("AutoPickup", true, Scroll)
CreateToggle("MeleeExpand", true, Scroll)
CreateToggle("BounceEnabled", true, Scroll)
CreateToggle("PostAttackTeleport", false, Scroll)
CreateToggle("SpinEnabled", true, Scroll)
CreateToggle("UndergroundMode", false, Scroll)
CreateToggle("FreecamEnabled", false, Scroll)

local function CreateDivider(text, parent)
    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, 0, 0, 18)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = "── " .. text .. " ──"
    Lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    Lbl.Font = Enum.Font.GothamBold
    Lbl.TextSize = 11
    Lbl.Parent = parent
end

local function CreateNumberInput(name, callback, parent)
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 26)
    Row.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    Row.BorderSizePixel = 1
    Row.BorderColor3 = Color3.fromRGB(80, 80, 80)
    Row.Parent = parent

    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -85, 1, 0)
    Lbl.Position = UDim2.new(0, 8, 0, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Text = name
    Lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    Lbl.Font = Enum.Font.Gotham
    Lbl.TextSize = 12
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Parent = Row

    local Box = Instance.new("TextBox")
    Box.Size = UDim2.new(0, 70, 0, 20)
    Box.Position = UDim2.new(1, -78, 0.5, -10)
    Box.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    Box.BorderSizePixel = 1
    Box.BorderColor3 = Color3.fromRGB(200, 60, 60)
    Box.Text = tostring(getgenv().Config[name])
    Box.TextColor3 = Color3.fromRGB(255, 255, 255)
    Box.Font = Enum.Font.Gotham
    Box.TextSize = 12
    Box.ClearTextOnFocus = false
    Box.Parent = Row

    UIElements.Inputs[name] = Box

    Box.FocusLost:Connect(function()
        local num = tonumber(Box.Text)
        if num then getgenv().Config[name] = num else Box.Text = tostring(getgenv().Config[name]) end
    end)
end

CreateDivider("Settings", Scroll)
CreateNumberInput("TargetCycleTime", function(v) end, Scroll)
CreateNumberInput("OffsetFlipTime", function(v) end, Scroll)
CreateNumberInput("PostAttackDelay", function(v) end, Scroll)
CreateNumberInput("PostHideTime", function(v) end, Scroll)
CreateNumberInput("AboveHeight", function(v) end, Scroll)
CreateNumberInput("BelowDepth", function(v) end, Scroll)
CreateNumberInput("SpinRadius", function(v) end, Scroll)
CreateNumberInput("SpinSpeed", function(v) end, Scroll)
CreateNumberInput("UndergroundDepth", function(v) end, Scroll)
CreateNumberInput("FreecamSpeed", function(v) end, Scroll)
CreateNumberInput("HH2_FOV", function(v) end, Scroll)

-- Config System
CreateDivider("Configs", Scroll)
local ConfigRow = Instance.new("Frame")
ConfigRow.Size = UDim2.new(1, 0, 0, 28)
ConfigRow.BackgroundTransparency = 1
ConfigRow.Parent = Scroll

local ConfigNameBox = Instance.new("TextBox")
ConfigNameBox.Size = UDim2.new(1, -65, 1, 0)
ConfigNameBox.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
ConfigNameBox.BorderColor3 = Color3.fromRGB(200, 60, 60)
ConfigNameBox.BorderSizePixel = 1
ConfigNameBox.Text = "default"
ConfigNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
ConfigNameBox.Font = Enum.Font.Gotham
ConfigNameBox.TextSize = 12
ConfigNameBox.ClearTextOnFocus = false
ConfigNameBox.Parent = ConfigRow

local SaveBtn = Instance.new("TextButton")
SaveBtn.Size = UDim2.new(0, 60, 1, 0)
SaveBtn.Position = UDim2.new(1, -60, 0, 0)
SaveBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
SaveBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
SaveBtn.BorderSizePixel = 1
SaveBtn.Text = "Save"
SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SaveBtn.Font = Enum.Font.GothamBold
SaveBtn.TextSize = 12
SaveBtn.Parent = ConfigRow

local ConfigListFrame = Instance.new("Frame")
ConfigListFrame.Size = UDim2.new(1, 0, 0, 0)
ConfigListFrame.BackgroundTransparency = 1
ConfigListFrame.AutomaticSize = Enum.AutomaticSize.Y
ConfigListFrame.Parent = Scroll

local ConfigListLayout = Instance.new("UIListLayout")
ConfigListLayout.Padding = UDim.new(0, 4)
ConfigListLayout.Parent = ConfigListFrame

local function RefreshConfigList()
    for _, child in ipairs(ConfigListFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    pcall(function()
        local files = listfiles(ConfigDir)
        for _, file in ipairs(files) do
            local fileName = string.match(file, "[^/\\]+$")
            if fileName and fileName:find("%.json$") and fileName ~= "StarredNPCs.json" then
                local nameWithoutExt = string.gsub(fileName, "%.json$", "")
                
                local Row = Instance.new("Frame")
                Row.Size = UDim2.new(1, 0, 0, 24)
                Row.BackgroundTransparency = 1
                Row.Parent = ConfigListFrame

                local LoadBtn = Instance.new("TextButton")
                LoadBtn.Size = UDim2.new(1, -30, 1, 0)
                LoadBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
                LoadBtn.BorderSizePixel = 1
                LoadBtn.BorderColor3 = Color3.fromRGB(80, 80, 80)
                LoadBtn.Text = " " .. nameWithoutExt
                LoadBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
                LoadBtn.Font = Enum.Font.Gotham
                LoadBtn.TextSize = 12
                LoadBtn.TextXAlignment = Enum.TextXAlignment.Left
                LoadBtn.Parent = Row

                LoadBtn.MouseButton1Click:Connect(function()
                    local success, decoded = pcall(function()
                        return httpS:JSONDecode(readfile(ConfigDir .. "/" .. fileName))
                    end)
                    if success and decoded then
                        for k, v in pairs(decoded) do
                            if getgenv().Config[k] ~= nil then getgenv().Config[k] = v end
                        end
                        UpdateUIFromConfig()
                        ConfigNameBox.Text = nameWithoutExt
                    end
                end)

                local DelBtn = Instance.new("TextButton")
                DelBtn.Size = UDim2.new(0, 24, 1, 0)
                DelBtn.Position = UDim2.new(1, -24, 0, 0)
                DelBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
                DelBtn.BorderSizePixel = 1
                DelBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
                DelBtn.Text = "X"
                DelBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
                DelBtn.Font = Enum.Font.GothamBold
                DelBtn.TextSize = 12
                DelBtn.Parent = Row

                DelBtn.MouseButton1Click:Connect(function()
                    pcall(function()
                        delfile(ConfigDir .. "/" .. fileName)
                        RefreshConfigList()
                    end)
                end)
            end
        end
    end)
end

SaveBtn.MouseButton1Click:Connect(function()
    local name = ConfigNameBox.Text
    if name and name ~= "" then
        pcall(function()
            writefile(ConfigDir .. "/" .. name .. ".json", httpS:JSONEncode(getgenv().Config))
            RefreshConfigList()
        end)
    end
end)

RefreshConfigList()

CreateDivider("Modes", Scroll)

local function CreateModeButton(modeName)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, 0, 0, 30)
    Btn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Btn.BorderSizePixel = 1
    Btn.Text = " " .. modeName
    Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 14
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Parent = Scroll

    ModeButtons[modeName] = Btn

    Btn.MouseButton1Click:Connect(function()
        getgenv().Config.ManualMode = modeName
        getgenv().Config.AutoMode = false
        UpdateUIFromConfig()
    end)
end

CreateModeButton("Headhunter")
CreateModeButton("Headhunter2")
CreateModeButton("Orbit")
CreateModeButton("Normal")
RefreshModeUI("Orbit")

-- ==========================================
-- TARGET TAB UI (NPC MANAGER)
-- ==========================================
local TargetModeToggle = Instance.new("TextButton")
TargetModeToggle.Size = UDim2.new(1, 0, 0, 30)
TargetModeToggle.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
TargetModeToggle.BorderColor3 = Color3.fromRGB(100, 100, 100)
TargetModeToggle.BorderSizePixel = 1
TargetModeToggle.Text = "   Filter: ALL NPCs"
TargetModeToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
TargetModeToggle.Font = Enum.Font.GothamBold
TargetModeToggle.TextSize = 13
TargetModeToggle.TextXAlignment = Enum.TextXAlignment.Left
TargetModeToggle.Parent = TargetScroll

TargetModeToggle.MouseButton1Click:Connect(function()
    if getgenv().Config.TargetFilterMode == "All" then
        getgenv().Config.TargetFilterMode = "Selected"
        TargetModeToggle.Text = "   Filter: SELECTED ONLY"
        TargetModeToggle.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
    else
        getgenv().Config.TargetFilterMode = "All"
        TargetModeToggle.Text = "   Filter: ALL NPCs"
        TargetModeToggle.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    end
end)

local ScannerToggle = Instance.new("TextButton")
ScannerToggle.Size = UDim2.new(1, 0, 0, 30)
ScannerToggle.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
ScannerToggle.BorderColor3 = Color3.fromRGB(100, 100, 100)
ScannerToggle.BorderSizePixel = 1
ScannerToggle.Text = "   NPC Scanner: ON"
ScannerToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
ScannerToggle.Font = Enum.Font.GothamBold
ScannerToggle.TextSize = 13
ScannerToggle.TextXAlignment = Enum.TextXAlignment.Left
ScannerToggle.Parent = TargetScroll

ScannerToggle.MouseButton1Click:Connect(function()
    getgenv().Config.NPCScannerEnabled = not getgenv().Config.NPCScannerEnabled
    if getgenv().Config.NPCScannerEnabled then
        ScannerToggle.Text = "   NPC Scanner: ON"
        ScannerToggle.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
    else
        ScannerToggle.Text = "   NPC Scanner: OFF"
        ScannerToggle.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    end
end)

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(1, 0, 0, 30)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 100)
RefreshBtn.BorderColor3 = Color3.fromRGB(100, 100, 100)
RefreshBtn.BorderSizePixel = 1
RefreshBtn.Text = "   REFRESH LIST"
RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.TextSize = 13
RefreshBtn.Parent = TargetScroll

local NPCListContainer = Instance.new("Frame")
NPCListContainer.Size = UDim2.new(1, 0, 0, 0)
NPCListContainer.BackgroundTransparency = 1
NPCListContainer.AutomaticSize = Enum.AutomaticSize.Y
NPCListContainer.Parent = TargetScroll

local NPCListLayout = Instance.new("UIListLayout")
NPCListLayout.Padding = UDim.new(0, 4)
NPCListLayout.Parent = NPCListContainer

-- ==========================================
-- OPTIMIZED BACKGROUND SCANNER & ESP MANAGER
-- ==========================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if not getgenv().Config.NPCScannerEnabled then continue end
        
        local currentNPCs = {}
        
        for _, obj in ipairs(ws:GetDescendants()) do
            if obj:IsA("Model") and not plrs:GetPlayerFromCharacter(obj) and obj ~= lplr.Character then
                local hum = obj:FindFirstChildWhichIsA("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                
                if hum and hrp and hum.MaxHealth > 0 then
                    table.insert(currentNPCs, obj)
                    
                    if not getgenv().AllKnownNPCs[obj.Name] then
                        local success, cloned = pcall(function()
                            local c = obj:Clone()
                            for _, child in ipairs(c:GetDescendants()) do
                                if child:IsA("Script") or child:IsA("LocalScript") then
                                    child:Destroy()
                                elseif child:IsA("BasePart") then
                                    child.Anchored = true
                                    child.CanCollide = false
                                end
                            end
                            c.Parent = NPCTemplates
                            return c
                        end)
                        
                        if success and cloned then
                            getgenv().AllKnownNPCs[obj.Name] = cloned
                            if TargetScroll.Visible then
                                BuildNPCList()
                            end
                        end
                    end
                    
                    local esp = getgenv().ActiveESPs[obj]
                    if not esp then
                        esp = Instance.new("Highlight")
                        esp.Name = "AxiomESP"
                        esp.Adornee = obj
                        esp.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        esp.FillTransparency = 0.5
                        esp.Parent = game:GetService("CoreGui")
                        getgenv().ActiveESPs[obj] = esp
                    end
                    
                    local priority = getgenv().NPCPriorities[obj.Name]
                    if priority == "Green" then
                        esp.FillColor = Color3.fromRGB(0, 255, 0)
                        esp.OutlineColor = Color3.fromRGB(0, 255, 0)
                    elseif priority == "Yellow" then
                        esp.FillColor = Color3.fromRGB(255, 255, 0)
                        esp.OutlineColor = Color3.fromRGB(255, 255, 0)
                    elseif priority == "Red" then
                        esp.FillColor = Color3.fromRGB(255, 0, 0)
                        esp.OutlineColor = Color3.fromRGB(255, 0, 0)
                    else
                        esp.FillColor = Color3.fromRGB(255, 255, 255)
                        esp.OutlineColor = Color3.fromRGB(255, 255, 255)
                    end
                end
            end
        end
        
        getgenv().LiveNPCs = currentNPCs
        
        for obj, esp in pairs(getgenv().ActiveESPs) do
            if not obj or not obj.Parent or not obj:FindFirstChild("Humanoid") or obj.Humanoid.Health <= 0 then
                esp:Destroy()
                getgenv().ActiveESPs[obj] = nil
            end
        end
    end
end)

function BuildNPCList()
    for _, child in ipairs(NPCListContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    -- Merge AllKnownNPCs with StarredNPCs
    local displayNames = {}
    for name, _ in pairs(getgenv().AllKnownNPCs) do
        displayNames[name] = true
    end
    for name, _ in pairs(getgenv().StarredNPCs) do
        displayNames[name] = true
    end
    
    local sortedNames = {}
    for name, _ in pairs(displayNames) do
        table.insert(sortedNames, name)
    end
    table.sort(sortedNames)
    
    for _, name in ipairs(sortedNames) do
        local Model = getgenv().AllKnownNPCs[name]
        
        local Row = Instance.new("Frame")
        Row.Size = UDim2.new(1, 0, 0, 40)
        Row.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        Row.BorderSizePixel = 1
        Row.BorderColor3 = Color3.fromRGB(80, 80, 80)
        Row.Parent = NPCListContainer

        -- Viewport Preview
        local vp = Instance.new("ViewportFrame")
        vp.Size = UDim2.new(0, 36, 0, 36)
        vp.Position = UDim2.new(0, 2, 0, 2)
        vp.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
        vp.BorderSizePixel = 0
        vp.Parent = Row

        if Model then
            local cam = Instance.new("Camera")
            cam.Parent = vp
            vp.CurrentCamera = cam

            local cloneForVP = Model:Clone()
            cloneForVP.Parent = vp
            
            local pivot = cloneForVP:GetPivot()
            if pivot then
                cam.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 0.5, -4), pivot.Position)
            end
        end

        -- Star Button
        local StarBtn = Instance.new("TextButton")
        StarBtn.Size = UDim2.new(0, 20, 0, 20)
        StarBtn.Position = UDim2.new(0, 40, 0.5, -10)
        StarBtn.BackgroundTransparency = 1
        StarBtn.Text = getgenv().StarredNPCs[name] and "★" or "☆"
        StarBtn.TextColor3 = getgenv().StarredNPCs[name] and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(150, 150, 150)
        StarBtn.TextSize = 18
        StarBtn.Font = Enum.Font.GothamBold
        StarBtn.Parent = Row

        StarBtn.MouseButton1Click:Connect(function()
            getgenv().StarredNPCs[name] = not getgenv().StarredNPCs[name]
            if getgenv().StarredNPCs[name] == false then getgenv().StarredNPCs[name] = nil end
            SaveStarred()
            StarBtn.Text = getgenv().StarredNPCs[name] and "★" or "☆"
            StarBtn.TextColor3 = getgenv().StarredNPCs[name] and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(150, 150, 150)
        end)

        -- Select Button
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(1, -120, 1, 0)
        Btn.Position = UDim2.new(0, 62, 0, 0)
        Btn.BackgroundColor3 = getgenv().SelectedNPCs[name] and Color3.fromRGB(30, 80, 30) or Color3.fromRGB(40, 40, 50)
        Btn.BorderSizePixel = 1
        Btn.BorderColor3 = Color3.fromRGB(100, 100, 100)
        Btn.Text = " " .. name
        Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        Btn.Font = Enum.Font.Gotham
        Btn.TextSize = 12
        Btn.TextXAlignment = Enum.TextXAlignment.Left
        Btn.Parent = Row
        
        Btn.MouseButton1Click:Connect(function()
            getgenv().SelectedNPCs[name] = not getgenv().SelectedNPCs[name]
            if getgenv().SelectedNPCs[name] == false then getgenv().SelectedNPCs[name] = nil end
            Btn.BackgroundColor3 = getgenv().SelectedNPCs[name] and Color3.fromRGB(30, 80, 30) or Color3.fromRGB(40, 40, 50)
        end)

        -- Priority Dots
        local DotContainer = Instance.new("Frame")
        DotContainer.Size = UDim2.new(0, 54, 1, 0)
        DotContainer.Position = UDim2.new(1, -56, 0, 0)
        DotContainer.BackgroundTransparency = 1
        DotContainer.Parent = Row

        local function CreateDot(color, priorityName, xPos)
            local Dot = Instance.new("TextButton")
            Dot.Size = UDim2.new(0, 12, 0, 12)
            Dot.Position = UDim2.new(0, xPos, 0.5, -6)
            Dot.BackgroundColor3 = color
            Dot.BorderSizePixel = 2
            Dot.Text = ""
            Dot.Parent = DotContainer
            
            local isActive = (getgenv().NPCPriorities[name] == priorityName)
            if isActive then
                Dot.BorderColor3 = Color3.fromRGB(255, 255, 255)
            else
                Dot.BorderColor3 = Color3.fromRGB(30, 30, 30)
            end

            Dot.MouseButton1Click:Connect(function()
                if getgenv().NPCPriorities[name] == priorityName then
                    getgenv().NPCPriorities[name] = nil
                else
                    getgenv().NPCPriorities[name] = priorityName
                end
                BuildNPCList()
                UpdateESPColors()
            end)
        end

        CreateDot(Color3.fromRGB(255, 50, 50), "Red", 0)
        CreateDot(Color3.fromRGB(255, 255, 50), "Yellow", 16)
        CreateDot(Color3.fromRGB(50, 255, 50), "Green", 32)
    end
end

RefreshBtn.MouseButton1Click:Connect(BuildNPCList)

-- ==========================================
-- HUD OVERLAY & HIGHLIGHT
-- ==========================================
local HudGui = Instance.new("ScreenGui")
HudGui.Name = "AxiomHUD"
HudGui.ResetOnSpawn = false
HudGui.Parent = game:GetService("CoreGui")

local HudLabel = Instance.new("TextLabel")
HudLabel.Size = UDim2.new(0, 400, 0, 40)
HudLabel.Position = UDim2.new(0.5, -200, 1, -60)
HudLabel.BackgroundTransparency = 1
HudLabel.Text = "Equipped: None | Mode: Idle"
HudLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
HudLabel.Font = Enum.Font.GothamBold
HudLabel.TextSize = 18
HudLabel.TextStrokeTransparency = 0
HudLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
HudLabel.Parent = HudGui

local targetHighlight = Instance.new("Highlight")
targetHighlight.Name = "AxiomTargetESP"
targetHighlight.FillColor = Color3.fromRGB(0, 255, 0)
targetHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
targetHighlight.FillTransparency = 0.5
targetHighlight.OutlineTransparency = 0
targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
targetHighlight.Adornee = nil
targetHighlight.Parent = game:GetService("CoreGui")

-- ==========================================
-- 2. DESYNC SERVICE
-- ==========================================
local DesyncService = {
    active = false,
    connection = nil,
    server = nil,
    client = nil,
    offset = Vector3.new(0, 15, 0)
}

function DesyncService:Init()
    if not getgenv().AxiomDesyncHooked and CameraController then
        getgenv().AxiomDesyncHooked = true
        local ref = CameraController.Update
        CameraController.Update = function(...)
            local fighter = FighterController and FighterController.LocalFighter
            if self.active and fighter and fighter.Entity and fighter.Entity.RootPart and self.client then
                fighter.Entity.RootPart.CFrame = self.client
            end
            return ref(...)
        end
    end
end

function DesyncService:Start(targetModel, offset)
    if self.active then return end
    if not lplr.Character then return end
    local fighter = FighterController and FighterController.LocalFighter
    if not fighter or not fighter.Entity or not fighter.Entity.RootPart then return end

    self.offset = offset or Vector3.new(0, 15, 0)
    self.active = true
    
    self.connection = runS.Heartbeat:Connect(function(dt)
        if not self.active then
            if self.connection then self.connection:Disconnect(); self.connection = nil end
            return
        end

        if not targetModel or not targetModel.Parent or not targetModel:FindFirstChild('HumanoidRootPart') or not fighter or not fighter.Entity or not fighter.Entity.RootPart then
            if self.connection then self.connection:Disconnect(); self.connection = nil end
            if self.client and fighter and fighter.Entity.RootPart then
                fighter.Entity.RootPart.CFrame = self.client
            end
            self.active = false
            self.client = nil
            self.server = nil
            return
        end

        self.client = fighter.Entity.RootPart.CFrame
        local targetPos = targetModel.HumanoidRootPart.Position
        local spin = getSpinOffset(self.offset.Y)
        
        self.server = targetPos + self.offset + spin
        fighter.Entity.RootPart.CFrame = CFrame.lookAt(self.server, targetPos)
    end)
end

function DesyncService:Stop()
    if not self.active then return end
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
    local fighter = FighterController and FighterController.LocalFighter
    if self.client and fighter and fighter.Entity.RootPart then
        fighter.Entity.RootPart.CFrame = self.client
    end
    self.active = false
    self.server = nil
    self.client = nil
end

DesyncService:Init()

-- ==========================================
-- 3. TP STATE
-- ==========================================
local TPState = {
    active = false,
    targetModel = nil,
    offset = Vector3.new(0, 7, 0)
}

runS.Stepped:Connect(function()
    if not TPState.active or not TPState.targetModel then return end
    if not TPState.targetModel.Parent then
        TPState.active = false
        TPState.targetModel = nil
        return
    end
    
    local char = lplr.Character
    if not char then return end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    local myHum = char:FindFirstChildWhichIsA("Humanoid")
    if not myRoot then return end
    
    local tRoot = TPState.targetModel:FindFirstChild("HumanoidRootPart")
    local tHead = TPState.targetModel:FindFirstChild("HitboxHead") 
        or TPState.targetModel:FindFirstChild("Head") 
        or tRoot
    if not tRoot or not tHead then return end

    if myHum and getgenv().Config.UndergroundMode then
        if myHum:GetState() ~= Enum.HumanoidStateType.Physics then
            myHum:ChangeState(Enum.HumanoidStateType.Physics)
        end
    elseif myHum and myHum:GetState() == Enum.HumanoidStateType.Physics then
        myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    
    local tpPos = tRoot.Position + TPState.offset
    local spin = getSpinOffset(TPState.offset.Y)
    local finalPos = tpPos + spin
    
    myRoot.CFrame = CFrame.lookAt(finalPos, tHead.Position)
    
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
end)

-- ==========================================
-- 4. BOUNCE HEARTBEAT
-- ==========================================
local abovePhase = true
local lastOffsetFlip = tick()

runS.Heartbeat:Connect(function()
    if not getgenv().Config.Enabled then return end
    if not TPState.active then return end
    
    if getgenv().Config.UndergroundMode then
        TPState.offset = Vector3.new(0, -getgenv().Config.UndergroundDepth, 0)
        return
    end

    if getgenv().Config.BounceEnabled then
        if tick() - lastOffsetFlip >= getgenv().Config.OffsetFlipTime then
            abovePhase = not abovePhase
            lastOffsetFlip = tick()
        end
    else
        abovePhase = true
        lastOffsetFlip = tick()
    end
    
    local y = abovePhase and getgenv().Config.AboveHeight or -getgenv().Config.BelowDepth
    TPState.offset = Vector3.new(0, y, 0)
end)

-- ==========================================
-- 5. CORE LOGIC
-- ==========================================
local lastFire = 0
local retreatUntil = 0
local lastActiveMode = ""
local targetIndex = 1
local currentTargetModel = nil
local targetStartTime = 0

local postAttackState = "idle"
local postAttackTimer = 0
local hideAnchor = nil

local function resetPostAttack()
    if postAttackState ~= "idle" and hideAnchor and lplr.Character then
        local myRoot = lplr.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then myRoot.CFrame = hideAnchor end
    end
    postAttackState = "idle"
    hideAnchor = nil
end

local function getValidTargets(isHH2)
    local char = lplr.Character
    local camera = ws.CurrentCamera
    if not char or not camera then return {} end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return {} end
    
    local targets = {}
    local filterMode = getgenv().Config.TargetFilterMode
    local selected = getgenv().SelectedNPCs
    local liveNPCs = getgenv().LiveNPCs
    
    for _, obj in ipairs(liveNPCs) do
        if obj and obj.Parent then
            local pRoot = obj:FindFirstChild("HumanoidRootPart")
            local pHead = obj:FindFirstChild("HitboxHead") or obj:FindFirstChild("Head") or pRoot
            local pHum = obj:FindFirstChildWhichIsA("Humanoid")
            
            if pRoot and pHead and pHum and pHum.Health and pHum.Health > 0 then
                if filterMode == "Selected" and next(selected) ~= nil then
                    if not selected[obj.Name] then continue end
                end
                
                local dist = (myRoot.Position - pRoot.Position).Magnitude
                if dist < 2000 then
                    local isVisible = true
                    local crosshairScore = 0
                    
                    if isHH2 then
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        rayParams.FilterDescendantsInstances = {char, obj, NPCTemplates}
                        local rayOrigin = camera.CFrame.Position
                        local rayDir = pHead.Position - rayOrigin
                        
                        local hit = ws:Raycast(rayOrigin, rayDir, rayParams)
                        if hit then isVisible = false end
                        
                        if isVisible then
                            local camLook = camera.CFrame.LookVector
                            local dirToTarget = rayDir.Unit
                            crosshairScore = camLook:Dot(dirToTarget)
                            
                            local fovLimit = math.cos(math.rad(getgenv().Config.HH2_FOV / 2))
                            if crosshairScore < fovLimit then isVisible = false end
                        end
                    end
                    
                    if isVisible then
                        table.insert(targets, {
                            model = obj, root = pRoot, head = pHead, hum = pHum, dist = dist, crosshairScore = crosshairScore
                        })
                    end
                end
            end
        end
    end
    
    local priorities = getgenv().NPCPriorities
    local priorityWeights = { Green = 3, Yellow = 2, Red = 1 }
    
    table.sort(targets, function(a, b)
        local pA = priorityWeights[priorities[a.model.Name]] or 0
        local pB = priorityWeights[priorities[b.model.Name]] or 0
        
        if pA ~= pB then
            return pA > pB
        end
        
        if isHH2 then
            return a.crosshairScore > b.crosshairScore
        else
            local yDiff = math.abs(a.root.Position.Y - b.root.Position.Y)
            if yDiff > 1 then return a.root.Position.Y < b.root.Position.Y end
            return a.dist < b.dist
        end
    end)
    
    return targets
end

runS.Heartbeat:Connect(function()
    local fighter = FighterController and FighterController.LocalFighter
    local item = fighter and fighter.EquippedItem
    local itemName = item and item.Name or "Fists"
    
    local isMelee = true
    if item then
        local typeValid = false
        if item.Info and item.Info.Type then
            local t = item.Info.Type
            if t == "Gun" then isMelee = false; typeValid = true
            elseif t == "Melee" then isMelee = true; typeValid = true
            end
        end
        
        if not typeValid then
            local n = string.lower(itemName)
            if n:find("gun") or n:find("rifle") or n:find("pistol") or n:find("shotgun") or n:find("smg") or n:find("sniper") or n:find("launcher") or n:find("revolver") then
                isMelee = false
            end
        end
    end

    local activeMode = getgenv().Config.ManualMode
    if getgenv().Config.AutoMode then
        activeMode = isMelee and "Orbit" or "Headhunter"
    end

    if activeMode ~= lastActiveMode then
        lastActiveMode = activeMode
        currentTargetModel = nil
        targetIndex = 1
        TPState.active = false
        TPState.targetModel = nil
        abovePhase = true
        lastOffsetFlip = tick()
        resetPostAttack()
        RefreshModeUI(activeMode)
    end

    if getgenv().Config.Enabled then
        HudLabel.Text = string.format("Equipped: %s | Mode: %s", itemName, activeMode)
    else
        HudLabel.Text = "Slayer Disabled"
    end

    if not getgenv().Config.Enabled then 
        targetHighlight.Adornee = nil
        DesyncService:Stop()
        TPState.active = false
        TPState.targetModel = nil
        resetPostAttack()
        return 
    end

    if not getgenv().Config.PostAttackTeleport then resetPostAttack() end

    if tick() < retreatUntil then
        TPState.active = false
        TPState.targetModel = nil
        return
    end
    
    local isHH2 = (activeMode == "Headhunter2")
    local targets = getValidTargets(isHH2)
    
    if #targets == 0 then 
        targetHighlight.Adornee = nil
        DesyncService:Stop()
        TPState.active = false
        TPState.targetModel = nil
        currentTargetModel = nil
        resetPostAttack()
        return 
    end

    local target
    if isHH2 then
        targetIndex = 1
        target = targets[1]
        currentTargetModel = target.model
    else
        if targetIndex > #targets or targetIndex < 1 then targetIndex = 1 end
        target = targets[targetIndex]

        if currentTargetModel ~= target.model then
            currentTargetModel = target.model
            targetStartTime = tick()
        elseif tick() - targetStartTime >= getgenv().Config.TargetCycleTime then
            targetIndex = targetIndex + 1
            if targetIndex > #targets then targetIndex = 1 end
            target = targets[targetIndex]
            currentTargetModel = target.model
            targetStartTime = tick()
        end
    end

    local targetModel = target.model
    local targetRoot = target.root
    local targetHead = target.head
    local targetHum = target.hum

    if targetModel and targetModel.Parent and targetModel:IsDescendantOf(ws) then
        targetHighlight.Adornee = targetModel
    else
        targetHighlight.Adornee = nil
    end

    if not targetHum or not targetHum.Parent or not targetHum.Health or targetHum.Health <= 0 then
        targetHighlight.Adornee = nil
        DesyncService:Stop()
        TPState.active = false
        TPState.targetModel = nil
        resetPostAttack()
        if activeMode == "Orbit" or activeMode == "Headhunter" then
            retreatUntil = tick() + 1.2
            local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
            if myRoot then myRoot.CFrame = myRoot.CFrame + Vector3.new(0, 150, 0) end
        end
        currentTargetModel = nil
        return
    end

    if getgenv().Config.PostAttackTeleport then
        if postAttackState == "waiting" then
            if tick() - postAttackTimer >= getgenv().Config.PostAttackDelay then
                postAttackState = "hiding"
                postAttackTimer = tick()
                TPState.active = false
                TPState.targetModel = nil
                local myRoot = lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    hideAnchor = myRoot.CFrame
                    myRoot.CFrame = CFrame.new(myRoot.Position + Vector3.new(0, 500, 0))
                    myRoot.AssemblyLinearVelocity = Vector3.zero
                    myRoot.AssemblyAngularVelocity = Vector3.zero
                end
                return
            end
            return
        elseif postAttackState == "hiding" then
            if tick() - postAttackTimer < getgenv().Config.PostHideTime then return end
            postAttackState = "idle"
            hideAnchor = nil
        end
    end

    if not lplr.Character or not lplr.Character:FindFirstChild("HumanoidRootPart") then return end
    if tick() - lastFire < 0.05 then return end
    lastFire = tick()

    local firePostAttack = getgenv().Config.PostAttackTeleport and postAttackState == "idle"

    if activeMode == "Headhunter2" or activeMode == "Headhunter" then
        if DesyncService.active then DesyncService:Stop() end
        TPState.active = false
        TPState.targetModel = nil
        
        if firePostAttack then
            postAttackState = "waiting"
            postAttackTimer = tick()
        end
        
        local myRoot = lplr.Character.HumanoidRootPart
        local shootPos = myRoot.Position
        local aimPos = targetHead.Position
        
        local data = {
            [utf8.char(1)] = {
                [utf8.char(0)] = util:EncodeCFrame(CFrame.new(shootPos, aimPos)),
                [utf8.char(1)] = util:EncodeCFrame(CFrame.new(shootPos, aimPos)),
                [utf8.char(2)] = targetHead,
                [utf8.char(1)] = util:EncodeCFrame(CFrame.new(shootPos, aimPos)),
            },
        }
        
        pcall(function()
            repS.Remotes.Replication.Fighter.UseItem:FireServer(item:Get("ObjectID"), enum:ToEnum("StartShooting"), data, nil)
        end)
        return
    end

    if activeMode == "Orbit" or activeMode == "Normal" then
        if DesyncService.active then DesyncService:Stop() end
        TPState.active = true
        TPState.targetModel = targetModel
        
        if firePostAttack then
            postAttackState = "waiting"
            postAttackTimer = tick()
        end
        
        if isMelee or not item then
            pcall(function() if fighter then fighter:Input("StartShooting") end end)
            return
        end
        
        local myRoot = lplr.Character.HumanoidRootPart
        local shootPos = myRoot.Position
        local aimPos = targetHead.Position
        
        local data = {
            [utf8.char(1)] = {
                [utf8.char(0)] = util:EncodeCFrame(CFrame.new(shootPos, aimPos)),
                [utf8.char(1)] = util:EncodeCFrame(CFrame.new(shootPos, aimPos)),
                [utf8.char(2)] = targetHead,
                [utf8.char(1)] = util:EncodeCFrame(CFrame.new(shootPos, aimPos)),
            },
        }
        
        pcall(function()
            repS.Remotes.Replication.Fighter.UseItem:FireServer(item:Get("ObjectID"), enum:ToEnum("StartShooting"), data, nil)
        end)
        return
    end
end)

-- ==========================================
-- 6. UTILITY LOOPS
-- ==========================================
runS.Heartbeat:Connect(function()
    if not getgenv().Config.MeleeExpand or not lplr.Character then return end
    if not FighterController or not FighterController.LocalFighter then return end
    
    local item = FighterController.LocalFighter.EquippedItem
    if item and item.Name then
        local n = string.lower(item.Name)
        if n:find("sword") or n:find("knife") or n:find("katana") or n:find("fist") or n:find("melee") or n:find("axe") or n:find("bat") then
            local vm = item.ViewModel
            if vm and vm.ItemModel then
                for _, part in pairs(vm.ItemModel:GetDescendants()) do
                    if part:IsA("BasePart") and (part.Name:find("Hitbox") or part.Name:find("Blade") or part.Name:find("Fist")) then
                        part.Size = part.Size * 2.5
                        part.Transparency = 1
                    end
                end
            end
        end
    end
end)

runS.RenderStepped:Connect(function()
    if not getgenv().Config.AutoPickup or not lplr.Character then return end
    local myRoot = lplr.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    
    for _, drop in pairs(ws:GetChildren()) do
        if drop.Name == "_drop" and drop:IsA("BasePart") then
            pcall(function()
                firetouchinterest(myRoot, drop, 0)
                firetouchinterest(myRoot, drop, 1)
            end)
        end
    end
end)

runS.Stepped:Connect(function()
    if not lplr.Character then return end
    if getgenv().Config.Noclip then
        for _, v in pairs(lplr.Character:GetDescendants()) do
            if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
        end
    end
end)

print("[Axiom] v71 Loaded. Infinite Yield freecam integrated.")