local cloneref = cloneref or function(o) return o end
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MatchUI = Remotes:WaitForChild("MatchUI")
local SubmitWord = Remotes:WaitForChild("SubmitWord")
local BillboardUpdate = Remotes:WaitForChild("BillboardUpdate")

-- ============================================================
-- WORD DATA
-- ============================================================
local Prefix1 = {}
local Prefix2 = {}

local CurrentLetter = nil
local Ready = false
local Options = {}
local IsMinimized = false
local ScriptActive = true

local LetterWordCount = {}

-- ============================================================
-- AUTO ANSWER STATE
-- ============================================================
local AutoAnswerEnabled = false
local AutoAnswerReady = false
local AutoAnswerAnswered = false
local AutoAnswerRound = 0

local MatchUsedWords = {}
local CurrentMatchId = 0
local LastSubmittedWord = nil

-- ============================================================
-- HUMAN MODE STATE
-- Mode: delay sebelum ketik ~0.7s, sengaja typo+koreksi, skip killer letter
-- ============================================================
local HumanModeEnabled = false

-- ============================================================
-- FAKE TYPE STATE
-- User ketik kata palsu di textbox → script detect huruf akhir → cari & submit kata nyata
-- ============================================================
local FakeTypeEnabled = false
local FakeTypeConnection = nil  -- koneksi listener textbox

-- ============================================================
-- KILLER LETTER CONFIG
-- ============================================================
local KILLER_SCORE_OVERRIDE = {
	x = 99999, z = 95000, q = 90000, v = 70000, f = 60000,
	w = 50000, y = 45000, j = 35000, k = 30000, g = 25000, c = 22000,
}

local MAX_BUTTONS = 50

-- ============================================================
-- TYPING CONFIG (Human-like)
-- ============================================================
local TYPING_CONFIG = {
	thinkDelayMin = 1.2,
	thinkDelayMax = 3.0,
	charDelayMin = 0.12,
	charDelayMax = 0.30,
	pauseChance = 0.12,
	pauseDelayMin = 0.3,
	pauseDelayMax = 0.7,
	submitDelayMin = 0.3,
	submitDelayMax = 0.8,
	hardDeadline = 11.0,
}

-- ============================================================
-- HUMAN MODE CONFIG
-- ============================================================
local HUMAN_CONFIG = {
	-- Delay awal sebelum mulai ketik (lebih lama dari normal, seperti mikir)
	preTypeDelayMin = 0.6,
	preTypeDelayMax = 1.1,
	-- Typo: chance per karakter untuk sengaja typo lalu backspace+koreksi
	typoChance = 0.18,        -- 18% per karakter
	typoHoldMin = 0.15,       -- berapa lama karakter salah terlihat sebelum dikoreksi
	typoHoldMax = 0.45,
	-- Karakter tetangga keyboard QWERTY untuk typo realistis
	qwertyNeighbors = {
		a={"q","w","s","z"}, b={"v","g","h","n"}, c={"x","d","f","v"},
		d={"s","e","r","f","c","x"}, e={"w","r","d","s"}, f={"d","r","t","g","v","c"},
		g={"f","t","y","h","b","v"}, h={"g","y","u","j","n","b"}, i={"u","o","k","j"},
		j={"h","u","i","k","m","n"}, k={"j","i","o","l","m"}, l={"k","o","p"},
		m={"n","j","k"}, n={"b","h","j","m"}, o={"i","p","l","k"},
		p={"o","l"}, q={"w","a"}, r={"e","t","f","d"}, s={"a","w","e","d","x","z"},
		t={"r","y","g","f"}, u={"y","i","h","j"}, v={"c","f","g","b"},
		w={"q","e","a","s"}, x={"z","s","d","c"}, y={"t","u","g","h"},
		z={"a","s","x"},
	},
	-- Skip killer letters (x,z,q) — cari kata yang akhirannya bukan killer
	skipKillerLetters = true,
	killerLettersToSkip = {x=true, z=true, q=true},
}

-- ============================================================
-- TWEEN HELPER
-- ============================================================
local function Tween(obj, props, duration, style, dir)
	local info = TweenInfo.new(duration or 0.3, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function TweenWait(obj, props, duration, style, dir)
	local t = Tween(obj, props, duration, style, dir)
	t.Completed:Wait()
end

-- ============================================================
-- NightHubX THEME SYSTEM
-- ============================================================
local Themes = {
	["Night"] = {
		accent       = Color3.fromRGB(120, 80, 255),
		accentLight  = Color3.fromRGB(160, 120, 255),
		accentDark   = Color3.fromRGB(80, 40, 200),
		gradTop      = Color3.fromRGB(10, 8, 20),
		gradBot      = Color3.fromRGB(5, 4, 14),
		cardBg       = Color3.fromRGB(14, 12, 28),
		cardBgAlt    = Color3.fromRGB(18, 16, 34),
		cardHover    = Color3.fromRGB(28, 22, 50),
		panelBg      = Color3.fromRGB(10, 8, 22),
		stroke       = Color3.fromRGB(50, 35, 90),
		strokeLight  = Color3.fromRGB(90, 65, 150),
		textPrimary  = Color3.fromRGB(255, 255, 255),
		textSecondary= Color3.fromRGB(200, 185, 230),
		textMuted    = Color3.fromRGB(130, 115, 165),
		scrollBar    = Color3.fromRGB(120, 80, 255),
		glow         = Color3.fromRGB(150, 100, 255),
		success      = Color3.fromRGB(40, 220, 120),
		error        = Color3.fromRGB(255, 60, 80),
		info         = Color3.fromRGB(80, 180, 255),
		warning      = Color3.fromRGB(255, 190, 40),
	},
	["Crimson"] = {
		accent       = Color3.fromRGB(220, 40, 80),
		accentLight  = Color3.fromRGB(255, 80, 110),
		accentDark   = Color3.fromRGB(160, 20, 50),
		gradTop      = Color3.fromRGB(18, 5, 10),
		gradBot      = Color3.fromRGB(8, 3, 6),
		cardBg       = Color3.fromRGB(20, 8, 14),
		cardBgAlt    = Color3.fromRGB(26, 10, 18),
		cardHover    = Color3.fromRGB(38, 14, 24),
		panelBg      = Color3.fromRGB(14, 5, 10),
		stroke       = Color3.fromRGB(80, 20, 35),
		strokeLight  = Color3.fromRGB(130, 35, 55),
		textPrimary  = Color3.fromRGB(255, 255, 255),
		textSecondary= Color3.fromRGB(215, 180, 190),
		textMuted    = Color3.fromRGB(150, 110, 120),
		scrollBar    = Color3.fromRGB(220, 40, 80),
		glow         = Color3.fromRGB(255, 60, 100),
		success      = Color3.fromRGB(40, 220, 120),
		error        = Color3.fromRGB(255, 60, 80),
		info         = Color3.fromRGB(80, 180, 255),
		warning      = Color3.fromRGB(255, 190, 40),
	},
	["Cyan"] = {
		accent       = Color3.fromRGB(0, 200, 220),
		accentLight  = Color3.fromRGB(60, 235, 255),
		accentDark   = Color3.fromRGB(0, 140, 165),
		gradTop      = Color3.fromRGB(4, 16, 22),
		gradBot      = Color3.fromRGB(2, 8, 12),
		cardBg       = Color3.fromRGB(6, 20, 28),
		cardBgAlt    = Color3.fromRGB(8, 24, 34),
		cardHover    = Color3.fromRGB(12, 34, 46),
		panelBg      = Color3.fromRGB(4, 14, 20),
		stroke       = Color3.fromRGB(0, 70, 90),
		strokeLight  = Color3.fromRGB(0, 110, 140),
		textPrimary  = Color3.fromRGB(255, 255, 255),
		textSecondary= Color3.fromRGB(175, 220, 228),
		textMuted    = Color3.fromRGB(100, 155, 165),
		scrollBar    = Color3.fromRGB(0, 200, 220),
		glow         = Color3.fromRGB(0, 240, 255),
		success      = Color3.fromRGB(40, 220, 120),
		error        = Color3.fromRGB(255, 60, 80),
		info         = Color3.fromRGB(80, 180, 255),
		warning      = Color3.fromRGB(255, 190, 40),
	},
	["Gold"] = {
		accent       = Color3.fromRGB(220, 175, 30),
		accentLight  = Color3.fromRGB(255, 215, 70),
		accentDark   = Color3.fromRGB(165, 130, 10),
		gradTop      = Color3.fromRGB(18, 14, 4),
		gradBot      = Color3.fromRGB(10, 8, 2),
		cardBg       = Color3.fromRGB(22, 18, 6),
		cardBgAlt    = Color3.fromRGB(28, 22, 8),
		cardHover    = Color3.fromRGB(40, 32, 12),
		panelBg      = Color3.fromRGB(16, 12, 4),
		stroke       = Color3.fromRGB(80, 65, 15),
		strokeLight  = Color3.fromRGB(130, 105, 25),
		textPrimary  = Color3.fromRGB(255, 255, 255),
		textSecondary= Color3.fromRGB(225, 210, 165),
		textMuted    = Color3.fromRGB(160, 145, 90),
		scrollBar    = Color3.fromRGB(220, 175, 30),
		glow         = Color3.fromRGB(255, 220, 60),
		success      = Color3.fromRGB(40, 220, 120),
		error        = Color3.fromRGB(255, 60, 80),
		info         = Color3.fromRGB(80, 180, 255),
		warning      = Color3.fromRGB(255, 190, 40),
	},
	["Void"] = {
		accent       = Color3.fromRGB(155, 155, 175),
		accentLight  = Color3.fromRGB(200, 200, 215),
		accentDark   = Color3.fromRGB(110, 110, 130),
		gradTop      = Color3.fromRGB(12, 12, 16),
		gradBot      = Color3.fromRGB(6, 6, 8),
		cardBg       = Color3.fromRGB(16, 16, 20),
		cardBgAlt    = Color3.fromRGB(20, 20, 26),
		cardHover    = Color3.fromRGB(30, 30, 38),
		panelBg      = Color3.fromRGB(10, 10, 14),
		stroke       = Color3.fromRGB(40, 40, 55),
		strokeLight  = Color3.fromRGB(65, 65, 85),
		textPrimary  = Color3.fromRGB(255, 255, 255),
		textSecondary= Color3.fromRGB(190, 190, 205),
		textMuted    = Color3.fromRGB(120, 120, 138),
		scrollBar    = Color3.fromRGB(155, 155, 175),
		glow         = Color3.fromRGB(200, 200, 220),
		success      = Color3.fromRGB(40, 220, 120),
		error        = Color3.fromRGB(255, 60, 80),
		info         = Color3.fromRGB(80, 180, 255),
		warning      = Color3.fromRGB(255, 190, 40),
	},
}

local themeOrder = {"Night", "Crimson", "Cyan", "Gold", "Void"}
local CurrentThemeName = "Night"
local CurrentTheme = Themes[CurrentThemeName]
local SortMode = "strategy"

local ThemeElements = {}

local function ApplyTheme(name)
	local theme = Themes[name]
	if not theme then return end
	CurrentThemeName = name
	CurrentTheme = theme

	for _, entry in ipairs(ThemeElements) do
		if entry.type == "accentLine" then
			entry.obj.BackgroundColor3 = theme.accent
		elseif entry.type == "mainGrad" then
			entry.obj.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, theme.gradTop),
				ColorSequenceKeypoint.new(1, theme.gradBot)
			}
		elseif entry.type == "stroke" then
			entry.obj.Color = theme.stroke
		elseif entry.type == "titleIcon" then
			entry.obj.BackgroundColor3 = theme.accent
		elseif entry.type == "titleIconGlow" then
			entry.obj.BackgroundColor3 = theme.accent
		elseif entry.type == "titleIconStroke" then
			entry.obj.Color = theme.accentLight
		elseif entry.type == "accentGlowGrad" then
			entry.obj.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0,0,0)),
				ColorSequenceKeypoint.new(0.15, theme.accent),
				ColorSequenceKeypoint.new(0.85, theme.accent),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0,0,0)),
			}
		elseif entry.type == "themeBtn" then
			entry.obj.BackgroundColor3 = theme.accent
		elseif entry.type == "prefixLabel" then
			entry.obj.TextColor3 = theme.accent
		elseif entry.type == "statusLabel" then
			entry.obj.TextColor3 = theme.accentLight
		elseif entry.type == "countLabel" then
			entry.obj.TextColor3 = theme.textSecondary
		elseif entry.type == "prefixTitle" then
			entry.obj.TextColor3 = theme.textMuted
		elseif entry.type == "button" then
			local bg = (entry.index % 2 == 0) and theme.cardBgAlt or theme.cardBg
			entry.obj.BackgroundColor3 = bg
		elseif entry.type == "leftPanel" then
			entry.obj.BackgroundColor3 = theme.panelBg
		elseif entry.type == "badge" then
			entry.obj.BackgroundColor3 = theme.accent
			entry.obj.TextColor3 = theme.textPrimary
		elseif entry.type == "leftPanelGrad" then
			entry.obj.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(16,14,32)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(10,8,22)),
			}
		end
	end
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local gui = Instance.new("ScreenGui", PlayerGui)
gui.Name = "NightHubX"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================
local notifContainer = Instance.new("Frame", gui)
notifContainer.Name = "NotifContainer"
notifContainer.Size = UDim2.new(0, 320, 1, 0)
notifContainer.Position = UDim2.new(1, -335, 0, 10)
notifContainer.BackgroundTransparency = 1
notifContainer.ZIndex = 200

local notifLayout = Instance.new("UIListLayout", notifContainer)
notifLayout.Padding = UDim.new(0, 8)
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top

local notifCounter = 0

local NotifIcons  = { success="✅", error="❌", info="ℹ️", warning="⚠️", correct="🎉", wrong="💢", loaded="⚡", unloaded="🔌", danger="💀", strategy="🧠", auto="🤖", filter="🚫" }
local NotifColors = { success=Color3.fromRGB(40,220,120), error=Color3.fromRGB(255,60,80), info=Color3.fromRGB(80,180,255), warning=Color3.fromRGB(255,190,40), correct=Color3.fromRGB(40,230,120), wrong=Color3.fromRGB(255,60,70), loaded=Color3.fromRGB(120,80,255), unloaded=Color3.fromRGB(180,100,50), danger=Color3.fromRGB(200,30,60), strategy=Color3.fromRGB(160,100,255), auto=Color3.fromRGB(0,200,220), filter=Color3.fromRGB(255,120,0) }

local function SendNotification(notifType, titleText, messageText, duration)
	duration = duration or 3.5
	notifCounter = notifCounter + 1

	local nc = NotifColors[notifType] or Color3.fromRGB(120, 80, 255)
	local ni = NotifIcons[notifType] or "🔔"

	local notif = Instance.new("Frame", notifContainer)
	notif.Size = UDim2.new(0, 310, 0, 0)
	notif.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
	notif.BorderSizePixel = 0
	notif.ClipsDescendants = true
	notif.LayoutOrder = notifCounter
	notif.ZIndex = 201
	notif.BackgroundTransparency = 0.05
	Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 12)

	local ns = Instance.new("UIStroke", notif)
	ns.Color = nc; ns.Thickness = 1.5; ns.Transparency = 0.35

	local ng = Instance.new("UIGradient", notif)
	ng.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(18,14,35)), ColorSequenceKeypoint.new(1, Color3.fromRGB(8,6,18))}
	ng.Rotation = 135

	local ab = Instance.new("Frame", notif)
	ab.Size = UDim2.new(0, 4, 1, -12); ab.Position = UDim2.new(0, 6, 0, 6)
	ab.BackgroundColor3 = nc; ab.BorderSizePixel = 0; ab.ZIndex = 203
	Instance.new("UICorner", ab).CornerRadius = UDim.new(0, 3)

	local ag = Instance.new("Frame", notif)
	ag.Size = UDim2.new(0, 40, 1, 0); ag.BackgroundColor3 = nc
	ag.BackgroundTransparency = 0.88; ag.BorderSizePixel = 0; ag.ZIndex = 202
	local agg = Instance.new("UIGradient", ag)
	agg.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)}

	local ico = Instance.new("TextLabel", notif)
	ico.Size = UDim2.new(0, 32, 0, 32); ico.Position = UDim2.new(0, 18, 0, 12)
	ico.BackgroundColor3 = nc; ico.BackgroundTransparency = 0.85
	ico.Text = ni; ico.Font = Enum.Font.GothamBold; ico.TextSize = 16
	ico.TextColor3 = Color3.fromRGB(255,255,255); ico.BorderSizePixel = 0; ico.ZIndex = 204
	Instance.new("UICorner", ico).CornerRadius = UDim.new(0, 8)

	local nt = Instance.new("TextLabel", notif)
	nt.Size = UDim2.new(1, -100, 0, 18); nt.Position = UDim2.new(0, 58, 0, 10)
	nt.BackgroundTransparency = 1; nt.Text = titleText or "NightHubX"
	nt.Font = Enum.Font.GothamBlack; nt.TextSize = 13
	nt.TextColor3 = Color3.fromRGB(255,255,255); nt.TextXAlignment = Enum.TextXAlignment.Left
	nt.TextTruncate = Enum.TextTruncate.AtEnd; nt.ZIndex = 204

	local nm = Instance.new("TextLabel", notif)
	nm.Size = UDim2.new(1, -100, 0, 28); nm.Position = UDim2.new(0, 58, 0, 28)
	nm.BackgroundTransparency = 1; nm.Text = messageText or ""
	nm.Font = Enum.Font.Gotham; nm.TextSize = 11
	nm.TextColor3 = Color3.fromRGB(180,170,210); nm.TextXAlignment = Enum.TextXAlignment.Left
	nm.TextWrapped = true; nm.TextYAlignment = Enum.TextYAlignment.Top; nm.ZIndex = 204

	local ncb = Instance.new("TextButton", notif)
	ncb.Size = UDim2.new(0, 24, 0, 24); ncb.Position = UDim2.new(1, -30, 0, 8)
	ncb.BackgroundColor3 = Color3.fromRGB(255,255,255); ncb.BackgroundTransparency = 0.92
	ncb.Text = "✕"; ncb.Font = Enum.Font.GothamBold; ncb.TextSize = 10
	ncb.TextColor3 = Color3.fromRGB(140,130,165); ncb.BorderSizePixel = 0
	ncb.AutoButtonColor = false; ncb.ZIndex = 205
	Instance.new("UICorner", ncb).CornerRadius = UDim.new(0, 6)
	ncb.MouseEnter:Connect(function() Tween(ncb, {BackgroundTransparency=0.6, TextColor3=Color3.fromRGB(255,255,255)}, 0.15) end)
	ncb.MouseLeave:Connect(function() Tween(ncb, {BackgroundTransparency=0.92, TextColor3=Color3.fromRGB(140,130,165)}, 0.15) end)

	local pb = Instance.new("Frame", notif)
	pb.Size = UDim2.new(1,-16,0,3); pb.Position = UDim2.new(0,8,1,-8)
	pb.BackgroundColor3 = Color3.fromRGB(20,16,40); pb.BorderSizePixel = 0; pb.ZIndex = 203
	Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 2)

	local pf = Instance.new("Frame", pb)
	pf.Size = UDim2.new(1,0,1,0); pf.BackgroundColor3 = nc; pf.BorderSizePixel = 0; pf.ZIndex = 204
	Instance.new("UICorner", pf).CornerRadius = UDim.new(0, 2)

	Tween(notif, {Size = UDim2.new(0,310,0,68)}, 0.35, Enum.EasingStyle.Back)
	Tween(pf, {Size = UDim2.new(0,0,1,0)}, duration, Enum.EasingStyle.Linear)

	local dismissed = false
	local function Dismiss()
		if dismissed then return end
		dismissed = true
		Tween(notif, {Size = UDim2.new(0,310,0,0), BackgroundTransparency=1}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Tween(ns, {Transparency=1}, 0.2)
		task.wait(0.35); notif:Destroy()
	end
	ncb.MouseButton1Click:Connect(Dismiss)
	task.delay(duration, Dismiss)
end

-- ============================================================
-- LOADING SCREEN
-- ============================================================
local loadScreen = Instance.new("Frame", gui)
loadScreen.Name = "LoadScreen"
loadScreen.Size = UDim2.new(1,0,1,0)
loadScreen.BackgroundColor3 = Color3.fromRGB(6, 4, 14)
loadScreen.BorderSizePixel = 0
loadScreen.ZIndex = 100

local loadGrad = Instance.new("UIGradient", loadScreen)
loadGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(10,6,22)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4,2,10)),
}
loadGrad.Rotation = 135

-- Particle stars
for i = 1, 28 do
	local p = Instance.new("Frame", loadScreen)
	p.Name = "Particle"..i
	local sz = math.random(2,5)
	p.Size = UDim2.new(0, sz, 0, sz)
	p.Position = UDim2.new(math.random()*0.98, 0, math.random()*0.98, 0)
	p.BackgroundColor3 = Color3.fromRGB(120+math.random(80), 80+math.random(80), 255)
	p.BackgroundTransparency = 0.3 + math.random()*0.5
	p.BorderSizePixel = 0
	p.ZIndex = 101
	Instance.new("UICorner", p).CornerRadius = UDim.new(1,0)
end

local loadCenter = Instance.new("Frame", loadScreen)
loadCenter.Size = UDim2.new(0, 320, 0, 380)
loadCenter.Position = UDim2.new(0.5, -160, 0.5, -190)
loadCenter.BackgroundTransparency = 1
loadCenter.ZIndex = 102

-- Logo hexagon icon
local hexContainer = Instance.new("Frame", loadCenter)
hexContainer.Size = UDim2.new(0, 90, 0, 90)
hexContainer.Position = UDim2.new(0.5, -45, 0, 10)
hexContainer.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
hexContainer.BackgroundTransparency = 0.15
hexContainer.BorderSizePixel = 0
hexContainer.ZIndex = 103
Instance.new("UICorner", hexContainer).CornerRadius = UDim.new(0, 22)

local hexStroke = Instance.new("UIStroke", hexContainer)
hexStroke.Color = Color3.fromRGB(160, 120, 255); hexStroke.Thickness = 2; hexStroke.Transparency = 0.3

local hexIcon = Instance.new("TextLabel", hexContainer)
hexIcon.Size = UDim2.new(1,0,1,0)
hexIcon.BackgroundTransparency = 1
hexIcon.Text = "✦"
hexIcon.Font = Enum.Font.GothamBlack
hexIcon.TextSize = 48
hexIcon.TextColor3 = Color3.fromRGB(255,255,255)
hexIcon.ZIndex = 104

-- Pulsing glow ring
local glowRing = Instance.new("Frame", loadCenter)
glowRing.Size = UDim2.new(0, 90, 0, 90)
glowRing.Position = UDim2.new(0.5, -45, 0, 10)
glowRing.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
glowRing.BackgroundTransparency = 0.75
glowRing.BorderSizePixel = 0
glowRing.ZIndex = 102
Instance.new("UICorner", glowRing).CornerRadius = UDim.new(0, 22)

task.spawn(function()
	while glowRing and glowRing.Parent do
		TweenWait(glowRing, {Size=UDim2.new(0,110,0,110), Position=UDim2.new(0.5,-55,0,0), BackgroundTransparency=0.88}, 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		TweenWait(glowRing, {Size=UDim2.new(0,90,0,90), Position=UDim2.new(0.5,-45,0,10), BackgroundTransparency=0.72}, 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
end)

local loadTitle = Instance.new("TextLabel", loadCenter)
loadTitle.Size = UDim2.new(1,0,0,42)
loadTitle.Position = UDim2.new(0,0,0,115)
loadTitle.BackgroundTransparency = 1
loadTitle.Text = "NightHubX"
loadTitle.Font = Enum.Font.GothamBlack
loadTitle.TextSize = 42
loadTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
loadTitle.ZIndex = 103

local loadGradTitle = Instance.new("UIGradient", loadTitle)
loadGradTitle.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(160,120,255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80,200,255)),
}

local loadSub = Instance.new("TextLabel", loadCenter)
loadSub.Size = UDim2.new(1,0,0,20)
loadSub.Position = UDim2.new(0,0,0,158)
loadSub.BackgroundTransparency = 1
loadSub.Text = "Word Auto-Detect • Strategy Engine • v4"
loadSub.Font = Enum.Font.GothamMedium
loadSub.TextSize = 14
loadSub.TextColor3 = Color3.fromRGB(120, 80, 255)
loadSub.ZIndex = 103

local loadBarBg = Instance.new("Frame", loadCenter)
loadBarBg.Size = UDim2.new(0, 260, 0, 5)
loadBarBg.Position = UDim2.new(0.5,-130,0,195)
loadBarBg.BackgroundColor3 = Color3.fromRGB(20, 16, 40)
loadBarBg.BorderSizePixel = 0
loadBarBg.ZIndex = 103
Instance.new("UICorner", loadBarBg).CornerRadius = UDim.new(1,0)

local loadBar = Instance.new("Frame", loadBarBg)
loadBar.Size = UDim2.new(0,0,1,0)
loadBar.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
loadBar.BorderSizePixel = 0
loadBar.ZIndex = 104
Instance.new("UICorner", loadBar).CornerRadius = UDim.new(1,0)

local loadBarFill = Instance.new("UIGradient", loadBar)
loadBarFill.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120,80,255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200,160,255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(80,180,255)),
}

local loadStatus = Instance.new("TextLabel", loadCenter)
loadStatus.Size = UDim2.new(1,0,0,16)
loadStatus.Position = UDim2.new(0,0,0,208)
loadStatus.BackgroundTransparency = 1
loadStatus.Text = "Menginisialisasi NightHubX..."
loadStatus.Font = Enum.Font.Gotham
loadStatus.TextSize = 11
loadStatus.TextColor3 = Color3.fromRGB(110, 90, 160)
loadStatus.ZIndex = 103

-- Animate load elements in
loadTitle.TextTransparency = 1; loadSub.TextTransparency = 1
loadBarBg.BackgroundTransparency = 1; loadBar.BackgroundTransparency = 1
loadStatus.TextTransparency = 1
hexContainer.Size = UDim2.new(0,0,0,0); hexContainer.Position = UDim2.new(0.5,0,0,55)

task.spawn(function()
	task.wait(0.3)
	Tween(hexContainer, {Size=UDim2.new(0,90,0,90), Position=UDim2.new(0.5,-45,0,10)}, 0.6, Enum.EasingStyle.Back)
	task.wait(0.4)
	Tween(loadTitle, {TextTransparency=0}, 0.5)
	task.wait(0.15)
	Tween(loadSub, {TextTransparency=0}, 0.5)
	task.wait(0.2)
	Tween(loadBarBg, {BackgroundTransparency=0}, 0.3)
	Tween(loadBar, {BackgroundTransparency=0}, 0.3)
	Tween(loadStatus, {TextTransparency=0}, 0.3)
end)

-- ============================================================
-- MAIN FRAME
-- ============================================================
local shadow = Instance.new("ImageLabel", gui)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(0,0,0)
shadow.ImageTransparency = 1
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(49,49,450,450)
shadow.Size = UDim2.new(0,760,0,500)
shadow.Position = UDim2.new(0.5,-400,0.5,-270)
shadow.ZIndex = 1

local frame = Instance.new("Frame", gui)
frame.Name = "MainFrame"
frame.Size = UDim2.new(0,720,0,460)
frame.Position = UDim2.new(0.5,-360,0.5,-230)
frame.BackgroundColor3 = Color3.fromRGB(8,6,18)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.ClipsDescendants = true
frame.Visible = false
frame.ZIndex = 2
Instance.new("UICorner", frame).CornerRadius = UDim.new(0,16)

local mainStroke = Instance.new("UIStroke", frame)
mainStroke.Color = CurrentTheme.stroke
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.1
table.insert(ThemeElements, {type="stroke", obj=mainStroke})

local mainGrad = Instance.new("UIGradient", frame)
mainGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, CurrentTheme.gradTop),
	ColorSequenceKeypoint.new(1, CurrentTheme.gradBot)
}
mainGrad.Rotation = 145
table.insert(ThemeElements, {type="mainGrad", obj=mainGrad})

frame:GetPropertyChangedSignal("Position"):Connect(function()
	shadow.Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset-20, frame.Position.Y.Scale, frame.Position.Y.Offset-20)
end)

-- ============================================================
-- TOP BAR
-- ============================================================
local topBar = Instance.new("Frame", frame)
topBar.Size = UDim2.new(1,0,0,50)
topBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
topBar.BackgroundTransparency = 0.45
topBar.BorderSizePixel = 0
topBar.ZIndex = 5
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0,16)

local topBarFill = Instance.new("Frame", topBar)
topBarFill.Size = UDim2.new(1,0,0,20)
topBarFill.Position = UDim2.new(0,0,1,-20)
topBarFill.BackgroundColor3 = Color3.fromRGB(0,0,0)
topBarFill.BackgroundTransparency = 0.45
topBarFill.BorderSizePixel = 0
topBarFill.ZIndex = 5

local accentLine = Instance.new("Frame", frame)
accentLine.Size = UDim2.new(1,0,0,2)
accentLine.Position = UDim2.new(0,0,0,50)
accentLine.BackgroundColor3 = CurrentTheme.accent
accentLine.BorderSizePixel = 0
accentLine.ZIndex = 6
table.insert(ThemeElements, {type="accentLine", obj=accentLine})

local accentGlowGrad = Instance.new("UIGradient", accentLine)
accentGlowGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0,0,0)),
	ColorSequenceKeypoint.new(0.15, CurrentTheme.accent),
	ColorSequenceKeypoint.new(0.85, CurrentTheme.accent),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0,0,0))
}
accentGlowGrad.Transparency = NumberSequence.new{
	NumberSequenceKeypoint.new(0,0.9), NumberSequenceKeypoint.new(0.5,0), NumberSequenceKeypoint.new(1,0.9)
}
table.insert(ThemeElements, {type="accentGlowGrad", obj=accentGlowGrad})

-- Title icon
local titleIconGlow = Instance.new("Frame", topBar)
titleIconGlow.Size = UDim2.new(0,40,0,40)
titleIconGlow.Position = UDim2.new(0,8,0.5,-20)
titleIconGlow.BackgroundColor3 = CurrentTheme.accent
titleIconGlow.BackgroundTransparency = 0.78
titleIconGlow.BorderSizePixel = 0
titleIconGlow.ZIndex = 5
Instance.new("UICorner", titleIconGlow).CornerRadius = UDim.new(0,12)
table.insert(ThemeElements, {type="titleIconGlow", obj=titleIconGlow})

local titleIcon = Instance.new("TextLabel", topBar)
titleIcon.Size = UDim2.new(0,34,0,34)
titleIcon.Position = UDim2.new(0,11,0.5,-17)
titleIcon.BackgroundColor3 = CurrentTheme.accent
titleIcon.Text = "✦"
titleIcon.Font = Enum.Font.GothamBlack
titleIcon.TextSize = 18
titleIcon.TextColor3 = Color3.fromRGB(255,255,255)
titleIcon.BorderSizePixel = 0
titleIcon.ZIndex = 6
Instance.new("UICorner", titleIcon).CornerRadius = UDim.new(0,10)
table.insert(ThemeElements, {type="titleIcon", obj=titleIcon})

local titleIconStroke = Instance.new("UIStroke", titleIcon)
titleIconStroke.Color = CurrentTheme.accentLight
titleIconStroke.Thickness = 1.2; titleIconStroke.Transparency = 0.4
table.insert(ThemeElements, {type="titleIconStroke", obj=titleIconStroke})

local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(0,300,0,24)
title.Position = UDim2.new(0,54,0,5)
title.BackgroundTransparency = 1
title.Text = "NightHubX"
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(255,255,255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 6

local titleGrad = Instance.new("UIGradient", title)
titleGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(200,170,255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(100,210,255)),
}

local subtitle = Instance.new("TextLabel", topBar)
subtitle.Size = UDim2.new(0,320,0,14)
subtitle.Position = UDim2.new(0,54,0,29)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Word Auto-Detect • Strategy+ Engine • DupFilter v4"
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 10
subtitle.TextColor3 = CurrentTheme.textMuted
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 6

-- ============================================================
-- CONTROL BUTTONS
-- ============================================================
local function MakeCtrlBtn(name, text, hoverCol, posX, tsz)
	local btn = Instance.new("TextButton", topBar)
	btn.Name = name
	btn.Size = UDim2.new(0,32,0,32)
	btn.Position = UDim2.new(1,posX,0.5,-16)
	btn.BackgroundColor3 = Color3.fromRGB(255,255,255)
	btn.BackgroundTransparency = 0.92
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = tsz or 14
	btn.TextColor3 = Color3.fromRGB(170,160,200)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ZIndex = 6
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,9)
	btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3=hoverCol, BackgroundTransparency=0.12, TextColor3=Color3.fromRGB(255,255,255)}, 0.18) end)
	btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3=Color3.fromRGB(255,255,255), BackgroundTransparency=0.92, TextColor3=Color3.fromRGB(170,160,200)}, 0.18) end)
	return btn
end

local closeBtn    = MakeCtrlBtn("CloseBtn",    "✕", Color3.fromRGB(220,50,70),  -44, 13)
local minimizeBtn = MakeCtrlBtn("MinimizeBtn", "—", Color3.fromRGB(200,170,30), -82, 14)
local themeBtn    = MakeCtrlBtn("ThemeBtn",    "◆", CurrentTheme.accent,       -120, 12)
local sortBtn     = MakeCtrlBtn("SortBtn",     "🧠", Color3.fromRGB(160,100,255),-158, 12)
local unloadBtn   = MakeCtrlBtn("UnloadBtn",   "⏏", Color3.fromRGB(180,100,50), -196, 13)

local UpdatePreview
local autoAnswerStatusLabel

closeBtn.MouseButton1Click:Connect(function()
	SendNotification("info", "NightHubX", "Menutup...", 1.5)
	task.wait(0.3)
	Tween(frame, {Size=UDim2.new(0,0,0,0), Position=UDim2.new(0.5,0,0.5,0)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	Tween(shadow, {ImageTransparency=1}, 0.3)
	task.wait(0.5); gui:Destroy()
end)

local OriginalSize = frame.Size
local OriginalShadowSize = shadow.Size

minimizeBtn.MouseButton1Click:Connect(function()
	if IsMinimized then
		IsMinimized = false
		Tween(frame, {Size=OriginalSize}, 0.35, Enum.EasingStyle.Back)
		Tween(shadow, {Size=OriginalShadowSize, ImageTransparency=0.5}, 0.35)
	else
		IsMinimized = true
		Tween(frame, {Size=UDim2.new(0,720,0,50)}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		Tween(shadow, {Size=UDim2.new(0,760,0,90), ImageTransparency=0.72}, 0.35)
	end
end)

sortBtn.MouseButton1Click:Connect(function()
	SortMode = (SortMode == "strategy") and "difficulty" or "strategy"
	local msg = (SortMode == "strategy") and "Mode: Strategy+ 🧠 | Akhiran x/z/q paling atas!" or "Mode: Difficulty | Urut tingkat kesulitan"
	SendNotification("strategy", "Sort Mode", msg, 2.5)
	if UpdatePreview then UpdatePreview() end
end)

unloadBtn.MouseButton1Click:Connect(function()
	if not ScriptActive then return end
	ScriptActive = false; AutoAnswerEnabled = false
	SendNotification("unloaded", "NightHubX Di-unload", "Script telah dimatikan.", 2.5)
	task.wait(1)
	Tween(frame, {Size=UDim2.new(0,0,0,0), Position=UDim2.new(0.5,0,0.5,0)}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.6); gui:Destroy()
end)

-- ============================================================
-- THEME PANEL
-- ============================================================
local themePanel = Instance.new("Frame", gui)
themePanel.Size = UDim2.new(0,200,0,0)
themePanel.Position = UDim2.new(0.5,220,0.5,-230)
themePanel.BackgroundColor3 = Color3.fromRGB(12,10,24)
themePanel.BorderSizePixel = 0
themePanel.Visible = false
themePanel.ZIndex = 50
themePanel.ClipsDescendants = true
Instance.new("UICorner", themePanel).CornerRadius = UDim.new(0,12)
local tps = Instance.new("UIStroke", themePanel)
tps.Color = Color3.fromRGB(50,35,90); tps.Thickness = 1.2

local tpHeader = Instance.new("TextLabel", themePanel)
tpHeader.Size = UDim2.new(1,0,0,28)
tpHeader.BackgroundTransparency = 1
tpHeader.Text = "  ◆  PILIH TEMA"
tpHeader.Font = Enum.Font.GothamBold
tpHeader.TextSize = 11
tpHeader.TextColor3 = Color3.fromRGB(160,130,220)
tpHeader.TextXAlignment = Enum.TextXAlignment.Left
tpHeader.ZIndex = 52

local tpLayout = Instance.new("UIListLayout", themePanel)
tpLayout.Padding = UDim.new(0,2)
tpLayout.SortOrder = Enum.SortOrder.LayoutOrder

local themeBtnList = {}
for idx, name in ipairs(themeOrder) do
	local theme = Themes[name]
	local optBtn = Instance.new("TextButton", themePanel)
	optBtn.Size = UDim2.new(1,0,0,38)
	optBtn.BackgroundColor3 = Color3.fromRGB(20,16,38)
	optBtn.BorderSizePixel = 0
	optBtn.Text = ""
	optBtn.AutoButtonColor = false
	optBtn.ZIndex = 51
	optBtn.LayoutOrder = idx+1
	Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0,7)

	local dot = Instance.new("Frame", optBtn)
	dot.Size = UDim2.new(0,14,0,14)
	dot.Position = UDim2.new(0,10,0.5,-7)
	dot.BackgroundColor3 = theme.accent
	dot.BorderSizePixel = 0; dot.ZIndex = 52
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

	local nl = Instance.new("TextLabel", optBtn)
	nl.Size = UDim2.new(1,-70,1,0); nl.Position = UDim2.new(0,32,0,0)
	nl.BackgroundTransparency = 1; nl.Text = name
	nl.Font = Enum.Font.GothamBold; nl.TextSize = 13
	nl.TextColor3 = Color3.fromRGB(200,190,220); nl.TextXAlignment = Enum.TextXAlignment.Left; nl.ZIndex = 52

	local check = Instance.new("TextLabel", optBtn)
	check.Name = "Check"
	check.Size = UDim2.new(0,20,0,20); check.Position = UDim2.new(1,-28,0.5,-10)
	check.BackgroundTransparency = 1
	check.Text = (name == CurrentThemeName) and "✓" or ""
	check.Font = Enum.Font.GothamBold; check.TextSize = 14
	check.TextColor3 = theme.accent; check.ZIndex = 52

	optBtn.MouseEnter:Connect(function() Tween(optBtn, {BackgroundColor3=Color3.fromRGB(30,24,55)}, 0.15) end)
	optBtn.MouseLeave:Connect(function() Tween(optBtn, {BackgroundColor3=Color3.fromRGB(20,16,38)}, 0.15) end)
	optBtn.MouseButton1Click:Connect(function()
		ApplyTheme(name)
		for _, b in ipairs(themeBtnList) do
			local c = b:FindFirstChild("Check"); if c then c.Text="" end
		end
		check.Text = "✓"
		task.wait(0.2)
		Tween(themePanel, {Size=UDim2.new(0,200,0,0)}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.3); themePanel.Visible = false
	end)
	table.insert(themeBtnList, optBtn)
end

local tpFullH = 30 + #themeOrder * 40 + 8
themeBtn.MouseButton1Click:Connect(function()
	if themePanel.Visible then
		Tween(themePanel, {Size=UDim2.new(0,200,0,0)}, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.3); themePanel.Visible = false
	else
		themePanel.Size = UDim2.new(0,200,0,0); themePanel.Visible = true
		Tween(themePanel, {Size=UDim2.new(0,200,0,tpFullH)}, 0.3, Enum.EasingStyle.Back)
	end
end)

-- ============================================================
-- LEFT PANEL
-- ============================================================
local prefixLabel, dangerLabel, strategyLabel, statusLabel, countLabel

local leftPanel = Instance.new("Frame", frame)
leftPanel.Name = "LeftPanel"
leftPanel.Size = UDim2.new(0,225,1,-62)
leftPanel.Position = UDim2.new(0,10,0,56)
leftPanel.BackgroundColor3 = CurrentTheme.panelBg
leftPanel.BackgroundTransparency = 0.12
leftPanel.BorderSizePixel = 0
leftPanel.ZIndex = 3
Instance.new("UICorner", leftPanel).CornerRadius = UDim.new(0,12)
table.insert(ThemeElements, {type="leftPanel", obj=leftPanel})

local leftStroke = Instance.new("UIStroke", leftPanel)
leftStroke.Color = Color3.fromRGB(40,30,75); leftStroke.Thickness = 1; leftStroke.Transparency = 0.15

local leftGrad = Instance.new("UIGradient", leftPanel)
leftGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.fromRGB(16,14,32)), ColorSequenceKeypoint.new(1, Color3.fromRGB(10,8,22))}
leftGrad.Rotation = 160
table.insert(ThemeElements, {type="leftPanelGrad", obj=leftGrad})

-- Prefix section
local prefSection = Instance.new("Frame", leftPanel)
prefSection.Size = UDim2.new(1,-16,0,94)
prefSection.Position = UDim2.new(0,8,0,8)
prefSection.BackgroundColor3 = Color3.fromRGB(14,12,28)
prefSection.BorderSizePixel = 0; prefSection.ZIndex = 4
Instance.new("UICorner", prefSection).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", prefSection).Color = Color3.fromRGB(40,30,75)
Instance.new("UIGradient", prefSection).Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(18,14,36)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12,10,26)),
}

local prefTitle = Instance.new("TextLabel", prefSection)
prefTitle.Size = UDim2.new(1,-12,0,16); prefTitle.Position = UDim2.new(0,10,0,8)
prefTitle.BackgroundTransparency = 1; prefTitle.Text = "🔤  HURUF AKTIF"
prefTitle.Font = Enum.Font.GothamBold; prefTitle.TextSize = 9
prefTitle.TextColor3 = CurrentTheme.textMuted; prefTitle.TextXAlignment = Enum.TextXAlignment.Left; prefTitle.ZIndex = 5
table.insert(ThemeElements, {type="prefixTitle", obj=prefTitle})

prefixLabel = Instance.new("TextLabel", prefSection)
prefixLabel.Name = "PrefixLabel"
prefixLabel.Size = UDim2.new(0,80,0,50); prefixLabel.Position = UDim2.new(0,10,0,30)
prefixLabel.BackgroundTransparency = 1; prefixLabel.Text = "—"
prefixLabel.Font = Enum.Font.GothamBlack; prefixLabel.TextSize = 40
prefixLabel.TextColor3 = CurrentTheme.accent; prefixLabel.TextXAlignment = Enum.TextXAlignment.Left; prefixLabel.ZIndex = 5
table.insert(ThemeElements, {type="prefixLabel", obj=prefixLabel})

dangerLabel = Instance.new("TextLabel", prefSection)
dangerLabel.Name = "DangerLabel"
dangerLabel.Size = UDim2.new(0,90,0,20); dangerLabel.Position = UDim2.new(1,-98,0,12)
dangerLabel.BackgroundColor3 = Color3.fromRGB(200,30,60); dangerLabel.BackgroundTransparency = 0.72
dangerLabel.Text = ""; dangerLabel.Font = Enum.Font.GothamBold; dangerLabel.TextSize = 9
dangerLabel.TextColor3 = Color3.fromRGB(255,100,130); dangerLabel.BorderSizePixel = 0; dangerLabel.ZIndex = 6; dangerLabel.Visible = false
Instance.new("UICorner", dangerLabel).CornerRadius = UDim.new(0,6)

strategyLabel = Instance.new("TextLabel", prefSection)
strategyLabel.Name = "StrategyLabel"
strategyLabel.Size = UDim2.new(0,90,0,18); strategyLabel.Position = UDim2.new(1,-98,0,58)
strategyLabel.BackgroundColor3 = Color3.fromRGB(120,80,255); strategyLabel.BackgroundTransparency = 0.78
strategyLabel.Text = "🧠 STRATEGY+"; strategyLabel.Font = Enum.Font.GothamBold; strategyLabel.TextSize = 8
strategyLabel.TextColor3 = Color3.fromRGB(180,150,255); strategyLabel.BorderSizePixel = 0; strategyLabel.ZIndex = 6
Instance.new("UICorner", strategyLabel).CornerRadius = UDim.new(0,5)

-- Status section
local statusSection = Instance.new("Frame", leftPanel)
statusSection.Size = UDim2.new(1,-16,0,54); statusSection.Position = UDim2.new(0,8,0,108)
statusSection.BackgroundColor3 = Color3.fromRGB(12,10,24); statusSection.BorderSizePixel = 0; statusSection.ZIndex = 4
Instance.new("UICorner", statusSection).CornerRadius = UDim.new(0,8)
local ss2 = Instance.new("UIStroke", statusSection)
ss2.Color = Color3.fromRGB(35,25,65); ss2.Thickness = 1; ss2.Transparency = 0.4

statusLabel = Instance.new("TextLabel", statusSection)
statusLabel.Size = UDim2.new(1,-16,0,18); statusLabel.Position = UDim2.new(0,10,0,8)
statusLabel.BackgroundTransparency = 1; statusLabel.Text = "⏳ Memuat kamus..."
statusLabel.Font = Enum.Font.GothamMedium; statusLabel.TextSize = 11
statusLabel.TextColor3 = CurrentTheme.accentLight; statusLabel.TextXAlignment = Enum.TextXAlignment.Left; statusLabel.ZIndex = 5
table.insert(ThemeElements, {type="statusLabel", obj=statusLabel})

countLabel = Instance.new("TextLabel", statusSection)
countLabel.Size = UDim2.new(1,-16,0,16); countLabel.Position = UDim2.new(0,10,0,30)
countLabel.BackgroundTransparency = 1; countLabel.Text = "Kata ditemukan: 0"
countLabel.Font = Enum.Font.Gotham; countLabel.TextSize = 11
countLabel.TextColor3 = CurrentTheme.textSecondary; countLabel.TextXAlignment = Enum.TextXAlignment.Left; countLabel.ZIndex = 5
table.insert(ThemeElements, {type="countLabel", obj=countLabel})

-- ============================================================
-- AUTO DETECT / AUTO ANSWER SECTION
-- ============================================================
local autoSection = Instance.new("Frame", leftPanel)
autoSection.Name = "AutoSection"
autoSection.Size = UDim2.new(1,-16,0,188); autoSection.Position = UDim2.new(0,8,0,168)
autoSection.BackgroundColor3 = Color3.fromRGB(10,8,22); autoSection.BorderSizePixel = 0; autoSection.ZIndex = 4
Instance.new("UICorner", autoSection).CornerRadius = UDim.new(0,10)

local asSt = Instance.new("UIStroke", autoSection)
asSt.Color = Color3.fromRGB(60,35,120); asSt.Thickness = 1.2; asSt.Transparency = 0.45

Instance.new("UIGradient", autoSection).Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(16,12,35)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10,8,24)),
}

local autoTitle2 = Instance.new("TextLabel", autoSection)
autoTitle2.Size = UDim2.new(1,-12,0,18); autoTitle2.Position = UDim2.new(0,10,0,6)
autoTitle2.BackgroundTransparency = 1; autoTitle2.Text = "🤖  AUTO DETECT & ANSWER"
autoTitle2.Font = Enum.Font.GothamBold; autoTitle2.TextSize = 9
autoTitle2.TextColor3 = Color3.fromRGB(140,100,255); autoTitle2.TextXAlignment = Enum.TextXAlignment.Left; autoTitle2.ZIndex = 5

-- ── Helper buat mini toggle row ──
local function MakeMiniToggle(parent, posY, labelText, accentCol)
	local row = Instance.new("TextButton", parent)
	row.Size = UDim2.new(1,-20,0,26); row.Position = UDim2.new(0,10,0,posY)
	row.BackgroundColor3 = Color3.fromRGB(16,12,32); row.Text = ""
	row.BorderSizePixel = 0; row.AutoButtonColor = false; row.ZIndex = 5
	Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)
	local rs = Instance.new("UIStroke", row)
	rs.Color = Color3.fromRGB(45,30,90); rs.Thickness = 1; rs.Transparency = 0.5

	local track = Instance.new("Frame", row)
	track.Size = UDim2.new(0,34,0,16); track.Position = UDim2.new(0,5,0.5,-8)
	track.BackgroundColor3 = Color3.fromRGB(40,30,65); track.BorderSizePixel = 0; track.ZIndex = 6
	Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)

	local knob = Instance.new("Frame", track)
	knob.Size = UDim2.new(0,12,0,12); knob.Position = UDim2.new(0,2,0.5,-6)
	knob.BackgroundColor3 = Color3.fromRGB(130,120,165); knob.BorderSizePixel = 0; knob.ZIndex = 7
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(1,-48,1,0); lbl.Position = UDim2.new(0,44,0,0)
	lbl.BackgroundTransparency = 1; lbl.Text = labelText
	lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 9
	lbl.TextColor3 = Color3.fromRGB(110,100,150); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.ZIndex = 6

	row.MouseEnter:Connect(function() Tween(row,{BackgroundColor3=Color3.fromRGB(22,16,44)},0.12) end)
	row.MouseLeave:Connect(function() Tween(row,{BackgroundColor3=Color3.fromRGB(16,12,32)},0.12) end)

	local function SetOn(on)
		if on then
			Tween(track,{BackgroundColor3=accentCol},0.22)
			Tween(knob,{Position=UDim2.new(1,-14,0.5,-6),BackgroundColor3=Color3.fromRGB(255,255,255)},0.22,Enum.EasingStyle.Back)
			Tween(rs,{Color=accentCol},0.18)
			lbl.TextColor3 = accentCol
		else
			Tween(track,{BackgroundColor3=Color3.fromRGB(40,30,65)},0.22)
			Tween(knob,{Position=UDim2.new(0,2,0.5,-6),BackgroundColor3=Color3.fromRGB(130,120,165)},0.22,Enum.EasingStyle.Back)
			Tween(rs,{Color=Color3.fromRGB(45,30,90)},0.18)
			lbl.TextColor3 = Color3.fromRGB(110,100,150)
		end
	end

	return row, SetOn, lbl
end

-- ── Toggle 1: Auto Answer utama ──
local autoToggleBtn = Instance.new("TextButton", autoSection)
autoToggleBtn.Name = "AutoToggle"
autoToggleBtn.Size = UDim2.new(1,-20,0,30); autoToggleBtn.Position = UDim2.new(0,10,0,28)
autoToggleBtn.BackgroundColor3 = Color3.fromRGB(18,14,38); autoToggleBtn.Text = ""
autoToggleBtn.BorderSizePixel = 0; autoToggleBtn.AutoButtonColor = false; autoToggleBtn.ZIndex = 5
Instance.new("UICorner", autoToggleBtn).CornerRadius = UDim.new(0,9)

local atStr = Instance.new("UIStroke", autoToggleBtn)
atStr.Color = Color3.fromRGB(55,35,100); atStr.Thickness = 1; atStr.Transparency = 0.4

local toggleTrack = Instance.new("Frame", autoToggleBtn)
toggleTrack.Size = UDim2.new(0,40,0,20); toggleTrack.Position = UDim2.new(0,6,0.5,-10)
toggleTrack.BackgroundColor3 = Color3.fromRGB(45,35,70); toggleTrack.BorderSizePixel = 0; toggleTrack.ZIndex = 6
Instance.new("UICorner", toggleTrack).CornerRadius = UDim.new(1,0)

local toggleKnob = Instance.new("Frame", toggleTrack)
toggleKnob.Size = UDim2.new(0,16,0,16); toggleKnob.Position = UDim2.new(0,2,0.5,-8)
toggleKnob.BackgroundColor3 = Color3.fromRGB(140,130,175); toggleKnob.BorderSizePixel = 0; toggleKnob.ZIndex = 7
Instance.new("UICorner", toggleKnob).CornerRadius = UDim.new(1,0)

local autoToggleLabel = Instance.new("TextLabel", autoToggleBtn)
autoToggleLabel.Size = UDim2.new(1,-58,1,0); autoToggleLabel.Position = UDim2.new(0,52,0,0)
autoToggleLabel.BackgroundTransparency = 1; autoToggleLabel.Text = "OFF — Klik untuk aktifkan"
autoToggleLabel.Font = Enum.Font.GothamBold; autoToggleLabel.TextSize = 10
autoToggleLabel.TextColor3 = Color3.fromRGB(120,110,160); autoToggleLabel.TextXAlignment = Enum.TextXAlignment.Left; autoToggleLabel.ZIndex = 6

-- Divider kecil antara auto toggle dan sub-fitur
local subDiv = Instance.new("Frame", autoSection)
subDiv.Size = UDim2.new(1,-20,0,1); subDiv.Position = UDim2.new(0,10,0,64)
subDiv.BackgroundColor3 = Color3.fromRGB(50,35,90); subDiv.BorderSizePixel = 0; subDiv.ZIndex = 5

local subLabel = Instance.new("TextLabel", autoSection)
subLabel.Size = UDim2.new(1,-20,0,14); subLabel.Position = UDim2.new(0,10,0,69)
subLabel.BackgroundTransparency = 1; subLabel.Text = "SUB-FITUR AUTO"
subLabel.Font = Enum.Font.GothamBold; subLabel.TextSize = 8
subLabel.TextColor3 = Color3.fromRGB(80,65,120); subLabel.TextXAlignment = Enum.TextXAlignment.Left; subLabel.ZIndex = 5

-- ── Toggle 2: Human Mode ──
local humanModeBtn, SetHumanModeVisual, humanModeLabel =
	MakeMiniToggle(autoSection, 86, "👤 Human Mode (typo+delay+skip killer)", Color3.fromRGB(255,170,50))

-- ── Toggle 3: Fake Type ──
local fakeTypeBtn, SetFakeTypeVisual, fakeTypeLabel =
	MakeMiniToggle(autoSection, 116, "🎭 Fake Type (ketik palsu → submit nyata)", Color3.fromRGB(0,210,180))

-- Info Fake Type
local fakeTypeInfo = Instance.new("TextLabel", autoSection)
fakeTypeInfo.Size = UDim2.new(1,-20,0,28); fakeTypeInfo.Position = UDim2.new(0,10,0,146)
fakeTypeInfo.BackgroundColor3 = Color3.fromRGB(0,30,28); fakeTypeInfo.BackgroundTransparency = 0.5
fakeTypeInfo.Text = "Ketik asal di input → script cari kata\nvalid dari huruf awal+akhir → Enter = submit"
fakeTypeInfo.Font = Enum.Font.Gotham; fakeTypeInfo.TextSize = 8
fakeTypeInfo.TextColor3 = Color3.fromRGB(0,180,160); fakeTypeInfo.BorderSizePixel = 0; fakeTypeInfo.ZIndex = 5
fakeTypeInfo.TextWrapped = true; fakeTypeInfo.TextYAlignment = Enum.TextYAlignment.Center
Instance.new("UICorner", fakeTypeInfo).CornerRadius = UDim.new(0,6)

autoAnswerStatusLabel = Instance.new("TextLabel", autoSection)
autoAnswerStatusLabel.Name = "AutoStatus"
autoAnswerStatusLabel.Size = UDim2.new(1,-20,0,12); autoAnswerStatusLabel.Position = UDim2.new(0,10,1,-14)
autoAnswerStatusLabel.BackgroundTransparency = 1; autoAnswerStatusLabel.Text = ""
autoAnswerStatusLabel.Font = Enum.Font.Gotham; autoAnswerStatusLabel.TextSize = 8
autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(100,90,140); autoAnswerStatusLabel.TextXAlignment = Enum.TextXAlignment.Left; autoAnswerStatusLabel.ZIndex = 5

local autoGlow = Instance.new("Frame", autoSection)
autoGlow.Size = UDim2.new(1,6,1,6); autoGlow.Position = UDim2.new(0,-3,0,-3)
autoGlow.BackgroundColor3 = Color3.fromRGB(120,80,255); autoGlow.BackgroundTransparency = 1; autoGlow.BorderSizePixel = 0; autoGlow.ZIndex = 3
Instance.new("UICorner", autoGlow).CornerRadius = UDim.new(0,12)

local function UpdateAutoToggleVisual()
	if AutoAnswerEnabled then
		Tween(toggleTrack, {BackgroundColor3=Color3.fromRGB(100,60,220)}, 0.25)
		Tween(toggleKnob, {Position=UDim2.new(1,-18,0.5,-8), BackgroundColor3=Color3.fromRGB(255,255,255)}, 0.25, Enum.EasingStyle.Back)
		Tween(atStr, {Color=Color3.fromRGB(120,80,255)}, 0.2)
		autoToggleLabel.Text = "ON — Auto Detect AKTIF!"
		autoToggleLabel.TextColor3 = Color3.fromRGB(160,120,255)
		Tween(autoGlow, {BackgroundTransparency=0.82}, 0.3)
		Tween(asSt, {Color=Color3.fromRGB(100,60,200)}, 0.2)
	else
		Tween(toggleTrack, {BackgroundColor3=Color3.fromRGB(45,35,70)}, 0.25)
		Tween(toggleKnob, {Position=UDim2.new(0,2,0.5,-8), BackgroundColor3=Color3.fromRGB(140,130,175)}, 0.25, Enum.EasingStyle.Back)
		Tween(atStr, {Color=Color3.fromRGB(55,35,100)}, 0.2)
		autoToggleLabel.Text = "OFF — Klik untuk aktifkan"
		autoToggleLabel.TextColor3 = Color3.fromRGB(120,110,160)
		Tween(autoGlow, {BackgroundTransparency=1}, 0.3)
		Tween(asSt, {Color=Color3.fromRGB(60,35,120)}, 0.2)
	end
end

task.spawn(function()
	while autoGlow and autoGlow.Parent do
		if AutoAnswerEnabled then
			TweenWait(autoGlow, {BackgroundTransparency=0.75}, 1, Enum.EasingStyle.Sine)
			TweenWait(autoGlow, {BackgroundTransparency=0.9}, 1, Enum.EasingStyle.Sine)
		else task.wait(0.5) end
	end
end)

autoToggleBtn.MouseEnter:Connect(function() Tween(autoToggleBtn, {BackgroundColor3=Color3.fromRGB(26,20,50)}, 0.15) end)
autoToggleBtn.MouseLeave:Connect(function() Tween(autoToggleBtn, {BackgroundColor3=Color3.fromRGB(18,14,38)}, 0.15) end)

autoToggleBtn.MouseButton1Click:Connect(function()
	AutoAnswerEnabled = not AutoAnswerEnabled
	UpdateAutoToggleVisual()
	if AutoAnswerEnabled then
		local modeInfo = HumanModeEnabled and " | 👤 Human Mode ON" or ""
		SendNotification("auto", "Auto Detect AKTIF 🤖", "NightHubX jawab otomatis. DupFilter ON."..modeInfo, 4)
		autoAnswerStatusLabel.Text = "⏳ Menunggu giliran..."
		autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(140,100,255)
	else
		SendNotification("info", "Auto Detect NONAKTIF", "Mode manual aktif.", 2.5)
		autoAnswerStatusLabel.Text = ""
	end
end)

-- ── Human Mode toggle ──
humanModeBtn.MouseButton1Click:Connect(function()
	HumanModeEnabled = not HumanModeEnabled
	SetHumanModeVisual(HumanModeEnabled)
	if HumanModeEnabled then
		SendNotification("warning", "👤 Human Mode ON",
			"Delay 0.7s, sengaja typo+koreksi, skip akhiran x/z/q. Lebih lambat tapi lebih manusiawi.", 4)
	else
		SendNotification("info", "Human Mode OFF", "Kembali ke mode normal (cepat).", 2.5)
	end
end)

-- ============================================================
-- FAKE TYPE LISTENER
-- User ketik kata asal di textbox → script pakai FindOptions(CurrentLetter)
-- persis sama dengan auto answer → ambil kata terbaik → submit saat Enter
-- ============================================================
local function SetupFakeTypeListener()
	if FakeTypeConnection then
		pcall(function() FakeTypeConnection:Disconnect() end)
		FakeTypeConnection = nil
	end
	if not FakeTypeEnabled then return end

	task.spawn(function()
		-- Cari textbox game
		local input = nil
		for _ = 1, 30 do
			local box = player.PlayerGui:FindFirstChild("MatchUI", true)
			if box then
				input = box:FindFirstChildWhichIsA("TextBox", true)
				if input then break end
			end
			task.wait(0.25)
		end
		if not input then
			SendNotification("warning", "🎭 Fake Type", "Textbox input tidak ditemukan.", 3)
			return
		end

		-- Kata nyata yang sudah di-resolve, siap disubmit
		local pendingRealWord = nil
		local lastRaw = ""

		-- Monitor ketikan user secara realtime
		-- Setiap perubahan teks → resolve ulang kata terbaik dari FindOptions
		local textConn = input:GetPropertyChangedSignal("Text"):Connect(function()
			if not FakeTypeEnabled or not Ready or not CurrentLetter then return end

			local raw = string.lower(input.Text):gsub("[^a-z]", "")
			if raw == lastRaw then return end
			lastRaw = raw

			if #raw < 1 then
				pendingRealWord = nil
				if autoAnswerStatusLabel then
					autoAnswerStatusLabel.Text = "🎭 Ketik kata palsu di input game..."
					autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(0, 200, 180)
				end
				return
			end

			-- Pakai FindOptions persis sama dengan auto answer
			-- Kata terbaik sudah terurut strategy/difficulty
			local opts = FindOptions(CurrentLetter)
			if not opts or #opts == 0 then
				pendingRealWord = nil
				if autoAnswerStatusLabel then
					autoAnswerStatusLabel.Text = "🎭 Tidak ada kata tersedia untuk '" .. CurrentLetter:upper() .. "'"
					autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 80)
				end
				return
			end

			-- Ambil kata terbaik (sama seperti auto answer ambil Options[1])
			pendingRealWord = opts[1]
			local lc = string.sub(pendingRealWord, -1)
			local _, dangerText = GetDangerCategory(pendingRealWord)
			if autoAnswerStatusLabel then
				autoAnswerStatusLabel.Text = '🎭 Ketik: "' .. raw .. '" → siap submit: "' .. pendingRealWord .. '" ' .. dangerText
				autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(0, 220, 190)
			end
		end)

		-- Saat user tekan Enter → intercept, kirim kata NYATA bukan kata palsu
		local focusConn = input.FocusLost:Connect(function(enterPressed)
			if not FakeTypeEnabled then return end
			if not enterPressed then return end
			if not pendingRealWord then return end
			if not CurrentLetter then return end

			local wordToSend = pendingRealWord
			pendingRealWord = nil
			lastRaw = ""

			local remaining = string.sub(wordToSend, #CurrentLetter + 1)
			MarkWordAsUsed(wordToSend, "fake_type")
			LastSubmittedWord = wordToSend
			SubmitWord:FireServer(remaining)

			local lc = string.sub(wordToSend, -1)
			local _, dangerText = GetDangerCategory(wordToSend)
			SendNotification("auto", "🎭 Fake Type Submit!",
				'"' .. wordToSend .. '" → ' .. lc:upper() .. " " .. dangerText, 3)
			if autoAnswerStatusLabel then
				autoAnswerStatusLabel.Text = '🎭 ✅ "' .. wordToSend .. '" terkirim!'
				autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(0, 240, 200)
			end
			UpdatePreview()
		end)

		FakeTypeConnection = {
			Disconnect = function()
				pcall(function() textConn:Disconnect() end)
				pcall(function() focusConn:Disconnect() end)
			end
		}
	end)
end

fakeTypeBtn.MouseButton1Click:Connect(function()
	FakeTypeEnabled = not FakeTypeEnabled
	SetFakeTypeVisual(FakeTypeEnabled)
	if FakeTypeEnabled then
		SendNotification("auto", "🎭 Fake Type ON",
			"Ketik kata asal di input game → script ambil huruf awal+akhir → cari kata valid → submit nyata saat Enter.", 5)
		autoAnswerStatusLabel.Text = "🎭 Fake Type aktif — ketik kata asal di input game"
		autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(0,210,180)
		SetupFakeTypeListener()
	else
		SendNotification("info", "Fake Type OFF", "Mode Fake Type dimatikan.", 2.5)
		if FakeTypeConnection then
			pcall(function() FakeTypeConnection:Disconnect() end)
			FakeTypeConnection = nil
		end
		autoAnswerStatusLabel.Text = ""
	end
end)

-- Info tips — posisi disesuaikan (autoSection lebih tinggi: 168+188=356, +8 gap = 364)
local divLine = Instance.new("Frame", leftPanel)
divLine.Size = UDim2.new(1,-24,0,1); divLine.Position = UDim2.new(0,12,0,364)
divLine.BackgroundColor3 = Color3.fromRGB(40,28,75); divLine.BorderSizePixel = 0; divLine.ZIndex = 4

local tipsHeader2 = Instance.new("TextLabel", leftPanel)
tipsHeader2.Size = UDim2.new(1,-16,0,14); tipsHeader2.Position = UDim2.new(0,10,0,370)
tipsHeader2.BackgroundTransparency = 1; tipsHeader2.Text = "💡  PANDUAN CEPAT"
tipsHeader2.Font = Enum.Font.GothamBold; tipsHeader2.TextSize = 9
tipsHeader2.TextColor3 = CurrentTheme.textMuted; tipsHeader2.TextXAlignment = Enum.TextXAlignment.Left; tipsHeader2.ZIndex = 4

local tips = {
	"Klik kata → auto-input ke game",
	"👤 Human Mode = typo+delay+skip killer",
	"🎭 Fake Type = ketik palsu, submit nyata",
	"🚫 Kata terpakai hilang otomatis",
	"◆ Ganti tema | 🧠 Sort | ⏏ Unload",
}
for i, tip in ipairs(tips) do
	local tl = Instance.new("TextLabel", leftPanel)
	tl.Size = UDim2.new(1,-22,0,14); tl.Position = UDim2.new(0,14,0,370+(i*14))
	tl.BackgroundTransparency = 1; tl.Text = "› "..tip
	tl.Font = Enum.Font.Gotham; tl.TextSize = 8
	tl.TextColor3 = CurrentTheme.textMuted; tl.TextXAlignment = Enum.TextXAlignment.Left
	tl.TextWrapped = true; tl.ZIndex = 4
end

local verBadge = Instance.new("Frame", leftPanel)
verBadge.Size = UDim2.new(1,-16,0,26); verBadge.Position = UDim2.new(0,8,1,-30)
verBadge.BackgroundColor3 = Color3.fromRGB(14,10,30); verBadge.BorderSizePixel = 0; verBadge.ZIndex = 4
Instance.new("UICorner", verBadge).CornerRadius = UDim.new(0,7)
Instance.new("UIStroke", verBadge).Color = Color3.fromRGB(40,28,75)

local verText = Instance.new("TextLabel", verBadge)
verText.Size = UDim2.new(1,0,1,0); verText.BackgroundTransparency = 1
verText.Text = "⚡  NightHubX v5 • HumanMode + FakeType"
verText.Font = Enum.Font.GothamMedium; verText.TextSize = 9
verText.TextColor3 = CurrentTheme.textMuted; verText.ZIndex = 5

-- ============================================================
-- RIGHT PANEL — WORD LIST
-- ============================================================
local rightPanel = Instance.new("Frame", frame)
rightPanel.Name = "RightPanel"
rightPanel.Size = UDim2.new(1,-252,1,-62); rightPanel.Position = UDim2.new(0,242,0,56)
rightPanel.BackgroundTransparency = 1; rightPanel.BorderSizePixel = 0; rightPanel.ZIndex = 3

local headerBar = Instance.new("Frame", rightPanel)
headerBar.Size = UDim2.new(1,-4,0,30); headerBar.BackgroundColor3 = Color3.fromRGB(14,12,28)
headerBar.BackgroundTransparency = 0.15; headerBar.BorderSizePixel = 0; headerBar.ZIndex = 4
Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0,8)
Instance.new("UIStroke", headerBar).Color = Color3.fromRGB(40,28,75)

local colWord = Instance.new("TextLabel", headerBar)
colWord.Size = UDim2.new(1,-140,1,0); colWord.Position = UDim2.new(0,16,0,0)
colWord.BackgroundTransparency = 1; colWord.Text = "WORD LIST"
colWord.Font = Enum.Font.GothamBold; colWord.TextSize = 10
colWord.TextColor3 = Color3.fromRGB(120,90,200); colWord.TextXAlignment = Enum.TextXAlignment.Left; colWord.ZIndex = 5

local colTag = Instance.new("TextLabel", headerBar)
colTag.Size = UDim2.new(0,120,1,0); colTag.Position = UDim2.new(1,-130,0,0)
colTag.BackgroundTransparency = 1; colTag.Text = "DANGER / DIFF"
colTag.Font = Enum.Font.GothamBold; colTag.TextSize = 10
colTag.TextColor3 = Color3.fromRGB(120,90,200); colTag.TextXAlignment = Enum.TextXAlignment.Right; colTag.ZIndex = 5

local scrollFrame = Instance.new("ScrollingFrame", rightPanel)
scrollFrame.Size = UDim2.new(1,-4,1,-36); scrollFrame.Position = UDim2.new(0,0,0,34)
scrollFrame.BackgroundColor3 = Color3.fromRGB(10,8,20); scrollFrame.BackgroundTransparency = 0.1
scrollFrame.BorderSizePixel = 0; scrollFrame.ZIndex = 3
scrollFrame.ScrollBarThickness = 4; scrollFrame.ScrollBarImageColor3 = CurrentTheme.scrollBar
scrollFrame.CanvasSize = UDim2.new(0,0,0,0)
Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", scrollFrame).Color = Color3.fromRGB(35,25,65)

local listLayout = Instance.new("UIListLayout", scrollFrame)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,2)

local listPad = Instance.new("UIPadding", scrollFrame)
listPad.PaddingTop = UDim.new(0,4); listPad.PaddingBottom = UDim.new(0,4)
listPad.PaddingLeft = UDim.new(0,4); listPad.PaddingRight = UDim.new(0,4)

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0,0,0,listLayout.AbsoluteContentSize.Y+8)
end)

-- ============================================================
-- WORD BUTTONS
-- ============================================================
local buttons = {}
local buttonIndicators = {}

local function CreateButton(index)
	local btn = Instance.new("TextButton", scrollFrame)
	btn.Name = "WordBtn"..index
	btn.Size = UDim2.new(1,0,0,34)
	btn.LayoutOrder = index
	local bg = (index%2==0) and CurrentTheme.cardBgAlt or CurrentTheme.cardBg
	btn.BackgroundColor3 = bg
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(220,215,235)
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.ZIndex = 4
	btn.Visible = false
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

	local btnStroke = Instance.new("UIStroke", btn)
	btnStroke.Color = CurrentTheme.stroke; btnStroke.Thickness = 1; btnStroke.Transparency = 0.5

	local indicator = Instance.new("TextLabel", btn)
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(0,90,0,20); indicator.Position = UDim2.new(1,-96,0.5,-10)
	indicator.BackgroundColor3 = Color3.fromRGB(40,200,100); indicator.BackgroundTransparency = 0.72
	indicator.Text = ""; indicator.Font = Enum.Font.GothamBold; indicator.TextSize = 8
	indicator.TextColor3 = Color3.fromRGB(255,255,255); indicator.BorderSizePixel = 0; indicator.ZIndex = 6; indicator.Visible = false
	Instance.new("UICorner", indicator).CornerRadius = UDim.new(0,5)

	local badge = Instance.new("TextLabel", btn)
	badge.Name = "Badge"
	badge.Size = UDim2.new(0,22,0,18); badge.Position = UDim2.new(1,-28,0.5,-9)
	badge.BackgroundColor3 = CurrentTheme.accent; badge.BackgroundTransparency = 0.7
	badge.Text = tostring(index); badge.Font = Enum.Font.GothamBold; badge.TextSize = 9
	badge.TextColor3 = CurrentTheme.textPrimary; badge.TextTransparency = 0.2; badge.BorderSizePixel = 0; badge.ZIndex = 6
	Instance.new("UICorner", badge).CornerRadius = UDim.new(0,5)
	table.insert(ThemeElements, {type="badge", obj=badge, index=index})

	btn.MouseEnter:Connect(function()
		Tween(btn, {BackgroundColor3=CurrentTheme.cardHover}, 0.12)
		Tween(btnStroke, {Color=CurrentTheme.accentLight, Transparency=0.12}, 0.12)
	end)
	btn.MouseLeave:Connect(function()
		local bgc = (index%2==0) and CurrentTheme.cardBgAlt or CurrentTheme.cardBg
		Tween(btn, {BackgroundColor3=bgc}, 0.12)
		Tween(btnStroke, {Color=CurrentTheme.stroke, Transparency=0.5}, 0.12)
	end)

	table.insert(buttons, btn)
	table.insert(buttonIndicators, indicator)
	table.insert(ThemeElements, {type="button", obj=btn, index=index})
end

for i = 1, MAX_BUTTONS do CreateButton(i) end

-- ============================================================
-- STRATEGY ENGINE
-- ============================================================
local function GetEndingDangerScore(word)
	local lc = string.sub(word,-1)
	local opts = LetterWordCount[lc] or 0
	local over = KILLER_SCORE_OVERRIDE[lc] or 0
	local dyn = (opts==0) and 99999 or (10000-opts)
	return math.max(over, dyn)
end

local function GetDangerCategory(word)
	local lc = string.sub(word,-1)
	local cnt = LetterWordCount[lc] or 0
	local isKiller = KILLER_SCORE_OVERRIDE[lc] and KILLER_SCORE_OVERRIDE[lc] >= 70000
	if cnt==0 then return "impossible","☠️ IMPOSSIBLE",Color3.fromRGB(255,0,0)
	elseif cnt<=3 or isKiller then return "killer","💀 KILLER",Color3.fromRGB(255,40,60)
	elseif cnt<=10 or (KILLER_SCORE_OVERRIDE[lc] and KILLER_SCORE_OVERRIDE[lc]>=40000) then return "danger","⚠️ BAHAYA",Color3.fromRGB(255,150,30)
	elseif cnt<=30 or (KILLER_SCORE_OVERRIDE[lc] and KILLER_SCORE_OVERRIDE[lc]>=20000) then return "risky","🟡 RISKY",Color3.fromRGB(240,220,40)
	elseif cnt<=100 then return "normal","🔵 NORMAL",Color3.fromRGB(100,160,240)
	else return "safe","🟢 AMAN",Color3.fromRGB(40,220,120) end
end

local HardLetters = {q=10,x=9,z=8,v=7,f=6,w=5,y=4,k=3,b=2,p=1}
local function Difficulty(word) return HardLetters[string.sub(word,-1)] or 0 end

-- ============================================================
-- FIND OPTIONS (excludes MatchUsedWords)
-- ============================================================
local function FindOptions(prefix)
	prefix = string.lower(prefix):gsub("[^a-z]","")
	local list
	if #prefix>=2 then list = Prefix2[string.sub(prefix,1,2)]
	else list = Prefix1[string.sub(prefix,1,1)] end
	if not list then return {} end

	local filtered, seen = {}, {}
	for _, word in ipairs(list) do
		if string.sub(word,1,#prefix)==prefix then
			if not seen[word] and not MatchUsedWords[word] then
				seen[word]=true; table.insert(filtered, word)
			end
		end
	end
	if #filtered==0 then return {} end

	if SortMode=="strategy" then
		table.sort(filtered, function(a,b)
			local sA, sB = GetEndingDangerScore(a), GetEndingDangerScore(b)
			if sA~=sB then return sA>sB end
			if #a~=#b then return #a<#b end
			return a<b
		end)
	else
		table.sort(filtered, function(a,b)
			local dA, dB = Difficulty(a), Difficulty(b)
			if dA~=dB then return dA>dB end
			return #a<#b
		end)
	end
	return filtered
end

-- ============================================================
-- MARK WORD AS USED
-- ============================================================
local function MarkWordAsUsed(word, source)
	if not word or #word<3 then return end
	local w = string.lower(word):gsub("%s","")
	if not string.match(w,"^[a-z]+$") then return end
	if not MatchUsedWords[w] then MatchUsedWords[w]=true end
end

-- ============================================================
-- UPDATE PREVIEW (Word List GUI)
-- ============================================================
UpdatePreview = function()
	if not Ready then return end
	if not CurrentLetter then return end

	Options = FindOptions(CurrentLetter)

	if SortMode=="strategy" then
		strategyLabel.Text="🧠 STRATEGY+"; strategyLabel.TextColor3=Color3.fromRGB(180,150,255)
		strategyLabel.BackgroundColor3=Color3.fromRGB(120,80,255)
	else
		strategyLabel.Text="📊 DIFFICULTY"; strategyLabel.TextColor3=Color3.fromRGB(160,200,255)
		strategyLabel.BackgroundColor3=Color3.fromRGB(60,110,220)
	end

	local usedCount=0
	for _ in pairs(MatchUsedWords) do usedCount=usedCount+1 end

	if not Options or #Options==0 then
		prefixLabel.Text = CurrentLetter:upper()
		countLabel.Text = "Kata: 0 (🚫"..usedCount.." terpakai)"
		statusLabel.Text = "⚠️ Tidak ada kata!"
		dangerLabel.Visible=true; dangerLabel.Text="💀 MATI!"
		dangerLabel.BackgroundColor3=Color3.fromRGB(200,30,60); dangerLabel.TextColor3=Color3.fromRGB(255,90,120)
		for _,b in ipairs(buttons) do b.Text=""; b.Visible=false end
		for _,ind in ipairs(buttonIndicators) do ind.Visible=false end
		return
	end

	prefixLabel.Text = CurrentLetter:upper()
	countLabel.Text = "Kata: "..#Options.." (🚫"..usedCount.." terpakai)"
	statusLabel.Text = "✅ "..math.min(#Options,MAX_BUTTONS).."/"..#Options.." ditampilkan"

	if #Options<=3 then
		dangerLabel.Visible=true; dangerLabel.Text="⚠️ KRITIS! "..#Options
		dangerLabel.BackgroundColor3=Color3.fromRGB(200,30,60); dangerLabel.TextColor3=Color3.fromRGB(255,100,130)
	elseif #Options<=10 then
		dangerLabel.Visible=true; dangerLabel.Text="⚠️ SEDIKIT "..#Options
		dangerLabel.BackgroundColor3=Color3.fromRGB(180,120,20); dangerLabel.TextColor3=Color3.fromRGB(255,200,80)
	else
		dangerLabel.Visible=false
	end

	for i, btn in ipairs(buttons) do
		local ind = buttonIndicators[i]
		if Options[i] then
			btn.Text = "  "..Options[i]; btn.Visible=true; btn.BackgroundTransparency=1
			if SortMode=="strategy" then
				local _,label,color = GetDangerCategory(Options[i])
				ind.Text=label; ind.BackgroundColor3=color; ind.TextColor3=Color3.fromRGB(255,255,255); ind.Visible=true
			else
				local lc=string.sub(Options[i],-1); local diff=HardLetters[lc]
				if diff and diff>=6 then ind.Text="💀 HARD"; ind.BackgroundColor3=Color3.fromRGB(220,50,80); ind.Visible=true
				elseif diff and diff>=3 then ind.Text="⚠️ MED"; ind.BackgroundColor3=Color3.fromRGB(200,160,30); ind.Visible=true
				else ind.Visible=false end
				ind.TextColor3=Color3.fromRGB(255,255,255)
			end
			task.delay(i*0.011, function() Tween(btn,{BackgroundTransparency=0},0.18) end)
		else
			btn.Text=""; btn.Visible=false; ind.Visible=false
		end
	end
end

-- ============================================================
-- BUTTON CLICK
-- ============================================================
for i, btn in ipairs(buttons) do
	btn.MouseButton1Click:Connect(function()
		local word = Options[i]; if not word then return end
		MarkWordAsUsed(word, "manual_click"); LastSubmittedWord=word

		local origC = btn.BackgroundColor3
		Tween(btn, {BackgroundColor3=CurrentTheme.accent}, 0.08)
		task.delay(0.13, function() Tween(btn,{BackgroundColor3=origC},0.22) end)

		local lc = string.sub(word,-1)
		local opCnt = LetterWordCount[lc] or 0
		local _,dangerText = GetDangerCategory(word)

		local box = player.PlayerGui:FindFirstChild("MatchUI",true)
		if box then
			local input = box:FindFirstChildWhichIsA("TextBox",true)
			if input then
				local rem = word
				if CurrentLetter and #CurrentLetter>0 then rem=string.sub(word,#CurrentLetter+1) end
				input.Text = rem
				SendNotification("success","Kata Dipilih",'"'..word..'" → '..lc:upper().." ("..opCnt.." kata) "..dangerText, 2.5)
			end
		end
		task.delay(0.3, function() UpdatePreview() end)
	end)
end

-- ============================================================
-- LOAD WORD LIST
-- ============================================================
task.spawn(function()
	local function SetProgress(pct, text)
		if loadBar and loadBar.Parent then Tween(loadBar,{Size=UDim2.new(pct,0,1,0)},0.4) end
		if loadStatus and loadStatus.Parent then loadStatus.Text=text end
	end

	SetProgress(0.08, "Menghubungkan ke server KBBI...")
	task.wait(0.5)

	local text=""
	local ok, res = pcall(function()
		return game:HttpGet("https://raw.githubusercontent.com/SOBING4413/sambungkata/main/dependescis/kbbi.txt")
	end)
	if ok and res then text=res; SetProgress(0.4,"Memproses kamus KBBI...")
	else warn("[NightHubX] Gagal memuat wordlist"); SetProgress(0.4,"⚠️ Gagal memuat kamus!") end

	task.wait(0.3)
	SetProgress(0.62,"Mengindeks kata-kata...")

	local wordCount=0
	for word in string.gmatch(text,"[^\r\n]+") do
		local w=string.lower(word):gsub("%s","")
		if string.match(w,"^[a-z]+$") and #w>=3 then
			local p1=string.sub(w,1,1); local p2=string.sub(w,1,2)
			Prefix1[p1]=Prefix1[p1] or {}; table.insert(Prefix1[p1],w)
			Prefix2[p2]=Prefix2[p2] or {}; table.insert(Prefix2[p2],w)
			wordCount=wordCount+1
		end
	end
	for letter=string.byte("a"),string.byte("z") do
		local ch=string.char(letter)
		LetterWordCount[ch]=Prefix1[ch] and #Prefix1[ch] or 0
	end

	SetProgress(0.88,"NightHubX: "..wordCount.." kata terindeks!")
	task.wait(0.35)
	SetProgress(1.0,"Selesai! Memuat antarmuka...")
	task.wait(0.55)

	Ready=true; AutoAnswerReady=true
	statusLabel.Text="✅ "..wordCount.." kata dimuat"

	Tween(loadTitle,{TextTransparency=1},0.4); Tween(loadSub,{TextTransparency=1},0.4)
	Tween(loadBarBg,{BackgroundTransparency=1},0.3); Tween(loadBar,{BackgroundTransparency=1},0.3)
	Tween(loadStatus,{TextTransparency=1},0.3)
	Tween(hexContainer,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0,55)},0.4,Enum.EasingStyle.Back,Enum.EasingDirection.In)

	for _,child in ipairs(loadScreen:GetChildren()) do
		if child.Name:find("Particle") then Tween(child,{BackgroundTransparency=1},0.3) end
	end

	task.wait(0.5); Tween(loadScreen,{BackgroundTransparency=1},0.5); task.wait(0.25)

	frame.Visible=true; frame.Size=UDim2.new(0,0,0,0); frame.Position=UDim2.new(0.5,0,0.5,0)
	shadow.ImageTransparency=1
	Tween(frame,{Size=UDim2.new(0,720,0,460),Position=UDim2.new(0.5,-360,0.5,-230)},0.5,Enum.EasingStyle.Back)
	Tween(shadow,{ImageTransparency=0.45},0.5)
	task.wait(0.65); loadScreen:Destroy()

	SendNotification("loaded","NightHubX Ready! ⚡","Auto Detect + Strategy Engine aktif. "..wordCount.." kata. DupFilter ON.",4.5)
	print("[NightHubX v4] Loaded "..wordCount.." words. AutoDetect+DupFilter engine ready!")
end)

-- ============================================================
-- AUTO ANSWER ENGINE
-- ============================================================
-- HELPER: ambil karakter typo realistis dari tetangga keyboard
-- ============================================================
local function GetTypoChar(originalChar)
	local neighbors = HUMAN_CONFIG.qwertyNeighbors[originalChar]
	if not neighbors or #neighbors == 0 then
		-- fallback: karakter acak sekitar
		local alphabet = "abcdefghijklmnopqrstuvwxyz"
		return string.sub(alphabet, math.random(1,26), math.random(1,26))
	end
	return neighbors[math.random(1,#neighbors)]
end

-- ============================================================
-- KETIK NORMAL — cepat, pakai BillboardUpdate per karakter
-- ============================================================
local function TypeNormal(remaining_word, turnStartTime)
	local rem = TYPING_CONFIG.hardDeadline - (tick() - turnStartTime)
	if rem <= 1.0 then BillboardUpdate:FireServer(remaining_word); return true end

	local estTime = #remaining_word * (TYPING_CONFIG.charDelayMin + TYPING_CONFIG.charDelayMax) / 2
		+ TYPING_CONFIG.submitDelayMax
	local speedMul = 1.0
	if estTime > rem - 0.5 then speedMul = math.max((rem - 0.5) / estTime, 0.3) end

	for i = 1, #remaining_word do
		if not AutoAnswerEnabled then return false end
		if TYPING_CONFIG.hardDeadline - (tick() - turnStartTime) <= 0.8 then
			BillboardUpdate:FireServer(remaining_word); return true
		end
		BillboardUpdate:FireServer(string.sub(remaining_word, 1, i))
		local d = (TYPING_CONFIG.charDelayMin + math.random() * (TYPING_CONFIG.charDelayMax - TYPING_CONFIG.charDelayMin)) * speedMul
		if math.random() < TYPING_CONFIG.pauseChance and i < #remaining_word then
			d = d + (TYPING_CONFIG.pauseDelayMin + math.random() * (TYPING_CONFIG.pauseDelayMax - TYPING_CONFIG.pauseDelayMin)) * speedMul
		end
		task.wait(d)
	end
	return true
end

-- ============================================================
-- KETIK HUMAN MODE — lambat, delay 0.7s awal, typo+koreksi
-- ============================================================
local function TypeHuman(remaining_word, turnStartTime)
	local rem = TYPING_CONFIG.hardDeadline - (tick() - turnStartTime)
	if rem <= 2.0 then BillboardUpdate:FireServer(remaining_word); return true end

	-- Delay ~0.7s sebelum mulai ketik (simulasi ragu/mikir)
	local preD = HUMAN_CONFIG.preTypeDelayMin + math.random() * (HUMAN_CONFIG.preTypeDelayMax - HUMAN_CONFIG.preTypeDelayMin)
	if TYPING_CONFIG.hardDeadline - (tick() - turnStartTime) < preD + 2.5 then
		preD = math.max(0.15, TYPING_CONFIG.hardDeadline - (tick() - turnStartTime) - 2.5)
	end
	task.wait(preD)
	if not AutoAnswerEnabled then return false end

	-- Speed multiplier: lebih lambat 1.8x dari normal
	local slowMin = TYPING_CONFIG.charDelayMin * 1.8
	local slowMax = TYPING_CONFIG.charDelayMax * 1.8
	local estTime = #remaining_word * (slowMin + slowMax) / 2
		+ TYPING_CONFIG.submitDelayMax
		+ #remaining_word * HUMAN_CONFIG.typoChance * HUMAN_CONFIG.typoHoldMax
	local rem2 = TYPING_CONFIG.hardDeadline - (tick() - turnStartTime)
	local speedMul = 1.0
	if estTime > rem2 - 0.5 then speedMul = math.max((rem2 - 0.5) / estTime, 0.3) end

	local typed = ""
	local i = 1
	while i <= #remaining_word do
		if not AutoAnswerEnabled then return false end
		if TYPING_CONFIG.hardDeadline - (tick() - turnStartTime) <= 0.9 then
			BillboardUpdate:FireServer(remaining_word); return true
		end

		local ch = string.sub(remaining_word, i, i)

		-- Typo chance (bukan di karakter terakhir)
		if math.random() < HUMAN_CONFIG.typoChance and i < #remaining_word then
			local wrong = GetTypoChar(ch)
			typed = typed .. wrong
			BillboardUpdate:FireServer(typed)
			task.wait((HUMAN_CONFIG.typoHoldMin + math.random() * (HUMAN_CONFIG.typoHoldMax - HUMAN_CONFIG.typoHoldMin)) * speedMul)
			if not AutoAnswerEnabled then return false end
			-- Backspace
			typed = string.sub(typed, 1, #typed - 1)
			BillboardUpdate:FireServer(typed)
			task.wait(0.09 * speedMul)
			if not AutoAnswerEnabled then return false end
		end

		-- Ketik karakter benar
		typed = typed .. ch
		BillboardUpdate:FireServer(typed)

		local d = (slowMin + math.random() * (slowMax - slowMin)) * speedMul
		if math.random() < TYPING_CONFIG.pauseChance and i < #remaining_word then
			d = d + (TYPING_CONFIG.pauseDelayMin + math.random() * (TYPING_CONFIG.pauseDelayMax - TYPING_CONFIG.pauseDelayMin)) * speedMul
		end
		task.wait(d)
		i = i + 1
	end
	return true
end

-- ============================================================
-- DO AUTO ANSWER
-- Human Mode dan Normal pakai alur SAMA PERSIS:
--   FindOptions(CurrentLetter) → ambil [1] → ketik → SubmitWord:FireServer
-- Perbedaan hanya di fungsi typing yang dipanggil
-- ============================================================
local function DoAutoAnswer(turnStartTime)
	if not CurrentLetter or not AutoAnswerEnabled then return end

	-- Ambil opsi sama persis seperti UpdatePreview
	Options = FindOptions(CurrentLetter)

	-- Human Mode: skip kata berakhiran killer (x/z/q)
	local candidates = Options
	if HumanModeEnabled and HUMAN_CONFIG.skipKillerLetters then
		local safe = {}
		for _, w in ipairs(Options) do
			if not HUMAN_CONFIG.killerLettersToSkip[string.sub(w, -1)] then
				table.insert(safe, w)
			end
		end
		if #safe > 0 then candidates = safe end
	end

	if not candidates or #candidates == 0 then
		if autoAnswerStatusLabel then
			autoAnswerStatusLabel.Text = "❌ Tidak ada kata untuk '" .. CurrentLetter:upper() .. "'"
			autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 100)
		end
		SendNotification("warning", "NightHubX", "Tidak ada kata tersedia untuk '" .. CurrentLetter:upper() .. "'", 3)
		return
	end

	-- Ambil kata terbaik — persis sama dengan auto answer
	local word = candidates[1]
	MarkWordAsUsed(word, "auto_answer")
	LastSubmittedWord = word

	if autoAnswerStatusLabel then
		local tag = HumanModeEnabled and " 👤" or " 🤖"
		autoAnswerStatusLabel.Text = '⏳ "' .. word .. '"' .. tag
		autoAnswerStatusLabel.TextColor3 = Color3.fromRGB(140, 100, 255)
	end

	-- Think delay (Human Mode lebih lama)
	local thinkMin = HumanModeEnabled and TYPING_CONFIG.thinkDelayMin + 0.4 or TYPING_CONFIG.thinkDelayMin
	local thinkMax = HumanModeEnabled and TYPING_CONFIG.thinkDelayMax + 0.6 or TYPING_CONFIG.thinkDelayMax
	local thinkD = thinkMin + math.random() * (thinkMax - thinkMin)
	local tLeft = TYPING_CONFIG.hardDeadline - (tick() - turnStartTime)
	if tLeft < thinkD + 2.0 then thinkD = math.max(0.2, tLeft - 2.0) end
	task.wait(thinkD)
	if not AutoAnswerEnabled then return end

	-- Ketik (pilih versi sesuai mode)
	local remaining = string.sub(word, #CurrentLetter + 1)
	local ok
	if HumanModeEnabled then
		ok = TypeHuman(remaining, turnStartTime)
	else
		ok = TypeNormal(remaining, turnStartTime)
	end
	if not ok or not AutoAnswerEnabled then return end

	-- Delay sebelum submit
	local subD = TYPING_CONFIG.submitDelayMin + math.random() * (TYPING_CONFIG.submitDelayMax - TYPING_CONFIG.submitDelayMin)
	local tNow = TYPING_CONFIG.hardDeadline - (tick() - turnStartTime)
	if tNow < subD + 0.3 then subD = math.max(0.1, tNow - 0.3) end
	task.wait(subD)
	if not AutoAnswerEnabled then return end

	-- Submit
	SubmitWord:FireServer(remaining)

	local lc = string.sub(word, -1)
	local _, dangerText = GetDangerCategory(word)
	local t = string.format("%.1f", tick() - turnStartTime)
	if autoAnswerStatusLabel then
		autoAnswerStatusLabel.Text = '✅ "' .. word .. '" ' .. dangerText .. ' (' .. t .. 's)'
	end
	local label = HumanModeEnabled and "Human 👤" or "Auto 🤖"
	SendNotification("auto", label, '"' .. word .. '" → ' .. lc:upper() .. " " .. dangerText .. " [" .. t .. "s]", 2.5)
	UpdatePreview()
end

local function TriggerAutoAnswer()
	if not CurrentLetter or AutoAnswerAnswered then return end
	if not AutoAnswerEnabled then return end
	AutoAnswerAnswered=true

	local turnStart=tick()
	task.spawn(function()
		local timeout=0
		while not AutoAnswerReady and timeout<10 do task.wait(0.5); timeout=timeout+0.5 end
		if AutoAnswerReady and AutoAnswerEnabled then DoAutoAnswer(turnStart) end
	end)
end

-- ============================================================
-- RESET FOR NEW MATCH
-- ============================================================
local function ResetForNewMatch()
	local prevCount=0
	for _ in pairs(MatchUsedWords) do prevCount=prevCount+1 end
	MatchUsedWords={}; AutoAnswerRound=0; AutoAnswerAnswered=false; LastSubmittedWord=nil
	SendNotification("info","Match Baru 🔄","NightHubX reset "..prevCount.." kata terpakai. Semua opsi tersedia!",3)
	if autoAnswerStatusLabel and AutoAnswerEnabled then
		autoAnswerStatusLabel.Text="🔄 Match baru! Reset "..prevCount.." kata."
		autoAnswerStatusLabel.TextColor3=Color3.fromRGB(100,180,255)
	end
	if CurrentLetter then UpdatePreview() end
end

-- ============================================================
-- EVENTS
-- ============================================================
MatchUI.OnClientEvent:Connect(function(event, data)
	if not ScriptActive then return end

	if event=="UpdateServerLetter" then
		if type(data)=="string" then
			CurrentLetter=string.lower(data):gsub("[^a-z]","")
			AutoAnswerAnswered=false; UpdatePreview()
			if autoAnswerStatusLabel and AutoAnswerEnabled then
				autoAnswerStatusLabel.Text="⏳ Huruf: "..CurrentLetter:upper().." | Menunggu giliran..."
			end
			-- Re-setup Fake Type listener karena CurrentLetter berubah
			if FakeTypeEnabled then
				SetupFakeTypeListener()
			end
		end
	elseif event=="StartTurn" then
		AutoAnswerRound=AutoAnswerRound+1; AutoAnswerAnswered=false; TriggerAutoAnswer()
	elseif event=="Mistake" then
		AutoAnswerAnswered=false
		if AutoAnswerEnabled then
			if autoAnswerStatusLabel then
				autoAnswerStatusLabel.Text="🔄 Salah! Mencoba kata lain..."
				autoAnswerStatusLabel.TextColor3=Color3.fromRGB(255,160,50)
			end
			SendNotification("wrong","Auto: Jawaban Salah","Mencoba kata lain dari opsi...",2)
			UpdatePreview(); task.wait(0.5); TriggerAutoAnswer()
		else
			SendNotification("wrong","Jawaban Salah! 💢","Coba lagi.",3)
		end
	elseif event=="CorrectAnswer" then
		if type(data)=="string" and #data>0 then
			local aw=string.lower(data):gsub("%s","")
			if #aw>=3 then MarkWordAsUsed(aw,"correct_answer") end
		elseif LastSubmittedWord then
			MarkWordAsUsed(LastSubmittedWord,"correct_answer_fallback")
		end
		if AutoAnswerEnabled then
			SendNotification("correct","Auto: Benar! 🎉","Ronde "..AutoAnswerRound.." berhasil!",2.5)
		else
			SendNotification("correct","Jawaban Benar! 🎉","Kerja bagus!",3)
		end
		UpdatePreview()
	elseif event=="EndTurn" then
		CurrentLetter=nil; AutoAnswerAnswered=false
		if autoAnswerStatusLabel and AutoAnswerEnabled then
			autoAnswerStatusLabel.Text="⏸️ Giliran selesai. Menunggu..."
		end
	elseif event=="MatchStart" or event=="NewMatch" or event=="GameStart" then
		ResetForNewMatch()
	elseif event=="MatchEnd" or event=="GameEnd" or event=="EndMatch" then
		ResetForNewMatch()
	end
end)

BillboardUpdate.OnClientEvent:Connect(function(playerName, wordData)
	if not ScriptActive then return end
	if type(wordData)=="string" and #wordData>=3 then
		local uw=string.lower(wordData):gsub("%s","")
		if string.match(uw,"^[a-z]+$") then
			if playerName~=player.Name then
				MarkWordAsUsed(uw,"other_player:"..tostring(playerName))
				if CurrentLetter then task.defer(function() UpdatePreview() end) end
			end
		end
	end
end)

local lastKnownRound=0
task.spawn(function()
	while gui and gui.Parent do
		if AutoAnswerRound>3 and AutoAnswerRound<lastKnownRound then ResetForNewMatch() end
		lastKnownRound=AutoAnswerRound; task.wait(2)
	end
end)

-- ============================================================
-- ANIMATIONS
-- ============================================================
task.spawn(function()
	while accentLine and accentLine.Parent do
		TweenWait(accentLine, {BackgroundTransparency=0.4}, 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		TweenWait(accentLine, {BackgroundTransparency=0}, 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
end)

task.spawn(function()
	while titleIconGlow and titleIconGlow.Parent do
		TweenWait(titleIconGlow, {BackgroundTransparency=0.62, Size=UDim2.new(0,44,0,44), Position=UDim2.new(0,6,0.5,-22)}, 1.5, Enum.EasingStyle.Sine)
		TweenWait(titleIconGlow, {BackgroundTransparency=0.82, Size=UDim2.new(0,40,0,40), Position=UDim2.new(0,8,0.5,-20)}, 1.5, Enum.EasingStyle.Sine)
	end
end)

print("[NightHubX v5] SmartAuto+DupFilter+HumanMode+FakeType initialized!")
print("[NightHubX v5] HumanMode: auto-jawab santai | FakeType: intercept input user → submit nyata")
print("[NightHubX v5] Tema: Night/Crimson/Cyan/Gold/Void | Strategy+ Engine | 13s deadline")
