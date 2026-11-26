local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
	COLLAPSE_BG   = Color3.fromRGB(75, 75, 85),
}

local FULL_SIZE = UDim2.new(0, 360, 0, 210)
local MINI_SIZE = UDim2.new(0, 360, 0, 40)
local DEFAULT_POS = UDim2.new(0, 10, 0.5, -105)

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
	self.currentPos = DEFAULT_POS
	self.currentModel = nil
	self.trackedModels = {}
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

	-- แถบด้านบนสำหรับลากย้ายหน้าต่าง
	local headerBar = Instance.new("Frame")
	headerBar.Name = "Header"
	headerBar.Size = UDim2.new(1, 0, 0, 38)
	headerBar.Position = UDim2.new(0, 0, 0, 0)
	headerBar.BackgroundTransparency = 1
	headerBar.BorderSizePixel = 0
	headerBar.ZIndex = 2
	headerBar.Parent = frame

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -172, 0, 24)
	titleLabel.Position = UDim2.new(0, 10, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextScaled = true
	titleLabel.Text = "🔍 Cr.Chinnakrit Topang"
	titleLabel.TextColor3 = COLORS.GRAY_TITLE
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.ZIndex = 2
	titleLabel.Parent = headerBar

	-- ปุ่มเลื่อนเปิด/ปิดสคริปต์ (Toggle Switch)
	local switchText = Instance.new("TextLabel")
	switchText.Size = UDim2.new(0, 48, 0, 20)
	switchText.Position = UDim2.new(1, -134, 0, 10)
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
	switchTrack.Position = UDim2.new(1, -82, 0, 9)
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
	collapseBtn.Size = UDim2.new(0, 26, 0, 22)
	collapseBtn.Position = UDim2.new(1, -34, 0, 9)
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
	statusLabel.Size = UDim2.new(1, -20, 0, 50)
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
	infoLabel.Position = UDim2.new(0, 10, 0, 56)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextScaled = true
	infoLabel.TextWrapped = true
	infoLabel.Text = ""
	infoLabel.TextColor3 = COLORS.GRAY_INFO
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = bodyContainer

	local faultLabel = Instance.new("TextLabel")
	faultLabel.Size = UDim2.new(1, -20, 0, 54)
	faultLabel.Position = UDim2.new(0, 10, 0, 84)
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
	closeBtn.Size = UDim2.new(0, 100, 0, 26)
	closeBtn.Position = UDim2.new(0, 10, 1, -32)
	closeBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextScaled = true
	closeBtn.Text = "❌ ปิดสคริปต์"
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Parent = bodyContainer
	Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

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
	self.collapseBtn = collapseBtn
	self:updateSwitchVisual(true)
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
	end)
end

function Krypt:destroy()
	self.isRunning = false
	self.isEnabled = false

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
