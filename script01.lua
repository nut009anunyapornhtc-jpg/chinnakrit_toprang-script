local keysURL = "https://raw.githubusercontent.com/nut009anunyapornhtc-jpg/chinnakrit_toprang-script/refs/heads/main/README.md"
local realScriptURL = "https://pastebin.com/raw/0sGhQ26e"
local keyFileName = "ThanonPhra_SavedKey.txt"

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end
local currentUserId = tostring(LocalPlayer.UserId)

local uiParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")

if uiParent:FindFirstChild("KeyLoader") then
    uiParent.KeyLoader:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KeyLoader"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = uiParent

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 300, 0, 180)
Frame.Position = UDim2.new(0.5, -150, 0.5, -90)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
Frame.BackgroundTransparency = 0.35
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 16)

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(255, 255, 255)
Stroke.Thickness = 1
Stroke.Transparency = 0.6
Stroke.Parent = Frame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "🔑 กรุณากรอกคีย์เพื่อใช้งาน"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Parent = Frame

local TextBox = Instance.new("TextBox")
TextBox.Size = UDim2.new(1, -40, 0, 40)
TextBox.Position = UDim2.new(0, 20, 0, 50)
TextBox.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
TextBox.BackgroundTransparency = 0.5
TextBox.BorderSizePixel = 0
TextBox.Font = Enum.Font.Gotham
TextBox.PlaceholderText = "ใส่คีย์ของคุณที่นี่..."
TextBox.Text = ""
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.TextSize = 14
TextBox.Parent = Frame
Instance.new("UICorner", TextBox).CornerRadius = UDim.new(0, 8)

local SubmitBtn = Instance.new("TextButton")
SubmitBtn.Size = UDim2.new(1, -40, 0, 40)
SubmitBtn.Position = UDim2.new(0, 20, 0, 110)
SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
SubmitBtn.BackgroundTransparency = 0.2
SubmitBtn.Font = Enum.Font.GothamBold
SubmitBtn.Text = "✅ ยืนยันคีย์"
SubmitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SubmitBtn.TextSize = 16
SubmitBtn.Parent = Frame
Instance.new("UICorner", SubmitBtn).CornerRadius = UDim.new(0, 8)

local MsgLabel = Instance.new("TextLabel")
MsgLabel.Size = UDim2.new(1, -40, 0, 20)
MsgLabel.Position = UDim2.new(0, 20, 1, -25)
MsgLabel.BackgroundTransparency = 1
MsgLabel.Font = Enum.Font.Gotham
MsgLabel.Text = "⏳ กำลังโหลดข้อมูลคีย์..."
MsgLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
MsgLabel.TextSize = 12
MsgLabel.Parent = Frame

local validKeyMap = {}
local isDataLoaded = false

local function fetchKeyData()
    local success, result = pcall(function()
        return game:HttpGet(keysURL)
    end)
    
    if not success or not result then
        MsgLabel.Text = "❌ โหลดรายชื่อคีย์จาก GitHub ไม่สำเร็จ"
        MsgLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end
    
    local keyMap = {}
    for line in result:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        local keyPart, idPart = trimmed:match("^([^:]+):(%d+)$")
        if keyPart and idPart then
            keyMap[keyPart:match("^%s*(.-)%s*$")] = idPart
        end
    end
    validKeyMap = keyMap
    isDataLoaded = true
    MsgLabel.Text = ""
end

local function checkKeyAndId(inputKey)
    if not isDataLoaded then
        fetchKeyData()
    end
    local boundUserId = validKeyMap[inputKey]
    if not boundUserId then
        return false, "❌ คีย์ไม่ถูกต้อง หรือรูปแบบใน GitHub ผิด"
    end
    if boundUserId ~= currentUserId then
        return false, "⛔ คีย์นี้ถูกผูกไว้กับไอดีอื่นแล้ว!"
    end
    return true, "✅ ยืนยันตัวตนสำเร็จ! กำลังโหลด..."
end

local function getSavedKey()
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        local ok, exists = pcall(isfile, keyFileName)
        if ok and exists then
            local readOk, content = pcall(readfile, keyFileName)
            if readOk and type(content) == "string" then
                return content:match("^%s*(.-)%s*$")
            end
        end
    end
    return nil
end

local function saveKey(key)
    if typeof(writefile) == "function" then
        pcall(function() writefile(keyFileName, key) end)
    end
end

local function removeSavedKey()
    if typeof(isfile) == "function" and typeof(delfile) == "function" then
        pcall(function()
            if isfile(keyFileName) then delfile(keyFileName) end
        end)
    end
end

local function loadRealScript(msg)
    MsgLabel.Text = msg
    MsgLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    
    local success, err = pcall(function()
        loadstring(game:HttpGet(realScriptURL))()
    end)
    
    if success then
        ScreenGui:Destroy()
    else
        MsgLabel.Text = "❌ โหลดสคริปต์หลักไม่สำเร็จ (Pastebin)"
        MsgLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        warn("Load Error:", err)
    end
end

task.spawn(function()
    fetchKeyData()
    local savedKey = getSavedKey()
    if savedKey and savedKey ~= "" then
        TextBox.Text = savedKey
        local isValid, msg = checkKeyAndId(savedKey)
        if isValid then
            loadRealScript(msg)
        else
            removeSavedKey()
            TextBox.Text = ""
            MsgLabel.Text = msg
            MsgLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end
end)

SubmitBtn.MouseButton1Click:Connect(function()
    local enteredKey = TextBox.Text:match("^%s*(.-)%s*$")
    if enteredKey == "" then return end

    local isValid, msg = checkKeyAndId(enteredKey)
    if isValid then
        saveKey(enteredKey)
        loadRealScript(msg)
    else
        MsgLabel.Text = msg
        MsgLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        TextBox.Text = ""
    end
end)

TextBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        SubmitBtn:Activate()
    end
end)
