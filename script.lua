local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local AmuletLab = require(ReplicatedStorage:WaitForChild("AmuletLab"))

local COLORS = {
    GREEN_FILL    = Color3.fromRGB(0, 200, 0),
    GREEN_OUTLINE = Color3.fromRGB(0, 255, 0),
    RED_FILL      = Color3.fromRGB(200, 0, 0),
    RED_OUTLINE   = Color3.fromRGB(255, 0, 0),

    -- โทนสีเทาสำหรับหน้าต่าง UI และสถานะเริ่มต้น
    UI_BG         = Color3.fromRGB(35, 35, 40),
    UI_STROKE     = Color3.fromRGB(130, 130, 135),
    GRAY_TITLE    = Color3.fromRGB(210, 210, 210),
    GRAY_STATUS   = Color3.fromRGB(190, 190, 190),
    GRAY_INFO     = Color3.fromRGB(170, 170, 170),
    GRAY_FAULT    = Color3.fromRGB(150, 150, 150),

    -- สีปุ่มเลื่อนเปิด/ปิด และปุ่มพับหน้าต่าง
    SWITCH_ON_BG  = Color3.fromRGB(45, 165, 85),
    SWITCH_OFF_BG = Color3.fromRGB(85, 85, 92),
    SWITCH_KNOB   = Color3.fromRGB(240, 240, 245),
    COLLAPSE_BG   = Color3.fromRGB(65, 65, 72),
}

local FULL_SIZE = UDim2.new(0, 350, 0, 210)
local FULL_POS  = UDim2.new(0, 10, 0.5, -105)
local MINI_SIZE = UDim2.new(0, 350, 0, 40)
local MINI_POS  = UDim2.new(0, 10, 0.5, -105)

local function formatMoney(amount)
    local num = tonumber(amount) or 0
    if type(AmuletLab.Money) == "function" then
        local ok, res = pcall(AmuletLab.Money, num)
        if ok and res then
            return tostring(res)
        end
    end
    local formatted = tostring(math.floor(num + 0.5))
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return "฿" .. formatted
end

local Krypt = {}
Krypt.__index = Krypt

function Krypt.new()
    local self = setmetatable({}, Krypt)
    self.isRunning = true
    self.isEnabled = true
    self.isCollapsed = false
    self.currentModel = nil
    self.trackedModels = {}
    self.originalBuild = nil
    self.heartbeatConn = nil
    self.gui = nil
    self.mainFrame = nil
    self.bodyContainer = nil
    self.statusLabel = nil
    self.infoLabel = nil
    self.faultLabel = nil
    self.switchTrack = nil
    self.switchKnob = nil
    self.switchText = nil
    self.collapseBtn = nil
    return self
end

function Krypt:clearHighlights()
    for model, _ in pairs(self.trackedModels) do
        if model and model.Parent then
            for _, child in pairs(model:GetChildren()) do
                if child:IsA("Highlight") and child.Name == "SongPhraHL" then
                    child:Destroy()
                end
            end
        end
    end
end

function Krypt:setCollapsed(collapsed, instant)
    if not self.isRunning or not self.mainFrame or not self.bodyContainer or not self.collapseBtn then return end
    self.isCollapsed = (collapsed == true)

    local targetSize = self.isCollapsed and MINI_SIZE or FULL_SIZE
    local targetPos  = self.isCollapsed and MINI_POS or FULL_POS
    self.collapseBtn.Text = self.isCollapsed and "+" or "—"
    self.bodyContainer.Visible = not self.isCollapsed

    if instant then
        self.mainFrame.Size = targetSize
        self.mainFrame.Position = targetPos
    else
        local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(self.mainFrame, info, { Size = targetSize, Position = targetPos }):Play()
    end
end

function Krypt:updateSwitchVisual(instant)
    if not self.switchTrack or not self.switchKnob or not self.switchText then return end

    local targetPos = self.isEnabled
        and UDim2.new(1, -20, 0.5, -9)
        or UDim2.new(0, 2, 0.5, -9)

    local targetBg = self.isEnabled
        and COLORS.SWITCH_ON_BG
        or COLORS.SWITCH_OFF_BG

    self.switchText.Text = self.isEnabled and "เปิดอยู่" or "ปิดอยู่"

    if instant then
        self.switchKnob.Position = targetPos
        self.switchTrack.BackgroundColor3 = targetBg
    else
        local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(self.switchKnob, info, { Position = targetPos }):Play()
        TweenService:Create(self.switchTrack, info, { BackgroundColor3 = targetBg }):Play()
    end
end

function Krypt:setEnabled(enabled, instant)
    if not self.isRunning then return end
    self.isEnabled = (enabled == true)
    self:updateSwitchVisual(instant)

    if self.isEnabled then
        self:hookBuild()
        for model, analysis in pairs(self.trackedModels) do
            if model and model.Parent and analysis then
                self:applyHighlight(model, analysis.isFake)
            end
        end

        if self.currentModel and self.currentModel.Parent and self.trackedModels[self.currentModel] then
            pcall(function()
                self:updateGUI(self.trackedModels[self.currentModel], self.currentModel)
            end)
        elseif self.statusLabel then
            self.statusLabel.Text = "⏳ กำลังรอพระ...\n(กดส่องพระ หรือรอพระขึ้นบนโต๊ะ)"
            self.statusLabel.TextColor3 = COLORS.GRAY_STATUS
            if self.infoLabel then self.infoLabel.Text = "" end
            if self.faultLabel then self.faultLabel.Text = "" end
        end
    else
        if self.originalBuild then
            AmuletLab.Build = self.originalBuild
            _G.KryptOriginalBuild = nil
            self.originalBuild = nil
        end
        self:clearHighlights()

        if self.statusLabel then
            self.statusLabel.Text = "⏸️ ปิดการทำงานของสคริปต์อยู่\n(เลื่อนปุ่มด้านบนเพื่อเปิดใช้งาน)"
            self.statusLabel.TextColor3 = COLORS.GRAY_STATUS
        end
        if self.infoLabel then self.infoLabel.Text = "" end
        if self.faultLabel then self.faultLabel.Text = "" end
    end
end

function Krypt:createGUI()
    local old = PlayerGui:FindFirstChild("SongPhraGUI")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "SongPhraGUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999
    sg.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = FULL_SIZE
    frame.Position = FULL_POS
    frame.BackgroundColor3 = COLORS.UI_BG
    frame.BackgroundTransparency = 0.08
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)

    local stroke = Instance.new("UIStroke")
    stroke.Color = COLORS.UI_STROKE
    stroke.Thickness = 2.5
    stroke.Parent = frame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -162, 0, 28)
    titleLabel.Position = UDim2.new(0, 10, 0, 6)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextScaled = true
    titleLabel.Text = "🔍 Cr.Chinnakrit Topang"
    titleLabel.TextColor3 = COLORS.GRAY_TITLE
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = frame

    -- ปุ่มเลื่อนเปิด/ปิดสคริปต์ (Toggle Switch)
    local switchText = Instance.new("TextLabel")
    switchText.Size = UDim2.new(0, 50, 0, 22)
    switchText.Position = UDim2.new(1, -130, 0, 9)
    switchText.BackgroundTransparency = 1
    switchText.Font = Enum.Font.GothamBold
    switchText.TextScaled = true
    switchText.Text = "เปิดอยู่"
    switchText.TextColor3 = COLORS.GRAY_TITLE
    switchText.TextXAlignment = Enum.TextXAlignment.Right
    switchText.Parent = frame

    local switchTrack = Instance.new("TextButton")
    switchTrack.Name = "ToggleSwitch"
    switchTrack.Size = UDim2.new(0, 44, 0, 22)
    switchTrack.Position = UDim2.new(1, -82, 0, 9)
    switchTrack.BackgroundColor3 = COLORS.SWITCH_ON_BG
    switchTrack.BorderSizePixel = 0
    switchTrack.Text = ""
    switchTrack.AutoButtonColor = false
    switchTrack.Parent = frame
    Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

    local switchKnob = Instance.new("Frame")
    switchKnob.Name = "Knob"
    switchKnob.Size = UDim2.new(0, 18, 0, 18)
    switchKnob.Position = UDim2.new(1, -20, 0.5, -9)
    switchKnob.BackgroundColor3 = COLORS.SWITCH_KNOB
    switchKnob.BorderSizePixel = 0
    switchKnob.Parent = switchTrack
    Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

    -- ปุ่มพับ/ขยายหน้าต่าง
    local collapseBtn = Instance.new("TextButton")
    collapseBtn.Name = "CollapseBtn"
    collapseBtn.Size = UDim2.new(0, 24, 0, 22)
    collapseBtn.Position = UDim2.new(1, -34, 0, 9)
    collapseBtn.BackgroundColor3 = COLORS.COLLAPSE_BG
    collapseBtn.BorderSizePixel = 0
    collapseBtn.Font = Enum.Font.GothamBold
    collapseBtn.TextScaled = true
    collapseBtn.Text = "—"
    collapseBtn.TextColor3 = Color3.new(1, 1, 1)
    collapseBtn.Parent = frame
    Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 6)

    -- ส่วนเนื้อหาที่พับซ่อนได้
    local bodyContainer = Instance.new("Frame")
    bodyContainer.Name = "Body"
    bodyContainer.Size = UDim2.new(1, 0, 1, -36)
    bodyContainer.Position = UDim2.new(0, 0, 0, 36)
    bodyContainer.BackgroundTransparency = 1
    bodyContainer.BorderSizePixel = 0
    bodyContainer.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 52)
    statusLabel.Position = UDim2.new(0, 10, 0, 2)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextScaled = true
    statusLabel.TextWrapped = true
    statusLabel.Text = "⏳ กำลังรอพระ...\n(กดส่องพระ หรือรอพระขึ้นบนโต๊ะ)"
    statusLabel.TextColor3 = COLORS.GRAY_STATUS
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextYAlignment = Enum.TextYAlignment.Top
    statusLabel.Parent = bodyContainer

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -20, 0, 26)
    infoLabel.Position = UDim2.new(0, 10, 0, 58)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextScaled = true
    infoLabel.TextWrapped = true
    infoLabel.Text = ""
    infoLabel.TextColor3 = COLORS.GRAY_INFO
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = bodyContainer

    local faultLabel = Instance.new("TextLabel")
    faultLabel.Size = UDim2.new(1, -20, 0, 56)
    faultLabel.Position = UDim2.new(0, 10, 0, 86)
    faultLabel.BackgroundTransparency = 1
    faultLabel.Font = Enum.Font.Gotham
    faultLabel.TextScaled = true
    faultLabel.TextWrapped = true
    faultLabel.Text = ""
    faultLabel.TextColor3 = COLORS.GRAY_FAULT
    faultLabel.TextXAlignment = Enum.TextXAlignment.Left
    faultLabel.TextYAlignment = Enum.TextYAlignment.Top
    faultLabel.
