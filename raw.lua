--[[
    Modern Roblox UI Library - FIXED UIListLayout Issue
    Fixed UIListLayout creation and access
]]

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Get appropriate parent (for different executors)
local function getParent()
    if gethui then
        return gethui()
    elseif syn and syn.protect_gui then
        local gui = Instance.new("ScreenGui")
        syn.protect_gui(gui)
        gui.Parent = CoreGui
        return gui
    else
        return CoreGui
    end
end

-- Constants
local LIBRARY_NAME = "ModernUILibrary"
local CONFIG_FILE_NAME = "ModernUI_Config.json"

-- Main Library Object
local Library = {
    Windows = {},
    Notifications = {},
    Config = {},
    Theme = {},
    Flags = {},
    Connections = {}
}

-- Utility Functions
local Utility = {}

function Utility:CreateInstance(className, properties, parent)
    local instance = Instance.new(className)
    
    for property, value in pairs(properties or {}) do
        if property ~= "Parent" then
            pcall(function()
                instance[property] = value
            end)
        end
    end
    
    if parent then
        instance.Parent = parent
    end
    
    return instance
end

function Utility:TweenObject(object, properties, duration, style, direction)
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    
    local tween = TweenService:Create(object, tweenInfo, properties)
    tween:Play()
    return tween
end

function Utility:Connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Library.Connections, connection)
    return connection
end

function Utility:Round(number, decimals)
    local mult = 10^(decimals or 0)
    return math.floor(number * mult + 0.5) / mult
end

-- Theme System
local ThemeManager = {}

ThemeManager.DefaultTheme = {
    -- Primary Colors
    Primary = Color3.fromRGB(24, 24, 24),
    Secondary = Color3.fromRGB(32, 32, 32),
    Tertiary = Color3.fromRGB(40, 40, 40),
    
    -- Accent Colors
    Accent = Color3.fromRGB(100, 150, 255),
    AccentHover = Color3.fromRGB(120, 170, 255),
    AccentActive = Color3.fromRGB(80, 130, 235),
    
    -- Text Colors
    TextPrimary = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(180, 180, 180),
    TextTertiary = Color3.fromRGB(120, 120, 120),
    
    -- Status Colors
    Success = Color3.fromRGB(80, 200, 120),
    Warning = Color3.fromRGB(255, 180, 60),
    Error = Color3.fromRGB(255, 100, 100),
    
    -- UI Properties
    CornerRadius = UDim.new(0, 8),
    FontSize = 14,
    Font = Enum.Font.Gotham,
    
    -- Transparency
    BackgroundTransparency = 0,
    ElementTransparency = 0.05,
    
    -- Stroke
    StrokeColor = Color3.fromRGB(60, 60, 60),
    StrokeTransparency = 0.5
}

function ThemeManager:GetTheme()
    return Library.Theme
end

function ThemeManager:SetTheme(newTheme)
    for key, value in pairs(newTheme) do
        Library.Theme[key] = value
    end
    
    -- Update all existing UI elements
    for _, window in pairs(Library.Windows) do
        if window.UpdateTheme then
            window:UpdateTheme()
        end
    end
end

function ThemeManager:Initialize()
    Library.Theme = {}
    for key, value in pairs(self.DefaultTheme) do
        Library.Theme[key] = value
    end
end

-- Configuration Management
local ConfigManager = {}

function ConfigManager:SaveConfig()
    if not writefile then
        warn("Executor doesn't support file operations")
        return false
    end
    
    local configData = {}
    
    for flag, value in pairs(Library.Flags) do
        configData[flag] = value
    end
    
    local success, result = pcall(function()
        return HttpService:JSONEncode(configData)
    end)
    
    if success then
        writefile(CONFIG_FILE_NAME, result)
        return true
    else
        warn("Failed to save config: " .. tostring(result))
        return false
    end
end

function ConfigManager:LoadConfig()
    if not isfile or not readfile then
        warn("Executor doesn't support file operations")
        return false
    end
    
    if isfile(CONFIG_FILE_NAME) then
        local success, result = pcall(function()
            local data = readfile(CONFIG_FILE_NAME)
            return HttpService:JSONDecode(data)
        end)
        
        if success then
            for flag, value in pairs(result) do
                Library.Flags[flag] = value
            end
            
            -- Update all UI elements with loaded values
            for _, window in pairs(Library.Windows) do
                if window.LoadConfigValues then
                    window:LoadConfigValues()
                end
            end
            
            return true
        else
            warn("Failed to load config: " .. tostring(result))
        end
    end
    
    return false
end

function ConfigManager:SetFlag(flag, value)
    Library.Flags[flag] = value
end

function ConfigManager:GetFlag(flag, default)
    return Library.Flags[flag] or default
end

-- Component Base Class
local Component = {}
Component.__index = Component

function Component:New(componentType)
    local self = setmetatable({}, Component)
    self.Type = componentType
    self.Children = {}
    self.Parent = nil
    self.Visible = true
    self.Callbacks = {}
    return self
end

function Component:SetCallback(name, callback)
    self.Callbacks[name] = callback
end

function Component:InvokeCallback(name, ...)
    if self.Callbacks[name] then
        return self.Callbacks[name](...)
    end
end

function Component:UpdateTheme()
    for _, child in ipairs(self.Children) do
        if child.UpdateTheme then
            child:UpdateTheme()
        end
    end
end

-- Forward declare all component classes
local Toggle = {}
local Button = {}
local Slider = {}
local Label = {}
local Section = {}
local Tab = {}
local Window = {}

-- Toggle Component
Toggle.__index = Toggle
setmetatable(Toggle, {__index = Component})

function Toggle:New(options, section)
    local self = setmetatable(Component:New("Toggle"), Toggle)
    
    self.Name = options.Name or "Toggle"
    self.Flag = options.Flag
    self.Default = options.Default or false
    self.Section = section
    self.State = self.Default
    
    if self.Flag then
        self.State = ConfigManager:GetFlag(self.Flag, self.Default)
    end
    
    self:SetCallback("Callback", options.Callback)
    self:CreateGUI()
    self:SetState(self.State)
    
    return self
end

function Toggle:CreateGUI()
    -- Main Container
    self.Container = Utility:CreateInstance("Frame", {
        Name = self.Name,
        Size = UDim2.new(1, -20, 0, 35),
        BackgroundColor3 = Library.Theme.Tertiary,
        BorderSizePixel = 0,
        Parent = self.Section.ElementContainer
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = self.Container
    })
    
    -- Toggle Button
    self.Button = Utility:CreateInstance("TextButton", {
        Name = "Button",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Parent = self.Container
    })
    
    -- Toggle Label
    self.Label = Utility:CreateInstance("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Name,
        TextColor3 = Library.Theme.TextPrimary,
        TextSize = Library.Theme.FontSize,
        Font = Library.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.Container
    })
    
    -- Toggle Switch
    self.Switch = Utility:CreateInstance("Frame", {
        Name = "Switch",
        Size = UDim2.new(0, 40, 0, 20),
        Position = UDim2.new(1, -50, 0, 7),
        BackgroundColor3 = Library.Theme.Tertiary,
        BorderSizePixel = 0,
        Parent = self.Container
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 10),
        Parent = self.Switch
    })
    
    -- Toggle Knob
    self.Knob = Utility:CreateInstance("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Library.Theme.TextSecondary,
        BorderSizePixel = 0,
        Parent = self.Switch
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 8),
        Parent = self.Knob
    })
    
    -- Click handler
    Utility:Connect(self.Button.MouseButton1Click, function()
        self:SetState(not self.State)
    end)
end

function Toggle:SetState(state)
    self.State = state
    
    if self.Flag then
        ConfigManager:SetFlag(self.Flag, state)
    end
    
    -- Update visual state
    if state then
        self.Switch.BackgroundColor3 = Library.Theme.Accent
        self.Knob.BackgroundColor3 = Library.Theme.TextPrimary
        Utility:TweenObject(self.Knob, {Position = UDim2.new(0, 22, 0, 2)}, 0.2)
    else
        self.Switch.BackgroundColor3 = Library.Theme.Tertiary
        self.Knob.BackgroundColor3 = Library.Theme.TextSecondary
        Utility:TweenObject(self.Knob, {Position = UDim2.new(0, 2, 0, 2)}, 0.2)
    end
    
    -- Invoke callback
    self:InvokeCallback("Callback", state)
end

function Toggle:UpdateTheme()
    if not self.Container then return end
    
    self.Container.BackgroundColor3 = Library.Theme.Tertiary
    self.Label.TextColor3 = Library.Theme.TextPrimary
    self:SetState(self.State)
    
    Component.UpdateTheme(self)
end

function Toggle:LoadConfigValue()
    if self.Flag then
        local value = ConfigManager:GetFlag(self.Flag, self.Default)
        self:SetState(value)
    end
end

-- Button Component
Button.__index = Button
setmetatable(Button, {__index = Component})

function Button:New(options, section)
    local self = setmetatable(Component:New("Button"), Button)
    
    self.Name = options.Name or "Button"
    self.Section = section
    
    self:SetCallback("Callback", options.Callback)
    self:CreateGUI()
    
    return self
end

function Button:CreateGUI()
    -- Main Container
    self.Container = Utility:CreateInstance("TextButton", {
        Name = self.Name,
        Size = UDim2.new(1, -20, 0, 35),
        BackgroundColor3 = Library.Theme.Accent,
        BorderSizePixel = 0,
        Text = "",
        Parent = self.Section.ElementContainer
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = self.Container
    })
    
    -- Button Label
    self.Label = Utility:CreateInstance("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Name,
        TextColor3 = Library.Theme.TextPrimary,
        TextSize = Library.Theme.FontSize,
        Font = Library.Theme.Font,
        Parent = self.Container
    })
    
    -- Hover effects
    Utility:Connect(self.Container.MouseEnter, function()
        Utility:TweenObject(self.Container, {BackgroundColor3 = Library.Theme.AccentHover}, 0.2)
    end)
    
    Utility:Connect(self.Container.MouseLeave, function()
        Utility:TweenObject(self.Container, {BackgroundColor3 = Library.Theme.Accent}, 0.2)
    end)
    
    -- Click handler
    Utility:Connect(self.Container.MouseButton1Click, function()
        Utility:TweenObject(self.Container, {BackgroundColor3 = Library.Theme.AccentActive}, 0.1)
        task.spawn(function()
            task.wait(0.1)
            Utility:TweenObject(self.Container, {BackgroundColor3 = Library.Theme.AccentHover}, 0.1)
        end)
        
        self:InvokeCallback("Callback")
    end)
end

function Button:UpdateTheme()
    if not self.Container then return end
    
    self.Container.BackgroundColor3 = Library.Theme.Accent
    self.Label.TextColor3 = Library.Theme.TextPrimary
    
    Component.UpdateTheme(self)
end

-- Slider Component
Slider.__index = Slider
setmetatable(Slider, {__index = Component})

function Slider:New(options, section)
    local self = setmetatable(Component:New("Slider"), Slider)
    
    self.Name = options.Name or "Slider"
    self.Flag = options.Flag
    self.Min = options.Min or 0
    self.Max = options.Max or 100
    self.Default = options.Default or self.Min
    self.Decimals = options.Decimals or 0
    self.Units = options.Units or ""
    self.Section = section
    self.Value = self.Default
    
    if self.Flag then
        self.Value = ConfigManager:GetFlag(self.Flag, self.Default)
    end
    
    self:SetCallback("Callback", options.Callback)
    self:CreateGUI()
    self:SetValue(self.Value)
    
    return self
end

function Slider:CreateGUI()
    -- Main Container
    self.Container = Utility:CreateInstance("Frame", {
        Name = self.Name,
        Size = UDim2.new(1, -20, 0, 50),
        BackgroundColor3 = Library.Theme.Tertiary,
        BorderSizePixel = 0,
        Parent = self.Section.ElementContainer
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = self.Container
    })
    
    -- Slider Label
    self.Label = Utility:CreateInstance("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -80, 0, 20),
        Position = UDim2.new(0, 15, 0, 5),
        BackgroundTransparency = 1,
        Text = self.Name,
        TextColor3 = Library.Theme.TextPrimary,
        TextSize = Library.Theme.FontSize,
        Font = Library.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.Container
    })
    
    -- Value Label
    self.ValueLabel = Utility:CreateInstance("TextLabel", {
        Name = "Value",
        Size = UDim2.new(0, 60, 0, 20),
        Position = UDim2.new(1, -75, 0, 5),
        BackgroundTransparency = 1,
        Text = tostring(self.Value) .. self.Units,
        TextColor3 = Library.Theme.TextSecondary,
        TextSize = Library.Theme.FontSize,
        Font = Library.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = self.Container
    })
    
    -- Slider Track
    self.Track = Utility:CreateInstance("Frame", {
        Name = "Track",
        Size = UDim2.new(1, -30, 0, 6),
        Position = UDim2.new(0, 15, 0, 32),
        BackgroundColor3 = Library.Theme.Primary,
        BorderSizePixel = 0,
        Parent = self.Container
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 3),
        Parent = self.Track
    })
    
    -- Slider Fill
    self.Fill = Utility:CreateInstance("Frame", {
        Name = "Fill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Library.Theme.Accent,
        BorderSizePixel = 0,
        Parent = self.Track
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 3),
        Parent = self.Fill
    })
    
    -- Input handling
    local dragging = false
    
    Utility:Connect(self.Track.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            self:UpdateFromInput(input.Position.X)
        end
    end)
    
    Utility:Connect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            self:UpdateFromInput(input.Position.X)
        end
    end)
    
    Utility:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

function Slider:UpdateFromInput(inputX)
    local trackX = self.Track.AbsolutePosition.X
    local trackWidth = self.Track.AbsoluteSize.X
    local relativeX = math.clamp(inputX - trackX, 0, trackWidth)
    local percentage = relativeX / trackWidth
    
    local newValue = self.Min + (self.Max - self.Min) * percentage
    newValue = Utility:Round(newValue, self.Decimals)
    
    self:SetValue(newValue)
end

function Slider:SetValue(value)
    self.Value = math.clamp(value, self.Min, self.Max)
    
    if self.Flag then
        ConfigManager:SetFlag(self.Flag, self.Value)
    end
    
    -- Update visual
    local percentage = (self.Value - self.Min) / (self.Max - self.Min)
    self.Fill.Size = UDim2.new(percentage, 0, 1, 0)
    self.ValueLabel.Text = tostring(self.Value) .. self.Units
    
    -- Invoke callback
    self:InvokeCallback("Callback", self.Value)
end

function Slider:UpdateTheme()
    if not self.Container then return end
    
    self.Container.BackgroundColor3 = Library.Theme.Tertiary
    self.Label.TextColor3 = Library.Theme.TextPrimary
    self.ValueLabel.TextColor3 = Library.Theme.TextSecondary
    self.Track.BackgroundColor3 = Library.Theme.Primary
    self.Fill.BackgroundColor3 = Library.Theme.Accent
    
    Component.UpdateTheme(self)
end

function Slider:LoadConfigValue()
    if self.Flag then
        local value = ConfigManager:GetFlag(self.Flag, self.Default)
        self:SetValue(value)
    end
end

-- Label Component
Label.__index = Label
setmetatable(Label, {__index = Component})

function Label:New(options, section)
    local self = setmetatable(Component:New("Label"), Label)
    
    self.Name = options.Name or ""
    self.Text = options.Text or options.Name or "Label"
    self.Section = section
    
    self:CreateGUI()
    
    return self
end

function Label:CreateGUI()
    -- Main Container
    self.Container = Utility:CreateInstance("Frame", {
        Name = self.Name,
        Size = UDim2.new(1, -20, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Section.ElementContainer
    })
    
    -- Label
    self.Label = Utility:CreateInstance("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Text,
        TextColor3 = Library.Theme.TextSecondary,
        TextSize = Library.Theme.FontSize,
        Font = Library.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        Parent = self.Container
    })
end

function Label:UpdateTheme()
    if not self.Container then return end
    
    self.Label.TextColor3 = Library.Theme.TextSecondary
    
    Component.UpdateTheme(self)
end

-- Section Component - FIXED VERSION
Section.__index = Section
setmetatable(Section, {__index = Component})

function Section:New(options, tab)
    local self = setmetatable(Component:New("Section"), Section)
    
    self.Name = options.Name or "Section"
    self.Side = options.Side or "Left"
    self.Tab = tab
    self.Elements = {}
    self.Collapsed = false
    
    self:CreateGUI()
    
    return self
end

function Section:CreateGUI()
    local parent = self.Tab:GetColumn(self.Side)
    
    -- Section Container
    self.Container = Utility:CreateInstance("Frame", {
        Name = self.Name,
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = Library.Theme.Secondary,
        BorderSizePixel = 0,
        Parent = parent
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = Library.Theme.CornerRadius,
        Parent = self.Container
    })
    
    -- Section Header
    self.Header = Utility:CreateInstance("TextButton", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 35),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Parent = self.Container
    })
    
    -- Section Title
    self.TitleLabel = Utility:CreateInstance("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Name,
        TextColor3 = Library.Theme.TextPrimary,
        TextSize = Library.Theme.FontSize,
        Font = Library.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.Header
    })
    
    -- Element Container
    self.ElementContainer = Utility:CreateInstance("Frame", {
        Name = "Elements",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 35),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Container
    })
    
    -- Create and store the UIListLayout reference
    self.ElementLayout = Utility:CreateInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = self.ElementContainer
    })
    
    -- Update section size when elements change - FIXED
    Utility:Connect(self.ElementLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        self:UpdateSize()
    end)
    
    -- Initial size update
    task.defer(function()
        self:UpdateSize()
    end)
end

function Section:UpdateSize()
    -- Safety check to ensure ElementLayout exists
    if not self.ElementLayout or not self.ElementContainer then return end
    
    local elementHeight = self.ElementLayout.AbsoluteContentSize.Y
    local totalHeight = 35 + elementHeight + 15
    
    self.ElementContainer.Size = UDim2.new(1, 0, 0, elementHeight)
    self.Container.Size = UDim2.new(1, 0, 0, totalHeight)
end

function Section:AddToggle(options)
    local toggle = Toggle:New(options, self)
    table.insert(self.Elements, toggle)
    return toggle
end

function Section:AddButton(options)
    local button = Button:New(options, self)
    table.insert(self.Elements, button)
    return button
end

function Section:AddSlider(options)
    local slider = Slider:New(options, self)
    table.insert(self.Elements, slider)
    return slider
end

function Section:AddLabel(options)
    local label = Label:New(options, self)
    table.insert(self.Elements, label)
    return label
end

function Section:UpdateTheme()
    if not self.Container then return end
    
    self.Container.BackgroundColor3 = Library.Theme.Secondary
    self.TitleLabel.TextColor3 = Library.Theme.TextPrimary
    
    Component.UpdateTheme(self)
end

function Section:LoadConfigValues()
    for _, element in ipairs(self.Elements) do
        if element.LoadConfigValue then
            element:LoadConfigValue()
        end
    end
end

-- Tab Component - FIXED VERSION
Tab.__index = Tab
setmetatable(Tab, {__index = Component})

function Tab:New(options, window)
    local self = setmetatable(Component:New("Tab"), Tab)
    
    self.Name = options.Name or "Tab"
    self.Icon = options.Icon
    self.Window = window
    self.Sections = {}
    self.Active = false
    
    self:CreateGUI()
    
    return self
end

function Tab:CreateGUI()
    -- Tab Button
    self.Button = Utility:CreateInstance("TextButton", {
        Name = self.Name,
        Size = UDim2.new(1, -10, 0, 35),
        BackgroundColor3 = Library.Theme.Tertiary,
        BorderSizePixel = 0,
        Text = "",
        Parent = self.Window.TabList
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = self.Button
    })
    
    -- Tab Label
    self.Label = Utility:CreateInstance("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, -20, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Name,
        TextColor3 = Library.Theme.TextSecondary,
        TextSize = Library.Theme.FontSize,
        Font = Library.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.Button
    })
    
    -- Tab Content
    self.Content = Utility:CreateInstance("Frame", {
        Name = self.Name .. "Content",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        Parent = self.Window.ContentContainer
    })
    
    -- Left Column
    self.LeftColumn = Utility:CreateInstance("ScrollingFrame", {
        Name = "LeftColumn",
        Size = UDim2.new(0.5, -10, 1, -20),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Library.Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = self.Content
    })
    
    -- Store layout references - FIXED
    self.LeftLayout = Utility:CreateInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = self.LeftColumn
    })
    
    -- Right Column
    self.RightColumn = Utility:CreateInstance("ScrollingFrame", {
        Name = "RightColumn",
        Size = UDim2.new(0.5, -10, 1, -20),
        Position = UDim2.new(0.5, 0, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Library.Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = self.Content
    })
    
    -- Store layout references - FIXED
    self.RightLayout = Utility:CreateInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = self.RightColumn
    })
    
    -- Update canvas size when layout changes - FIXED
    Utility:Connect(self.LeftLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        self.LeftColumn.CanvasSize = UDim2.new(0, 0, 0, self.LeftLayout.AbsoluteContentSize.Y + 20)
    end)
    
    Utility:Connect(self.RightLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        self.RightColumn.CanvasSize = UDim2.new(0, 0, 0, self.RightLayout.AbsoluteContentSize.Y + 20)
    end)
    
    -- Button click handler
    Utility:Connect(self.Button.MouseButton1Click, function()
        self.Window:SelectTab(self)
    end)
end

function Tab:SetActive(active)
    self.Active = active
    self.Content.Visible = active
    
    if active then
        self.Button.BackgroundColor3 = Library.Theme.Accent
        self.Label.TextColor3 = Library.Theme.TextPrimary
    else
        self.Button.BackgroundColor3 = Library.Theme.Tertiary
        self.Label.TextColor3 = Library.Theme.TextSecondary
    end
end

function Tab:AddSection(options)
    local section = Section:New(options, self)
    table.insert(self.Sections, section)
    return section
end

function Tab:GetColumn(side)
    return side == "Right" and self.RightColumn or self.LeftColumn
end

function Tab:UpdateTheme()
    self:SetActive(self.Active)
    Component.UpdateTheme(self)
end

function Tab:LoadConfigValues()
    for _, section in ipairs(self.Sections) do
        if section.LoadConfigValues then
            section:LoadConfigValues()
        end
    end
end

-- Window Component - FIXED VERSION
Window.__index = Window
setmetatable(Window, {__index = Component})

function Window:New(options)
    local self = setmetatable(Component:New("Window"), Window)
    
    self.Title = options.Title or "Modern UI"
    self.Keybind = options.Keybind or Enum.KeyCode.RightShift
    self.Size = options.Size or UDim2.new(0, 600, 0, 500)
    self.MinSize = options.MinSize or UDim2.new(0, 400, 0, 300)
    
    self.Tabs = {}
    self.CurrentTab = nil
    self.Visible = false
    
    self:CreateGUI()
    self:SetupDragging()
    self:SetupResizing()
    self:SetupKeybind()
    
    return self
end

function Window:CreateGUI()
    -- Main ScreenGui
    self.ScreenGui = Utility:CreateInstance("ScreenGui", {
        Name = LIBRARY_NAME .. "_" .. tick(),
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    
    -- Set parent after creation
    self.ScreenGui.Parent = getParent()
    
    -- Main Frame
    self.Main = Utility:CreateInstance("Frame", {
        Name = "Main",
        Size = self.Size,
        Position = UDim2.new(0.5, -self.Size.X.Offset/2, 0.5, -self.Size.Y.Offset/2),
        BackgroundColor3 = Library.Theme.Primary,
        BorderSizePixel = 0,
        Visible = false,
        Parent = self.ScreenGui
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = Library.Theme.CornerRadius,
        Parent = self.Main
    })
    
    Utility:CreateInstance("UIStroke", {
        Color = Library.Theme.StrokeColor,
        Transparency = Library.Theme.StrokeTransparency,
        Parent = self.Main
    })
    
    -- Header
    self.Header = Utility:CreateInstance("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 40),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Library.Theme.Secondary,
        BorderSizePixel = 0,
        Parent = self.Main
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = Library.Theme.CornerRadius,
        Parent = self.Header
    })
    
    -- Header bottom cover
    Utility:CreateInstance("Frame", {
        Name = "Cover",
        Size = UDim2.new(1, 0, 0, 8),
        Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = Library.Theme.Secondary,
        BorderSizePixel = 0,
        Parent = self.Header
    })
    
    -- Title
    self.TitleLabel = Utility:CreateInstance("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -100, 1, 0),
        Position = UDim2.new(0, 15, 0, 0),
        BackgroundTransparency = 1,
        Text = self.Title,
        TextColor3 = Library.Theme.TextPrimary,
        TextSize = Library.Theme.FontSize + 4,
        Font = Library.Theme.Font,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = self.Header
    })
    
    -- Close Button
    self.CloseButton = Utility:CreateInstance("TextButton", {
        Name = "Close",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0, 5),
        BackgroundColor3 = Library.Theme.Error,
        BorderSizePixel = 0,
        Text = "×",
        TextColor3 = Library.Theme.TextPrimary,
        TextSize = 18,
        Font = Library.Theme.Font,
        Parent = self.Header
    })
    
    Utility:CreateInstance("UICorner", {
        CornerRadius = UDim.new(0, 4),
        Parent = self.CloseButton
    })
    
    Utility:Connect(self.CloseButton.MouseButton1Click, function()
        self:Toggle()
    end)
    
    -- Tab Container
    self.TabContainer = Utility:CreateInstance("Frame", {
        Name = "TabContainer",
        Size = UDim2.new(0, 150, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundColor3 = Library.Theme.Secondary,
        BorderSizePixel = 0,
        Parent = self.Main
    })
    
    -- Tab List
    self.TabList = Utility:CreateInstance("ScrollingFrame", {
        Name = "TabList",
        Size = UDim2.new(1, 0, 1, -10),
        Position = UDim2.new(0, 0, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Library.Theme.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = self.TabContainer
    })
    
    -- Store layout reference - FIXED
    self.TabListLayout = Utility:CreateInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = self.TabList
    })
    
    -- Content Container
    self.ContentContainer = Utility:CreateInstance("Frame", {
        Name = "ContentContainer",
        Size = UDim2.new(1, -150, 1, -40),
        Position = UDim2.new(0, 150, 0, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = self.Main
    })
    
    -- Resize Handle
    self.ResizeHandle = Utility:CreateInstance("Frame", {
        Name = "ResizeHandle",
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -20, 1, -20),
        BackgroundColor3 = Library.Theme.Tertiary,
        BorderSizePixel = 0,
        Parent = self.Main
    })
end

function Window:SetupDragging()
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    Utility:Connect(self.Header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = self.Main.Position
        end
    end)
    
    Utility:Connect(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            self.Main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    Utility:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

function Window:SetupResizing()
    local resizing = false
    local resizeStart = nil
    local startSize = nil
    
    Utility:Connect(self.ResizeHandle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resizeStart = input.Position
            startSize = self.Main.Size
        end
    end)
    
    Utility:Connect(UserInputService.InputChanged, function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resizeStart
            local newSize = UDim2.new(
                startSize.X.Scale,
                math.max(self.MinSize.X.Offset, startSize.X.Offset + delta.X),
                startSize.Y.Scale,
                math.max(self.MinSize.Y.Offset, startSize.Y.Offset + delta.Y)
            )
            self.Main.Size = newSize
            self.Size = newSize -- Update stored size
        end
    end)
    
    Utility:Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end)
end

function Window:SetupKeybind()
    Utility:Connect(UserInputService.InputBegan, function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == self.Keybind then
            self:Toggle()
        end
    end)
end

function Window:Toggle()
    self.Visible = not self.Visible
    
    if self.Visible then
        self.Main.Visible = true
        self.Main.Size = UDim2.new(0, 50, 0, 50)
        Utility:TweenObject(self.Main, {Size = self.Size}, 0.3)
    else
        Utility:TweenObject(self.Main, {Size = UDim2.new(0, 0, 0, 0)}, 0.3)
        task.spawn(function()
            task.wait(0.3)
            self.Main.Visible = false
        end)
    end
end

function Window:AddTab(options)
    local tab = Tab:New(options, self)
    table.insert(self.Tabs, tab)
    
    if not self.CurrentTab then
        self:SelectTab(tab)
    end
    
    return tab
end

function Window:SelectTab(tab)
    if self.CurrentTab then
        self.CurrentTab:SetActive(false)
    end
    
    self.CurrentTab = tab
    tab:SetActive(true)
end

function Window:UpdateTheme()
    if not self.Main then return end
    
    self.Main.BackgroundColor3 = Library.Theme.Primary
    self.Header.BackgroundColor3 = Library.Theme.Secondary
    self.TabContainer.BackgroundColor3 = Library.Theme.Secondary
    self.TitleLabel.TextColor3 = Library.Theme.TextPrimary
    
    Component.UpdateTheme(self)
end

function Window:LoadConfigValues()
    for _, tab in ipairs(self.Tabs) do
        if tab.LoadConfigValues then
            tab:LoadConfigValues()
        end
    end
end

-- Notification System
function Library:Notify(options)
    local notification = {
        Title = options.Title or "Notification",
        Content = options.Content or "",
        Duration = options.Duration or 5,
        Type = options.Type or "Info"
    }
    
    task.spawn(function()
        -- Create notification GUI
        local notificationGui = Utility:CreateInstance("ScreenGui", {
            Name = "ModernUI_Notification",
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        })
        
        notificationGui.Parent = getParent()
        
        local container = Utility:CreateInstance("Frame", {
            Name = "Container",
            Size = UDim2.new(0, 300, 0, 80),
            Position = UDim2.new(1, -320, 1, -100),
            BackgroundColor3 = Library.Theme.Secondary,
            BorderSizePixel = 0,
            Parent = notificationGui
        })
        
        Utility:CreateInstance("UICorner", {
            CornerRadius = Library.Theme.CornerRadius,
            Parent = container
        })
        
        -- Type indicator
        local typeColors = {
            Info = Library.Theme.Accent,
            Success = Library.Theme.Success,
            Warning = Library.Theme.Warning,
            Error = Library.Theme.Error
        }
        
        local indicator = Utility:CreateInstance("Frame", {
            Name = "Indicator",
            Size = UDim2.new(0, 4, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = typeColors[notification.Type],
            BorderSizePixel = 0,
            Parent = container
        })
        
        Utility:CreateInstance("UICorner", {
            CornerRadius = UDim.new(0, 4),
            Parent = indicator
        })
        
        -- Title
        local title = Utility:CreateInstance("TextLabel", {
            Name = "Title",
            Size = UDim2.new(1, -20, 0, 20),
            Position = UDim2.new(0, 15, 0, 10),
            BackgroundTransparency = 1,
            Text = notification.Title,
            TextColor3 = Library.Theme.TextPrimary,
            TextSize = Library.Theme.FontSize + 2,
            Font = Library.Theme.Font,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = container
        })
        
        -- Content
        local content = Utility:CreateInstance("TextLabel", {
            Name = "Content",
            Size = UDim2.new(1, -20, 0, 40),
            Position = UDim2.new(0, 15, 0, 30),
            BackgroundTransparency = 1,
            Text = notification.Content,
            TextColor3 = Library.Theme.TextSecondary,
            TextSize = Library.Theme.FontSize,
            Font = Library.Theme.Font,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Parent = container
        })
        
        -- Animate in
        container.Position = UDim2.new(1, 20, 1, -100)
        Utility:TweenObject(container, {Position = UDim2.new(1, -320, 1, -100)}, 0.5)
        
        -- Auto-dismiss
        task.wait(notification.Duration)
        
        -- Animate out
        Utility:TweenObject(container, {Position = UDim2.new(1, 20, 1, -100)}, 0.3)
        
        task.wait(0.3)
        notificationGui:Destroy()
    end)
end

-- Initialize Library
function Library:Initialize()
    ThemeManager:Initialize()
end

-- Public API Functions
function Library:CreateWindow(options)
    local window = Window:New(options)
    table.insert(self.Windows, window)
    return window
end

function Library:GetTheme()
    return ThemeManager:GetTheme()
end

function Library:SetTheme(theme)
    ThemeManager:SetTheme(theme)
end

function Library:SaveConfig()
    return ConfigManager:SaveConfig()
end

function Library:LoadConfig()
    return ConfigManager:LoadConfig()
end

function Library:Destroy()
    -- Clean up all connections
    for _, connection in ipairs(self.Connections) do
        if connection.Disconnect then
            connection:Disconnect()
        end
    end
    
    -- Destroy all windows
    for _, window in ipairs(self.Windows) do
        if window.ScreenGui then
            window.ScreenGui:Destroy()
        end
    end
    
    -- Clear tables
    self.Windows = {}
    self.Connections = {}
end

-- Initialize the library
Library:Initialize()

return Library
