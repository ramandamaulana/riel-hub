--[[
    REFACTORED: System Broken -> Riel Style UI (Universal Edition)
    UPDATED BY: kitaroriel
    CHANGES: 
    - Main Script Tab now mimics "Universal Scripts" features.
    - Added Slider support.
    - Added Noclip, Infinite Jump, Speed Logic.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local mouse = plr:GetMouse()

--------------------------------------------------------------------------------
-- 1. SETUP PARENT
--------------------------------------------------------------------------------
local GuiParent
if RunService:IsStudio() then
    GuiParent = plr:WaitForChild("PlayerGui")
else
    local success, core = pcall(function() return game:GetService("CoreGui") end)
    if success then GuiParent = core else GuiParent = plr:WaitForChild("PlayerGui") end
end

if GuiParent:FindFirstChild("MarVScript_Remake") then
    GuiParent.MarVScript_Remake:Destroy()
end

--------------------------------------------------------------------------------
-- 2. VARIABLES & LOGIC
--------------------------------------------------------------------------------
_G.AntiFlingToggled = false
local ScriptWhitelist = {}
local TargetedPlayer = nil

-- CONTROL VARIABLES
local BackpackEnabled = false
local SitHeadEnabled = false

-- [[ ANIMATION DATABASE ]] --
local AnimData = {
    Original = {Idle="", Walk="", Run="", Jump="", Fall="", Climb=""},
    Adidas = {Idle = "5319828216", Walk = "5319841935", Run = "5319844329", Jump = "5319841077", Fall = "5319839762", Climb = "5319830532"},
    Wicked = {Idle = "616136790", Walk = "616139451", Run = "616140816", Jump = "616138447", Fall = "616134815", Climb = "616133594"},
    Vampire = {Idle = "1083445855", Walk = "1083473930", Run = "1083462077", Jump = "1083455352", Fall = "1083461422", Climb = "1083439238"},
    Zombie = {Idle = "616158929", Walk = "616168032", Run = "616163682", Jump = "616161997", Fall = "616157476", Climb = "616156119"},
    Ninja = {Idle = "656117400", Walk = "656121766", Run = "656118852", Jump = "656118341", Fall = "656115606", Climb = "656114359"},
    Mage = {Idle = "707742142", Walk = "707897309", Run = "707861613", Jump = "707853694", Fall = "707829716", Climb = "707826056"},
    Toy = {Idle = "782841498", Walk = "782843345", Run = "782842708", Jump = "782847020", Fall = "782846423", Climb = "782843869"}
}
local AnimNames = {"Original", "Adidas", "Wicked", "Vampire", "Zombie", "Ninja", "Mage", "Toy"}

-- THEME SYSTEM VARIABLES
local CurrentTheme = {
    Main = Color3.fromRGB(15, 15, 18),
    Sidebar = Color3.fromRGB(20, 20, 24),
    Accent = Color3.fromRGB(0, 255, 128),
    Text = Color3.fromRGB(255, 255, 255),
    SubText = Color3.fromRGB(150, 150, 150),
    Input = Color3.fromRGB(30, 30, 35)
}

-- Object Registry for Theme Switching
local ThemeObjects = {
    MainFrames = {}, Sidebars = {}, Strokes = {}, Texts = {}, Images = {}, ScrollBars = {}, Indicators = {}, Inputs = {}, Sliders = {}
}

local function RegisterThemeObj(type, instance)
    if not ThemeObjects[type] then ThemeObjects[type] = {} end
    table.insert(ThemeObjects[type], instance)
end

-- Helper Functions
local function GetPing()
    local ping = 0
    pcall(function() ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()/1000 end)
    return ping
end

local function GetPlayer(UserDisplay)
    if UserDisplay ~= "" then
        for i,v in pairs(Players:GetPlayers()) do
            if v.Name:lower():match(UserDisplay:lower()) or v.DisplayName:lower():match(UserDisplay:lower()) then return v end
        end
    end
    return nil
end

local function GetRoot(Player)
    if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then return Player.Character.HumanoidRootPart end
    return nil
end

local function TeleportTO(posX,posY,posZ,player,method)
    pcall(function()
        local root = GetRoot(plr)
        if not root then return end
        root.Velocity = Vector3.new(0,0,0)
        if player == "pos" then root.CFrame = CFrame.new(posX,posY,posZ)
        elseif player and GetRoot(player) then root.CFrame = CFrame.new(GetRoot(player).Position) + Vector3.new(0,2,0) end
    end)
end

local function PredictionTP(player)
    local root = GetRoot(player); local myRoot = GetRoot(plr)
    if root and myRoot then
        local pos = root.Position; local vel = root.Velocity; local ping = GetPing()
        myRoot.CFrame = CFrame.new((pos.X)+(vel.X)*(ping*3.5),(pos.Y)+(vel.Y)*(ping*2),(pos.Z)+(vel.Z)*(ping*3.5))
    end
end

local function GetPush()
    local TempPush = nil
    pcall(function()
        if plr.Backpack:FindFirstChild("Push") then TempPush = plr.Backpack.Push; TempPush.Parent = plr.Character end
        if plr.Character:FindFirstChild("Push") then TempPush = plr.Character.Push end
    end)
    return TempPush
end

local function Push(Target)
    local PushTool = GetPush()
    if PushTool and PushTool:FindFirstChild("PushTool") and Target.Character then
        local args = {[1] = Target.Character}; PushTool.PushTool:FireServer(unpack(args)); PushTool.Parent = plr.Backpack
    end
end

local function SendNotify(title, message, duration)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = message, Duration = duration or 3}) end)
end

local function StopCarry()
    pcall(function()
        local root = GetRoot(plr)
        if root and root:FindFirstChild("BreakVelocity") then root.BreakVelocity:Destroy() end
        if plr.Character and plr.Character:FindFirstChild("Humanoid") then
            plr.Character.Humanoid.Sit = false
            plr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        if root then root.Velocity = Vector3.new(0,0,0); root.CFrame = root.CFrame * CFrame.new(0,0,3) end 
    end)
end

-- [[ FIXED ANIMATION HANDLER ]] --
local function ChangeAnimation(animType, presetName)
    pcall(function()
        local char = plr.Character
        if not char then return end
        local hum = char:FindFirstChild("Humanoid")
        local animate = char:FindFirstChild("Animate")
        if not animate or not hum then return end
        
        local id = "0"
        if AnimData[presetName] and AnimData[presetName][animType] then
            id = AnimData[presetName][animType]
        end
        
        local targetAnim = nil
        if animType == "Idle" then targetAnim = animate:FindFirstChild("idle")
        elseif animType == "Walk" then targetAnim = animate:FindFirstChild("walk")
        elseif animType == "Run" then targetAnim = animate:FindFirstChild("run")
        elseif animType == "Jump" then targetAnim = animate:FindFirstChild("jump")
        elseif animType == "Fall" then targetAnim = animate:FindFirstChild("fall")
        elseif animType == "Climb" then targetAnim = animate:FindFirstChild("climb")
        end
        
        if targetAnim and id ~= "0" then
            for _, v in pairs(targetAnim:GetChildren()) do if v:IsA("Animation") then v.AnimationId = "http://www.roblox.com/asset/?id="..id end end
            for _, track in pairs(hum:GetPlayingAnimationTracks()) do track:Stop() end
            hum:ChangeState(Enum.HumanoidStateType.Landed)
        end
    end)
end

--------------------------------------------------------------------------------
-- 3. UI CONSTRUCTION
--------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MarVScript_Remake"
ScreenGui.Parent = GuiParent
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- [[ THEME CHANGER FUNCTION ]] --
local function ApplyTheme(themeData)
    CurrentTheme = themeData
    for _, v in pairs(ThemeObjects.MainFrames) do v.BackgroundColor3 = CurrentTheme.Main end
    for _, v in pairs(ThemeObjects.Sidebars) do v.BackgroundColor3 = CurrentTheme.Sidebar end
    for _, v in pairs(ThemeObjects.Strokes) do v.Color = CurrentTheme.Accent end
    for _, v in pairs(ThemeObjects.Texts) do v.TextColor3 = CurrentTheme.Accent end
    for _, v in pairs(ThemeObjects.Images) do v.ImageColor3 = CurrentTheme.Accent end
    for _, v in pairs(ThemeObjects.ScrollBars) do v.ScrollBarImageColor3 = CurrentTheme.Accent end
    for _, v in pairs(ThemeObjects.Inputs) do v.BackgroundColor3 = CurrentTheme.Input end
    for _, v in pairs(ThemeObjects.Sliders) do v.BackgroundColor3 = CurrentTheme.Accent end
    for _, v in pairs(ThemeObjects.Indicators) do 
        if v.BackgroundColor3 ~= Color3.fromRGB(15,15,15) then v.BackgroundColor3 = CurrentTheme.Accent end
    end
end

-- [[ TOGGLE BUTTON ]] --
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleButton"
ToggleBtn.Parent = ScreenGui
ToggleBtn.BackgroundColor3 = CurrentTheme.Sidebar
ToggleBtn.Position = UDim2.new(0, 20, 0.5, -30)
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Text = ""
ToggleBtn.AutoButtonColor = true
ToggleBtn.ZIndex = 10
RegisterThemeObj("Sidebars", ToggleBtn)

local ToggleCorner = Instance.new("UICorner"); ToggleCorner.CornerRadius = UDim.new(1, 0); ToggleCorner.Parent = ToggleBtn
local ToggleStroke = Instance.new("UIStroke"); ToggleStroke.Color = CurrentTheme.Accent; ToggleStroke.Thickness = 2; ToggleStroke.Parent = ToggleBtn
RegisterThemeObj("Strokes", ToggleStroke)

local ToggleIcon = Instance.new("ImageLabel")
ToggleIcon.Parent = ToggleBtn
ToggleIcon.BackgroundTransparency = 1
ToggleIcon.Size = UDim2.new(0.6, 0, 0.6, 0)
ToggleIcon.Position = UDim2.new(0.2, 0, 0.2, 0)
ToggleIcon.Image = "rbxassetid://12298407748"
ToggleIcon.ImageColor3 = CurrentTheme.Accent
RegisterThemeObj("Images", ToggleIcon)

local tDragging, tDragInput, tDragStart, tStartPos
ToggleBtn.InputBegan:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then tDragging = true; tDragStart = Input.Position; tStartPos = ToggleBtn.Position end end)
ToggleBtn.InputChanged:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseMovement then tDragInput = Input end end)
game:GetService("UserInputService").InputChanged:Connect(function(Input) if Input == tDragInput and tDragging then local Delta = Input.Position - tDragStart; ToggleBtn.Position = UDim2.new(tStartPos.X.Scale, tStartPos.X.Offset + Delta.X, tStartPos.Y.Scale, tStartPos.Y.Offset + Delta.Y) end end)
game:GetService("UserInputService").InputEnded:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then tDragging = false end end)

-- [[ MAIN CONTAINER ]] --
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Parent = ScreenGui
Main.BackgroundColor3 = CurrentTheme.Main
Main.Position = UDim2.new(0.5, -290, 0.5, -190)
Main.Size = UDim2.new(0, 580, 0, 380)
Main.ClipsDescendants = true
Main.Visible = true
RegisterThemeObj("MainFrames", Main)

ToggleBtn.MouseButton1Click:Connect(function() Main.Visible = not Main.Visible end)
local MainCorner = Instance.new("UICorner"); MainCorner.CornerRadius = UDim.new(0, 8); MainCorner.Parent = Main
local MainStroke = Instance.new("UIStroke"); MainStroke.Color = Color3.fromRGB(40, 40, 40); MainStroke.Thickness = 1; MainStroke.Parent = Main

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Parent = Main
Sidebar.BackgroundColor3 = CurrentTheme.Sidebar
Sidebar.Size = UDim2.new(0, 160, 1, 0)
RegisterThemeObj("Sidebars", Sidebar)

local SidebarStroke = Instance.new("UIStroke"); SidebarStroke.Color = Color3.fromRGB(40, 40, 40); SidebarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; SidebarStroke.Parent = Sidebar

local LogoText = Instance.new("TextLabel")
LogoText.Parent = Sidebar
LogoText.BackgroundTransparency = 1
LogoText.Position = UDim2.new(0, 15, 0, 20)
LogoText.Size = UDim2.new(0, 130, 0, 30)
LogoText.Font = Enum.Font.GothamBold
LogoText.Text = "No system is safe :("
LogoText.TextColor3 = CurrentTheme.Accent
LogoText.TextSize = 16
LogoText.TextXAlignment = Enum.TextXAlignment.Left
RegisterThemeObj("Texts", LogoText)

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Parent = Main
Header.BackgroundTransparency = 1
Header.Position = UDim2.new(0, 160, 0, 0)
Header.Size = UDim2.new(1, -160, 0, 50)

local function CreateStatusBadge(text, posOffset)
    local Badge = Instance.new("Frame")
    Badge.BackgroundColor3 = CurrentTheme.Accent
    Badge.Position = UDim2.new(1, posOffset, 0.5, -12)
    Badge.Size = UDim2.new(0, 80, 0, 24)
    Badge.Parent = Header
    RegisterThemeObj("Indicators", Badge) 
    
    local BadgeCorner = Instance.new("UICorner"); BadgeCorner.CornerRadius = UDim.new(0, 4); BadgeCorner.Parent = Badge
    local Label = Instance.new("TextLabel")
    Label.Parent = Badge
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.new(1,0,1,0)
    Label.Font = Enum.Font.GothamBold
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(15, 15, 18)
    Label.TextSize = 11
    return Label
end
local FPSLabel = CreateStatusBadge("FPS: 60", -180)
local PingLabel = CreateStatusBadge("PING: 0ms", -90)

task.spawn(function()
    while Main.Parent do
        PingLabel.Text = "PING: " .. math.floor(GetPing()*1000) .. "ms"
        if workspace:FindFirstChild("GetRealPhysicsFPS") then FPSLabel.Text = "FPS: " .. math.floor(workspace:GetRealPhysicsFPS()) else FPSLabel.Text = "FPS: N/A" end
        task.wait(1)
    end
end)

local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Parent = Main
Content.BackgroundTransparency = 1
Content.Position = UDim2.new(0, 170, 0, 55)
Content.Size = UDim2.new(0, 400, 0, 315)

local Tabs = {}
local TabButtons = {}
local function SwitchTab(tabId) 
    for id, page in pairs(Tabs) do page.Visible = (id == tabId) end 
    for id, btn in pairs(TabButtons) do
        if id == tabId then
            btn.BackgroundTransparency = 0
            btn.TextColor3 = CurrentTheme.Accent
        else
            btn.BackgroundTransparency = 1
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end
end

local TabListLayout = Instance.new("UIListLayout"); TabListLayout.Parent = Sidebar; TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder; TabListLayout.Padding = UDim.new(0, 5); TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local TabPadding = Instance.new("UIPadding"); TabPadding.Parent = Sidebar; TabPadding.PaddingTop = UDim.new(0, 70)

local function CreateTab(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name .. "_Page"
    Page.Parent = Content
    Page.BackgroundTransparency = 1
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.Visible = false
    Page.ScrollBarThickness = 2
    Page.ScrollBarImageColor3 = CurrentTheme.Accent
    RegisterThemeObj("ScrollBars", Page)
    
    local PageLayout = Instance.new("UIListLayout"); PageLayout.Parent = Page; PageLayout.SortOrder = Enum.SortOrder.LayoutOrder; PageLayout.Padding = UDim.new(0, 8)
    local PagePad = Instance.new("UIPadding"); PagePad.Parent = Page; PagePad.PaddingRight = UDim.new(0, 5); PagePad.PaddingTop = UDim.new(0, 5)
    Tabs[name] = Page
    
    local Btn = Instance.new("TextButton"); Btn.Name = name .. "_Btn"; Btn.Parent = Sidebar; Btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35); Btn.BackgroundTransparency = 1; Btn.Size = UDim2.new(0, 140, 0, 35); Btn.Font = Enum.Font.GothamMedium; Btn.Text = "   " .. name; Btn.TextColor3 = Color3.fromRGB(150, 150, 150); Btn.TextSize = 13; Btn.TextXAlignment = Enum.TextXAlignment.Left; local BtnCorner = Instance.new("UICorner"); BtnCorner.CornerRadius = UDim.new(0, 6); BtnCorner.Parent = Btn
    TabButtons[name] = Btn
    
    Btn.MouseButton1Click:Connect(function() SwitchTab(name) end)
    return Page
end

local function CreateButton(page, text, callback)
    local ButtonFrame = Instance.new("Frame"); ButtonFrame.Parent = page; ButtonFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); ButtonFrame.Size = UDim2.new(1, 0, 0, 35); local BtnCorner = Instance.new("UICorner"); BtnCorner.CornerRadius = UDim.new(0, 6); BtnCorner.Parent = ButtonFrame; local BtnStroke = Instance.new("UIStroke"); BtnStroke.Color = Color3.fromRGB(50, 50, 55); BtnStroke.Parent = ButtonFrame
    local Click = Instance.new("TextButton"); Click.Parent = ButtonFrame; Click.Size = UDim2.new(1, 0, 1, 0); Click.BackgroundTransparency = 1; Click.Font = Enum.Font.Gotham; Click.Text = text; Click.TextColor3 = Color3.fromRGB(220, 220, 220); Click.TextSize = 13
    Click.MouseButton1Click:Connect(function() Click.TextSize = 11; TweenService:Create(Click, TweenInfo.new(0.1), {TextSize = 13}):Play(); callback() end)
    return ButtonFrame
end

local function CreateToggle(page, text, callback, defaultState)
    local ToggleFrame = Instance.new("Frame"); ToggleFrame.Parent = page; ToggleFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); ToggleFrame.Size = UDim2.new(1, 0, 0, 35); local TCorner = Instance.new("UICorner"); TCorner.CornerRadius = UDim.new(0, 6); TCorner.Parent = ToggleFrame; local TStroke = Instance.new("UIStroke"); TStroke.Color = Color3.fromRGB(50, 50, 55); TStroke.Parent = ToggleFrame
    local Label = Instance.new("TextLabel"); Label.Parent = ToggleFrame; Label.BackgroundTransparency = 1; Label.Position = UDim2.new(0, 10, 0, 0); Label.Size = UDim2.new(0.7, 0, 1, 0); Label.Font = Enum.Font.Gotham; Label.Text = text; Label.TextColor3 = Color3.fromRGB(220, 220, 220); Label.TextSize = 13; Label.TextXAlignment = Enum.TextXAlignment.Left
    local Indicator = Instance.new("Frame"); Indicator.Parent = ToggleFrame; Indicator.AnchorPoint = Vector2.new(1, 0.5); Indicator.Position = UDim2.new(1, -10, 0.5, 0); Indicator.Size = UDim2.new(0, 14, 0, 14); Indicator.BackgroundColor3 = Color3.fromRGB(15, 15, 15); local ICorner = Instance.new("UICorner"); ICorner.CornerRadius = UDim.new(0, 3); ICorner.Parent = Indicator; local IStroke = Instance.new("UIStroke"); IStroke.Color = Color3.fromRGB(60, 60, 60); IStroke.Parent = Indicator
    
    RegisterThemeObj("Indicators", Indicator)
    
    local Btn = Instance.new("TextButton"); Btn.Parent = ToggleFrame; Btn.Size = UDim2.new(1, 0, 1, 0); Btn.BackgroundTransparency = 1; Btn.Text = ""; 
    local toggled = defaultState or false
    
    local function SetState(val)
        toggled = val
        if toggled then Indicator.BackgroundColor3 = CurrentTheme.Accent; IStroke.Color = CurrentTheme.Accent
        else Indicator.BackgroundColor3 = Color3.fromRGB(15, 15, 15); IStroke.Color = Color3.fromRGB(60, 60, 60) end
    end
    
    SetState(toggled) -- Initialize
    Btn.Name = "ToggleTrigger"
    Btn.Parent.Name = "ToggleFrame_" .. text:gsub(" ", "")
    Btn.MouseButton1Click:Connect(function() toggled = not toggled; SetState(toggled); callback(toggled, function(v) SetState(v) end) end)
    return {Set = SetState}
end

local function CreateInput(page, placeholder, callback, defaultText)
    local Frame = Instance.new("Frame"); Frame.Parent = page; Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Frame.Size = UDim2.new(1, 0, 0, 35); local FCorner = Instance.new("UICorner"); FCorner.CornerRadius = UDim.new(0, 6); FCorner.Parent = Frame
    local Box = Instance.new("TextBox"); Box.Parent = Frame; Box.Size = UDim2.new(1, -20, 1, 0); Box.Position = UDim2.new(0, 10, 0, 0); Box.BackgroundTransparency = 1; Box.Font = Enum.Font.Gotham; Box.PlaceholderText = placeholder; Box.Text = defaultText or ""; Box.TextColor3 = Color3.fromRGB(255, 255, 255); Box.TextSize = 13; Box.TextXAlignment = Enum.TextXAlignment.Left; 
    Box.FocusLost:Connect(function() callback(Box.Text, Box) end)
    return Box
end

-- [[ NEW SLIDER FUNCTION ]] --
local function CreateSlider(page, text, min, max, default, callback)
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Parent = page
    SliderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    SliderFrame.Size = UDim2.new(1, 0, 0, 45)
    
    local SCorner = Instance.new("UICorner"); SCorner.CornerRadius = UDim.new(0, 6); SCorner.Parent = SliderFrame
    local SStroke = Instance.new("UIStroke"); SStroke.Color = Color3.fromRGB(50, 50, 55); SStroke.Parent = SliderFrame
    
    local Label = Instance.new("TextLabel")
    Label.Parent = SliderFrame
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 10, 0, 5)
    Label.Size = UDim2.new(1, -20, 0, 20)
    Label.Font = Enum.Font.Gotham
    Label.Text = text
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Parent = SliderFrame
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Position = UDim2.new(0, 10, 0, 5)
    ValueLabel.Size = UDim2.new(1, -20, 0, 20)
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.Text = tostring(default)
    ValueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ValueLabel.TextSize = 13
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local SliderBar = Instance.new("Frame")
    SliderBar.Parent = SliderFrame
    SliderBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    SliderBar.Position = UDim2.new(0, 10, 0, 30)
    SliderBar.Size = UDim2.new(1, -20, 0, 6)
    local BarCorner = Instance.new("UICorner"); BarCorner.CornerRadius = UDim.new(1, 0); BarCorner.Parent = SliderBar
    
    local Fill = Instance.new("Frame")
    Fill.Parent = SliderBar
    Fill.BackgroundColor3 = CurrentTheme.Accent
    Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    local FillCorner = Instance.new("UICorner"); FillCorner.CornerRadius = UDim.new(1, 0); FillCorner.Parent = Fill
    RegisterThemeObj("Sliders", Fill)
    
    local Trigger = Instance.new("TextButton")
    Trigger.Parent = SliderBar
    Trigger.BackgroundTransparency = 1
    Trigger.Size = UDim2.new(1, 0, 1, 0)
    Trigger.Text = ""
    
    local dragging = false
    local function UpdateSlide(input)
        local sizeX = math.clamp((input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + ((max - min) * sizeX))
        Fill.Size = UDim2.new(sizeX, 0, 1, 0)
        ValueLabel.Text = tostring(value)
        callback(value)
    end
    
    Trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            UpdateSlide(input)
        end
    end)
    
    game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            UpdateSlide(input)
        end
    end)
    
    return {
        SetValue = function(val)
            local constrained = math.clamp(val, min, max)
            local alpha = (constrained - min) / (max - min)
            Fill.Size = UDim2.new(alpha, 0, 1, 0)
            ValueLabel.Text = tostring(constrained)
        end
    }
end

-- [[ CUSTOM ANIMATION PRESET ROW ]] --
local function CreatePresetRow(page, animName, animType)
    local Row = Instance.new("Frame")
    Row.Parent = page
    Row.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
    Row.BackgroundTransparency = 0.5
    Row.Size = UDim2.new(1, 0, 0, 45)
    local RCorner = Instance.new("UICorner"); RCorner.CornerRadius = UDim.new(0, 6); RCorner.Parent = Row
    
    local Icon = Instance.new("TextLabel")
    Icon.Parent = Row
    Icon.BackgroundTransparency = 1
    Icon.Position = UDim2.new(0, 10, 0, 0)
    Icon.Size = UDim2.new(0, 20, 1, 0)
    Icon.Font = Enum.Font.GothamBold
    Icon.Text = "●"
    Icon.TextColor3 = Color3.fromRGB(255, 255, 255)
    Icon.TextSize = 12
    
    local Label = Instance.new("TextLabel")
    Label.Parent = Row
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 35, 0, 0)
    Label.Size = UDim2.new(0.5, 0, 1, 0)
    Label.Font = Enum.Font.GothamMedium
    Label.Text = animName
    Label.TextColor3 = Color3.fromRGB(220, 220, 220)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    
    local InputFrame = Instance.new("Frame")
    InputFrame.Parent = Row
    InputFrame.AnchorPoint = Vector2.new(1, 0.5)
    InputFrame.Position = UDim2.new(1, -10, 0.5, 0)
    InputFrame.Size = UDim2.new(0, 120, 0, 30)
    InputFrame.BackgroundColor3 = CurrentTheme.Input
    RegisterThemeObj("Inputs", InputFrame)
    
    local ICorner = Instance.new("UICorner"); ICorner.CornerRadius = UDim.new(0, 6); ICorner.Parent = InputFrame
    local IStroke = Instance.new("UIStroke"); IStroke.Color = Color3.fromRGB(50, 50, 55); IStroke.Parent = InputFrame
    
    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Parent = InputFrame
    ValueLabel.Size = UDim2.new(1, -20, 1, 0)
    ValueLabel.Position = UDim2.new(0, 10, 0, 0)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Font = Enum.Font.Gotham
    ValueLabel.Text = "Original"
    ValueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    ValueLabel.TextSize = 13
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local Arrow = Instance.new("ImageLabel")
    Arrow.Parent = InputFrame
    Arrow.BackgroundTransparency = 1
    Arrow.AnchorPoint = Vector2.new(1, 0.5)
    Arrow.Position = UDim2.new(1, -5, 0.5, 0)
    Arrow.Size = UDim2.new(0, 16, 0, 16)
    Arrow.Image = "rbxassetid://6034818372"
    Arrow.ImageColor3 = CurrentTheme.Accent
    RegisterThemeObj("Images", Arrow)

    local ClickBtn = Instance.new("TextButton")
    ClickBtn.Parent = InputFrame
    ClickBtn.Size = UDim2.new(1, 0, 1, 0)
    ClickBtn.BackgroundTransparency = 1
    ClickBtn.Text = ""
    
    local currentIndex = 1
    ClickBtn.MouseButton1Click:Connect(function()
        currentIndex = currentIndex + 1
        if currentIndex > #AnimNames then currentIndex = 1 end
        local selectedPreset = AnimNames[currentIndex]
        ValueLabel.Text = selectedPreset
        ChangeAnimation(animType, selectedPreset)
    end)
    return Row
end

-- Dragging
local Dragging, DragInput, DragStart, StartPos
Main.InputBegan:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = true; DragStart = Input.Position; StartPos = Main.Position end end)
Main.InputChanged:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseMovement then DragInput = Input end end)
game:GetService("UserInputService").InputChanged:Connect(function(Input) if Input == DragInput and Dragging then local Delta = Input.Position - DragStart; Main.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y) end end)
game:GetService("UserInputService").InputEnded:Connect(function(Input) if Input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end end)
game:GetService("UserInputService").InputBegan:Connect(function(input, gp) if not gp and input.KeyCode == Enum.KeyCode.RightControl then Main.Visible = not Main.Visible end end)

--------------------------------------------------------------------------------
-- 4. LINKING LOGIC TO UI
--------------------------------------------------------------------------------
local TabHome = CreateTab("Home")
local TabMain = CreateTab("Main Script")
local TabPlayer = CreateTab("Target")
local TabLocal = CreateTab("Local Player")
local TabAnim = CreateTab("Animations")
local TabMisc = CreateTab("Misc")

-- [[ HOME TAB ]] --
local HomeContainer = Instance.new("Frame"); HomeContainer.Parent = TabHome; HomeContainer.BackgroundTransparency = 1; HomeContainer.Size = UDim2.new(1, 0, 1, 0)
local UserImg = Instance.new("ImageLabel"); UserImg.Parent = HomeContainer; UserImg.BackgroundColor3 = Color3.fromRGB(30,30,30); UserImg.Size = UDim2.new(0, 70, 0, 70); UserImg.Position = UDim2.new(0, 5, 0, 10); UserImg.Image = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
local CornerImg = Instance.new("UICorner"); CornerImg.CornerRadius = UDim.new(1,0); CornerImg.Parent = UserImg; local StrokeImg = Instance.new("UIStroke"); StrokeImg.Color = CurrentTheme.Accent; StrokeImg.Parent = UserImg; RegisterThemeObj("Strokes", StrokeImg)
local Welcome = Instance.new("TextLabel"); Welcome.Parent = HomeContainer; Welcome.BackgroundTransparency = 1; Welcome.Position = UDim2.new(0, 85, 0, 20); Welcome.Size = UDim2.new(0, 200, 0, 30); Welcome.Font = Enum.Font.GothamBold; Welcome.TextColor3 = Color3.fromRGB(255,255,255); Welcome.TextSize = 18; Welcome.Text = "Welcome, " .. plr.DisplayName; Welcome.TextXAlignment = Enum.TextXAlignment.Left
local InfoFrame = Instance.new("Frame"); InfoFrame.Parent = HomeContainer; InfoFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30); InfoFrame.Position = UDim2.new(0, 5, 0, 95); InfoFrame.Size = UDim2.new(1, -10, 0, 160); local InfoCorner = Instance.new("UICorner"); InfoCorner.CornerRadius = UDim.new(0, 6); InfoCorner.Parent = InfoFrame; local InfoStroke = Instance.new("UIStroke"); InfoStroke.Color = Color3.fromRGB(40,40,40); InfoStroke.Parent = InfoFrame
local function CreateInfoLabel(text, order) local Lbl = Instance.new("TextLabel"); Lbl.Parent = InfoFrame; Lbl.BackgroundTransparency = 1; Lbl.Size = UDim2.new(1, -20, 0, 25); Lbl.Position = UDim2.new(0, 10, 0, 10 + (order * 25)); Lbl.Font = Enum.Font.GothamMedium; Lbl.TextColor3 = Color3.fromRGB(200, 200, 200); Lbl.TextSize = 13; Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Text = text; return Lbl end

local JoinDate = os.date("%d/%m/%Y", os.time() - (plr.AccountAge * 86400))
CreateInfoLabel("• User ID: " .. plr.UserId, 0)
CreateInfoLabel("• Account Age: " .. plr.AccountAge .. " Days", 1)
CreateInfoLabel("• Join Date: " .. JoinDate, 2)
local DateLbl = CreateInfoLabel("• Date: " .. os.date("%A, %d %B %Y"), 3)
local TimeLbl = CreateInfoLabel("• Session Time: 00:00:00", 4)

task.spawn(function()
    local startTime = os.time()
    while ScreenGui.Parent do
        local diff = os.time() - startTime; local h = math.floor(diff / 3600); local m = math.floor((diff % 3600) / 60); local s = diff % 60
        TimeLbl.Text = string.format("• Session Time: %02d:%02d:%02d", h, m, s)
        DateLbl.Text = "• Date: " .. os.date("%A, %d %B %Y")
        task.wait(1)
    end
end)
local ExitBtn = Instance.new("TextButton"); ExitBtn.Parent = HomeContainer; ExitBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50); ExitBtn.Position = UDim2.new(0, 5, 0, 270); ExitBtn.Size = UDim2.new(1, -10, 0, 35); ExitBtn.Font = Enum.Font.GothamBold; ExitBtn.Text = "DESTROY UI"; ExitBtn.TextColor3 = Color3.fromRGB(255,255,255); ExitBtn.TextSize = 14; local ECorner = Instance.new("UICorner"); ECorner.CornerRadius = UDim.new(0,6); ECorner.Parent = ExitBtn
ExitBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- [MAIN SCRIPT (UPDATED TO UNIVERSAL STYLE)]
local WalkSpeedVal = 16
local JumpPowerVal = 50
local SpeedEnabled = false
local JumpEnabled = false
local NoclipEnabled = false
local TapTpEnabled = false

local function LoopSpeed()
    while ScreenGui.Parent do
        if SpeedEnabled and plr.Character and plr.Character:FindFirstChild("Humanoid") then
            plr.Character.Humanoid.WalkSpeed = WalkSpeedVal
        end
        if JumpEnabled and plr.Character and plr.Character:FindFirstChild("Humanoid") then
            plr.Character.Humanoid.JumpPower = JumpPowerVal
        end
        task.wait()
    end
end
task.spawn(LoopSpeed)

-- 1. Enable Speed Toggle
CreateToggle(TabMain, "Enable Speed", function(state)
    SpeedEnabled = state
    if not state and plr.Character and plr.Character:FindFirstChild("Humanoid") then
        plr.Character.Humanoid.WalkSpeed = 16
    end
end)

-- 2. Enable Jump Toggle
CreateToggle(TabMain, "Enable Jump Power", function(state)
    JumpEnabled = state
    if not state and plr.Character and plr.Character:FindFirstChild("Humanoid") then
        plr.Character.Humanoid.JumpPower = 50
    end
end)

-- 3. Speed Textbox & Slider
local SpeedSlider -- Forward declaration
local SpeedBox = CreateInput(TabMain, "Speed Value", function(text, boxObj)
    local num = tonumber(text)
    if num then
        WalkSpeedVal = num
        if SpeedSlider then SpeedSlider.SetValue(num) end -- Sync Slider
    end
end, "16")

SpeedSlider = CreateSlider(TabMain, "Walkspeed Slider", 16, 500, 16, function(val)
    WalkSpeedVal = val
    SpeedBox.Text = tostring(val) -- Sync Textbox
end)

-- 4. Jump Power Textbox & Slider
local JumpSlider -- Forward declaration
local JumpBox = CreateInput(TabMain, "Jump Power Value", function(text, boxObj)
    local num = tonumber(text)
    if num then
        JumpPowerVal = num
        if JumpSlider then JumpSlider.SetValue(num) end -- Sync Slider
    end
end, "50")

JumpSlider = CreateSlider(TabMain, "Jump Power Slider", 50, 500, 50, function(val)
    JumpPowerVal = val
    JumpBox.Text = tostring(val) -- Sync Textbox
end)

-- 5. Noclip
CreateToggle(TabMain, "Noclip Toggle", function(state)
    NoclipEnabled = state
    if state then
        task.spawn(function()
            while NoclipEnabled and ScreenGui.Parent do
                if plr.Character then
                    for _, v in pairs(plr.Character:GetDescendants()) do
                        if v:IsA("BasePart") and v.CanCollide == true then
                            v.CanCollide = false
                        end
                    end
                end
                RunService.Stepped:Wait()
            end
        end)
    end
end)

-- 6. Tap Teleport
CreateToggle(TabMain, "Tap Teleport (Ctrl+Click)", function(state)
    TapTpEnabled = state
end)

mouse.Button1Down:Connect(function()
    if TapTpEnabled and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local pos = mouse.Hit + Vector3.new(0, 2.5, 0)
        local root = GetRoot(plr)
        if root then
            root.CFrame = CFrame.new(pos.Position)
        end
    end
end)

CreateButton(TabMain, "Reset Physics (Fix Float)", function()
    if plr.Character and plr.Character:FindFirstChild("Humanoid") then
        for _, v in pairs(plr.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.Velocity = Vector3.zero end
        end
    end
end)


-- [TARGET TAB]
local TargetIconContainer = Instance.new("Frame"); TargetIconContainer.Parent = TabPlayer; TargetIconContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25); TargetIconContainer.Size = UDim2.new(1, 0, 0, 100); local TargetIconCorner = Instance.new("UICorner"); TargetIconCorner.CornerRadius = UDim.new(0,6); TargetIconCorner.Parent = TargetIconContainer
local TargetIcon = Instance.new("ImageLabel"); TargetIcon.Parent = TargetIconContainer; TargetIcon.BackgroundColor3 = Color3.fromRGB(30, 30, 35); TargetIcon.Size = UDim2.new(0, 80, 0, 80); TargetIcon.Position = UDim2.new(0, 10, 0, 10); TargetIcon.Image = "rbxassetid://10818605405"; local TI_Corner = Instance.new("UICorner"); TI_Corner.CornerRadius = UDim.new(1,0); TI_Corner.Parent = TargetIcon
local TargetInfoLabel = Instance.new("TextLabel"); TargetInfoLabel.Parent = TargetIconContainer; TargetInfoLabel.BackgroundTransparency = 1; TargetInfoLabel.Position = UDim2.new(0, 100, 0, 10); TargetInfoLabel.Size = UDim2.new(1, -110, 1, -20); TargetInfoLabel.Font = Enum.Font.GothamMedium; TargetInfoLabel.TextColor3 = Color3.fromRGB(200, 200, 200); TargetInfoLabel.TextSize = 12; TargetInfoLabel.TextXAlignment = Enum.TextXAlignment.Left; TargetInfoLabel.TextYAlignment = Enum.TextYAlignment.Top; TargetInfoLabel.Text = "No Target Selected"; TargetInfoLabel.TextWrapped = true

local function UpdateTargetDisplay(p)
    if p then
        local tAge = p.AccountAge
        local tJoinDate = os.date("%d/%m/%Y", os.time() - (tAge * 86400))
        TargetInfoLabel.Text = string.format("Name: %s\nDisp: %s\nAge: %s Days\nJoined: %s", p.Name, p.DisplayName, tAge, tJoinDate)
        TargetedPlayer = p.Name
        task.spawn(function() local thumb = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420); TargetIcon.Image = thumb end)
    else
        TargetInfoLabel.Text = "No Target Selected"; TargetedPlayer = nil; TargetIcon.Image = "rbxassetid://10818605405"
    end
end
CreateInput(TabPlayer, "Type username...", function(text) local t = GetPlayer(text); if t then UpdateTargetDisplay(t) else SendNotify("System", "Not found", 2) end end)
CreateButton(TabPlayer, "Select Tool (Click Player)", function()
    local GetTargetTool = Instance.new("Tool"); GetTargetTool.Name = "ClickTarget"; GetTargetTool.RequiresHandle = false; GetTargetTool.TextureId = "rbxassetid://2716591855"; GetTargetTool.Parent = plr.Backpack
    GetTargetTool.Activated:Connect(function() local hit = mouse.Target; if hit and hit.Parent then local p = Players:GetPlayerFromCharacter(hit.Parent) or Players:GetPlayerFromCharacter(hit.Parent.Parent); if p then UpdateTargetDisplay(p) end end end)
    SendNotify("System", "Check Backpack for ClickTarget", 3)
end)

-- [[ FIXED BACKPACK LOGIC ]] --
CreateToggle(TabPlayer, "Backpack (Sit on Back)", function(state)
    BackpackEnabled = state
    if state then
        SitHeadEnabled = false 
        task.spawn(function()
            while BackpackEnabled and TargetedPlayer and Players:FindFirstChild(TargetedPlayer) and ScreenGui.Parent do
                pcall(function()
                    local tRoot = GetRoot(Players[TargetedPlayer]); local myRoot = GetRoot(plr)
                    if tRoot and myRoot then
                        if not GetRoot(plr):FindFirstChild("BreakVelocity") then
                             local bv = Instance.new("BodyAngularVelocity", myRoot); bv.Name = "BreakVelocity"; bv.MaxTorque = Vector3.new(50000,50000,50000); bv.P = 1250
                        end
                        plr.Character.Humanoid.Sit = true
                        myRoot.CFrame = tRoot.CFrame * CFrame.new(0,0,1.5)
                        myRoot.Velocity = Vector3.new(0,0,0)
                    end
                end)
                task.wait()
            end
            StopCarry()
        end)
    else StopCarry() end
end)

-- [[ NEW SIT HEAD LOGIC ]] --
CreateToggle(TabPlayer, "Sit on Head", function(state)
    SitHeadEnabled = state
    if state then
        BackpackEnabled = false
        task.spawn(function()
            while SitHeadEnabled and TargetedPlayer and Players:FindFirstChild(TargetedPlayer) and ScreenGui.Parent do
                pcall(function()
                    local tRoot = GetRoot(Players[TargetedPlayer]); local myRoot = GetRoot(plr)
                    if tRoot and myRoot then
                        if not GetRoot(plr):FindFirstChild("BreakVelocity") then
                             local bv = Instance.new("BodyAngularVelocity", myRoot); bv.Name = "BreakVelocity"; bv.MaxTorque = Vector3.new(50000,50000,50000); bv.P = 1250
                        end
                        plr.Character.Humanoid.Sit = true
                        myRoot.CFrame = tRoot.CFrame * CFrame.new(0, 2.5, 0)
                        myRoot.Velocity = Vector3.new(0,0,0)
                    end
                end)
                task.wait()
            end
            StopCarry()
        end)
    else StopCarry() end
end)

CreateButton(TabPlayer, "Teleport to Target", function() if TargetedPlayer and Players[TargetedPlayer] then TeleportTO(0,0,0,Players[TargetedPlayer],"safe") end end)
CreateButton(TabPlayer, "Fling Target", function()
    if TargetedPlayer and Players[TargetedPlayer] then
        local OldPos = GetRoot(plr).Position; local T = Players[TargetedPlayer]; local root = GetRoot(plr)
        if T and T.Character and root then
            local bambam = Instance.new("BodyAngularVelocity"); bambam.Name = "FlingVelocity"; bambam.Parent = root; bambam.AngularVelocity = Vector3.new(0,99999,0); bambam.MaxTorque = Vector3.new(0,math.huge,0); bambam.P = math.huge
            for i=1, 20 do task.wait(); local tRoot = GetRoot(T); if tRoot then root.CFrame = tRoot.CFrame * CFrame.new(0,0,0); root.Velocity = Vector3.new(0,0,0) end end
            bambam:Destroy(); root.Velocity = Vector3.new(0,0,0); root.RotVelocity = Vector3.new(0,0,0); TeleportTO(OldPos.X,OldPos.Y,OldPos.Z,"pos","safe")
        end
    end
end)
CreateButton(TabPlayer, "Push Target", function() if TargetedPlayer and Players[TargetedPlayer] then local root = GetRoot(plr); if root then local pushpos = root.CFrame; PredictionTP(Players[TargetedPlayer]); task.wait(GetPing()+0.05); Push(Players[TargetedPlayer]); root.CFrame = pushpos end end end)

-- [LOCAL PLAYER TAB]
local FlySpeed = 50
local flying = false; local flybv, flybg
CreateToggle(TabLocal, "Fly Mode (Superman)", function(state)
    flying = state; local root = GetRoot(plr)
    local human = plr.Character and plr.Character:FindFirstChild("Humanoid")
    if state and root then
        flybv = Instance.new("BodyVelocity", root); flybv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); flybv.Velocity = Vector3.new(0,0,0)
        flybg = Instance.new("BodyGyro", root); flybg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); flybg.P = 10000
        if human then human.PlatformStand = true end
        task.spawn(function()
            while flying and root do
                local cam = workspace.CurrentCamera; 
                flybg.CFrame = cam.CFrame * CFrame.Angles(math.rad(-90), 0, 0)
                local vel = Vector3.new(0,0,0); local uis = game:GetService("UserInputService")
                if uis:IsKeyDown(Enum.KeyCode.W) then vel = vel + cam.CFrame.LookVector * FlySpeed end
                if uis:IsKeyDown(Enum.KeyCode.S) then vel = vel - cam.CFrame.LookVector * FlySpeed end
                if uis:IsKeyDown(Enum.KeyCode.D) then vel = vel + cam.CFrame.RightVector * FlySpeed end
                if uis:IsKeyDown(Enum.KeyCode.A) then vel = vel - cam.CFrame.RightVector * FlySpeed end
                flybv.Velocity = vel; task.wait()
            end
        end)
    else
        if flybv then flybv:Destroy() end; if flybg then flybg:Destroy() end; 
        if root then root.Velocity = Vector3.new(0,0,0) end
        if human then human.PlatformStand = false end
    end
end)
CreateButton(TabLocal, "Respawn Character", function() local root = GetRoot(plr); if root then local RsP = root.Position; plr.Character.Humanoid.Health = 0; plr.CharacterAdded:wait(); task.wait(1); TeleportTO(RsP.X,RsP.Y,RsP.Z,"pos","safe") end end)

-- [ANIMATIONS TAB - REDESIGNED]
local AnimHeader = Instance.new("Frame")
AnimHeader.Parent = TabAnim
AnimHeader.BackgroundTransparency = 1
AnimHeader.Size = UDim2.new(1, 0, 0, 80)
local AH_Title = Instance.new("TextLabel")
AH_Title.Parent = AnimHeader
AH_Title.BackgroundTransparency = 1
AH_Title.Size = UDim2.new(1, 0, 0, 25)
AH_Title.Font = Enum.Font.GothamBold
AH_Title.Text = "Animation Preset"
AH_Title.TextColor3 = Color3.fromRGB(255, 255, 255)
AH_Title.TextSize = 16
AH_Title.TextXAlignment = Enum.TextXAlignment.Left

local AH_Desc = Instance.new("TextLabel")
AH_Desc.Parent = AnimHeader
AH_Desc.BackgroundTransparency = 1
AH_Desc.Position = UDim2.new(0, 0, 0, 25)
AH_Desc.Size = UDim2.new(1, 0, 0, 50)
AH_Desc.Font = Enum.Font.Gotham
AH_Desc.Text = "Berfungsi untuk mengubah animasi mulai dari idle, jalan, lompat dan jatuh tanpa harus beli robux."
AH_Desc.TextColor3 = Color3.fromRGB(150, 150, 150)
AH_Desc.TextSize = 12
AH_Desc.TextXAlignment = Enum.TextXAlignment.Left
AH_Desc.TextWrapped = true

CreatePresetRow(TabAnim, "Idle Animation", "Idle")
CreatePresetRow(TabAnim, "Walk Animation", "Walk")
CreatePresetRow(TabAnim, "Run Animation", "Run")
CreatePresetRow(TabAnim, "Jump Animation", "Jump")
CreatePresetRow(TabAnim, "Climb Animation", "Climb")
CreatePresetRow(TabAnim, "Fall Animation", "Fall")

local ResetBtn = CreateButton(TabAnim, "Reset Animation", function()
    local root = GetRoot(plr); 
    if root then 
        local RsP = root.Position; 
        plr.Character.Humanoid.Health = 0; 
        plr.CharacterAdded:wait(); 
        task.wait(1); 
        TeleportTO(RsP.X,RsP.Y,RsP.Z,"pos","safe") 
    end
end)
local rbFrame = ResetBtn 
rbFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
rbFrame.BackgroundTransparency = 0.5

-- [MISC TAB - THEME SWITCHER]
local ThemeLabel = Instance.new("TextLabel")
ThemeLabel.Parent = TabMisc
ThemeLabel.BackgroundTransparency = 1
ThemeLabel.Size = UDim2.new(1, 0, 0, 30)
ThemeLabel.Font = Enum.Font.GothamBold
ThemeLabel.Text = "SELECT THEME"
ThemeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
ThemeLabel.TextSize = 14

local function CreateThemeBtn(name, main, sidebar, accent, text)
    CreateButton(TabMisc, "Theme: " .. name, function()
        ApplyTheme({Main=main, Sidebar=sidebar, Accent=accent, Text=text, SubText=Color3.fromRGB(150,150,150), Input=Color3.fromRGB(30,30,35)})
        for id, btn in pairs(TabButtons) do if btn.BackgroundTransparency == 0 then btn.TextColor3 = accent end end
    end)
end

CreateThemeBtn("Matrix (Default)", Color3.fromRGB(15, 15, 18), Color3.fromRGB(20, 20, 24), Color3.fromRGB(0, 255, 128), Color3.fromRGB(255, 255, 255))
CreateThemeBtn("Blood Red", Color3.fromRGB(20, 10, 10), Color3.fromRGB(30, 15, 15), Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 255, 255))
CreateThemeBtn("Deep Ocean", Color3.fromRGB(10, 15, 25), Color3.fromRGB(15, 20, 35), Color3.fromRGB(0, 150, 255), Color3.fromRGB(255, 255, 255))
CreateThemeBtn("Royal Purple", Color3.fromRGB(20, 10, 25), Color3.fromRGB(30, 15, 35), Color3.fromRGB(170, 0, 255), Color3.fromRGB(255, 255, 255))
CreateThemeBtn("Sunset Orange", Color3.fromRGB(25, 15, 10), Color3.fromRGB(35, 20, 15), Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 255, 255))

CreateButton(TabMisc, "Rejoin Server", function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, plr) end)
CreateButton(TabMisc, "Infinite Yield", function() loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))() end)

SwitchTab("Home")
SendNotify("Kitaroriel Remake", "System Ready!", 5)
