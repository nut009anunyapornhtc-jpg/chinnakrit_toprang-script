local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local VirtualInputManager = game:GetService("VirtualInputManager")

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
	RENT_ON_BG    = Color3.fromRGB(35, 135, 200),
	RENT_OFF_BG   = Color3.fromRGB(75, 75, 82),
	REJECT_ON_BG  = Color3.fromRGB(195, 65, 65),
	REJECT_OFF_BG = Color3.fromRGB(75, 75, 82),
	TRAY_ON_BG    = Color3.fromRGB(165, 115, 35),
	TRAY_OFF_BG   = Color3.fromRGB(75, 75, 82),
	SWITCH_KNOB   = Color3.fromRGB(240, 240, 245),
	COLLAPSE_BG   = Color3.fromRGB(75, 75, 85),
}

local FULL_SIZE = UDim2.new(0, 570, 0, 215)
local MINI_SIZE = UDim2.new(0, 570, 0, 40)
local DEFAULT_POS = UDim2.new(0, 10, 0.5, -107)

local GENUINE_PRIORITY_KEYWORDS = { "เช่า" }
local GENUINE_FALLBACK_KEYWORDS = { "พระแท้", "rent", "buy", "ซื้อ", "claim", "accept" }

local FAKE_PRIORITY_KEYWORDS = { "พระเกี" }
local FAKE_FALLBACK_KEYWORDS = { "ไม่เอา", "decline", "reject", "skip", "pass", "no", "ไม่เช่า", "ปฏิเสธ", "ข้าม", "ยกเลิก" }

local TRAY_KEYWORDS = { "ถาด", "tray", "ส่อง", "inspect", "ดูพระ" }

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

local function isClickableGuiCandidate(obj)
	if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then
		return false
	end
	if not obj.Visible or not obj.Active then
		return false
	end
	if obj:FindFirstAncestor("SongPhraGUI") then
		return false
	end
	return true
end

local function getGuiCombinedText(obj)
	local labelText = ""
	if obj:IsA("TextButton") then
		labelText = tostring(obj.Text or "")
	end
	for _, desc in ipairs(obj:GetDescendants()) do
		if desc:IsA("TextLabel") or desc:IsA("TextButton") then
			labelText = labelText .. " " .. tostring(desc.Text or "")
		end
	end
	return string.lower(labelText)
end

local function hasAnyKeyword(lowerText, keywords)
	for _, kw in ipairs(keywords) do
		if string.find(lowerText, string.lower(kw), 1, true) then
			return true
		end
	end
	return false
end

local function findPriorityButton(priorityKeywords, fallbackKeywords)
	local priorityMatch = nil
	local fallbackMatch = nil

	for _, desc in ipairs(PlayerGui:GetDescendants()) do
		if isClickableGuiCandidate(desc) then
			local lower = getGuiCombinedText(desc)
			if not priorityMatch and hasAnyKeyword(lower, priorityKeywords) then
				priorityMatch = desc
			elseif not fallbackMatch and hasAnyKeyword(lower, fallbackKeywords) then
				fallbackMatch = desc
			end
		end
	end

	return priorityMatch or fallbackMatch
end

local function findGenuineButtonCandidate()
	return findPriorityButton(GENUINE_PRIORITY_KEYWORDS, GENUINE_FALLBACK_KEYWORDS)
end

local function findRejectButtonCandidate()
	return findPriorityButton(FAKE_PRIORITY_KEYWORDS, FAKE_FALLBACK_KEYWORDS)
end

local function clickGuiObject(btn)
	if not btn or not btn.Parent then return false end

	if typeof(firesignal) == "function" then
		local fired = false
		for _, sigName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
			local ok = pcall(function()
				if btn[sigName] then
					firesignal(btn[sigName])
					fired = true
				end
			end)
			if fired then return true end
		end
	end

	local absPos = btn.AbsolutePosition
	local absSize = btn.AbsoluteSize
	if absSize.X <= 0 or absSize.Y <= 0 then return false end

	local inset = GuiService:GetGuiInset()
	local centerX = absPos.X + absSize.X * 0.5 + inset.X
	local centerY = absPos.Y + absSize.Y * 0.5 + inset.Y

	local okVim = pcall(function()
		VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)
		task.wait(0.05)
		VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0)
	end)
	return okVim
end

local Krypt = {}
Krypt.__index = Krypt

function Krypt.new()
	local self = setmetatable({}, Krypt)
	self.isRunning = true
	self.isEnabled = true
	self.isCollapsed = false
	self.autoBuyGenuine = false
	self.autoRejectFake = false
	self.autoInspectTray = false
	self.lastActionTime = 0
	self.lastTrayTime = 0
	self.currentPos = DEFAULT_POS
	self.currentModel = nil
	self.trackedModels = {}
	self.boughtModels = {}
	self.rejectedModels = {}
	self.inspectedTargets = {}
	self.originalBuild = nil
	self.heartbeatConn = nil
	self.inputChangedConn = nil
	self.inputEndedConn = nil
	self.gui = nil
	self.mainFrame = nil
	self.bodyContainer = nil
	self.statusLabel = nil
	self.infoLabel = nil
	self.faultLabel = nil
	self.switchTrack = nil
	self.switchKnob = nil
	self.switchText = nil
	self.rentTrack = nil
	self.rentKnob = nil
	self.rentText = nil
	self.rejectTrack = nil
	self.rejectKnob = nil
	self.rejectText = nil
	self.trayTrack = nil
	self.trayKnob = nil
	self.trayText = nil
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

function Krypt:updateRentSwitchVisual(instant)
	if not self.rentTrack or not self.rentKnob or not self.rentText then return end

	local targetPos = self.autoBuyGenuine
		and UDim2.new(1, -20, 0.5, -9)
		or UDim2.new(0, 2, 0.5, -9)

	local targetBg = self.autoBuyGenuine
		and COLORS.RENT_ON_BG
		or COLORS.RENT_OFF_BG

	self.rentText.Text = self.autoBuyGenuine and "เช่าซื้อ: เปิด" or "เช่าซื้อ: ปิด"

	if instant then
		self.rentKnob.Position = targetPos
		self.rentTrack.BackgroundColor3 = targetBg
	else
		local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(self.rentKnob, info, { Position = targetPos }):Play()
		TweenService:Create(self.rentTrack, info, { BackgroundColor3 = targetBg }):Play()
	end
end

function Krypt:updateRejectSwitchVisual(instant)
	if not self.rejectTrack or not self.rejectKnob or not self.rejectText then return end

	local targetPos = self.autoRejectFake
		and UDim2.new(1, -20, 0.5, -9)
		or UDim2.new(0, 2, 0.5, -9)

	local targetBg = self.autoRejectFake
		and COLORS.REJECT_ON_BG
		or COLORS.REJECT_OFF_BG

	self.rejectText.Text = self.autoRejectFake and "ไม่เช่าเก๊: เปิด" or "ไม่เช่าเก๊: ปิด"

	if instant then
		self.rejectKnob.Position = targetPos
		self.rejectTrack.BackgroundColor3 = targetBg
	else
		local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(self.rejectKnob, info, { Position = targetPos }):Play()
		TweenService:Create(self.rejectTrack, info, { BackgroundColor3 = targetBg }):Play()
	end
end

function Krypt:updateTraySwitchVisual(instant)
	if not self.trayTrack or not self.trayKnob or not self.trayText then return end

	local targetPos = self.autoInspectTray
		and UDim2.new(1, -20, 0.5, -9)
		or UDim2.new(0, 2, 0.5, -9)

	local targetBg = self.autoInspectTray
		and COLORS.TRAY_ON_BG
		or COLORS.TRAY_OFF_BG

	self.trayText.Text = self.autoInspectTray and "ดูถาด: เปิด" or "ดูถาด: ปิด"

	if instant then
		self.trayKnob.Position = targetPos
		self.trayTrack.BackgroundColor3 = targetBg
	else
		local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(self.trayKnob, info, { Position = targetPos }):Play()
		TweenService:Create(self.trayTrack, info, { BackgroundColor3 = targetBg }):Play()
	end
end

function Krypt:setAutoBuyGenuine(enabled, instant)
	if not self.isRunning then return end
	self.autoBuyGenuine = (enabled == true)
	self:updateRentSwitchVisual(instant)

	if self.autoBuyGenuine and self.isEnabled and self.currentModel and self.currentModel.Parent and self.trackedModels[self.currentModel] then
		self:tryAutoBuyGenuine(self.currentModel, self.trackedModels[self.currentModel])
	end
end

function Krypt:setAutoRejectFake(enabled, instant)
	if not self.isRunning then return end
	self.autoRejectFake = (enabled == true)
	self:updateRejectSwitchVisual(instant)

	if self.autoRejectFake and self.isEnabled and self.currentModel and self.currentModel.Parent and self.trackedModels[self.currentModel] then
		self:tryAutoRejectFake(self.currentModel, self.trackedModels[self.currentModel])
	end
end

function Krypt:setAutoInspectTray(enabled, instant)
	if not self.isRunning then return end
	self.autoInspectTray = (enabled == true)
	self:updateTraySwitchVisual(instant)

	if self.autoInspectTray and self.isEnabled then
		self:tryAutoInspectTray()
	end
end

function Krypt:tryAutoBuyGenuine(model, analysis)
	if not self.isRunning or not self.isEnabled or not self.autoBuyGenuine then return end
	if not analysis or analysis.isFake == true then return end
	if not model or not model.Parent or self.boughtModels[model] then return end

	local now = os.clock()
	if now - self.lastActionTime < 0.6 then return end

	local targetBtn = findGenuineButtonCandidate()
	if targetBtn then
		self.lastActionTime = now
		self.boughtModels[model] = true
		task.spawn(function()
			task.wait(0.08)
			if self.isRunning and self.isEnabled and self.autoBuyGenuine and model and model.Parent and not analysis.isFake then
				clickGuiObject(targetBtn)
			end
		end)
	end
end

function Krypt:tryAutoRejectFake(model, analysis)
	if not self.isRunning or not self.isEnabled or not self.autoRejectFake then return end
	if not analysis or analysis.isFake ~= true then return end
	if not model or not model.Parent or self.rejectedModels[model] then return end

	local now = os.clock()
	if now - self.lastActionTime < 0.6 then return end

	local targetBtn = findRejectButtonCandidate()
	if targetBtn then
		self.lastActionTime = now
		self.rejectedModels[model] = true
		task.spawn(function()
			task.wait(0.08)
			if self.isRunning and self.isEnabled and self.autoRejectFake and model and model.Parent and analysis.isFake then
				clickGuiObject(targetBtn)
			end
		end)
	end
end

function Krypt:tryAutoInspectTray()
	if not self.isRunning or not self.isEnabled or not self.autoInspectTray then return end
	if self.currentModel and self.currentModel.Parent then return end

	local now = os.clock()
	if now - self.lastTrayTime < 0.8 then return end

	for _, desc in ipairs(PlayerGui:GetDescendants()) do
		if isClickableGuiCandidate(desc) and not self.inspectedTargets[desc] then
			local lower = getGuiCombinedText(desc)
			local ancName = string.lower(tostring(desc.Parent and desc.Parent.Name or ""))
			if hasAnyKeyword(lower, TRAY_KEYWORDS) or string.find(ancName, "tray", 1, true) or string.find(ancName, "ถาด", 1, true) then
				self.lastTrayTime = now
				self.inspectedTargets[desc] = true
				task.spawn(function()
					task.wait(0.05)
					if self.isRunning and self.isEnabled and self.autoInspectTray and desc and desc.Parent then
						clickGuiObject(desc)
					end
				end)
				return
			end
		end
	end

	for _, obj in ipairs(workspace:GetDescendants()) do
		if (obj:IsA("ClickDetector") or obj:IsA("ProximityPrompt")) and not self.inspectedTargets[obj] then
			local pathLower = string.lower(obj:GetFullName())
			if string.find(pathLower, "tray", 1, true) or string.find(pathLower, "ถาด", 1, true) then
				self.lastTrayTime = now
				self.inspectedTargets[obj] = true
				task.spawn(function()
					if not self.isRunning or not self.isEnabled or not self.autoInspectTray or not obj.Parent then return end
					if obj:IsA("ClickDetector") then
						pcall(function()
							if typeof(fireclickdetector) == "function" then
								fireclickdetector(obj)
							end
						end)
					elseif obj:IsA("ProximityPrompt") then
						pcall(function()
							if typeof(fireproximityprompt) == "function" then
								fireproximityprompt(obj)
							else
								obj:InputHoldBegin()
								task.wait(0.05)
								obj:InputHoldEnd()
							end
						end)
					end
				end)
				return
			end
		end
	end
end

function Krypt:enableDrag(dragHandle, targetFrame)
	if self.inputChangedConn then
		self.inputChangedConn:Disconnect()
		self.inputChangedConn = nil
	end
	if self.inputEndedConn then
		self.inputEndedConn:Disconnect()
		self.inputEndedConn = nil
	end

	local dragging = false
	local dragStart = nil
	local startPos = nil

	dragHandle.InputBegan:Connect(function(input)
		if not self.isRunning then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = targetFrame.Position
		end
	end)

	self.inputChangedConn = UserInputService.InputChanged:Connect(function(input)
		if not self.isRunning or not dragging or not targetFrame then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			local nextPos = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
			targetFrame.Position = nextPos
			self.currentPos = nextPos
		end
	end)

	self.inputEndedConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging and targetFrame then
				self.currentPos = targetFrame.Position
			end
			dragging = false
		end
	end)
end

function Krypt:setCollapsed(collapsed, instant)
	if not self.isRunning or not self.mainFrame or not self.bodyContainer or not self.collapseBtn then return end
	self.isCollapsed = (collapsed == true)

	local targetSize = self.isCollapsed and MINI_SIZE or FULL_SIZE
	local targetPos  = self.currentPos
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
	frame.Position = self.currentPos
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

	-- แถบด้านบนสำหรับลากย้ายหน้าต่างและควบคุมปุ่มแยก
	local headerBar = Instance.new("Frame")
	headerBar.Name = "Header"
	headerBar.Size = UDim2.new(1, 0, 0, 38)
	headerBar.Position = UDim2.new(0, 0, 0, 0)
	headerBar.BackgroundTransparency = 1
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 2
	headerBar.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0, 102, 0, 22)
	titleLabel.Position = UDim2.new(0, 10, 0, 9)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.Text = "🔍 SongPhra"
	titleLabel.TextColor3 = COLORS.GRAY_TITLE
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 2
	titleLabel.Parent = headerBar

	-- ปุ่มเลื่อนเปิด-ปิดโหมดดูพระในถาดเองแยกต่างหาก
	local trayText = Instance.new("TextLabel")
	trayText.Size = UDim2.new(0, 62, 0, 20)
	trayText.Position = UDim2.new(1, -442, 0, 10)
	trayText.BackgroundTransparency = 1
	trayText.Font = Enum.Font.GothamBold
	trayText.TextScaled = true
	trayText.Text = "ดูถาด: ปิด"
	trayText.TextColor3 = COLORS.GRAY_TITLE
	trayText.TextXAlignment = Enum.TextXAlignment.Right
	trayText.ZIndex = 3
	trayText.Parent = headerBar

	local trayTrack = Instance.new("TextButton")
	trayTrack.Name = "TraySwitch"
	trayTrack.Size = UDim2.new(0, 44, 0, 22)
	trayTrack.Position = UDim2.new(1, -376, 0, 9)
	trayTrack.BackgroundColor3 = COLORS.TRAY_OFF_BG
	trayTrack.BorderSizePixel = 0
	trayTrack.Text = ""
	trayTrack.AutoButtonColor = false
	trayTrack.ZIndex = 3
	trayTrack.Parent = headerBar
	Instance.new("UICorner", trayTrack).CornerRadius = UDim.new(1, 0)

	local trayKnob = Instance.new("Frame")
	trayKnob.Name = "Knob"
	trayKnob.Size = UDim2.new(0, 18, 0, 18)
	trayKnob.Position = UDim2.new(0, 2, 0.5, -9)
	trayKnob.BackgroundColor3 = COLORS.SWITCH_KNOB
	trayKnob.BorderSizePixel = 0
	trayKnob.ZIndex = 4
	trayKnob.Parent = trayTrack
	Instance.new("UICorner", trayKnob).CornerRadius = UDim.new(1, 0)

	-- ปุ่มเลื่อนเปิด-ปิดโหมดไม่เช่าพระเก๊แยกต่างหาก
	local rejectText = Instance.new("TextLabel")
	rejectText.Size = UDim2.new(0, 74, 0, 20)
	rejectText.Position = UDim2.new(1, -324, 0, 10)
	rejectText.BackgroundTransparency = 1
	rejectText.Font = Enum.Font.GothamBold
	rejectText.TextScaled = true
	rejectText.Text = "ไม่เช่าเก๊: ปิด"
	rejectText.TextColor3 = COLORS.GRAY_TITLE
	rejectText.TextXAlignment = Enum.TextXAlignment.Right
	rejectText.ZIndex = 3
	rejectText.Parent = headerBar

	local rejectTrack = Instance.new("TextButton")
	rejectTrack.Name = "RejectSwitch"
	rejectTrack.Size = UDim2.new(0, 44, 0, 22)
	rejectTrack.Position = UDim2.new(1, -246, 0, 9)
	rejectTrack.BackgroundColor3 = COLORS.REJECT_OFF_BG
	rejectTrack.BorderSizePixel = 0
	rejectTrack.Text = ""
	rejectTrack.AutoButtonColor = false
	rejectTrack.ZIndex = 3
	rejectTrack.Parent = headerBar
	Instance.new("UICorner", rejectTrack).CornerRadius = UDim.new(1, 0)

	local rejectKnob = Instance.new("Frame")
	rejectKnob.Name = "Knob"
	rejectKnob.Size = UDim2.new(0, 18, 0, 18)
	rejectKnob.Position = UDim2.new(0, 2, 0.5, -9)
	rejectKnob.BackgroundColor3 = COLORS.SWITCH_KNOB
	rejectKnob.BorderSizePixel = 0
	rejectKnob.ZIndex = 4
	rejectKnob.Parent = rejectTrack
	Instance.new("UICorner", rejectKnob).CornerRadius = UDim.new(1, 0)

	-- ปุ่มเลื่อนเปิด-ปิดโหมดเช่าซื้อพระแท้แยกต่างหาก
	local rentText = Instance.new("TextLabel")
	rentText.Size = UDim2.new(0, 66, 0, 20)
	rentText.Position = UDim2.new(1, -194, 0, 10)
	rentText.BackgroundTransparency = 1
	rentText.Font = Enum.Font.GothamBold
	rentText.TextScaled = true
	rentText.Text = "เช่าซื้อ: ปิด"
	rentText.TextColor3 = COLORS.GRAY_TITLE
	rentText.TextXAlignment = Enum.TextXAlignment.Right
	rentText.ZIndex = 3
	rentText.Parent = headerBar

	local rentTrack = Instance.new("TextButton")
	rentTrack.Name = "RentSwitch"
	rentTrack.Size = UDim2.new(0, 44, 0, 22)
	rentTrack.Position = UDim2.new(1, -124, 0, 9)
	rentTrack.BackgroundColor3 = COLORS.RENT_OFF_BG
	rentTrack.BorderSizePixel = 0
	rentTrack.Text = ""
	rentTrack.AutoButtonColor = false
	rentTrack.ZIndex = 3
	rentTrack.Parent = headerBar
	Instance.new("UICorner", rentTrack).CornerRadius = UDim.new(1, 0)

	local rentKnob = Instance.new("Frame")
	rentKnob.Name = "Knob"
	rentKnob.Size = UDim2.new(0, 18, 0, 18)
	rentKnob.Position = UDim2.new(0, 2, 0.5, -9)
	rentKnob.BackgroundColor3 = COLORS.SWITCH_KNOB
	rentKnob.BorderSizePixel = 0
	rentKnob.ZIndex = 4
	rentKnob.Parent = rentTrack
	Instance.new("UICorner", rentKnob).CornerRadius = UDim.new(1, 0)

	-- ปุ่มเลื่อนเปิด/ปิดสคริปต์หลัก (Toggle Switch)
	local switchText = Instance.new("TextLabel")
	switchText.Size = UDim2.new(0, 44, 0, 20)
	switchText.Position = UDim2.new(1, -76, 0, 10)
	switchText.BackgroundTransparency = 1
	switchText.Font = Enum.Font.GothamBold
	switchText.TextScaled = true
	switchText.Text = "เปิดอยู่"
	switchText.TextColor3 = COLORS.GRAY_TITLE
	switchText.TextXAlignment = Enum.TextXAlignment.Right
	switchText.ZIndex = 3
	switchText.Parent = headerBar

	local switchTrack = Instance.new("TextButton")
	switchTrack.Name = "ToggleSwitch"
	switchTrack.Size = UDim2.new(0, 44, 0, 22)
	switchTrack.Position = UDim2.new(1, -56, 0, 9)
	switchTrack.BackgroundColor3 = COLORS.SWITCH_ON_BG
	switchTrack.BorderSizePixel = 0
	switchTrack.Text = ""
	switchTrack.AutoButtonColor = false
	switchTrack.ZIndex = 3
	switchTrack.Parent = headerBar
	Instance.new("UICorner", switchTrack).CornerRadius = UDim.new(1, 0)

	local switchKnob = Instance.new("Frame")
	switchKnob.Name = "Knob"
	switchKnob.Size = UDim2.new(0, 18, 0, 18)
	switchKnob.Position = UDim2.new(1, -20, 0.5, -9)
	switchKnob.BackgroundColor3 = COLORS.SWITCH_KNOB
	switchKnob.BorderSizePixel = 0
	switchKnob.ZIndex = 4
	switchKnob.Parent = switchTrack
	Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

	-- ปุ่มพับ/ขยายหน้าต่าง
	local collapseBtn = Instance.new("TextButton")
	collapseBtn.Name = "CollapseBtn"
	collapseBtn.Size = UDim2.new(0, 22, 0, 22)
	collapseBtn.Position = UDim2.new(1, -26, 0, 9)
	collapseBtn.BackgroundColor3 = COLORS.COLLAPSE_BG
	collapseBtn.BorderSizePixel = 0
	collapseBtn.Font = Enum.Font.GothamBold
	collapseBtn.TextSize = 16
	collapseBtn.Text = "—"
	collapseBtn.TextColor3 = Color3.new(1, 1, 1)
	collapseBtn.ZIndex = 5
	collapseBtn.Parent = headerBar
	Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 6)

	-- ส่วนเนื้อหาที่พับซ่อนได้
	local bodyContainer = Instance.new("Frame")
	bodyContainer.Name = "Body"
	bodyContainer.Size = UDim2.new(1, 0, 1, -38)
	bodyContainer.Position = UDim2.new(0, 0, 0, 38)
	bodyContainer.BackgroundTransparency = 1
	bodyContainer.BorderSizePixel = 0
	bodyContainer.ZIndex = 2
	bodyContainer.Parent = frame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -20, 0, 48)
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
	infoLabel.Size = UDim2.new(1, -20, 0, 24)
	infoLabel.Position = UDim2.new(0, 10, 0, 52)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextScaled = true
	infoLabel.TextWrapped = true
	infoLabel.Text = ""
	infoLabel.TextColor3 = COLORS.GRAY_INFO
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = bodyContainer

	local faultLabel = Instance.new("TextLabel")
	faultLabel.Size = UDim2.new(1, -20, 0, 50)
	faultLabel.Position = UDim2.new(0, 10, 0, 78)
	faultLabel.BackgroundTransparency = 1
	faultLabel.Font = Enum.Font.Gotham
	faultLabel.TextScaled = true
	faultLabel.TextWrapped = true
	faultLabel.Text = ""
	faultLabel.TextColor3 = COLORS.GRAY_FAULT
	faultLabel.TextXAlignment = Enum.TextXAlignment.Left
	faultLabel.TextYAlignment = Enum.TextYAlignment.Top
	faultLabel.Parent = bodyContainer

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 110, 0, 26)
	closeBtn.Position = UDim2.new(0, 10, 1, -32)
	closeBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextScaled = true
	closeBtn.Text = "❌ ปิดสคริปต์"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Parent = bodyContainer
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

	trayTrack.Activated:Connect(function()
		self:setAutoInspectTray(not self.autoInspectTray, false)
	end)

	rejectTrack.Activated:Connect(function()
		self:setAutoRejectFake(not self.autoRejectFake, false)
	end)

	rentTrack.Activated:Connect(function()
		self:setAutoBuyGenuine(not self.autoBuyGenuine, false)
	end)

	switchTrack.Activated:Connect(function()
		self:setEnabled(not self.isEnabled, false)
	end)

	collapseBtn.Activated:Connect(function()
		self:setCollapsed(not self.isCollapsed, false)
	end)

	closeBtn.Activated:Connect(function()
		self:destroy()
	end)

	self:enableDrag(headerBar, frame)

	self.gui = sg
	self.mainFrame = frame
	self.bodyContainer = bodyContainer
	self.statusLabel = statusLabel
	self.infoLabel = infoLabel
	self.faultLabel = faultLabel
	self.switchTrack = switchTrack
	self.switchKnob = switchKnob
	self.switchText = switchText
	self.rentTrack = rentTrack
	self.rentKnob = rentKnob
	self.rentText = rentText
	self.rejectTrack = rejectTrack
	self.rejectKnob = rejectKnob
	self.rejectText = rejectText
	self.trayTrack = trayTrack
	self.trayKnob = trayKnob
	self.trayText = trayText
	self.collapseBtn = collapseBtn
	self:updateSwitchVisual(true)
	self:updateRentSwitchVisual(true)
	self:updateRejectSwitchVisual(true)
	self:updateTraySwitchVisual(true)
	self:setCollapsed(false, true)
end

function Krypt:analyzeAmulet(amuletData)
	if type(amuletData) ~= "table" or not amuletData.Model then
		return nil
	end

	local models = AmuletLab.Models
	local modelInfo = type(models) == "table" and models[amuletData.Model] or nil
	if not modelInfo then
		return nil
	end

	local isFake = false
	local faults = {}
	local seenFault = {}

	local function addFault(msg)
		msg = tostring(msg)
		if not seenFault[msg] then
			seenFault[msg] = true
			table.insert(faults, "❌ " .. msg)
		end
	end

	if amuletData.Fake == true then
		isFake = true
		if type(amuletData.Faults) == "table" then
			for _, fault in ipairs(amuletData.Faults) do
				if type(fault) == "table" then
					addFault(fault.Value or fault.Text or "จุดผิดปกติ")
				else
					addFault(fault)
				end
			end
		end
	end

	local features = amuletData.Features
	if type(features) == "table" then
		if modelInfo.Mesh then
			if features.Variant and features.Variant ~= modelInfo.Mesh then
				isFake = true
				local matched = false
				for _, chk in ipairs(modelInfo.Checks or {}) do
					if chk.Fake == features.Variant then
						addFault(chk.Why or chk.Text or ("พิมพ์ผิด: " .. tostring(features.Variant)))
						matched = true
						break
					end
				end
				if not matched then
					addFault("พิมพ์ไม่ตรงของแท้ (" .. tostring(features.Variant) .. ")")
				end
			end

			if features.Proc ~= nil then
				isFake = true
				local matched = false
				for _, chk in ipairs(modelInfo.Checks or {}) do
					if chk.Proc == features.Proc then
						addFault(chk.Why or chk.Text or ("ตำหนิผิด: " .. tostring(features.Proc)))
						matched = true
						break
					end
				end
				if not matched then
					addFault("ตำหนิผิดปกติ (" .. tostring(features.Proc) .. ")")
				end
			end
		else
			for _, chk in ipairs(modelInfo.Checks or {}) do
				local val = features[chk.Key]
				if val ~= nil and val ~= chk.Genuine then
					isFake = true
					local ok, why = pcall(function()
						return AmuletLab.WhyOf and AmuletLab.WhyOf(chk, val)
					end)
					if ok and why then
						addFault(why)
					else
						addFault((chk.Text or chk.Key) .. " (" .. tostring(val) .. ")")
					end
				end
			end
		end
	end

	return {
		isFake = isFake,
		faults = faults,
		modelInfo = modelInfo,
		data = amuletData,
	}
end

function Krypt:applyHighlight(model, isFake)
	if not self.isRunning or not self.isEnabled or not model or not model.Parent then return end

	for _, child in pairs(model:GetChildren()) do
		if child:IsA("Highlight") then
			if child.Name == "SongPhraHL" then
				child:Destroy()
			else
				child.Enabled = false
			end
		end
	end

	local hl = Instance.new("Highlight")
	hl.Name = "SongPhraHL"
	hl.Adornee = model
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.FillTransparency = 0.3
	hl.OutlineTransparency = 0

	if isFake then
		hl.FillColor = COLORS.RED_FILL
		hl.OutlineColor = COLORS.RED_OUTLINE
	else
		hl.FillColor = COLORS.GREEN_FILL
		hl.OutlineColor = COLORS.GREEN_OUTLINE
	end

	hl.Parent = model
end

function Krypt:updateGUI(analysis, model)
	if not self.isRunning or not self.isEnabled or not self.statusLabel or not analysis then return end

	local data = analysis.data
	local modelInfo = analysis.modelInfo
	local name = modelInfo.Name or data.Model
	local price = tonumber(modelInfo.Price) or 0
	local materials = AmuletLab.Materials
	local mat = (data.Mat and type(materials) == "table") and materials[data.Mat] or nil
	local matName = (type(mat) == "table" and mat.Name) or "ปกติ"
	local condition = tonumber(data.Condition) or 100
	local offer = data.Offer
	local realValue = math.floor(price * (0.5 + condition / 100 * 0.8) / 10 + 0.5) * 10

	self.currentModel = model

	if analysis.isFake then
		self.statusLabel.Text = "🔴 ของเก๊!  ❌ อย่าเช่า!\n" .. name
		self.statusLabel.TextColor3 = Color3.fromRGB(255, 70, 70)

		if offer then
			self.infoLabel.Text = "💰 เสนอ " .. formatMoney(offer) .. " (ราคากลาง " .. formatMoney(price) .. ")"
		else
			self.infoLabel.Text = "⚠️ พบจุดผิดปกติ • ราคากลาง " .. formatMoney(price)
		end
		self.infoLabel.TextColor3 = Color3.fromRGB(255, 180, 180)

		self.faultLabel.Text = #analysis.faults > 0 and table.concat(analysis.faults, "\n") or "❌ จุดผิดปกติ"
		self.faultLabel.TextColor3 = Color3.fromRGB(255, 150, 150)

		self:tryAutoRejectFake(model, analysis)
	else
		self.statusLabel.Text = "🟢 ของแท้!  ✅ เช่าได้!\n" .. name
		self.statusLabel.TextColor3 = Color3.fromRGB(70, 255, 70)

		self.infoLabel.Text = matName .. " • สภาพ " .. condition .. "/100 • มูลค่า " .. formatMoney(realValue)
		self.infoLabel.TextColor3 = Color3.fromRGB(180, 255, 180)

		if offer then
			local profit = realValue - (tonumber(offer) or 0)
			self.faultLabel.Text = "💰 เสนอ " .. formatMoney(offer) .. " → กำไร " .. formatMoney(profit)
		else
			self.faultLabel.Text = "✅ ตำหนิ/พิมพ์ตรงตามตำรา (ราคากลาง " .. formatMoney(price) .. ")"
		end
		self.faultLabel.TextColor3 = Color3.fromRGB(150, 255, 150)

		self:tryAutoBuyGenuine(model, analysis)
	end
end

function Krypt:hookBuild()
	if self.originalBuild then return end
	if type(AmuletLab.Build) ~= "function" then
		warn("[Krypt] ไม่พบ AmuletLab.Build")
		return
	end

	if _G.KryptOriginalBuild then
		AmuletLab.Build = _G.KryptOriginalBuild
	end

	self.originalBuild = AmuletLab.Build
	_G.KryptOriginalBuild = self.originalBuild

	AmuletLab.Build = function(amuletData, parent, ...)
		local model = self.originalBuild(amuletData, parent, ...)
		if not self.isRunning or not self.isEnabled or not model then
			return model
		end

		if parent and (parent:IsA("ViewportFrame") or parent:FindFirstAncestorWhichIsA("ViewportFrame")) then
			return model
		end

		local analysis = self:analyzeAmulet(amuletData)
		if not analysis then
			return model
		end

		task.defer(function()
			if not self.isRunning or not self.isEnabled or not model or not model.Parent then return end
			if model:FindFirstAncestorWhichIsA("ViewportFrame") then return end

			self.trackedModels[model] = analysis
			self:applyHighlight(model, analysis.isFake)
			pcall(function()
				self:updateGUI(analysis, model)
			end)

			model.ChildAdded:Connect(function(child)
				if not self.isRunning or not self.isEnabled then return end
				if child:IsA("Highlight") and child.Name ~= "SongPhraHL" then
					task.defer(function()
						if child.Parent then child.Enabled = false end
					end)
					pcall(function()
						self:updateGUI(analysis, model)
					end)
				elseif child:IsA("BillboardGui") then
					pcall(function()
						self:updateGUI(analysis, model)
					end)
				end
			end)
		end)

		return model
	end
end

function Krypt:startHeartbeat()
	if self.heartbeatConn then
		self.heartbeatConn:Disconnect()
	end

	self.heartbeatConn = RunService.Heartbeat:Connect(function()
		if not self.isRunning or not self.isEnabled then return end

		for model, _ in pairs(self.trackedModels) do
			if not model or not model.Parent then
				self.trackedModels[model] = nil
				self.boughtModels[model] = nil
				self.rejectedModels[model] = nil
			end
		end

		if self.currentModel and not self.currentModel.Parent then
			self.currentModel = nil
			local nextModel, nextAnalysis = next(self.trackedModels)
			if nextModel and nextAnalysis then
				pcall(function()
					self:updateGUI(nextAnalysis, nextModel)
				end)
			elseif self.statusLabel then
				self.statusLabel.Text = "⏳ กำลังรอพระองค์ต่อไป..."
				self.statusLabel.TextColor3 = COLORS.GRAY_STATUS
				if self.infoLabel then self.infoLabel.Text = "" end
				if self.faultLabel then self.faultLabel.Text = "" end
			end
		end

		if self.autoInspectTray and not (self.currentModel and self.currentModel.Parent) then
			self:tryAutoInspectTray()
		end
	end)
end

function Krypt:destroy()
	self.isRunning = false
	self.isEnabled = false
	self.autoBuyGenuine = false
	self.autoRejectFake = false
	self.autoInspectTray = false

	if self.heartbeatConn then
		self.heartbeatConn:Disconnect()
		self.heartbeatConn = nil
	end
	if self.inputChangedConn then
		self.inputChangedConn:Disconnect()
		self.inputChangedConn = nil
	end
	if self.inputEndedConn then
		self.inputEndedConn:Disconnect()
		self.inputEndedConn = nil
	end

	self:clearHighlights()
	self.trackedModels = {}
	self.boughtModels = {}
	self.rejectedModels = {}
	self.inspectedTargets = {}

	if self.originalBuild then
		AmuletLab.Build = self.originalBuild
		_G.KryptOriginalBuild = nil
		self.originalBuild = nil
	end

	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end

	print("[Krypt] ปิดสคริปต์แล้ว คืน hook แล้ว")
end

function Krypt:start()
	self:createGUI()
	self:hookBuild()
	self:startHeartbeat()
end

if _G.KryptInstance and type(_G.KryptInstance.destroy) == "function" then
	pcall(function()
		_G.KryptInstance:destroy()
	end)
end

local krypt = Krypt.new()
_G.KryptInstance = krypt
krypt:start()
