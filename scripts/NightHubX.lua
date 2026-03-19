-- NightHubX v5 | Total UI Redesign
local cloneref = cloneref or function(o) return o end
local RS       = cloneref(game:GetService("ReplicatedStorage"))
local Players  = game:GetService("Players")
local TSvc     = game:GetService("TweenService")
local UIS      = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes      = RS:WaitForChild("Remotes")
local MatchUI      = Remotes:WaitForChild("MatchUI")
local SubmitWord   = Remotes:WaitForChild("SubmitWord")
local BillboardUpd = Remotes:WaitForChild("BillboardUpdate")
local TypeSoundRE  = Remotes:WaitForChild("TypeSound")  -- RemoteEvent suara ketik

local function PlayTypeSound()
	-- FireServer langsung, sudah merupakan RemoteEvent
	TypeSoundRE:FireServer()
end

-- ─────────────────────────────────────────────
-- STATE
-- ─────────────────────────────────────────────
local Prefix1, Prefix2  = {}, {}
local CurrentLetter      = nil
local Ready              = false
local Options            = {}
local ScriptActive       = true
local LetterWordCount    = {}
local SortMode           = "strategy"

local AutoAnswerEnabled  = false
local AutoAnswerReady    = false
local AutoAnswerAnswered = false
local AutoAnswerRound    = 0
local MatchUsedWords     = {}
local LastSubmittedWord  = nil

local TypoEnabled        = false
local CustomCharDelay    = 0.15
local AntiKillerEnabled  = false

local KILLER_SCORE = {x=99999,z=95000,q=90000,v=70000,f=60000,w=50000,y=45000,j=35000,k=30000,g=25000,c=22000}
local KILLER_END   = {x=true,z=true,q=true,v=true,f=true,w=true,y=true}
local HardLetters  = {q=10,x=9,z=8,v=7,f=6,w=5,y=4,k=3,b=2,p=1}
local MAX_BTN      = 40

local TYPING = {
	thinkMin=1.2, thinkMax=3.0,
	pauseChance=0.10, pauseMin=0.2, pauseMax=0.5,
	subMin=0.25, subMax=0.7, deadline=11.0,
}

-- ─────────────────────────────────────────────
-- UTIL
-- ─────────────────────────────────────────────
local function Tw(o,p,d,s,dr)
	local t=TSvc:Create(o,TweenInfo.new(d or .2,s or Enum.EasingStyle.Quint,dr or Enum.EasingDirection.Out),p)
	t:Play(); return t
end
local function TwW(o,p,d,s,dr) Tw(o,p,d,s,dr).Completed:Wait() end
local function RoundC(o,r) Instance.new("UICorner",o).CornerRadius=UDim.new(0,r or 8) end
local function MkStroke(o,c,th,tr)
	local s=Instance.new("UIStroke",o)
	s.Color=c or Color3.new(1,1,1); s.Thickness=th or 1; s.Transparency=tr or .5
	return s
end
local function MkLabel(parent,props)
	local l=Instance.new("TextLabel",parent)
	for k,v in pairs(props) do l[k]=v end
	if not props.BackgroundTransparency then l.BackgroundTransparency=1 end
	return l
end

-- ─────────────────────────────────────────────
-- COLOUR PALETTE
-- ─────────────────────────────────────────────
local C = {
	-- backgrounds
	bg0   = Color3.fromRGB(8,8,14),      -- root
	bg1   = Color3.fromRGB(13,13,21),    -- panel
	bg2   = Color3.fromRGB(18,17,28),    -- card
	bg3   = Color3.fromRGB(24,23,36),    -- card hover
	-- accent (purple-blue)
	acc   = Color3.fromRGB(108,82,246),
	accL  = Color3.fromRGB(140,115,255),
	accD  = Color3.fromRGB(72,54,185),
	-- text
	t1    = Color3.fromRGB(235,232,255),
	t2    = Color3.fromRGB(160,155,200),
	t3    = Color3.fromRGB(100,95,140),
	-- status
	green = Color3.fromRGB(52,211,153),
	red   = Color3.fromRGB(251,74,74),
	yellow= Color3.fromRGB(251,191,36),
	orange= Color3.fromRGB(251,140,36),
	blue  = Color3.fromRGB(96,165,250),
	-- border
	brd   = Color3.fromRGB(38,35,60),
	brdL  = Color3.fromRGB(60,55,90),
}

-- Theme (bisa diganti)
local Themes = {
	{name="Violet", acc=Color3.fromRGB(108,82,246), accL=Color3.fromRGB(148,120,255), bg0=Color3.fromRGB(8,8,14)},
	{name="Rose",   acc=Color3.fromRGB(236,72,153),  accL=Color3.fromRGB(255,120,185), bg0=Color3.fromRGB(14,8,12)},
	{name="Emerald",acc=Color3.fromRGB(16,185,129),  accL=Color3.fromRGB(52,211,153),  bg0=Color3.fromRGB(6,14,11)},
	{name="Amber",  acc=Color3.fromRGB(245,158,11),  accL=Color3.fromRGB(251,191,36),  bg0=Color3.fromRGB(14,12,6)},
	{name="Sky",    acc=Color3.fromRGB(56,189,248),  accL=Color3.fromRGB(125,211,252), bg0=Color3.fromRGB(6,12,16)},
}
local themeIdx = 1

-- Elemen yang berubah saat ganti tema
local ThemeEls = {}  -- {obj, prop, "acc"/"accL"/"bg0"}
local function RegT(obj, prop, key) table.insert(ThemeEls,{obj,prop,key}) end
local function ApplyTheme(t)
	C.acc=t.acc; C.accL=t.accL; C.bg0=t.bg0
	for _,e in ipairs(ThemeEls) do
		local obj,prop,key=e[1],e[2],e[3]
		if key=="acc"  then obj[prop]=C.acc
		elseif key=="accL" then obj[prop]=C.accL
		elseif key=="bg0"  then obj[prop]=C.bg0 end
	end
end

-- ─────────────────────────────────────────────
-- GUI ROOT
-- ─────────────────────────────────────────────
local gui=Instance.new("ScreenGui",PlayerGui)
gui.Name="NightHubX"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.IgnoreGuiInset=true

-- ─────────────────────────────────────────────
-- NOTIFIKASI – slim pill, pojok kiri bawah
-- ─────────────────────────────────────────────
local notifFrame=Instance.new("Frame",gui)
notifFrame.Size=UDim2.new(0,220,1,0)
notifFrame.Position=UDim2.new(0,8,0,0)
notifFrame.BackgroundTransparency=1; notifFrame.ZIndex=500
local nLayout=Instance.new("UIListLayout",notifFrame)
nLayout.VerticalAlignment=Enum.VerticalAlignment.Bottom
nLayout.HorizontalAlignment=Enum.HorizontalAlignment.Left
nLayout.SortOrder=Enum.SortOrder.LayoutOrder
nLayout.Padding=UDim.new(0,4)
local nPad=Instance.new("UIPadding",notifFrame)
nPad.PaddingBottom=UDim.new(0,8)

local nCount=0
local NColors={
	info=C.blue, success=C.green, correct=C.green, error=C.red, wrong=C.red,
	warning=C.yellow, auto=C.acc, loaded=C.acc, unloaded=C.t3,
}
local function Notif(type,title,sub,dur)
	dur=dur or 3; nCount=nCount+1
	local col=NColors[type] or C.acc

	local pill=Instance.new("Frame",notifFrame)
	pill.Name="N"..nCount; pill.LayoutOrder=-nCount
	pill.Size=UDim2.new(1,0,0,0)
	pill.BackgroundColor3=C.bg1; pill.BorderSizePixel=0
	pill.ClipsDescendants=true; pill.ZIndex=501
	RoundC(pill,6); MkStroke(pill,col,1,0.4)

	local bar=Instance.new("Frame",pill)
	bar.Size=UDim2.new(0,2,1,0); bar.BackgroundColor3=col; bar.BorderSizePixel=0; bar.ZIndex=502

	local tL=MkLabel(pill,{
		Size=UDim2.new(1,-10,0,14),Position=UDim2.new(0,8,0,4),
		Text=title,Font=Enum.Font.GothamBold,TextSize=10,
		TextColor3=C.t1,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=502,
	})
	local hasS = sub and sub~=""
	if hasS then
		MkLabel(pill,{
			Size=UDim2.new(1,-10,0,11),Position=UDim2.new(0,8,0,18),
			Text=sub,Font=Enum.Font.Gotham,TextSize=8,
			TextColor3=C.t2,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=502,
		})
	end

	local h=hasS and 34 or 22
	Tw(pill,{Size=UDim2.new(1,0,0,h)},.2,Enum.EasingStyle.Back)

	local pBg=Instance.new("Frame",pill)
	pBg.Size=UDim2.new(1,0,0,2); pBg.Position=UDim2.new(0,0,1,-2)
	pBg.BackgroundColor3=C.brd; pBg.BorderSizePixel=0; pBg.ZIndex=502
	local pFl=Instance.new("Frame",pBg)
	pFl.Size=UDim2.new(1,0,1,0); pFl.BackgroundColor3=col; pFl.BorderSizePixel=0; pFl.ZIndex=503
	Tw(pFl,{Size=UDim2.new(0,0,1,0)},dur,Enum.EasingStyle.Linear)

	local gone=false
	local function bye()
		if gone then return end; gone=true
		Tw(pill,{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1},.15,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
		task.wait(.18); pill:Destroy()
	end
	task.delay(dur,bye)
end

-- ─────────────────────────────────────────────
-- MAIN WINDOW  560 × 400
-- ─────────────────────────────────────────────
local W,H = 560,400
local TBH  = 38   -- topbar height

local win=Instance.new("Frame",gui)
win.Name="NHX"; win.Size=UDim2.new(0,0,0,0)
win.Position=UDim2.new(.5,0,.5,0)
win.BackgroundColor3=C.bg0; win.BorderSizePixel=0
win.Active=true; win.Draggable=false; win.ClipsDescendants=true; win.ZIndex=2
RoundC(win,10)
local winStroke=MkStroke(win,C.brd,1,.1)

-- popup animasi masuk
task.defer(function()
	Tw(win,{Size=UDim2.new(0,W,0,H),Position=UDim2.new(.5,-W/2,.5,-H/2)},.38,Enum.EasingStyle.Back)
end)

-- ── DRAG dari topbar ──
local drag,dS,wS=false,Vector2.new(),UDim2.new()
UIS.InputChanged:Connect(function(i)
	if not drag then return end
	if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
	local d=i.Position-dS
	win.Position=UDim2.new(wS.X.Scale,wS.X.Offset+d.X,wS.Y.Scale,wS.Y.Offset+d.Y)
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end
end)

-- ── TOPBAR ──
local tb=Instance.new("Frame",win)
tb.Name="Topbar"; tb.Size=UDim2.new(1,0,0,TBH)
tb.BackgroundColor3=C.bg1; tb.BorderSizePixel=0; tb.ZIndex=10
RoundC(tb,10)
-- fill lower radius
local tbF=Instance.new("Frame",tb)
tbF.Size=UDim2.new(1,0,0,12); tbF.Position=UDim2.new(0,0,1,-12)
tbF.BackgroundColor3=C.bg1; tbF.BorderSizePixel=0; tbF.ZIndex=10

-- separator line bawah topbar
local tbLine=Instance.new("Frame",win)
tbLine.Size=UDim2.new(1,0,0,1); tbLine.Position=UDim2.new(0,0,0,TBH)
tbLine.BackgroundColor3=C.brd; tbLine.BorderSizePixel=0; tbLine.ZIndex=11

-- Drag dari topbar
tb.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		drag=true; dS=i.Position; wS=win.Position
		i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
	end
end)

-- Icon dot merah-kuning-hijau (ala macOS, dekorasi)
local function DotBtn(x,col,click)
	local d=Instance.new("TextButton",tb)
	d.Size=UDim2.new(0,11,0,11); d.Position=UDim2.new(0,x,0.5,-5.5)
	d.BackgroundColor3=col; d.Text=""; d.BorderSizePixel=0; d.AutoButtonColor=false; d.ZIndex=12
	RoundC(d,6)
	d.MouseButton1Click:Connect(click)
	return d
end

local dotClose=DotBtn(10,Color3.fromRGB(255,95,86),function()
	ScriptActive=false; AutoAnswerEnabled=false
	Tw(win,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(.5,0,.5,0)},.3,Enum.EasingStyle.Back,Enum.EasingDirection.In)
	task.wait(.35); gui:Destroy()
end)
local dotMin=DotBtn(25,Color3.fromRGB(255,189,68),function()
	local isMin = win.Size.Y.Offset<=TBH+2
	Tw(win,{Size=UDim2.new(0,W,0,isMin and H or TBH+1)},.28,Enum.EasingStyle.Quint)
end)
local dotTheme=DotBtn(40,Color3.fromRGB(39,201,63),function()
	themeIdx=themeIdx%#Themes+1
	local t=Themes[themeIdx]
	ApplyTheme(t)
	-- update elemen manual
	win.BackgroundColor3=C.bg0
	Notif("info","Tema: "..t.name,"",1.5)
end)

-- Title
MkLabel(tb,{
	Size=UDim2.new(0,200,1,0),Position=UDim2.new(0,62,0,0),
	Text="NightHubX",Font=Enum.Font.GothamBlack,TextSize=13,
	TextColor3=C.t1,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=11,
})
MkLabel(tb,{
	Size=UDim2.new(0,120,1,0),Position=UDim2.new(0,174,0,0),
	Text="v5",Font=Enum.Font.Gotham,TextSize=10,
	TextColor3=C.t3,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=11,
})

-- ─────────────────────────────────────────────
-- LAYOUT: kiri (info+kontrol) | kanan (word list)
-- ─────────────────────────────────────────────
local CY  = TBH+1   -- content Y start
local LW  = 170     -- lebar panel kiri
local GAP = 5

-- ══════════════════════════════════════════════
-- PANEL KIRI
-- ══════════════════════════════════════════════
local leftP=Instance.new("Frame",win)
leftP.Size=UDim2.new(0,LW,1,-CY-GAP)
leftP.Position=UDim2.new(0,GAP,0,CY)
leftP.BackgroundColor3=C.bg1; leftP.BorderSizePixel=0; leftP.ZIndex=3
RoundC(leftP,8); MkStroke(leftP,C.brd,1,.3)

-- helper label di leftP
local function LL(y,txt,fs,col,bold)
	return MkLabel(leftP,{
		Size=UDim2.new(1,-12,0,fs+2),Position=UDim2.new(0,6,0,y),
		Text=txt,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
		TextSize=fs,TextColor3=col or C.t2,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4,
	})
end

-- ── Huruf aktif (besar) ──
local prefBig=MkLabel(leftP,{
	Size=UDim2.new(1,-12,0,48),Position=UDim2.new(0,6,0,6),
	Text="—",Font=Enum.Font.GothamBlack,TextSize=40,
	TextColor3=C.acc,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4,
})
RegT(prefBig,"TextColor3","acc")

local prefSub=LL(50,"0 kata tersedia",8,C.t3,false)

local dangerBadge=Instance.new("TextLabel",leftP)
dangerBadge.Size=UDim2.new(0,80,0,16); dangerBadge.Position=UDim2.new(1,-84,0,10)
dangerBadge.BackgroundColor3=C.red; dangerBadge.BackgroundTransparency=0.7
dangerBadge.Text=""; dangerBadge.Font=Enum.Font.GothamBold; dangerBadge.TextSize=7
dangerBadge.TextColor3=Color3.fromRGB(255,130,130); dangerBadge.BorderSizePixel=0
dangerBadge.ZIndex=5; dangerBadge.Visible=false
RoundC(dangerBadge,4)

-- divider
local function HDivL(y)
	local d=Instance.new("Frame",leftP)
	d.Size=UDim2.new(1,-12,0,1); d.Position=UDim2.new(0,6,0,y)
	d.BackgroundColor3=C.brd; d.BorderSizePixel=0; d.ZIndex=4
end
HDivL(64)

local statusLabel=LL(68,"⏳ Memuat...",8,C.acc,true)

-- ── section label helper ──
local function SecLabel(y,txt)
	return MkLabel(leftP,{
		Size=UDim2.new(1,-12,0,12),Position=UDim2.new(0,6,0,y),
		Text=txt,Font=Enum.Font.GothamBold,TextSize=7,
		TextColor3=C.t3,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4,
	})
end

HDivL(82)
SecLabel(86,"AUTO ANSWER")

-- ── toggle helper ──
-- Membuat baris toggle ON/OFF dengan track kecil
local function MkTog(yPos, labelTxt, onColor)
	local row=Instance.new("TextButton",leftP)
	row.Size=UDim2.new(1,-12,0,20); row.Position=UDim2.new(0,6,0,yPos)
	row.BackgroundColor3=C.bg2; row.Text=""; row.BorderSizePixel=0
	row.AutoButtonColor=false; row.ZIndex=5; RoundC(row,5)
	local rStr=MkStroke(row,C.brd,1,.5)

	local track=Instance.new("Frame",row)
	track.Size=UDim2.new(0,26,0,13); track.Position=UDim2.new(0,4,0.5,-6.5)
	track.BackgroundColor3=Color3.fromRGB(35,30,55); track.BorderSizePixel=0; track.ZIndex=6
	RoundC(track,6)
	local knob=Instance.new("Frame",track)
	knob.Size=UDim2.new(0,9,0,9); knob.Position=UDim2.new(0,2,0.5,-4.5)
	knob.BackgroundColor3=C.t3; knob.BorderSizePixel=0; knob.ZIndex=7; RoundC(knob,5)

	local lbl=MkLabel(row,{
		Size=UDim2.new(1,-36,1,0),Position=UDim2.new(0,34,0,0),
		Text=labelTxt,Font=Enum.Font.GothamBold,TextSize=8,
		TextColor3=C.t3,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,
	})

	row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=C.bg3},.08) end)
	row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=C.bg2},.08) end)

	local function SetOn(on)
		if on then
			Tw(track,{BackgroundColor3=onColor},.18)
			Tw(knob,{Position=UDim2.new(1,-11,0.5,-4.5),BackgroundColor3=Color3.fromRGB(255,255,255)},.18,Enum.EasingStyle.Back)
			Tw(rStr,{Color=onColor,Transparency=.25},.15)
			lbl.TextColor3=onColor
		else
			Tw(track,{BackgroundColor3=Color3.fromRGB(35,30,55)},.18)
			Tw(knob,{Position=UDim2.new(0,2,0.5,-4.5),BackgroundColor3=C.t3},.18,Enum.EasingStyle.Back)
			Tw(rStr,{Color=C.brd,Transparency=.5},.15)
			lbl.TextColor3=C.t3
		end
	end
	return row,SetOn,lbl
end

-- Auto toggle
local autoBtn,SetAutoV,autoLbl=MkTog(100,"OFF",C.acc)
RegT(C,"acc","acc")  -- placeholder, handle manual

local autoGlow=Instance.new("Frame",leftP)
autoGlow.Size=UDim2.new(1,-10,0,22); autoGlow.Position=UDim2.new(0,5,0,99)
autoGlow.BackgroundColor3=C.acc; autoGlow.BackgroundTransparency=1
autoGlow.BorderSizePixel=0; autoGlow.ZIndex=3; RoundC(autoGlow,6)

task.spawn(function()
	while autoGlow and autoGlow.Parent do
		if AutoAnswerEnabled then
			TwW(autoGlow,{BackgroundTransparency=0.88},1.1,Enum.EasingStyle.Sine)
			TwW(autoGlow,{BackgroundTransparency=0.96},1.1,Enum.EasingStyle.Sine)
		else task.wait(.5) end
	end
end)

local autoStat=MkLabel(leftP,{
	Size=UDim2.new(1,-12,0,10),Position=UDim2.new(0,6,0,122),
	Text="",Font=Enum.Font.Gotham,TextSize=8,
	TextColor3=C.t3,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4,
})
local autoAnswerStatusLabel = autoStat  -- alias yang dipakai engine

HDivL(134)
SecLabel(138,"DELAY KETIK")

-- ── Slider delay ──
local DMIN,DMAX=0.1,3.0
local sliderRow=Instance.new("Frame",leftP)
sliderRow.Size=UDim2.new(1,-12,0,26); sliderRow.Position=UDim2.new(0,6,0,152)
sliderRow.BackgroundTransparency=1; sliderRow.BorderSizePixel=0; sliderRow.ZIndex=4

local slValL=MkLabel(sliderRow,{
	Size=UDim2.new(1,0,0,12),Position=UDim2.new(0,0,0,0),
	Text="0.15s",Font=Enum.Font.GothamBold,TextSize=9,
	TextColor3=C.acc,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=5,
})
RegT(slValL,"TextColor3","acc")

local slTrk=Instance.new("Frame",sliderRow)
slTrk.Size=UDim2.new(1,0,0,4); slTrk.Position=UDim2.new(0,0,0,16)
slTrk.BackgroundColor3=C.bg3; slTrk.BorderSizePixel=0; slTrk.ZIndex=5; RoundC(slTrk,2)

local slFil=Instance.new("Frame",slTrk)
slFil.Size=UDim2.new(0.017,0,1,0); slFil.BackgroundColor3=C.acc
slFil.BorderSizePixel=0; slFil.ZIndex=6; RoundC(slFil,2)
RegT(slFil,"BackgroundColor3","acc")

local slKnob=Instance.new("Frame",slTrk)
slKnob.Size=UDim2.new(0,10,0,10); slKnob.Position=UDim2.new(0.017,-5,0.5,-5)
slKnob.BackgroundColor3=Color3.fromRGB(220,215,255); slKnob.BorderSizePixel=0; slKnob.ZIndex=7; RoundC(slKnob,5)
MkStroke(slKnob,C.acc,1.5,.2)

local function SetSlider(pct)
	pct=math.clamp(pct,0,1)
	CustomCharDelay=math.floor((DMIN+pct*(DMAX-DMIN))*100+.5)/100
	slFil.Size=UDim2.new(pct,0,1,0)
	slKnob.Position=UDim2.new(pct,-5,0.5,-5)
	slValL.Text=string.format("%.2fs",CustomCharDelay)
	slFil.BackgroundColor3=Color3.fromRGB(math.floor(80+pct*160),math.floor(80+(1-pct)*120),255)
end
SetSlider((CustomCharDelay-DMIN)/(DMAX-DMIN))

local sDrag=false
slTrk.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=true end end)
slTrk.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=false end end)
UIS.InputChanged:Connect(function(i)
	if not sDrag then return end
	if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
	SetSlider((i.Position.X-slTrk.AbsolutePosition.X)/slTrk.AbsoluteSize.X)
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=false end
end)

HDivL(182)
SecLabel(186,"OPSI")

-- Typo toggle
local typoBtn,SetTypoV,typoLbl=MkTog(200,"Typo: OFF",C.yellow)
typoBtn.MouseButton1Click:Connect(function()
	TypoEnabled=not TypoEnabled; SetTypoV(TypoEnabled)
	typoLbl.Text=TypoEnabled and "Typo: ON" or "Typo: OFF"
	Notif(TypoEnabled and "warning" or "info",TypoEnabled and "Typo ON" or "Typo OFF",TypoEnabled and "Salah→hapus→benar" or "",2)
end)

-- Anti Killer toggle
local akBtn,SetAKV,akLbl=MkTog(224,"Anti Killer: OFF",C.green)
akBtn.MouseButton1Click:Connect(function()
	AntiKillerEnabled=not AntiKillerEnabled; SetAKV(AntiKillerEnabled)
	akLbl.Text=AntiKillerEnabled and "Anti Killer: ON" or "Anti Killer: OFF"
	Notif(AntiKillerEnabled and "success" or "info",AntiKillerEnabled and "Anti Killer ON" or "Anti Killer OFF",AntiKillerEnabled and "Skip x/z/q/v/f/w/y" or "",2)
end)

-- Sort toggle
local sortBtn,SetSortV,sortLbl=MkTog(248,"Sort: Strategy+",C.accL)
local isStrat=true; SetSortV(true)
sortBtn.MouseButton1Click:Connect(function()
	isStrat=not isStrat; SortMode=isStrat and "strategy" or "difficulty"
	SetSortV(isStrat)
	sortLbl.Text=isStrat and "Sort: Strategy+" or "Sort: Difficulty"
	if UpdatePreview then UpdatePreview() end
end)

HDivL(272)

-- Version badge
MkLabel(leftP,{
	Size=UDim2.new(1,-12,0,11),Position=UDim2.new(0,6,1,-14),
	Text="NightHubX v5 • DupFilter ON",Font=Enum.Font.Gotham,TextSize=7,
	TextColor3=C.t3,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=4,
})

-- ══════════════════════════════════════════════
-- PANEL KANAN — WORD LIST
-- ══════════════════════════════════════════════
local RX=LW+GAP*2
local rightP=Instance.new("Frame",win)
rightP.Size=UDim2.new(1,-(RX+GAP),1,-CY-GAP)
rightP.Position=UDim2.new(0,RX,0,CY)
rightP.BackgroundTransparency=1; rightP.BorderSizePixel=0; rightP.ZIndex=3

-- column header strip
local colHdr=Instance.new("Frame",rightP)
colHdr.Size=UDim2.new(1,0,0,22); colHdr.BackgroundColor3=C.bg2
colHdr.BackgroundTransparency=0; colHdr.BorderSizePixel=0; colHdr.ZIndex=4
RoundC(colHdr,6); MkStroke(colHdr,C.brd,1,.4)

MkLabel(colHdr,{
	Size=UDim2.new(1,-90,1,0),Position=UDim2.new(0,10,0,0),
	Text="KATA",Font=Enum.Font.GothamBold,TextSize=8,
	TextColor3=C.t3,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5,
})
MkLabel(colHdr,{
	Size=UDim2.new(0,86,1,0),Position=UDim2.new(1,-88,0,0),
	Text="BAHAYA",Font=Enum.Font.GothamBold,TextSize=8,
	TextColor3=C.t3,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=5,
})

-- scroll
local scrollF=Instance.new("ScrollingFrame",rightP)
scrollF.Size=UDim2.new(1,0,1,-25); scrollF.Position=UDim2.new(0,0,0,24)
scrollF.BackgroundColor3=C.bg1; scrollF.BackgroundTransparency=0
scrollF.BorderSizePixel=0; scrollF.ZIndex=3
scrollF.ScrollBarThickness=3; scrollF.ScrollBarImageColor3=C.acc
scrollF.CanvasSize=UDim2.new(0,0,0,0)
RoundC(scrollF,7); MkStroke(scrollF,C.brd,1,.35)

local listLay=Instance.new("UIListLayout",scrollF)
listLay.SortOrder=Enum.SortOrder.LayoutOrder; listLay.Padding=UDim.new(0,2)
local lPad=Instance.new("UIPadding",scrollF)
lPad.PaddingTop=UDim.new(0,3); lPad.PaddingBottom=UDim.new(0,3)
lPad.PaddingLeft=UDim.new(0,3); lPad.PaddingRight=UDim.new(0,3)

listLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollF.CanvasSize=UDim2.new(0,0,0,listLay.AbsoluteContentSize.Y+6)
end)

local buttons,btnDangers={},{}
local function MkWordBtn(idx)
	local btn=Instance.new("TextButton",scrollF)
	btn.Name="B"..idx; btn.Size=UDim2.new(1,0,0,26); btn.LayoutOrder=idx
	btn.BackgroundColor3=idx%2==0 and C.bg1 or C.bg2
	btn.Text=""; btn.Font=Enum.Font.GothamMedium; btn.TextSize=11
	btn.TextColor3=C.t2; btn.TextXAlignment=Enum.TextXAlignment.Left
	btn.BorderSizePixel=0; btn.AutoButtonColor=false; btn.ZIndex=4; btn.Visible=false
	RoundC(btn,5)
	local bSt=MkStroke(btn,C.brd,1,.7)

	-- rank number
	local rk=MkLabel(btn,{
		Size=UDim2.new(0,16,1,0),Position=UDim2.new(0,3,0,0),
		Text=tostring(idx),Font=Enum.Font.GothamBold,TextSize=7,
		TextColor3=C.t3,ZIndex=5,
	})

	local wdL=MkLabel(btn,{
		Name="Word",Size=UDim2.new(1,-96,1,0),Position=UDim2.new(0,20,0,0),
		Text="",Font=Enum.Font.GothamMedium,TextSize=11,
		TextColor3=C.t2,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5,
	})

	local dbg=Instance.new("TextLabel",btn)
	dbg.Name="D"; dbg.Size=UDim2.new(0,82,0,15); dbg.Position=UDim2.new(1,-85,0.5,-7.5)
	dbg.BackgroundColor3=C.green; dbg.BackgroundTransparency=0.72
	dbg.Text=""; dbg.Font=Enum.Font.GothamBold; dbg.TextSize=7
	dbg.TextColor3=Color3.fromRGB(255,255,255); dbg.BorderSizePixel=0; dbg.ZIndex=6; dbg.Visible=false
	RoundC(dbg,4)

	btn.MouseEnter:Connect(function()
		Tw(btn,{BackgroundColor3=C.bg3},.08)
		Tw(bSt,{Color=C.accL,Transparency=.35},.08)
	end)
	btn.MouseLeave:Connect(function()
		Tw(btn,{BackgroundColor3=idx%2==0 and C.bg1 or C.bg2},.08)
		Tw(bSt,{Color=C.brd,Transparency=.7},.08)
	end)

	table.insert(buttons,btn); table.insert(btnDangers,dbg)
end
for i=1,MAX_BTN do MkWordBtn(i) end

-- ─────────────────────────────────────────────
-- AUTO TOGGLE HANDLER (setelah semua label siap)
-- ─────────────────────────────────────────────
autoBtn.MouseButton1Click:Connect(function()
	AutoAnswerEnabled=not AutoAnswerEnabled
	SetAutoV(AutoAnswerEnabled)
	autoLbl.Text=AutoAnswerEnabled and "ON" or "OFF"
	if AutoAnswerEnabled then
		autoGlow.BackgroundColor3=C.acc
		Tw(autoGlow,{BackgroundTransparency=0.88},.25)
		autoStat.Text="⏳ Menunggu giliran..."
		autoStat.TextColor3=C.acc
		Notif("auto","Auto Answer ON","DupFilter aktif",2.5)
	else
		Tw(autoGlow,{BackgroundTransparency=1},.25)
		autoStat.Text=""
		Notif("info","Auto Answer OFF","",2)
	end
end)

-- ─────────────────────────────────────────────
-- STRATEGY ENGINE
-- ─────────────────────────────────────────────
local function GetScore(w)
	local lc=string.sub(w,-1)
	local cnt=LetterWordCount[lc] or 0
	local ov=KILLER_SCORE[lc] or 0
	return math.max(ov,cnt==0 and 99999 or (10000-cnt))
end

local function GetDanger(w)
	local lc=string.sub(w,-1)
	local cnt=LetterWordCount[lc] or 0
	local isK=KILLER_SCORE[lc] and KILLER_SCORE[lc]>=70000
	if cnt==0          then return "☠ IMPOSSIBLE",C.red
	elseif cnt<=3 or isK then return "💀 KILLER",   Color3.fromRGB(255,60,80)
	elseif cnt<=10     then return "⚠ BAHAYA",    C.orange
	elseif cnt<=30     then return "◈ RISKY",     C.yellow
	elseif cnt<=100    then return "● NORMAL",    C.blue
	else                    return "✓ AMAN",      C.green end
end

local function FindOptions(prefix)
	prefix=string.lower(prefix):gsub("[^a-z]","")
	local list=#prefix>=2 and Prefix2[string.sub(prefix,1,2)] or Prefix1[string.sub(prefix,1,1)]
	if not list then return {} end
	local f,seen={},{}
	for _,w in ipairs(list) do
		if string.sub(w,1,#prefix)==prefix and not seen[w] and not MatchUsedWords[w] then
			seen[w]=true; table.insert(f,w)
		end
	end
	if #f==0 then return {} end
	if SortMode=="strategy" then
		table.sort(f,function(a,b) local sA,sB=GetScore(a),GetScore(b); if sA~=sB then return sA>sB end; return #a<#b end)
	else
		table.sort(f,function(a,b)
			local dA=HardLetters[string.sub(a,-1)] or 0
			local dB=HardLetters[string.sub(b,-1)] or 0
			if dA~=dB then return dA>dB end; return #a<#b
		end)
	end
	return f
end

local function MarkUsed(w)
	if not w or #w<3 then return end
	local s=string.lower(w):gsub("%s","")
	if string.match(s,"^[a-z]+$") and not MatchUsedWords[s] then MatchUsedWords[s]=true end
end

UpdatePreview=function()
	if not Ready or not CurrentLetter then return end
	Options=FindOptions(CurrentLetter)
	local usedN=0; for _ in pairs(MatchUsedWords) do usedN=usedN+1 end

	prefBig.Text=CurrentLetter:upper()
	prefBig.TextColor3=C.acc

	if not Options or #Options==0 then
		prefSub.Text="0 kata (🚫"..usedN..")"
		statusLabel.Text="⚠ Tidak ada kata!"; statusLabel.TextColor3=C.red
		dangerBadge.Visible=true; dangerBadge.Text="MATI"; dangerBadge.BackgroundColor3=C.red
		for _,b in ipairs(buttons) do b.Visible=false end
		for _,d in ipairs(btnDangers) do d.Visible=false end
		return
	end

	prefSub.Text=#Options.." kata (🚫"..usedN..")"
	statusLabel.Text="✓ "..math.min(#Options,MAX_BTN).."/"..#Options
	statusLabel.TextColor3=C.green

	if #Options<=3 then
		dangerBadge.Visible=true; dangerBadge.Text="KRITIS"
		dangerBadge.BackgroundColor3=C.red; dangerBadge.TextColor3=Color3.fromRGB(255,130,130)
	elseif #Options<=10 then
		dangerBadge.Visible=true; dangerBadge.Text="SEDIKIT"
		dangerBadge.BackgroundColor3=C.orange; dangerBadge.TextColor3=Color3.fromRGB(255,210,100)
	else
		dangerBadge.Visible=false
	end

	for i,btn in ipairs(buttons) do
		local d=btnDangers[i]
		if Options[i] then
			local ww=Options[i]
			local wL=btn:FindFirstChild("Word"); if wL then wL.Text="  "..ww end
			btn.Visible=true
			local dtxt,dcol=GetDanger(ww)
			d.Text=dtxt; d.BackgroundColor3=dcol; d.Visible=true
		else
			btn.Visible=false; d.Visible=false
		end
	end
end

-- button click
for i,btn in ipairs(buttons) do
	btn.MouseButton1Click:Connect(function()
		local word=Options[i]; if not word then return end
		MarkUsed(word); LastSubmittedWord=word
		local orig=i%2==0 and C.bg1 or C.bg2
		Tw(btn,{BackgroundColor3=C.acc},.07)
		task.delay(.12,function() Tw(btn,{BackgroundColor3=orig},.18) end)
		local rem=CurrentLetter and #CurrentLetter>0 and string.sub(word,#CurrentLetter+1) or word
		local box=player.PlayerGui:FindFirstChild("MatchUI",true)
		if box then
			local inp=box:FindFirstChildWhichIsA("TextBox",true)
			if inp then
				inp.Text=rem
				Notif("success",word,GetDanger(word),2)
			end
		end
		task.delay(.22,UpdatePreview)
	end)
end

-- ─────────────────────────────────────────────
-- LOAD WORDLIST (background)
-- ─────────────────────────────────────────────
task.spawn(function()
	statusLabel.Text="⏳ Memuat kamus..."
	local text=""
	local ok,res=pcall(function()
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
	statusLabel.Text="✓ "..wc.." kata"
	statusLabel.TextColor3=C.green
	Notif("loaded","NightHubX Siap","v5 · "..wc.." kata",3)
	print("[NightHubX v5] "..wc.." kata dimuat")
end)

-- ─────────────────────────────────────────────
-- AUTO ANSWER ENGINE
-- ─────────────────────────────────────────────
local QWERTY={
	a={"q","w","s","z"},b={"v","g","h","n"},c={"x","d","f","v"},
	d={"s","e","r","f","c","x"},e={"w","r","d","s"},f={"d","r","t","g","v","c"},
	g={"f","t","y","h","b","v"},h={"g","y","u","j","n","b"},i={"u","o","k","j"},
	j={"h","u","i","k","m","n"},k={"j","i","o","l","m"},l={"k","o","p"},
	m={"n","j","k"},n={"b","h","j","m"},o={"i","p","l","k"},p={"o","l"},
	q={"w","a"},r={"e","t","f","d"},s={"a","w","e","d","x","z"},t={"r","y","g","f"},
	u={"y","i","h","j"},v={"c","f","g","b"},w={"q","e","a","s"},x={"z","s","d","c"},
	y={"t","u","g","h"},z={"a","s","x"},
}
local function TypoC(c) local n=QWERTY[c]; if n and #n>0 then return n[math.random(1,#n)] end; return c=="a" and "s" or "a" end

-- Rate limiter suara — game biasanya throttle kalau terlalu sering
local lastSound=0
local function PlaySound()
	local now=tick()
	if now-lastSound>=0.05 then   -- minimal 50ms antar suara
		lastSound=now
		TypeSoundRE:FireServer()
	end
end

local function TypeWord(rem,ts)
	local dl=TYPING.deadline-(tick()-ts)
	if dl<=1.0 then BillboardUpd:FireServer(rem); return true end
	local charD=CustomCharDelay
	local est=#rem*charD+TYPING.subMax+(TypoEnabled and #rem*0.18*0.34 or 0)
	local sp=est>dl-0.5 and math.max((dl-0.5)/est,0.3) or 1.0
	local typed=""
	for i=1,#rem do
		if not AutoAnswerEnabled then return false end
		if TYPING.deadline-(tick()-ts)<=0.8 then BillboardUpd:FireServer(rem); return true end
		local c=string.sub(rem,i,i)
		if TypoEnabled and math.random()<0.18 and i<#rem then
			local w2=TypoC(c)
			typed=typed..w2; BillboardUpd:FireServer(typed); PlaySound()
			task.wait(math.random(12,38)/100*sp)
			if not AutoAnswerEnabled then return false end
			typed=string.sub(typed,1,#typed-1); BillboardUpd:FireServer(typed)
			task.wait(0.07*sp)
			if not AutoAnswerEnabled then return false end
		end
		typed=typed..c; BillboardUpd:FireServer(typed); PlaySound()
		local d=charD*sp
		if math.random()<TYPING.pauseChance and i<#rem then
			d=d+(TYPING.pauseMin+math.random()*(TYPING.pauseMax-TYPING.pauseMin))*sp
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
			if not KILLER_END[string.sub(w,-1)] then table.insert(safe,w) end
		end
		if #safe>0 then cands=safe end
	end
	if not cands or #cands==0 then
		autoStat.Text="❌ Tidak ada kata"; autoStat.TextColor3=C.red; return
	end
	local word=cands[1]; MarkUsed(word); LastSubmittedWord=word
	local tags=(AntiKillerEnabled and "🛡" or "")..(TypoEnabled and "⚡" or "")
	autoStat.Text='⏳ "'..word..'" '..string.format("%.2f",CustomCharDelay).."s "..tags
	autoStat.TextColor3=C.acc

	local td=TYPING.thinkMin+math.random()*(TYPING.thinkMax-TYPING.thinkMin)
	local tl=TYPING.deadline-(tick()-ts)
	if tl<td+2.0 then td=math.max(0.2,tl-2.0) end
	task.wait(td); if not AutoAnswerEnabled then return end

	local rem=string.sub(word,#CurrentLetter+1)
	if not TypeWord(rem,ts) or not AutoAnswerEnabled then return end

	local sd=TYPING.subMin+math.random()*(TYPING.subMax-TYPING.subMin)
	local tn=TYPING.deadline-(tick()-ts)
	if tn<sd+0.3 then sd=math.max(0.1,tn-0.3) end
	task.wait(sd); if not AutoAnswerEnabled then return end

	SubmitWord:FireServer(rem)
	local lc=string.sub(word,-1)
	local dt=GetDanger(word)
	local t2=string.format("%.1f",tick()-ts)
	autoStat.Text='✅ "'..word..'" ('..t2..'s)'; autoStat.TextColor3=C.green
	Notif("auto","Auto",'"'..word..'" → '..lc:upper()..' '..dt,2)
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

-- ─────────────────────────────────────────────
-- RESET MATCH
-- ─────────────────────────────────────────────
local function ResetMatch()
	local n=0; for _ in pairs(MatchUsedWords) do n=n+1 end
	MatchUsedWords={}; AutoAnswerRound=0; AutoAnswerAnswered=false; LastSubmittedWord=nil
	if AutoAnswerEnabled then autoStat.Text="🔄 Reset "..n.." kata"; autoStat.TextColor3=C.blue end
	if CurrentLetter then UpdatePreview() end
	Notif("info","Match Baru","Reset "..n.." kata",2)
end

-- ─────────────────────────────────────────────
-- EVENTS
-- ─────────────────────────────────────────────
MatchUI.OnClientEvent:Connect(function(event,data)
	if not ScriptActive then return end
	if event=="UpdateServerLetter" then
		if type(data)=="string" then
			CurrentLetter=string.lower(data):gsub("[^a-z]","")
			AutoAnswerAnswered=false; UpdatePreview()
			if AutoAnswerEnabled then autoStat.Text="⏳ "..CurrentLetter:upper(); autoStat.TextColor3=C.acc end
		end
	elseif event=="StartTurn" then
		AutoAnswerRound=AutoAnswerRound+1; AutoAnswerAnswered=false; TriggerAuto()
	elseif event=="Mistake" then
		AutoAnswerAnswered=false
		if AutoAnswerEnabled then
			autoStat.Text="🔄 Salah!"; autoStat.TextColor3=C.orange
			Notif("wrong","Salah","Coba lagi",1.5)
			UpdatePreview(); task.wait(0.5); TriggerAuto()
		else Notif("wrong","Jawaban Salah","",2) end
	elseif event=="CorrectAnswer" then
		if type(data)=="string" and #data>0 then
			local aw=string.lower(data):gsub("%s",""); if #aw>=3 then MarkUsed(aw) end
		elseif LastSubmittedWord then MarkUsed(LastSubmittedWord) end
		if AutoAnswerEnabled then Notif("correct","Benar!","Ronde "..AutoAnswerRound,2)
		else Notif("correct","Benar!","",2) end
		UpdatePreview()
	elseif event=="EndTurn" then
		CurrentLetter=nil; AutoAnswerAnswered=false
		if AutoAnswerEnabled then autoStat.Text="⏸ Selesai" end
	elseif event=="MatchStart" or event=="NewMatch" or event=="GameStart"
		or event=="MatchEnd" or event=="GameEnd" or event=="EndMatch" then
		ResetMatch()
	end
end)

BillboardUpd.OnClientEvent:Connect(function(pName,wData)
	if not ScriptActive then return end
	if type(wData)=="string" and #wData>=3 then
		local uw=string.lower(wData):gsub("%s","")
		if string.match(uw,"^[a-z]+$") and pName~=player.Name then
			MarkUsed(uw); if CurrentLetter then task.defer(UpdatePreview) end
		end
	end
end)

local lastR=0
task.spawn(function()
	while gui and gui.Parent do
		if AutoAnswerRound>3 and AutoAnswerRound<lastR then ResetMatch() end
		lastR=AutoAnswerRound; task.wait(2)
	end
end)

-- accent line animasi di topbar
task.spawn(function()
	while tbLine and tbLine.Parent do
		TwW(tbLine,{BackgroundTransparency=0.5},1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
		TwW(tbLine,{BackgroundTransparency=0},1.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
	end
end)

print("[NightHubX v5] UI redesign loaded. TypeSound via :FireServer()")
