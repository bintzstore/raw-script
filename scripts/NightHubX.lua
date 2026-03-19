local cloneref = cloneref or function(o) return o end
local RS  = cloneref(game:GetService("ReplicatedStorage"))
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes      = RS:WaitForChild("Remotes")
local MatchUI      = Remotes:WaitForChild("MatchUI")
local SubmitWord   = Remotes:WaitForChild("SubmitWord")
local BillboardUpd = Remotes:WaitForChild("BillboardUpdate")

-- ============================================================
-- STATE
-- ============================================================
local Prefix1, Prefix2 = {}, {}
local CurrentLetter = nil
local Ready = false
local Options = {}
local ScriptActive = true
local LetterWordCount = {}
local SortMode = "strategy"

local AutoAnswerEnabled  = false
local AutoAnswerReady    = false
local AutoAnswerAnswered = false
local AutoAnswerRound    = 0
local MatchUsedWords     = {}
local LastSubmittedWord  = nil

local TypoEnabled       = false
local CustomCharDelay   = 0.15
local AntiKillerEnabled = false

local KILLER_SCORE_OVERRIDE = {x=99999,z=95000,q=90000,v=70000,f=60000,w=50000,y=45000,j=35000,k=30000,g=25000,c=22000}
local KILLER_ENDINGS        = {x=true,z=true,q=true,v=true,f=true}
local HardLetters           = {q=10,x=9,z=8,v=7,f=6,w=5,y=4,k=3,b=2,p=1}
local MAX_BUTTONS           = 40

local TYPING = {
	thinkDelayMin=1.2, thinkDelayMax=3.0,
	pauseChance=0.12, pauseDelayMin=0.3, pauseDelayMax=0.7,
	submitDelayMin=0.3, submitDelayMax=0.8, hardDeadline=11.0,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function T(obj, props, dur, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(dur or 0.22, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play(); return tw
end
local function TW(obj, props, dur, style, dir) T(obj,props,dur,style,dir).Completed:Wait() end

local function Corner(obj, r)
	Instance.new("UICorner", obj).CornerRadius = UDim.new(0, r or 8)
end
local function Stroke(obj, col, th, tr)
	local s = Instance.new("UIStroke", obj)
	s.Color = col or Color3.new(1,1,1); s.Thickness = th or 1; s.Transparency = tr or 0.5
	return s
end

-- ============================================================
-- THEME
-- ============================================================
local Themes = {
	Night   = {ac=Color3.fromRGB(120,80,255),  bg=Color3.fromRGB(10,8,18),  pn=Color3.fromRGB(14,12,24), cd=Color3.fromRGB(18,15,30), ch=Color3.fromRGB(26,22,42), t1=Color3.fromRGB(255,255,255), t2=Color3.fromRGB(180,165,215), mu=Color3.fromRGB(110,95,150), sk=Color3.fromRGB(45,32,85)},
	Crimson = {ac=Color3.fromRGB(220,45,80),   bg=Color3.fromRGB(14,6,10),  pn=Color3.fromRGB(18,9,13),  cd=Color3.fromRGB(22,11,16), ch=Color3.fromRGB(32,16,22), t1=Color3.fromRGB(255,255,255), t2=Color3.fromRGB(215,180,190), mu=Color3.fromRGB(145,100,115), sk=Color3.fromRGB(75,22,38)},
	Cyan    = {ac=Color3.fromRGB(0,200,220),   bg=Color3.fromRGB(4,14,18),  pn=Color3.fromRGB(6,18,24),  cd=Color3.fromRGB(8,22,30),  ch=Color3.fromRGB(12,32,44), t1=Color3.fromRGB(255,255,255), t2=Color3.fromRGB(175,220,228), mu=Color3.fromRGB(90,145,160), sk=Color3.fromRGB(0,65,80)},
	Gold    = {ac=Color3.fromRGB(220,175,30),  bg=Color3.fromRGB(14,11,4),  pn=Color3.fromRGB(18,14,6),  cd=Color3.fromRGB(22,18,8),  ch=Color3.fromRGB(32,26,12), t1=Color3.fromRGB(255,255,255), t2=Color3.fromRGB(225,210,165), mu=Color3.fromRGB(155,135,80), sk=Color3.fromRGB(75,58,12)},
	Void    = {ac=Color3.fromRGB(155,155,175), bg=Color3.fromRGB(10,10,13), pn=Color3.fromRGB(14,14,18), cd=Color3.fromRGB(18,18,22), ch=Color3.fromRGB(26,26,32), t1=Color3.fromRGB(255,255,255), t2=Color3.fromRGB(188,188,205), mu=Color3.fromRGB(115,115,132), sk=Color3.fromRGB(38,38,52)},
}
local themeOrder = {"Night","Crimson","Cyan","Gold","Void"}
local themeIdx = 1
local CT = Themes["Night"]

-- Daftar elemen yang perlu diupdate tema
local TE = {}
local function Re(kind, obj) table.insert(TE,{k=kind,o=obj}) end

local function ApplyTheme(name)
	local th = Themes[name]; if not th then return end
	CT = th
	for _, e in ipairs(TE) do
		local o = e.o
		if     e.k=="bg"  then o.BackgroundColor3 = th.bg
		elseif e.k=="pn"  then o.BackgroundColor3 = th.pn
		elseif e.k=="cd"  then o.BackgroundColor3 = th.cd
		elseif e.k=="sk"  then o.Color            = th.sk
		elseif e.k=="ac"  then o.BackgroundColor3 = th.ac
		elseif e.k=="acs" then o.Color            = th.ac
		elseif e.k=="mu"  then o.TextColor3       = th.mu
		elseif e.k=="t2"  then o.TextColor3       = th.t2
		elseif e.k=="t1"  then o.TextColor3       = th.t1
		elseif e.k=="scr" then o.ScrollBarImageColor3 = th.ac
		end
	end
end

-- ============================================================
-- GUI ROOT
-- ============================================================
local gui = Instance.new("ScreenGui", PlayerGui)
gui.Name = "NightHubX"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = true

-- ============================================================
-- NOTIFIKASI — compact toast pojok kanan atas
-- ============================================================
local notifHolder = Instance.new("Frame", gui)
notifHolder.Size = UDim2.new(0,240,1,0)
notifHolder.Position = UDim2.new(1,-250,0,8)
notifHolder.BackgroundTransparency = 1
notifHolder.ZIndex = 300

local notifLayout = Instance.new("UIListLayout", notifHolder)
notifLayout.Padding = UDim.new(0,5)
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

local notifN = 0

local NICONS = {success="✓",error="✕",info="·",warning="!",correct="✓",wrong="✕",auto="⚡",loaded="✦",unloaded="○"}
local NCOLORS = {
	success=Color3.fromRGB(40,200,100), error=Color3.fromRGB(235,55,80),
	info=Color3.fromRGB(80,160,255), warning=Color3.fromRGB(240,175,35),
	correct=Color3.fromRGB(40,210,110), wrong=Color3.fromRGB(240,60,80),
	auto=Color3.fromRGB(120,80,255), loaded=Color3.fromRGB(120,80,255),
	unloaded=Color3.fromRGB(175,100,50),
}

local function Notif(ntype, title, msg, dur)
	dur = dur or 3
	notifN = notifN + 1
	local col = NCOLORS[ntype] or Color3.fromRGB(120,80,255)
	local ico = NICONS[ntype] or "·"

	local pill = Instance.new("Frame", notifHolder)
	pill.Name = "Notif"..notifN
	pill.Size = UDim2.new(1,0,0,0)
	pill.BackgroundColor3 = Color3.fromRGB(11,9,20)
	pill.BorderSizePixel = 0
	pill.ClipsDescendants = true
	pill.LayoutOrder = notifN
	pill.ZIndex = 301
	Corner(pill, 8)

	local ps = Stroke(pill, col, 1, 0.35)

	-- left bar
	local lb = Instance.new("Frame", pill)
	lb.Size = UDim2.new(0,2,1,-8); lb.Position = UDim2.new(0,4,0,4)
	lb.BackgroundColor3 = col; lb.BorderSizePixel = 0; lb.ZIndex = 302
	Corner(lb, 1)

	-- icon
	local iF = Instance.new("Frame", pill)
	iF.Size = UDim2.new(0,18,0,18); iF.Position = UDim2.new(0,12,0,8)
	iF.BackgroundColor3 = col; iF.BackgroundTransparency = 0.78
	iF.BorderSizePixel = 0; iF.ZIndex = 302
	Corner(iF, 9)
	local iL = Instance.new("TextLabel", iF)
	iL.Size = UDim2.new(1,0,1,0); iL.BackgroundTransparency = 1
	iL.Text = ico; iL.Font = Enum.Font.GothamBold; iL.TextSize = 10
	iL.TextColor3 = col; iL.ZIndex = 303

	-- title
	local tL = Instance.new("TextLabel", pill)
	tL.Size = UDim2.new(1,-38,0,14); tL.Position = UDim2.new(0,36,0,5)
	tL.BackgroundTransparency = 1; tL.Text = title or ""
	tL.Font = Enum.Font.GothamBold; tL.TextSize = 10
	tL.TextColor3 = Color3.fromRGB(235,235,255)
	tL.TextXAlignment = Enum.TextXAlignment.Left
	tL.TextTruncate = Enum.TextTruncate.AtEnd; tL.ZIndex = 302

	-- msg (hanya kalau ada)
	local hasMsg = msg and msg ~= ""
	if hasMsg then
		local mL = Instance.new("TextLabel", pill)
		mL.Size = UDim2.new(1,-38,0,12); mL.Position = UDim2.new(0,36,0,19)
		mL.BackgroundTransparency = 1; mL.Text = msg
		mL.Font = Enum.Font.Gotham; mL.TextSize = 8
		mL.TextColor3 = Color3.fromRGB(155,145,188)
		mL.TextXAlignment = Enum.TextXAlignment.Left
		mL.TextTruncate = Enum.TextTruncate.AtEnd; mL.ZIndex = 302
	end

	local totalH = hasMsg and 38 or 26

	-- progress
	local pbg = Instance.new("Frame", pill)
	pbg.Size = UDim2.new(1,-8,0,2); pbg.Position = UDim2.new(0,4,1,-3)
	pbg.BackgroundColor3 = Color3.fromRGB(22,18,38); pbg.BorderSizePixel = 0; pbg.ZIndex = 302
	Corner(pbg, 1)
	local pfl = Instance.new("Frame", pbg)
	pfl.Size = UDim2.new(1,0,1,0); pfl.BackgroundColor3 = col; pfl.BorderSizePixel = 0; pfl.ZIndex = 303
	Corner(pfl, 1)

	T(pill, {Size=UDim2.new(1,0,0,totalH)}, 0.22, Enum.EasingStyle.Back)
	T(pfl, {Size=UDim2.new(0,0,1,0)}, dur, Enum.EasingStyle.Linear)

	local gone = false
	local function Bye()
		if gone then return end; gone = true
		T(pill, {Size=UDim2.new(1,0,0,0), BackgroundTransparency=1}, 0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		task.wait(0.22); pill:Destroy()
	end
	task.delay(dur, Bye)
end

-- ============================================================
-- MAIN FRAME — 480 × 370, compact
-- ============================================================
local W, H = 480, 370
local TOPBAR_H = 32
local CONTENT_Y = TOPBAR_H + 2  -- setelah topbar + accent line

local shadow = Instance.new("ImageLabel", gui)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(0,0,0)
shadow.ImageTransparency = 0.5
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(49,49,450,450)
shadow.Size = UDim2.new(0,W+28,0,H+28)
shadow.Position = UDim2.new(0.5,-(W/2)-14,0.5,-(H/2)-14)
shadow.ZIndex = 1

local frame = Instance.new("Frame", gui)
frame.Name = "MainFrame"
frame.Size = UDim2.new(0,0,0,0)
frame.Position = UDim2.new(0.5,0,0.5,0)
frame.BackgroundColor3 = CT.bg
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = false
frame.ClipsDescendants = true
frame.ZIndex = 2
Corner(frame, 10)
Re("bg", frame)

local fStr = Stroke(frame, CT.sk, 1.2, 0.1)
Re("sk", fStr)

frame:GetPropertyChangedSignal("Position"):Connect(function()
	shadow.Position = UDim2.new(
		frame.Position.X.Scale, frame.Position.X.Offset - 14,
		frame.Position.Y.Scale, frame.Position.Y.Offset - 14
	)
end)

-- Popup open
task.defer(function()
	T(frame, {Size=UDim2.new(0,W,0,H), Position=UDim2.new(0.5,-W/2,0.5,-H/2)}, 0.38, Enum.EasingStyle.Back)
end)

-- ============================================================
-- DRAG — hanya dari topbar
-- ============================================================
local dragging, dStart, fStart = false, Vector2.new(), UDim2.new()

UIS.InputChanged:Connect(function(inp)
	if not dragging then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement
		and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	local d = inp.Position - dStart
	frame.Position = UDim2.new(fStart.X.Scale, fStart.X.Offset+d.X, fStart.Y.Scale, fStart.Y.Offset+d.Y)
end)
UIS.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

-- ============================================================
-- TOP BAR — tinggi 32px, hanya X dan -
-- ============================================================
local topBar = Instance.new("Frame", frame)
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1,0,0,TOPBAR_H)
topBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
topBar.BackgroundTransparency = 0.48
topBar.BorderSizePixel = 0
topBar.ZIndex = 10
Corner(topBar, 10)

-- Isi bawah radius topbar
local tbF = Instance.new("Frame", topBar)
tbF.Size = UDim2.new(1,0,0,12); tbF.Position = UDim2.new(0,0,1,-12)
tbF.BackgroundColor3 = Color3.fromRGB(0,0,0); tbF.BackgroundTransparency = 0.48
tbF.BorderSizePixel = 0; tbF.ZIndex = 10

-- Accent line
local acLine = Instance.new("Frame", frame)
acLine.Size = UDim2.new(1,0,0,1)
acLine.Position = UDim2.new(0,0,0,TOPBAR_H)
acLine.BackgroundColor3 = CT.ac
acLine.BorderSizePixel = 0
acLine.ZIndex = 11
Re("ac", acLine)

local acGrad = Instance.new("UIGradient", acLine)
acGrad.Transparency = NumberSequence.new{
	NumberSequenceKeypoint.new(0,0.88), NumberSequenceKeypoint.new(0.5,0), NumberSequenceKeypoint.new(1,0.88)
}

task.spawn(function()
	while acLine and acLine.Parent do
		TW(acLine,{BackgroundTransparency=0.4},1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
		TW(acLine,{BackgroundTransparency=0},1.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
	end
end)

-- Drag dari topbar
topBar.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
		dragging = true; dStart = inp.Position; fStart = frame.Position
		inp.Changed:Connect(function()
			if inp.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

-- Icon + judul
local iconBg = Instance.new("Frame", topBar)
iconBg.Size = UDim2.new(0,20,0,20); iconBg.Position = UDim2.new(0,6,0.5,-10)
iconBg.BackgroundColor3 = CT.ac; iconBg.BackgroundTransparency = 0.12
iconBg.BorderSizePixel = 0; iconBg.ZIndex = 11
Corner(iconBg, 5)
Re("ac", iconBg)

local iconL = Instance.new("TextLabel", iconBg)
iconL.Size = UDim2.new(1,0,1,0); iconL.BackgroundTransparency = 1
iconL.Text = "✦"; iconL.Font = Enum.Font.GothamBlack; iconL.TextSize = 10
iconL.TextColor3 = Color3.fromRGB(255,255,255); iconL.ZIndex = 12

local titleL = Instance.new("TextLabel", topBar)
titleL.Size = UDim2.new(0,180,1,0); titleL.Position = UDim2.new(0,30,0,0)
titleL.BackgroundTransparency = 1; titleL.Text = "NightHubX"
titleL.Font = Enum.Font.GothamBlack; titleL.TextSize = 13
titleL.TextColor3 = Color3.fromRGB(255,255,255)
titleL.TextXAlignment = Enum.TextXAlignment.Left; titleL.ZIndex = 11

-- Tombol kontrol: hanya − dan ✕
local function MkCtrl(sym, posX, hCol)
	local b = Instance.new("TextButton", topBar)
	b.Size = UDim2.new(0,22,0,22); b.Position = UDim2.new(1,posX,0.5,-11)
	b.BackgroundColor3 = Color3.fromRGB(255,255,255); b.BackgroundTransparency = 0.94
	b.Text = sym; b.Font = Enum.Font.GothamBold; b.TextSize = 11
	b.TextColor3 = Color3.fromRGB(175,165,205)
	b.BorderSizePixel = 0; b.AutoButtonColor = false; b.ZIndex = 12
	Corner(b, 6)
	b.MouseEnter:Connect(function() T(b,{BackgroundColor3=hCol,BackgroundTransparency=0.08,TextColor3=Color3.fromRGB(255,255,255)},0.12) end)
	b.MouseLeave:Connect(function() T(b,{BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.94,TextColor3=Color3.fromRGB(175,165,205)},0.12) end)
	return b
end

local closeBtn    = MkCtrl("✕", -28, Color3.fromRGB(215,48,68))
local minimizeBtn = MkCtrl("−", -54, Color3.fromRGB(185,160,28))
local themeSwitchBtn = MkCtrl("◆", -80, CT.ac)
Re("ac", themeSwitchBtn)  -- warna berubah sesuai tema

closeBtn.MouseButton1Click:Connect(function()
	ScriptActive = false; AutoAnswerEnabled = false
	T(frame,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(0.5,0,0.5,0)},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.In)
	T(shadow,{ImageTransparency=1},0.25)
	task.wait(0.35); gui:Destroy()
end)

local IsMin = false
minimizeBtn.MouseButton1Click:Connect(function()
	IsMin = not IsMin
	T(frame, {Size=UDim2.new(0,W,0,IsMin and TOPBAR_H or H)}, 0.28, Enum.EasingStyle.Quint)
end)

themeSwitchBtn.MouseButton1Click:Connect(function()
	themeIdx = themeIdx % #themeOrder + 1
	local name = themeOrder[themeIdx]
	ApplyTheme(name)
	-- update elemen manual yang tidak masuk Re list
	acLine.BackgroundColor3 = CT.ac
	frame.BackgroundColor3 = CT.bg
	iconBg.BackgroundColor3 = CT.ac
	fStr.Color = CT.sk
	themeSwitchBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
	T(themeSwitchBtn,{BackgroundTransparency=0.94},0.1)
	Notif("info","Tema: "..name,"",1.5)
end)

-- ============================================================
-- LAYOUT KONTEN — 2 kolom
-- ============================================================
local LWIDTH = 155
local GAP = 4

-- ── LEFT PANEL ──
local leftPanel = Instance.new("Frame", frame)
leftPanel.Name = "Left"
leftPanel.Size = UDim2.new(0, LWIDTH, 1, -CONTENT_Y-GAP)
leftPanel.Position = UDim2.new(0, GAP, 0, CONTENT_Y)
leftPanel.BackgroundColor3 = CT.pn
leftPanel.BackgroundTransparency = 0.18
leftPanel.BorderSizePixel = 0
leftPanel.ZIndex = 3
Corner(leftPanel, 8)
Re("pn", leftPanel)
Stroke(leftPanel, CT.sk, 1, 0.35)

-- Prefix info card
local prefCard = Instance.new("Frame", leftPanel)
prefCard.Size = UDim2.new(1,-10,0,68); prefCard.Position = UDim2.new(0,5,0,5)
prefCard.BackgroundColor3 = CT.cd; prefCard.BorderSizePixel = 0; prefCard.ZIndex = 4
Corner(prefCard, 7)
Re("cd", prefCard)
Stroke(prefCard, CT.sk, 1, 0.45)

local prefTL = Instance.new("TextLabel", prefCard)
prefTL.Size = UDim2.new(1,-8,0,13); prefTL.Position = UDim2.new(0,8,0,5)
prefTL.BackgroundTransparency=1; prefTL.Text="HURUF AKTIF"
prefTL.Font=Enum.Font.GothamBold; prefTL.TextSize=7
prefTL.TextColor3=CT.mu; prefTL.TextXAlignment=Enum.TextXAlignment.Left; prefTL.ZIndex=5
Re("mu", prefTL)

local prefixLabel = Instance.new("TextLabel", prefCard)
prefixLabel.Name = "PrefixLabel"
prefixLabel.Size = UDim2.new(0,55,0,38); prefixLabel.Position = UDim2.new(0,5,0,18)
prefixLabel.BackgroundTransparency=1; prefixLabel.Text="—"
prefixLabel.Font=Enum.Font.GothamBlack; prefixLabel.TextSize=32
prefixLabel.TextColor3=CT.ac; prefixLabel.TextXAlignment=Enum.TextXAlignment.Left; prefixLabel.ZIndex=5

local dangerLabel = Instance.new("TextLabel", prefCard)
dangerLabel.Name = "DangerLabel"
dangerLabel.Size = UDim2.new(0,68,0,16); dangerLabel.Position = UDim2.new(1,-72,0,6)
dangerLabel.BackgroundColor3 = Color3.fromRGB(200,30,60); dangerLabel.BackgroundTransparency = 0.68
dangerLabel.Text = ""; dangerLabel.Font = Enum.Font.GothamBold; dangerLabel.TextSize = 7
dangerLabel.TextColor3 = Color3.fromRGB(255,110,135); dangerLabel.BorderSizePixel = 0
dangerLabel.ZIndex = 6; dangerLabel.Visible = false
Corner(dangerLabel, 4)

local countLabel = Instance.new("TextLabel", prefCard)
countLabel.Name = "CountLabel"
countLabel.Size = UDim2.new(1,-8,0,12); countLabel.Position = UDim2.new(0,8,0,54)
countLabel.BackgroundTransparency=1; countLabel.Text="—"
countLabel.Font=Enum.Font.Gotham; countLabel.TextSize=8
countLabel.TextColor3=CT.t2; countLabel.TextXAlignment=Enum.TextXAlignment.Left; countLabel.ZIndex=5
Re("t2", countLabel)

-- Status
local statusLabel = Instance.new("TextLabel", leftPanel)
statusLabel.Size = UDim2.new(1,-10,0,13); statusLabel.Position = UDim2.new(0,5,0,77)
statusLabel.BackgroundTransparency=1; statusLabel.Text="⏳ Memuat..."
statusLabel.Font=Enum.Font.GothamMedium; statusLabel.TextSize=9
statusLabel.TextColor3=CT.ac; statusLabel.TextXAlignment=Enum.TextXAlignment.Left; statusLabel.ZIndex=4

-- ── AUTO SECTION ──
local autoSec = Instance.new("Frame", leftPanel)
autoSec.Size = UDim2.new(1,-10,0,196); autoSec.Position = UDim2.new(0,5,0,93)
autoSec.BackgroundColor3 = CT.cd; autoSec.BorderSizePixel = 0; autoSec.ZIndex = 4
Corner(autoSec, 7)
Re("cd", autoSec)
local asSt = Stroke(autoSec, CT.sk, 1, 0.38)

local autoHdrL = Instance.new("TextLabel", autoSec)
autoHdrL.Size = UDim2.new(1,-8,0,13); autoHdrL.Position = UDim2.new(0,8,0,5)
autoHdrL.BackgroundTransparency=1; autoHdrL.Text="AUTO ANSWER"
autoHdrL.Font=Enum.Font.GothamBold; autoHdrL.TextSize=7
autoHdrL.TextColor3=CT.mu; autoHdrL.TextXAlignment=Enum.TextXAlignment.Left; autoHdrL.ZIndex=5
Re("mu", autoHdrL)

-- Mini toggle helper
local function MkTog(parent, y, lbl, onC)
	local row = Instance.new("TextButton", parent)
	row.Size = UDim2.new(1,-10,0,22); row.Position = UDim2.new(0,5,0,y)
	row.BackgroundColor3 = CT.bg; row.Text = ""; row.BorderSizePixel = 0
	row.AutoButtonColor = false; row.ZIndex = 5
	Corner(row, 6)
	Re("bg", row)
	local rs = Stroke(row, CT.sk, 1, 0.6)

	local tr = Instance.new("Frame", row)
	tr.Size = UDim2.new(0,28,0,13); tr.Position = UDim2.new(0,4,0.5,-6.5)
	tr.BackgroundColor3 = Color3.fromRGB(35,26,58); tr.BorderSizePixel = 0; tr.ZIndex = 6
	Corner(tr, 6)

	local kn = Instance.new("Frame", tr)
	kn.Size = UDim2.new(0,9,0,9); kn.Position = UDim2.new(0,2,0.5,-4.5)
	kn.BackgroundColor3 = Color3.fromRGB(110,100,148); kn.BorderSizePixel = 0; kn.ZIndex = 7
	Corner(kn, 4)

	local lb = Instance.new("TextLabel", row)
	lb.Size = UDim2.new(1,-38,1,0); lb.Position = UDim2.new(0,36,0,0)
	lb.BackgroundTransparency=1; lb.Text=lbl
	lb.Font=Enum.Font.GothamBold; lb.TextSize=8
	lb.TextColor3=CT.mu; lb.TextXAlignment=Enum.TextXAlignment.Left; lb.ZIndex=6
	Re("mu", lb)

	row.MouseEnter:Connect(function() T(row,{BackgroundColor3=CT.ch},0.1) end)
	row.MouseLeave:Connect(function() T(row,{BackgroundColor3=CT.bg},0.1) end)

	local function SetOn(on)
		if on then
			T(tr,{BackgroundColor3=onC},0.18)
			T(kn,{Position=UDim2.new(1,-11,0.5,-4.5),BackgroundColor3=Color3.fromRGB(255,255,255)},0.18,Enum.EasingStyle.Back)
			T(rs,{Color=onC,Transparency=0.28},0.15)
			lb.TextColor3=onC
		else
			T(tr,{BackgroundColor3=Color3.fromRGB(35,26,58)},0.18)
			T(kn,{Position=UDim2.new(0,2,0.5,-4.5),BackgroundColor3=Color3.fromRGB(110,100,148)},0.18,Enum.EasingStyle.Back)
			T(rs,{Color=CT.sk,Transparency=0.6},0.15)
			lb.TextColor3=CT.mu
		end
	end
	return row, SetOn, lb
end

-- Auto toggle
local autoBtn, SetAutoV, autoLbl = MkTog(autoSec, 20, "OFF", Color3.fromRGB(120,80,255))

-- Glow
local autoGlow = Instance.new("Frame", autoSec)
autoGlow.Size = UDim2.new(1,4,1,4); autoGlow.Position = UDim2.new(0,-2,0,-2)
autoGlow.BackgroundColor3 = Color3.fromRGB(120,80,255); autoGlow.BackgroundTransparency = 1
autoGlow.BorderSizePixel = 0; autoGlow.ZIndex = 3
Corner(autoGlow, 9)

task.spawn(function()
	while autoGlow and autoGlow.Parent do
		if AutoAnswerEnabled then
			TW(autoGlow,{BackgroundTransparency=0.84},1.2,Enum.EasingStyle.Sine)
			TW(autoGlow,{BackgroundTransparency=0.96},1.2,Enum.EasingStyle.Sine)
		else task.wait(0.5) end
	end
end)

-- Status label auto
local autoAnswerStatusLabel = Instance.new("TextLabel", autoSec)
autoAnswerStatusLabel.Name = "AutoStatus"
autoAnswerStatusLabel.Size = UDim2.new(1,-10,0,11); autoAnswerStatusLabel.Position = UDim2.new(0,5,1,-13)
autoAnswerStatusLabel.BackgroundTransparency=1; autoAnswerStatusLabel.Text=""
autoAnswerStatusLabel.Font=Enum.Font.Gotham; autoAnswerStatusLabel.TextSize=8
autoAnswerStatusLabel.TextColor3=CT.mu; autoAnswerStatusLabel.TextXAlignment=Enum.TextXAlignment.Left; autoAnswerStatusLabel.ZIndex=5
Re("mu", autoAnswerStatusLabel)

autoBtn.MouseButton1Click:Connect(function()
	AutoAnswerEnabled = not AutoAnswerEnabled
	SetAutoV(AutoAnswerEnabled)
	autoLbl.Text = AutoAnswerEnabled and "ON" or "OFF"
	if AutoAnswerEnabled then
		T(asSt,{Color=Color3.fromRGB(100,60,220),Transparency=0.1},0.2)
		T(autoGlow,{BackgroundTransparency=0.88},0.25)
		autoAnswerStatusLabel.Text="⏳ Menunggu giliran..."
		autoAnswerStatusLabel.TextColor3=Color3.fromRGB(120,80,255)
		Notif("auto","Auto Answer ON","DupFilter aktif",2.5)
	else
		T(asSt,{Color=CT.sk,Transparency=0.38},0.2)
		T(autoGlow,{BackgroundTransparency=1},0.25)
		autoAnswerStatusLabel.Text=""
		Notif("info","Auto Answer OFF","",2)
	end
end)

-- DELAY SLIDER
local DELAY_MIN, DELAY_MAX = 0.1, 3.0

local delRow = Instance.new("Frame", autoSec)
delRow.Size = UDim2.new(1,-10,0,32); delRow.Position = UDim2.new(0,5,0,46)
delRow.BackgroundTransparency=1; delRow.BorderSizePixel=0; delRow.ZIndex=5

local delHdr = Instance.new("TextLabel", delRow)
delHdr.Size = UDim2.new(0.62,0,0,13); delHdr.BackgroundTransparency=1
delHdr.Text="DELAY KETIK"; delHdr.Font=Enum.Font.GothamBold; delHdr.TextSize=7
delHdr.TextColor3=CT.mu; delHdr.TextXAlignment=Enum.TextXAlignment.Left; delHdr.ZIndex=6
Re("mu", delHdr)

local delValL = Instance.new("TextLabel", delRow)
delValL.Size = UDim2.new(0.38,0,0,13); delValL.Position = UDim2.new(0.62,0,0,0)
delValL.BackgroundTransparency=1; delValL.Text="0.15s"
delValL.Font=Enum.Font.GothamBold; delValL.TextSize=9
delValL.TextColor3=CT.ac; delValL.TextXAlignment=Enum.TextXAlignment.Right; delValL.ZIndex=6

local sTrk = Instance.new("Frame", delRow)
sTrk.Size = UDim2.new(1,0,0,5); sTrk.Position = UDim2.new(0,0,0,20)
sTrk.BackgroundColor3 = Color3.fromRGB(26,20,44); sTrk.BorderSizePixel=0; sTrk.ZIndex=6
Corner(sTrk, 2)

local sFil = Instance.new("Frame", sTrk)
sFil.Size = UDim2.new(0.017,0,1,0)
sFil.BackgroundColor3 = CT.ac; sFil.BorderSizePixel=0; sFil.ZIndex=7
Corner(sFil, 2)

local sKnb = Instance.new("Frame", sTrk)
sKnb.Size = UDim2.new(0,11,0,11); sKnb.Position = UDim2.new(0.017,-5.5,0.5,-5.5)
sKnb.BackgroundColor3 = Color3.fromRGB(205,195,255); sKnb.BorderSizePixel=0; sKnb.ZIndex=8
Corner(sKnb, 5)
Stroke(sKnb, CT.ac, 1.5, 0.25)

local function SetSlider(pct)
	pct = math.clamp(pct,0,1)
	CustomCharDelay = math.floor((DELAY_MIN+pct*(DELAY_MAX-DELAY_MIN))*100+0.5)/100
	sFil.Size = UDim2.new(pct,0,1,0)
	sKnb.Position = UDim2.new(pct,-5.5,0.5,-5.5)
	delValL.Text = string.format("%.2fs",CustomCharDelay)
	sFil.BackgroundColor3 = Color3.fromRGB(math.floor(80+pct*175), math.floor(80+(1-pct)*115), 255)
end
SetSlider((CustomCharDelay-DELAY_MIN)/(DELAY_MAX-DELAY_MIN))

local sDrag = false
sTrk.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=true end end)
sTrk.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=false end end)
UIS.InputChanged:Connect(function(i)
	if not sDrag then return end
	if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
	SetSlider((i.Position.X-sTrk.AbsolutePosition.X)/sTrk.AbsoluteSize.X)
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=false end
end)

-- Typo toggle
local typoBtn, SetTypoV, typoLbl = MkTog(autoSec, 84, "Typo: OFF", Color3.fromRGB(220,155,28))
typoBtn.MouseButton1Click:Connect(function()
	TypoEnabled = not TypoEnabled; SetTypoV(TypoEnabled)
	typoLbl.Text = TypoEnabled and "Typo: ON ⚡" or "Typo: OFF"
	Notif(TypoEnabled and "warning" or "info", TypoEnabled and "Typo ON" or "Typo OFF", TypoEnabled and "Salah→hapus→benar" or "", 2)
end)

-- Anti Killer toggle
local akBtn, SetAKV, akLbl = MkTog(autoSec, 110, "Anti Killer: OFF", Color3.fromRGB(40,200,100))
akBtn.MouseButton1Click:Connect(function()
	AntiKillerEnabled = not AntiKillerEnabled; SetAKV(AntiKillerEnabled)
	akLbl.Text = AntiKillerEnabled and "Anti Killer: ON 🛡" or "Anti Killer: OFF"
	Notif(AntiKillerEnabled and "success" or "info", AntiKillerEnabled and "Anti Killer ON" or "Anti Killer OFF", AntiKillerEnabled and "Skip x/z/q/v/f" or "", 2)
end)

-- Sort toggle
local sortBtn2, SetSortV, sortLbl2 = MkTog(autoSec, 136, "Sort: Strategy+", Color3.fromRGB(150,90,255))
local sortIsStrat = true
SetSortV(true)
sortBtn2.MouseButton1Click:Connect(function()
	sortIsStrat = not sortIsStrat
	SortMode = sortIsStrat and "strategy" or "difficulty"
	SetSortV(sortIsStrat)
	sortLbl2.Text = sortIsStrat and "Sort: Strategy+" or "Sort: Difficulty"
	if UpdatePreview then UpdatePreview() end
end)

-- Version
local verL2 = Instance.new("TextLabel", leftPanel)
verL2.Size = UDim2.new(1,-10,0,12); verL2.Position = UDim2.new(0,5,1,-14)
verL2.BackgroundTransparency=1; verL2.Text="NightHubX v4 • DupFilter"
verL2.Font=Enum.Font.Gotham; verL2.TextSize=7
verL2.TextColor3=CT.mu; verL2.TextXAlignment=Enum.TextXAlignment.Center; verL2.ZIndex=4
Re("mu", verL2)

-- ── RIGHT PANEL — Word List ──
local RX = LWIDTH + GAP*2
local rightPanel = Instance.new("Frame", frame)
rightPanel.Name = "Right"
rightPanel.Size = UDim2.new(1, -(RX+GAP), 1, -CONTENT_Y-GAP)
rightPanel.Position = UDim2.new(0, RX, 0, CONTENT_Y)
rightPanel.BackgroundTransparency = 1; rightPanel.BorderSizePixel = 0; rightPanel.ZIndex = 3

-- Column header
local colHdr = Instance.new("Frame", rightPanel)
colHdr.Size = UDim2.new(1,0,0,20); colHdr.BackgroundColor3 = CT.pn
colHdr.BackgroundTransparency = 0.22; colHdr.BorderSizePixel = 0; colHdr.ZIndex = 4
Corner(colHdr, 6)
Re("pn", colHdr)
Stroke(colHdr, CT.sk, 1, 0.42)

local hW = Instance.new("TextLabel", colHdr)
hW.Size=UDim2.new(1,-80,1,0); hW.Position=UDim2.new(0,8,0,0)
hW.BackgroundTransparency=1; hW.Text="KATA"
hW.Font=Enum.Font.GothamBold; hW.TextSize=8
hW.TextColor3=CT.mu; hW.TextXAlignment=Enum.TextXAlignment.Left; hW.ZIndex=5
Re("mu", hW)

local hD = Instance.new("TextLabel", colHdr)
hD.Size=UDim2.new(0,76,1,0); hD.Position=UDim2.new(1,-78,0,0)
hD.BackgroundTransparency=1; hD.Text="BAHAYA"
hD.Font=Enum.Font.GothamBold; hD.TextSize=8
hD.TextColor3=CT.mu; hD.TextXAlignment=Enum.TextXAlignment.Right; hD.ZIndex=5
Re("mu", hD)

-- Scroll
local scrollF = Instance.new("ScrollingFrame", rightPanel)
scrollF.Size = UDim2.new(1,0,1,-24); scrollF.Position = UDim2.new(0,0,0,22)
scrollF.BackgroundColor3 = CT.pn; scrollF.BackgroundTransparency = 0.2
scrollF.BorderSizePixel = 0; scrollF.ZIndex = 3
scrollF.ScrollBarThickness = 3; scrollF.ScrollBarImageColor3 = CT.ac
scrollF.CanvasSize = UDim2.new(0,0,0,0)
Corner(scrollF, 7)
Re("pn", scrollF); Re("scr", scrollF)
Stroke(scrollF, CT.sk, 1, 0.4)

local listLay = Instance.new("UIListLayout", scrollF)
listLay.SortOrder = Enum.SortOrder.LayoutOrder
listLay.Padding = UDim.new(0,2)

local lPad2 = Instance.new("UIPadding", scrollF)
lPad2.PaddingTop=UDim.new(0,3); lPad2.PaddingBottom=UDim.new(0,3)
lPad2.PaddingLeft=UDim.new(0,3); lPad2.PaddingRight=UDim.new(0,3)

listLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollF.CanvasSize = UDim2.new(0,0,0,listLay.AbsoluteContentSize.Y+6)
end)

-- Word buttons
local buttons, btnDangers = {}, {}

local function MkWordBtn(idx)
	local btn = Instance.new("TextButton", scrollF)
	btn.Name="B"..idx; btn.Size=UDim2.new(1,0,0,26)
	btn.LayoutOrder=idx
	btn.BackgroundColor3 = idx%2==0 and CT.pn or CT.cd
	btn.BackgroundTransparency=0; btn.Text=""
	btn.Font=Enum.Font.GothamMedium; btn.TextSize=10
	btn.TextColor3=CT.t2; btn.TextXAlignment=Enum.TextXAlignment.Left
	btn.BorderSizePixel=0; btn.AutoButtonColor=false; btn.ZIndex=4; btn.Visible=false
	Corner(btn, 5)
	local bSt = Stroke(btn, CT.sk, 1, 0.7)

	local rankL = Instance.new("TextLabel", btn)
	rankL.Name="Rank"; rankL.Size=UDim2.new(0,16,1,0); rankL.Position=UDim2.new(0,3,0,0)
	rankL.BackgroundTransparency=1; rankL.Text=tostring(idx)
	rankL.Font=Enum.Font.GothamBold; rankL.TextSize=7
	rankL.TextColor3=CT.mu; rankL.ZIndex=5
	Re("mu", rankL)

	local wordL = Instance.new("TextLabel", btn)
	wordL.Name="Word"; wordL.Size=UDim2.new(1,-94,1,0); wordL.Position=UDim2.new(0,20,0,0)
	wordL.BackgroundTransparency=1; wordL.Text=""
	wordL.Font=Enum.Font.GothamMedium; wordL.TextSize=10
	wordL.TextColor3=CT.t2; wordL.TextXAlignment=Enum.TextXAlignment.Left; wordL.ZIndex=5
	Re("t2", wordL)

	local dbadge = Instance.new("TextLabel", btn)
	dbadge.Name="D"; dbadge.Size=UDim2.new(0,80,0,15); dbadge.Position=UDim2.new(1,-83,0.5,-7.5)
	dbadge.BackgroundColor3=Color3.fromRGB(40,200,100); dbadge.BackgroundTransparency=0.75
	dbadge.Text=""; dbadge.Font=Enum.Font.GothamBold; dbadge.TextSize=7
	dbadge.TextColor3=Color3.fromRGB(255,255,255); dbadge.BorderSizePixel=0; dbadge.ZIndex=6; dbadge.Visible=false
	Corner(dbadge, 4)

	btn.MouseEnter:Connect(function()
		T(btn,{BackgroundColor3=CT.ch},0.08)
		T(bSt,{Color=CT.ac,Transparency=0.35},0.08)
	end)
	btn.MouseLeave:Connect(function()
		T(btn,{BackgroundColor3=idx%2==0 and CT.pn or CT.cd},0.08)
		T(bSt,{Color=CT.sk,Transparency=0.7},0.08)
	end)

	table.insert(buttons, btn)
	table.insert(btnDangers, dbadge)
end

for i = 1, MAX_BUTTONS do MkWordBtn(i) end

-- ============================================================
-- STRATEGY ENGINE
-- ============================================================
local function GetScore(word)
	local lc=string.sub(word,-1)
	local cnt=LetterWordCount[lc] or 0
	local ov=KILLER_SCORE_OVERRIDE[lc] or 0
	return math.max(ov, cnt==0 and 99999 or (10000-cnt))
end

local function GetDanger(word)
	local lc=string.sub(word,-1)
	local cnt=LetterWordCount[lc] or 0
	local isK=KILLER_SCORE_OVERRIDE[lc] and KILLER_SCORE_OVERRIDE[lc]>=70000
	if cnt==0       then return "☠ IMPOSSIBLE",Color3.fromRGB(255,30,60)
	elseif cnt<=3 or isK then return "💀 KILLER",   Color3.fromRGB(255,50,75)
	elseif cnt<=10  then return "⚠ BAHAYA",   Color3.fromRGB(255,145,30)
	elseif cnt<=30  then return "◈ RISKY",    Color3.fromRGB(235,215,40)
	elseif cnt<=100 then return "● NORMAL",   Color3.fromRGB(90,155,240)
	else                 return "✓ AMAN",     Color3.fromRGB(40,210,110) end
end

local function FindOptions(prefix)
	prefix = string.lower(prefix):gsub("[^a-z]","")
	local list = #prefix>=2 and Prefix2[string.sub(prefix,1,2)] or Prefix1[string.sub(prefix,1,1)]
	if not list then return {} end
	local f, seen = {}, {}
	for _, w in ipairs(list) do
		if string.sub(w,1,#prefix)==prefix and not seen[w] and not MatchUsedWords[w] then
			seen[w]=true; table.insert(f,w)
		end
	end
	if #f==0 then return {} end
	if SortMode=="strategy" then
		table.sort(f, function(a,b) local sA,sB=GetScore(a),GetScore(b); if sA~=sB then return sA>sB end; return #a<#b end)
	else
		table.sort(f, function(a,b) local dA=HardLetters[string.sub(a,-1)] or 0; local dB=HardLetters[string.sub(b,-1)] or 0; if dA~=dB then return dA>dB end; return #a<#b end)
	end
	return f
end

local function MarkUsed(word)
	if not word or #word<3 then return end
	local w=string.lower(word):gsub("%s","")
	if string.match(w,"^[a-z]+$") and not MatchUsedWords[w] then MatchUsedWords[w]=true end
end

UpdatePreview = function()
	if not Ready or not CurrentLetter then return end
	Options = FindOptions(CurrentLetter)
	local usedN=0; for _ in pairs(MatchUsedWords) do usedN=usedN+1 end

	prefixLabel.Text = CurrentLetter:upper()
	prefixLabel.TextColor3 = CT.ac

	if not Options or #Options==0 then
		countLabel.Text="0 kata (🚫"..usedN..")"
		statusLabel.Text="⚠ Tidak ada kata!"; statusLabel.TextColor3=Color3.fromRGB(255,80,100)
		dangerLabel.Visible=true; dangerLabel.Text="💀 MATI"; dangerLabel.BackgroundColor3=Color3.fromRGB(200,30,60)
		for _,b in ipairs(buttons) do b.Visible=false end
		for _,d in ipairs(btnDangers) do d.Visible=false end
		return
	end

	countLabel.Text=#Options.." kata (🚫"..usedN..")"
	statusLabel.Text="✓ "..math.min(#Options,MAX_BUTTONS).."/"..#Options
	statusLabel.TextColor3=CT.ac

	if #Options<=3 then
		dangerLabel.Visible=true; dangerLabel.Text="KRITIS "..#Options
		dangerLabel.BackgroundColor3=Color3.fromRGB(200,30,60); dangerLabel.TextColor3=Color3.fromRGB(255,100,130)
	elseif #Options<=10 then
		dangerLabel.Visible=true; dangerLabel.Text="SEDIKIT "..#Options
		dangerLabel.BackgroundColor3=Color3.fromRGB(180,120,20); dangerLabel.TextColor3=Color3.fromRGB(255,200,80)
	else
		dangerLabel.Visible=false
	end

	for i, btn in ipairs(buttons) do
		local d=btnDangers[i]
		if Options[i] then
			local w=Options[i]
			local wL=btn:FindFirstChild("Word")
			if wL then wL.Text="  "..w end
			btn.Visible=true
			local dtxt,dcol=GetDanger(w)
			d.Text=dtxt; d.BackgroundColor3=dcol; d.Visible=true
		else
			btn.Visible=false; d.Visible=false
		end
	end
end

-- Click
for i, btn in ipairs(buttons) do
	btn.MouseButton1Click:Connect(function()
		local word=Options[i]; if not word then return end
		MarkUsed(word); LastSubmittedWord=word

		local origC = i%2==0 and CT.pn or CT.cd
		T(btn,{BackgroundColor3=CT.ac},0.07)
		task.delay(0.12, function() T(btn,{BackgroundColor3=origC},0.18) end)

		local rem = CurrentLetter and #CurrentLetter>0 and string.sub(word,#CurrentLetter+1) or word
		local box = player.PlayerGui:FindFirstChild("MatchUI",true)
		if box then
			local inp2=box:FindFirstChildWhichIsA("TextBox",true)
			if inp2 then
				inp2.Text=rem
				local dtxt=GetDanger(word)
				Notif("success",word,dtxt,2)
			end
		end
		task.delay(0.22, UpdatePreview)
	end)
end

-- ============================================================
-- LOAD WORDLIST — background tanpa loading screen
-- ============================================================
task.spawn(function()
	statusLabel.Text="⏳ Memuat kamus..."
	local text=""
	local ok, res = pcall(function()
		return game:HttpGet("https://raw.githubusercontent.com/SOBING4413/sambungkata/main/dependescis/kbbi.txt")
	end)
	if ok and res then text=res end

	local wc=0
	for word in string.gmatch(text,"[^\r\n]+") do
		local w=string.lower(word):gsub("%s","")
		if string.match(w,"^[a-z]+$") and #w>=3 then
			local p1=string.sub(w,1,1); local p2=string.sub(w,1,2)
			Prefix1[p1]=Prefix1[p1] or {}; table.insert(Prefix1[p1],w)
			Prefix2[p2]=Prefix2[p2] or {}; table.insert(Prefix2[p2],w)
			wc=wc+1
		end
	end
	for l=string.byte("a"),string.byte("z") do
		local c=string.char(l)
		LetterWordCount[c]=Prefix1[c] and #Prefix1[c] or 0
	end

	Ready=true; AutoAnswerReady=true
	statusLabel.Text="✓ "..wc.." kata"; statusLabel.TextColor3=CT.ac
	Notif("loaded","NightHubX Siap","v4 • "..wc.." kata tersedia",3)
	print("[NightHubX v4] "..wc.." words loaded")
end)

-- ============================================================
-- AUTO ANSWER ENGINE
-- ============================================================
local QWERTY2={
	a={"q","w","s","z"},b={"v","g","h","n"},c={"x","d","f","v"},
	d={"s","e","r","f","c","x"},e={"w","r","d","s"},f={"d","r","t","g","v","c"},
	g={"f","t","y","h","b","v"},h={"g","y","u","j","n","b"},i={"u","o","k","j"},
	j={"h","u","i","k","m","n"},k={"j","i","o","l","m"},l={"k","o","p"},
	m={"n","j","k"},n={"b","h","j","m"},o={"i","p","l","k"},p={"o","l"},
	q={"w","a"},r={"e","t","f","d"},s={"a","w","e","d","x","z"},t={"r","y","g","f"},
	u={"y","i","h","j"},v={"c","f","g","b"},w={"q","e","a","s"},x={"z","s","d","c"},
	y={"t","u","g","h"},z={"a","s","x"},
}
local function TypoC(c) local n=QWERTY2[c]; if n and #n>0 then return n[math.random(1,#n)] end; return c=="a" and "s" or "a" end

local function TypeWord(rem, ts)
	local dl = TYPING.hardDeadline-(tick()-ts)
	if dl<=1.0 then BillboardUpd:FireServer(rem); return true end
	local charD=CustomCharDelay
	local est=#rem*charD+TYPING.submitDelayMax+(TypoEnabled and #rem*0.18*0.34 or 0)
	local sp=est>dl-0.5 and math.max((dl-0.5)/est,0.3) or 1.0
	local typed=""
	for i=1,#rem do
		if not AutoAnswerEnabled then return false end
		if TYPING.hardDeadline-(tick()-ts)<=0.8 then BillboardUpd:FireServer(rem); return true end
		local c=string.sub(rem,i,i)
		if TypoEnabled and math.random()<0.18 and i<#rem then
			local w2=TypoC(c)
			typed=typed..w2; BillboardUpd:FireServer(typed)
			task.wait(math.random(12,38)/100*sp)
			if not AutoAnswerEnabled then return false end
			typed=string.sub(typed,1,#typed-1); BillboardUpd:FireServer(typed)
			task.wait(0.07*sp)
			if not AutoAnswerEnabled then return false end
		end
		typed=typed..c; BillboardUpd:FireServer(typed)
		local d=charD*sp
		if math.random()<TYPING.pauseChance and i<#rem then
			d=d+(TYPING.pauseDelayMin+math.random()*(TYPING.pauseDelayMax-TYPING.pauseDelayMin))*sp
		end
		task.wait(d)
	end
	return true
end

local function DoAutoAnswer(ts)
	if not CurrentLetter or not AutoAnswerEnabled then return end
	Options=FindOptions(CurrentLetter)
	local cands=Options
	if AntiKillerEnabled then
		local safe={}
		for _,w in ipairs(Options) do
			if not KILLER_ENDINGS[string.sub(w,-1)] then table.insert(safe,w) end
		end
		if #safe>0 then cands=safe end
	end
	if not cands or #cands==0 then
		autoAnswerStatusLabel.Text="❌ Tidak ada kata"
		autoAnswerStatusLabel.TextColor3=Color3.fromRGB(255,80,100)
		return
	end
	local word=cands[1]
	MarkUsed(word); LastSubmittedWord=word
	local tags=(AntiKillerEnabled and "🛡" or "")..(TypoEnabled and "⚡" or "")
	autoAnswerStatusLabel.Text='⏳ "'..word..'" '..string.format("%.2f",CustomCharDelay).."s "..tags
	autoAnswerStatusLabel.TextColor3=Color3.fromRGB(120,80,255)

	local td=TYPING.thinkDelayMin+math.random()*(TYPING.thinkDelayMax-TYPING.thinkDelayMin)
	local tl=TYPING.hardDeadline-(tick()-ts)
	if tl<td+2.0 then td=math.max(0.2,tl-2.0) end
	task.wait(td)
	if not AutoAnswerEnabled then return end

	local rem=string.sub(word,#CurrentLetter+1)
	if not TypeWord(rem,ts) or not AutoAnswerEnabled then return end

	local sd=TYPING.submitDelayMin+math.random()*(TYPING.submitDelayMax-TYPING.submitDelayMin)
	local tn=TYPING.hardDeadline-(tick()-ts)
	if tn<sd+0.3 then sd=math.max(0.1,tn-0.3) end
	task.wait(sd)
	if not AutoAnswerEnabled then return end

	SubmitWord:FireServer(rem)
	local lc=string.sub(word,-1)
	local dt=GetDanger(word)
	local t2=string.format("%.1f",tick()-ts)
	autoAnswerStatusLabel.Text='✅ "'..word..'" ('..t2..'s)'
	autoAnswerStatusLabel.TextColor3=Color3.fromRGB(60,210,120)
	Notif("auto","Auto","\"..word..\" → "..lc:upper().." "..dt,2)
	UpdatePreview()
end

local function TriggerAuto()
	if not CurrentLetter or AutoAnswerAnswered or not AutoAnswerEnabled then return end
	AutoAnswerAnswered=true
	local ts=tick()
	task.spawn(function()
		local to=0
		while not AutoAnswerReady and to<10 do task.wait(0.5); to=to+0.5 end
		if AutoAnswerReady and AutoAnswerEnabled then DoAutoAnswer(ts) end
	end)
end

-- ============================================================
-- RESET
-- ============================================================
local function ResetMatch()
	local n=0; for _ in pairs(MatchUsedWords) do n=n+1 end
	MatchUsedWords={}; AutoAnswerRound=0; AutoAnswerAnswered=false; LastSubmittedWord=nil
	if AutoAnswerEnabled then
		autoAnswerStatusLabel.Text="🔄 Reset "..n.." kata"
		autoAnswerStatusLabel.TextColor3=Color3.fromRGB(100,180,255)
	end
	if CurrentLetter then UpdatePreview() end
	Notif("info","Match Baru","Reset "..n.." kata",2)
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
			if AutoAnswerEnabled then
				autoAnswerStatusLabel.Text="⏳ "..CurrentLetter:upper()
				autoAnswerStatusLabel.TextColor3=Color3.fromRGB(120,80,255)
			end
		end
	elseif event=="StartTurn" then
		AutoAnswerRound=AutoAnswerRound+1; AutoAnswerAnswered=false; TriggerAuto()
	elseif event=="Mistake" then
		AutoAnswerAnswered=false
		if AutoAnswerEnabled then
			autoAnswerStatusLabel.Text="🔄 Salah!"; autoAnswerStatusLabel.TextColor3=Color3.fromRGB(255,155,50)
			Notif("wrong","Salah","Coba lagi",1.5)
			UpdatePreview(); task.wait(0.5); TriggerAuto()
		else Notif("wrong","Jawaban Salah","",2) end
	elseif event=="CorrectAnswer" then
		if type(data)=="string" and #data>0 then
			local aw=string.lower(data):gsub("%s","")
			if #aw>=3 then MarkUsed(aw) end
		elseif LastSubmittedWord then MarkUsed(LastSubmittedWord) end
		if AutoAnswerEnabled then Notif("correct","Benar!","Ronde "..AutoAnswerRound,2)
		else Notif("correct","Benar!","",2) end
		UpdatePreview()
	elseif event=="EndTurn" then
		CurrentLetter=nil; AutoAnswerAnswered=false
		if AutoAnswerEnabled then autoAnswerStatusLabel.Text="⏸ Selesai" end
	elseif event=="MatchStart" or event=="NewMatch" or event=="GameStart"
		or event=="MatchEnd" or event=="GameEnd" or event=="EndMatch" then
		ResetMatch()
	end
end)

BillboardUpd.OnClientEvent:Connect(function(pName, wData)
	if not ScriptActive then return end
	if type(wData)=="string" and #wData>=3 then
		local uw=string.lower(wData):gsub("%s","")
		if string.match(uw,"^[a-z]+$") and pName~=player.Name then
			MarkUsed(uw)
			if CurrentLetter then task.defer(UpdatePreview) end
		end
	end
end)

local lastR2=0
task.spawn(function()
	while gui and gui.Parent do
		if AutoAnswerRound>3 and AutoAnswerRound<lastR2 then ResetMatch() end
		lastR2=AutoAnswerRound; task.wait(2)
	end
end)

print("[NightHubX v4] Compact UI loaded. No loading screen.")
