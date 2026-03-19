-- ╔══════════════════════════════════╗
-- ║       NightHubX  v6              ║
-- ║  Sambung Kata Auto Assistant     ║
-- ╚══════════════════════════════════╝
local cloneref = cloneref or function(o) return o end
local RS    = cloneref(game:GetService("ReplicatedStorage"))
local Plrs  = game:GetService("Players")
local TS    = game:GetService("TweenService")
local UIS   = game:GetService("UserInputService")
local SS    = game:GetService("SoundService")

local player    = Plrs.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes      = RS:WaitForChild("Remotes")
local MatchUI      = Remotes:WaitForChild("MatchUI")
local SubmitWord   = Remotes:WaitForChild("SubmitWord")
local BillboardUpd = Remotes:WaitForChild("BillboardUpdate")
local TypeSoundRE  = Remotes:WaitForChild("TypeSound")

-- ┌─────────────────────────────────┐
-- │  SUARA — murni lokal            │
-- │  Persis seperti game asli:      │
-- │  v_u_59:Play() langsung tiap   │
-- │  karakter diketik (bukan lewat  │
-- │  server/RemoteEvent)            │
-- └─────────────────────────────────┘
local typeSound = Instance.new("Sound")
typeSound.SoundId      = "rbxassetid://9113873548"
typeSound.Volume       = 0.6
typeSound.PlayOnRemove = false
typeSound.Parent       = PlayerGui

-- FireServer hanya throttle 0.08s seperti game asli, BUKAN trigger suara
local lastSoundFire = 0
local function FireTypeSound()
	typeSound:Play()   -- play lokal langsung, tidak tunggu server
	local now = tick()
	if now - lastSoundFire >= 0.08 then
		lastSoundFire = now
		TypeSoundRE:FireServer()
	end
end

-- ┌─────────────────────────────────┐
-- │  STATE                          │
-- └─────────────────────────────────┘
local Prefix1, Prefix2 = {}, {}
local CurrentLetter     = nil
local Ready             = false
local Options           = {}
local ScriptActive      = true
local LetterWordCount   = {}
local SortMode          = "strategy"

local AutoEnabled   = false
local AutoReady     = false
local AutoAnswered  = false
local AutoRound     = 0
local UsedWords     = {}
local LastWord      = nil

local TypoEnabled        = false
local CharDelay          = 0.15
local AntiHardEnabled    = false

-- KILLER_SCORE: tidak dipakai untuk sorting lagi (score flat), tetap ada untuk badge Danger
local KILLER_SCORE = {x=99999,z=95000,q=90000,v=70000,f=60000,w=50000,y=45000}
-- HARD_END: huruf susah yang dihindari saat Anti Hardword ON
local HARD_END = {x=true,z=true,q=true,v=true,f=true,w=true,y=true,j=true,k=true,g=true,c=true}
local HardL        = {q=10,x=9,z=8,v=7,f=6,w=5,y=4,k=3,b=2,p=1}
local MAX_BTN      = 40

local TYPING = {
	thinkMin=1.0, thinkMax=2.8,
	pChance=0.10, pMin=0.18, pMax=0.45,
	subMin=0.22, subMax=0.65, deadline=11.0,
	-- typo backspace: hapus karakter satu-satu dengan delay
	bsDelay = 0.09,   -- delay per karakter saat hapus typo
}

-- ┌─────────────────────────────────┐
-- │  UTIL                           │
-- └─────────────────────────────────┘
local function Tw(o,p,d,s,dr)
	local t=TS:Create(o,TweenInfo.new(d or .2,s or Enum.EasingStyle.Quint,dr or Enum.EasingDirection.Out),p)
	t:Play(); return t
end
local function TwW(o,p,d,s,dr) Tw(o,p,d,s,dr).Completed:Wait() end
local function RC(o,r) Instance.new("UICorner",o).CornerRadius=UDim.new(0,r or 6) end
local function Strk(o,c,th,tr)
	local s=Instance.new("UIStroke",o)
	s.Color=c; s.Thickness=th or 1; s.Transparency=tr or .5
	return s
end
local function Lbl(p,props)
	local l=Instance.new("TextLabel",p)
	l.BackgroundTransparency=1
	for k,v in pairs(props) do l[k]=v end
	return l
end
local function Btn(p,props)
	local b=Instance.new("TextButton",p)
	b.BorderSizePixel=0; b.AutoButtonColor=false
	for k,v in pairs(props) do b[k]=v end
	return b
end
local function Frame(p,props)
	local f=Instance.new("Frame",p)
	f.BorderSizePixel=0
	for k,v in pairs(props) do f[k]=v end
	return f
end

-- ┌─────────────────────────────────┐
-- │  PALETTE                        │
-- └─────────────────────────────────┘
local P = {
	base   = Color3.fromRGB(6,7,10),
	surf0  = Color3.fromRGB(11,12,17),
	surf1  = Color3.fromRGB(16,17,24),
	surf2  = Color3.fromRGB(22,23,33),
	surfH  = Color3.fromRGB(28,30,42),
	acc    = Color3.fromRGB(99,102,241),   -- indigo
	accH   = Color3.fromRGB(129,140,248),
	accD   = Color3.fromRGB(67,56,202),
	txt0   = Color3.fromRGB(248,248,255),
	txt1   = Color3.fromRGB(180,178,210),
	txt2   = Color3.fromRGB(110,108,145),
	ok     = Color3.fromRGB(52,211,153),
	warn   = Color3.fromRGB(251,191,36),
	err    = Color3.fromRGB(248,113,113),
	info   = Color3.fromRGB(96,165,250),
	orange = Color3.fromRGB(251,146,60),
	brd    = Color3.fromRGB(30,31,44),
	brdL   = Color3.fromRGB(50,52,72),
}

local Themes = {
	{n="Indigo",  acc=Color3.fromRGB(99,102,241),  accH=Color3.fromRGB(129,140,248), base=Color3.fromRGB(6,7,10)},
	{n="Rose",    acc=Color3.fromRGB(244,63,94),    accH=Color3.fromRGB(251,113,133), base=Color3.fromRGB(10,5,7)},
	{n="Teal",    acc=Color3.fromRGB(20,184,166),   accH=Color3.fromRGB(45,212,191),  base=Color3.fromRGB(4,10,9)},
	{n="Amber",   acc=Color3.fromRGB(245,158,11),   accH=Color3.fromRGB(252,211,77),  base=Color3.fromRGB(10,9,4)},
	{n="Fuchsia", acc=Color3.fromRGB(217,70,239),   accH=Color3.fromRGB(232,121,249), base=Color3.fromRGB(9,4,10)},
}
local tIdx=1

-- ┌─────────────────────────────────┐
-- │  GUI ROOT                       │
-- └─────────────────────────────────┘
local gui=Instance.new("ScreenGui",PlayerGui)
gui.Name="NightHubX"; gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.IgnoreGuiInset=true

-- ┌─────────────────────────────────┐
-- │  TOAST (pojok kanan atas)       │
-- └─────────────────────────────────┘
local toastHolder=Frame(gui,{
	Size=UDim2.new(0,210,1,0),
	Position=UDim2.new(1,-218,0,0),
	BackgroundTransparency=1, ZIndex=600,
})
local tLay=Instance.new("UIListLayout",toastHolder)
tLay.VerticalAlignment=Enum.VerticalAlignment.Top
tLay.HorizontalAlignment=Enum.HorizontalAlignment.Right
tLay.SortOrder=Enum.SortOrder.LayoutOrder
tLay.Padding=UDim.new(0,4)
Instance.new("UIPadding",toastHolder).PaddingTop=UDim.new(0,6)

local tN=0
local TC={info=P.info,success=P.ok,correct=P.ok,error=P.err,wrong=P.err,
          warning=P.warn,auto=P.acc,loaded=P.acc}
local function Toast(kind,title,msg,dur)
	dur=dur or 2.5; tN=tN+1
	local col=TC[kind] or P.acc
	local f=Frame(toastHolder,{
		Name="T"..tN, LayoutOrder=-tN,
		Size=UDim2.new(1,0,0,0),
		BackgroundColor3=P.surf1, ZIndex=601,
		ClipsDescendants=true,
	})
	RC(f,6); Strk(f,col,1,.35)

	-- left accent
	Frame(f,{Size=UDim2.new(0,2,1,0),BackgroundColor3=col,ZIndex=602})

	Lbl(f,{
		Size=UDim2.new(1,-8,0,14),Position=UDim2.new(0,8,0,4),
		Text=title,Font=Enum.Font.GothamBold,TextSize=10,
		TextColor3=P.txt0,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=602,
	})
	local h=18
	if msg and msg~="" then
		Lbl(f,{
			Size=UDim2.new(1,-8,0,11),Position=UDim2.new(0,8,0,18),
			Text=msg,Font=Enum.Font.Gotham,TextSize=8,
			TextColor3=P.txt1,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=602,
		})
		h=32
	end
	Tw(f,{Size=UDim2.new(1,0,0,h)},.18,Enum.EasingStyle.Back)

	local pb=Frame(f,{Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=P.brd,ZIndex=602})
	local pf=Frame(pb,{Size=UDim2.new(1,0,1,0),BackgroundColor3=col,ZIndex=603})
	Tw(pf,{Size=UDim2.new(0,0,1,0)},dur,Enum.EasingStyle.Linear)

	local gone=false
	local function bye()
		if gone then return end; gone=true
		Tw(f,{Size=UDim2.new(1,0,0,0),BackgroundTransparency=1},.14,Enum.EasingStyle.Quint,Enum.EasingDirection.In)
		task.wait(.16); f:Destroy()
	end
	task.delay(dur,bye)
end

-- ┌─────────────────────────────────┐
-- │  MAIN WINDOW  550 × 390         │
-- │  Layout baru: TOP bar tipis     │
-- │  Bawah: split kiri/kanan        │
-- │  Kiri: hanya word list          │
-- │  Kanan: kontrol+status          │
-- └─────────────────────────────────┘
local W,H = 550,390
local TH  = 30   -- topbar height

-- Window (tidak ada shadow ImageLabel)
local win=Frame(gui,{
	Name="Win",
	Size=UDim2.new(0,0,0,0),
	Position=UDim2.new(.5,0,.5,0),
	BackgroundColor3=P.base, ZIndex=10,
	ClipsDescendants=true,
})
RC(win,10); Strk(win,P.brd,1,.05)

-- Animasi masuk
task.defer(function()
	Tw(win,{Size=UDim2.new(0,W,0,H),Position=UDim2.new(.5,-W/2,.5,-H/2)},.36,Enum.EasingStyle.Back)
end)

-- Drag
local drag,dS,wS=false,Vector2.new(),UDim2.new()
UIS.InputChanged:Connect(function(i)
	if not drag then return end
	if i.UserInputType~=Enum.UserInputType.MouseMovement
		and i.UserInputType~=Enum.UserInputType.Touch then return end
	local d=i.Position-dS
	win.Position=UDim2.new(wS.X.Scale,wS.X.Offset+d.X,wS.Y.Scale,wS.Y.Offset+d.Y)
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1
		or i.UserInputType==Enum.UserInputType.Touch then drag=false end
end)

-- ┌─ TOPBAR ─────────────────────────┐
local tb=Frame(win,{
	Name="TB",Size=UDim2.new(1,0,0,TH),
	BackgroundColor3=P.surf0, ZIndex=20,
})
RC(tb,10)
Frame(tb,{Size=UDim2.new(1,0,0,12),Position=UDim2.new(0,0,1,-12),BackgroundColor3=P.surf0,ZIndex=20})

-- garis bawah topbar — accent animasi
local tbLine=Frame(win,{
	Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,0,TH),
	BackgroundColor3=P.acc, ZIndex=21,
})
task.spawn(function()
	while tbLine and tbLine.Parent do
		TwW(tbLine,{BackgroundTransparency=0.55},1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
		TwW(tbLine,{BackgroundTransparency=0  },1.4,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
	end
end)

tb.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1
		or i.UserInputType==Enum.UserInputType.Touch then
		drag=true; dS=i.Position; wS=win.Position
		i.Changed:Connect(function()
			if i.UserInputState==Enum.UserInputState.End then drag=false end
		end)
	end
end)

-- Title kiri
local titleBox=Frame(tb,{
	Size=UDim2.new(0,180,1,0),Position=UDim2.new(0,8,0,0),
	BackgroundTransparency=1,ZIndex=21,
})
-- kotak kecil accent sebelum judul
local titleAccBox=Frame(titleBox,{
	Size=UDim2.new(0,3,0,14),Position=UDim2.new(0,0,0.5,-7),
	BackgroundColor3=P.acc,ZIndex=22,
})
RC(titleAccBox,2)
Lbl(titleBox,{
	Size=UDim2.new(1,-8,1,0),Position=UDim2.new(0,8,0,0),
	Text="NightHubX",Font=Enum.Font.GothamBlack,TextSize=12,
	TextColor3=P.txt0,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=22,
})

-- Tombol kanan topbar — teks biasa, simpel
local function TbBtn(label,posX,hcol,fn)
	local b=Btn(tb,{
		Size=UDim2.new(0,22,0,22),Position=UDim2.new(1,posX,0.5,-11),
		BackgroundColor3=P.surf2,Text=label,
		Font=Enum.Font.GothamBold,TextSize=10,
		TextColor3=P.txt1,ZIndex=22,
	})
	RC(b,5)
	b.MouseEnter:Connect(function()
		Tw(b,{BackgroundColor3=hcol,TextColor3=P.txt0},.1)
	end)
	b.MouseLeave:Connect(function()
		Tw(b,{BackgroundColor3=P.surf2,TextColor3=P.txt1},.1)
	end)
	b.MouseButton1Click:Connect(fn)
	return b
end

TbBtn("✕",-28,P.err,function()
	-- close: tidak ada shadow, langsung destroy setelah animasi
	ScriptActive=false; AutoEnabled=false
	Tw(win,{Size=UDim2.new(0,0,0,0),Position=UDim2.new(.5,0,.5,0)},
		.28,Enum.EasingStyle.Back,Enum.EasingDirection.In)
	task.wait(.32); gui:Destroy()
end)

TbBtn("−",-54,P.warn,function()
	local isMin=win.Size.Y.Offset<=TH+2
	Tw(win,{Size=UDim2.new(0,W,0,isMin and H or TH+1)},.25,Enum.EasingStyle.Quint)
end)

TbBtn("◈",-80,P.accH,function()
	tIdx=tIdx%#Themes+1
	local t=Themes[tIdx]
	P.acc=t.acc; P.accH=t.accH; P.base=t.base
	win.BackgroundColor3=P.base
	tbLine.BackgroundColor3=P.acc
	titleAccBox.BackgroundColor3=P.acc
	Toast("info","Tema: "..t.n,"",1.5)
end)

-- ┌─────────────────────────────────────────────┐
-- │  KONTEN — kiri WORD LIST, kanan KONTROL     │
-- │  (layout terbalik dari versi lama)           │
-- └─────────────────────────────────────────────┘
local CY  = TH+2
local RW  = 185  -- lebar panel kanan (kontrol)
local GAP = 4

-- ══ PANEL KANAN (KONTROL) ══════════════════════
local rightCtrl=Frame(win,{
	Name="Ctrl",
	Size=UDim2.new(0,RW,1,-CY-GAP),
	Position=UDim2.new(1,-(RW+GAP),0,CY),
	BackgroundColor3=P.surf0, ZIndex=11,
})
RC(rightCtrl,8); Strk(rightCtrl,P.brd,1,.2)

local function RLbl(y,txt,fs,col,font)
	return Lbl(rightCtrl,{
		Size=UDim2.new(1,-10,0,fs+2),Position=UDim2.new(0,5,0,y),
		Text=txt,Font=font or Enum.Font.Gotham,TextSize=fs,
		TextColor3=col or P.txt1,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=12,
	})
end
local function HDivR(y)
	Frame(rightCtrl,{
		Size=UDim2.new(1,-10,0,1),Position=UDim2.new(0,5,0,y),
		BackgroundColor3=P.brd,ZIndex=12,
	})
end
local function SecHdr(y,txt)
	Lbl(rightCtrl,{
		Size=UDim2.new(1,-10,0,11),Position=UDim2.new(0,5,0,y),
		Text=txt,Font=Enum.Font.GothamBold,TextSize=7,
		TextColor3=P.txt2,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=12,
	})
end

-- Huruf aktif — tampilkan di kanan atas kontrol, besar
local prefBig=Lbl(rightCtrl,{
	Size=UDim2.new(0,60,0,42),Position=UDim2.new(0,4,0,4),
	Text="—",Font=Enum.Font.GothamBlack,TextSize=36,
	TextColor3=P.acc,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=12,
})
local prefCount=RLbl(46,"0 kata",8,P.txt2)
local prefDanger=Instance.new("TextLabel",rightCtrl)
prefDanger.Size=UDim2.new(0,70,0,15)
prefDanger.Position=UDim2.new(1,-74,0,6)
prefDanger.BackgroundColor3=P.err; prefDanger.BackgroundTransparency=0.7
prefDanger.Text=""; prefDanger.Font=Enum.Font.GothamBold; prefDanger.TextSize=7
prefDanger.TextColor3=Color3.fromRGB(255,140,140); prefDanger.BorderSizePixel=0
prefDanger.ZIndex=13; prefDanger.Visible=false; RC(prefDanger,4)

HDivR(58)

-- Status
local statusLbl=RLbl(62,"⏳ Memuat...",8,P.acc,Enum.Font.GothamBold)

HDivR(74)
SecHdr(78,"AUTO ANSWER")

-- Toggle helper — kini gaya pill horizontal
local function MkToggle(y,lText,onCol)
	local row=Btn(rightCtrl,{
		Size=UDim2.new(1,-10,0,22),Position=UDim2.new(0,5,0,y),
		BackgroundColor3=P.surf1,Text="",ZIndex=12,
	})
	RC(row,6); local rStr=Strk(row,P.brd,1,.55)
	local track=Frame(row,{
		Size=UDim2.new(0,26,0,12),Position=UDim2.new(0,4,0.5,-6),
		BackgroundColor3=Color3.fromRGB(32,26,52),ZIndex=13,
	}); RC(track,6)
	local knob=Frame(track,{
		Size=UDim2.new(0,8,0,8),Position=UDim2.new(0,2,0.5,-4),
		BackgroundColor3=P.txt2,ZIndex=14,
	}); RC(knob,4)
	local lbl=Lbl(row,{
		Size=UDim2.new(1,-36,1,0),Position=UDim2.new(0,34,0,0),
		Text=lText,Font=Enum.Font.GothamBold,TextSize=8,
		TextColor3=P.txt2,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=13,
	})
	row.MouseEnter:Connect(function() Tw(row,{BackgroundColor3=P.surfH},.08) end)
	row.MouseLeave:Connect(function() Tw(row,{BackgroundColor3=P.surf1},.08) end)
	local function Set(on)
		if on then
			Tw(track,{BackgroundColor3=onCol},.18)
			Tw(knob,{Position=UDim2.new(1,-10,0.5,-4),BackgroundColor3=P.txt0},.18,Enum.EasingStyle.Back)
			Tw(rStr,{Color=onCol,Transparency=.25},.15)
			lbl.TextColor3=onCol
		else
			Tw(track,{BackgroundColor3=Color3.fromRGB(32,26,52)},.18)
			Tw(knob,{Position=UDim2.new(0,2,0.5,-4),BackgroundColor3=P.txt2},.18,Enum.EasingStyle.Back)
			Tw(rStr,{Color=P.brd,Transparency=.55},.15)
			lbl.TextColor3=P.txt2
		end
	end
	return row,Set,lbl
end

local autoBtn,SetAutoV,autoLbl = MkToggle(92,"OFF",P.acc)

-- glow auto
local autoGlow=Frame(rightCtrl,{
	Size=UDim2.new(1,-8,0,24),Position=UDim2.new(0,4,0,91),
	BackgroundColor3=P.acc,BackgroundTransparency=1,ZIndex=10,
})
RC(autoGlow,6)
task.spawn(function()
	while autoGlow and autoGlow.Parent do
		if AutoEnabled then
			TwW(autoGlow,{BackgroundTransparency=0.88},1,Enum.EasingStyle.Sine)
			TwW(autoGlow,{BackgroundTransparency=0.96},1,Enum.EasingStyle.Sine)
		else task.wait(.5) end
	end
end)

-- status auto
local autoStat=RLbl(116,"",8,P.txt2)

HDivR(127)
SecHdr(131,"DELAY KETIK PER KARAKTER")

-- Slider delay
local DMIN,DMAX=0.1,3.0
local slRow=Frame(rightCtrl,{
	Size=UDim2.new(1,-10,0,26),Position=UDim2.new(0,5,0,144),
	BackgroundTransparency=1,ZIndex=12,
})
local slVal=Lbl(slRow,{
	Size=UDim2.new(1,0,0,12),Text="0.15s",
	Font=Enum.Font.GothamBold,TextSize=9,
	TextColor3=P.acc,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=13,
})
local slTrack=Frame(slRow,{
	Size=UDim2.new(1,0,0,4),Position=UDim2.new(0,0,0,16),
	BackgroundColor3=P.surf2,ZIndex=13,
}); RC(slTrack,2)
local slFill=Frame(slTrack,{
	Size=UDim2.new(0.017,0,1,0),BackgroundColor3=P.acc,ZIndex=14,
}); RC(slFill,2)
local slKnob=Frame(slTrack,{
	Size=UDim2.new(0,10,0,10),Position=UDim2.new(0.017,-5,0.5,-5),
	BackgroundColor3=P.accH,ZIndex=15,
}); RC(slKnob,5); Strk(slKnob,P.acc,1.5,.15)

local function SetSlider(pct)
	pct=math.clamp(pct,0,1)
	CharDelay=math.floor((DMIN+pct*(DMAX-DMIN))*100+.5)/100
	slFill.Size=UDim2.new(pct,0,1,0)
	slKnob.Position=UDim2.new(pct,-5,0.5,-5)
	slVal.Text=string.format("%.2fs",CharDelay)
	slFill.BackgroundColor3=Color3.fromRGB(math.floor(80+pct*155),math.floor(100+(1-pct)*110),255)
end
SetSlider((CharDelay-DMIN)/(DMAX-DMIN))

local sDrag=false
slTrack.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=true end
end)
slTrack.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=false end
end)
UIS.InputChanged:Connect(function(i)
	if not sDrag then return end
	if i.UserInputType~=Enum.UserInputType.MouseMovement and i.UserInputType~=Enum.UserInputType.Touch then return end
	SetSlider((i.Position.X-slTrack.AbsolutePosition.X)/slTrack.AbsoluteSize.X)
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then sDrag=false end
end)

HDivR(174)
SecHdr(178,"OPSI")

local typoBtn,SetTypoV,typoLbl=MkToggle(190,"Typo: OFF",P.warn)
typoBtn.MouseButton1Click:Connect(function()
	TypoEnabled=not TypoEnabled; SetTypoV(TypoEnabled)
	typoLbl.Text=TypoEnabled and "Typo: ON" or "Typo: OFF"
	Toast(TypoEnabled and "warning" or "info",TypoEnabled and "Typo ON" or "Typo OFF",
		TypoEnabled and "Salah→hapus pelan→benar" or "",2)
end)

local akBtn,SetAKV,akLbl=MkToggle(216,"Anti Hardword: OFF",P.ok)
akBtn.MouseButton1Click:Connect(function()
	AntiHardEnabled=not AntiHardEnabled; SetAKV(AntiHardEnabled)
	akLbl.Text=AntiHardEnabled and "Anti Hardword: ON" or "Anti Hardword: OFF"
	Toast(AntiHardEnabled and "success" or "info",
		AntiHardEnabled and "Anti Hardword ON" or "Anti Hardword OFF",
		AntiHardEnabled and "Skip x/z/q/v/f/w/y/j/k/g/c" or "",2)
end)

local sortBtn,SetSortV,sortLbl=MkToggle(242,"Sort: Strategy+",P.accH)
local isStrat=true; SetSortV(true)
sortBtn.MouseButton1Click:Connect(function()
	isStrat=not isStrat; SortMode=isStrat and "strategy" or "difficulty"
	SetSortV(isStrat)
	sortLbl.Text=isStrat and "Sort: Strategy+" or "Sort: Difficulty"
	if UpdatePreview then UpdatePreview() end
end)

HDivR(268)
Lbl(rightCtrl,{
	Size=UDim2.new(1,-10,0,10),Position=UDim2.new(0,5,1,-12),
	Text="NightHubX v6",Font=Enum.Font.Gotham,TextSize=7,
	TextColor3=P.txt2,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=12,
})

-- ══ PANEL KIRI (WORD LIST) ═════════════════════
local LW2 = W - RW - GAP*3
local leftList=Frame(win,{
	Name="List",
	Size=UDim2.new(0,LW2,1,-CY-GAP),
	Position=UDim2.new(0,GAP,0,CY),
	BackgroundColor3=P.surf0, ZIndex=11,
})
RC(leftList,8); Strk(leftList,P.brd,1,.2)

-- column header
local colH=Frame(leftList,{
	Size=UDim2.new(1,0,0,22),
	BackgroundColor3=P.surf1,ZIndex=12,
})
RC(colH,6)
Frame(leftList,{Size=UDim2.new(1,0,0,22),BackgroundColor3=P.surf1,ZIndex=11}) -- fill radius bawah
Lbl(colH,{Size=UDim2.new(1,-90,1,0),Position=UDim2.new(0,8,0,0),
	Text="KATA",Font=Enum.Font.GothamBold,TextSize=8,
	TextColor3=P.txt2,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=13})
Lbl(colH,{Size=UDim2.new(0,86,1,0),Position=UDim2.new(1,-88,0,0),
	Text="STATUS",Font=Enum.Font.GothamBold,TextSize=8,
	TextColor3=P.txt2,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=13})

-- scroll
local scroll=Instance.new("ScrollingFrame",leftList)
scroll.Size=UDim2.new(1,0,1,-24); scroll.Position=UDim2.new(0,0,0,23)
scroll.BackgroundColor3=P.base; scroll.BackgroundTransparency=0
scroll.BorderSizePixel=0; scroll.ZIndex=12
scroll.ScrollBarThickness=3; scroll.ScrollBarImageColor3=P.acc
scroll.CanvasSize=UDim2.new(0,0,0,0)
RC(scroll,6); Strk(scroll,P.brd,1,.3)

local ll=Instance.new("UIListLayout",scroll)
ll.SortOrder=Enum.SortOrder.LayoutOrder; ll.Padding=UDim.new(0,2)
local lp=Instance.new("UIPadding",scroll)
lp.PaddingTop=UDim.new(0,3); lp.PaddingBottom=UDim.new(0,3)
lp.PaddingLeft=UDim.new(0,3); lp.PaddingRight=UDim.new(0,3)
ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize=UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+6)
end)

local buttons,btnBadges={},{}
local function MkWBtn(i)
	local btn=Btn(scroll,{
		Name="B"..i, Size=UDim2.new(1,0,0,26), LayoutOrder=i,
		BackgroundColor3=i%2==0 and P.surf0 or P.surf1,
		Font=Enum.Font.GothamMedium, TextSize=11,
		TextColor3=P.txt1, TextXAlignment=Enum.TextXAlignment.Left,
		ZIndex=13, Visible=false,
	})
	RC(btn,5); local bSt=Strk(btn,P.brd,1,.75)

	-- rank
	Lbl(btn,{Size=UDim2.new(0,15,1,0),Position=UDim2.new(0,3,0,0),
		Text=tostring(i),Font=Enum.Font.GothamBold,TextSize=7,
		TextColor3=P.txt2,ZIndex=14})

	local wL=Lbl(btn,{Name="W",Size=UDim2.new(1,-92,1,0),Position=UDim2.new(0,19,0,0),
		Text="",Font=Enum.Font.GothamMedium,TextSize=11,
		TextColor3=P.txt0,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=14})

	local badge=Instance.new("TextLabel",btn)
	badge.Name="D"; badge.Size=UDim2.new(0,80,0,15)
	badge.Position=UDim2.new(1,-83,0.5,-7.5)
	badge.BackgroundColor3=P.ok; badge.BackgroundTransparency=0.75
	badge.Text=""; badge.Font=Enum.Font.GothamBold; badge.TextSize=7
	badge.TextColor3=P.txt0; badge.BorderSizePixel=0; badge.ZIndex=15; badge.Visible=false
	RC(badge,4)

	btn.MouseEnter:Connect(function()
		Tw(btn,{BackgroundColor3=P.surfH},.08)
		Tw(bSt,{Color=P.accH,Transparency=.35},.08)
	end)
	btn.MouseLeave:Connect(function()
		Tw(btn,{BackgroundColor3=i%2==0 and P.surf0 or P.surf1},.08)
		Tw(bSt,{Color=P.brd,Transparency=.75},.08)
	end)
	table.insert(buttons,btn); table.insert(btnBadges,badge)
end
for i=1,MAX_BTN do MkWBtn(i) end

-- ──────────────────────────────────────────────
-- AUTO TOGGLE handler (setelah semua label dibuat)
-- ──────────────────────────────────────────────
autoBtn.MouseButton1Click:Connect(function()
	AutoEnabled=not AutoEnabled; SetAutoV(AutoEnabled)
	autoLbl.Text=AutoEnabled and "ON" or "OFF"
	if AutoEnabled then
		autoGlow.BackgroundColor3=P.acc
		Tw(autoGlow,{BackgroundTransparency=0.88},.25)
		autoStat.Text="⏳ Menunggu giliran..."
		autoStat.TextColor3=P.acc
		Toast("auto","Auto Answer ON","DupFilter aktif",2.5)
	else
		Tw(autoGlow,{BackgroundTransparency=1},.25)
		autoStat.Text=""
		Toast("info","Auto Answer OFF","",2)
	end
end)

-- ─────────────────────────────────────────────
-- STRATEGY ENGINE
-- ─────────────────────────────────────────────
local function Score(w)
	-- Semua kata dapat score yang sama, urutan hanya berdasarkan panjang kata
	return 1
end

local function Danger(w)
	local lc=string.sub(w,-1)
	local cnt=LetterWordCount[lc] or 0
	local isK=KILLER_SCORE[lc] and KILLER_SCORE[lc]>=70000
	-- Label dikosongkan, hanya warna yang menunjukkan tingkat kesulitan
	if cnt==0          then return "", P.err
	elseif cnt<=3 or isK then return "", Color3.fromRGB(255,80,80)
	elseif cnt<=10     then return "", P.orange
	elseif cnt<=30     then return "", P.warn
	elseif cnt<=100    then return "", P.info
	else                    return "", P.ok end
end

local function FindOpts(prefix)
	prefix=string.lower(prefix):gsub("[^a-z]","")
	local list=#prefix>=2 and Prefix2[string.sub(prefix,1,2)] or Prefix1[string.sub(prefix,1,1)]
	if not list then return {} end
	local f,seen={},{}
	for _,w in ipairs(list) do
		if string.sub(w,1,#prefix)==prefix and not seen[w] and not UsedWords[w] then
			seen[w]=true; table.insert(f,w)
		end
	end
	if #f==0 then return {} end
	if SortMode=="strategy" then
		table.sort(f,function(a,b)
			local sA,sB=Score(a),Score(b)
			if sA~=sB then return sA>sB end; return #a<#b
		end)
	else
		table.sort(f,function(a,b)
			local dA=HardL[string.sub(a,-1)] or 0
			local dB=HardL[string.sub(b,-1)] or 0
			if dA~=dB then return dA>dB end; return #a<#b
		end)
	end
	return f
end

local function MarkUsed(w)
	if not w or #w<3 then return end
	local s=string.lower(w):gsub("%s","")
	if string.match(s,"^[a-z]+$") and not UsedWords[s] then UsedWords[s]=true end
end

UpdatePreview=function()
	if not Ready or not CurrentLetter then return end
	Options=FindOpts(CurrentLetter)
	local usedN=0; for _ in pairs(UsedWords) do usedN=usedN+1 end

	prefBig.Text=CurrentLetter:upper()
	prefBig.TextColor3=P.acc

	if not Options or #Options==0 then
		prefCount.Text="0 kata (🚫"..usedN..")"
		statusLbl.Text="⚠ Tidak ada kata!"; statusLbl.TextColor3=P.err
		prefDanger.Visible=true; prefDanger.Text="MATI"
		prefDanger.BackgroundColor3=P.err; prefDanger.TextColor3=Color3.fromRGB(255,140,140)
		for _,b in ipairs(buttons) do b.Visible=false end
		for _,d in ipairs(btnBadges) do d.Visible=false end
		return
	end

	prefCount.Text=#Options.." kata (🚫"..usedN..")"
	statusLbl.Text="✓ "..math.min(#Options,MAX_BTN).."/"..#Options
	statusLbl.TextColor3=P.ok

	if #Options<=3 then
		prefDanger.Visible=true; prefDanger.Text="KRITIS"
		prefDanger.BackgroundColor3=P.err
	elseif #Options<=10 then
		prefDanger.Visible=true; prefDanger.Text="SEDIKIT"
		prefDanger.BackgroundColor3=P.orange; prefDanger.TextColor3=Color3.fromRGB(255,200,100)
	else
		prefDanger.Visible=false
	end

	for i,btn in ipairs(buttons) do
		local d=btnBadges[i]
		if Options[i] then
			local ww=Options[i]
			local wL=btn:FindFirstChild("W"); if wL then wL.Text="  "..ww end
			btn.Visible=true
			local dtxt,dcol=Danger(ww)
			d.Text=dtxt; d.BackgroundColor3=dcol; d.Visible=true
		else
			btn.Visible=false; d.Visible=false
		end
	end
end

for i,btn in ipairs(buttons) do
	btn.MouseButton1Click:Connect(function()
		local word=Options[i]; if not word then return end
		MarkUsed(word); LastWord=word
		local orig=i%2==0 and P.surf0 or P.surf1
		Tw(btn,{BackgroundColor3=P.acc},.07)
		task.delay(.12,function() Tw(btn,{BackgroundColor3=orig},.18) end)
		local rem=CurrentLetter and #CurrentLetter>0 and string.sub(word,#CurrentLetter+1) or word
		local box=player.PlayerGui:FindFirstChild("MatchUI",true)
		if box then
			local inp=box:FindFirstChildWhichIsA("TextBox",true)
			if inp then inp.Text=rem; Toast("success",word,Danger(word),2) end
		end
		task.delay(.22,UpdatePreview)
	end)
end

-- ─────────────────────────────────────────────
-- LOAD WORDLIST
-- ─────────────────────────────────────────────
task.spawn(function()
	statusLbl.Text="⏳ Memuat kamus..."
	local text=""
	local ok,res=pcall(function()
		return game:HttpGet("https://raw.githubusercontent.com/SOBING4413/sambungkata/main/dependescis/kbbi.txt")
	end)
	if ok and res then text=res end
	local wc=0
	for word in string.gmatch(text,"[^\r\n]+") do
		local w=string.lower(word):gsub("%s","")
		if string.match(w,"^[a-z]+$") and #w>=3 then
			local p1,p2=string.sub(w,1,1),string.sub(w,1,2)
			Prefix1[p1]=Prefix1[p1] or {}; table.insert(Prefix1[p1],w)
			Prefix2[p2]=Prefix2[p2] or {}; table.insert(Prefix2[p2],w)
			wc=wc+1
		end
	end
	for l=string.byte("a"),string.byte("z") do
		local c=string.char(l)
		LetterWordCount[c]=Prefix1[c] and #Prefix1[c] or 0
	end
	Ready=true; AutoReady=true
	statusLbl.Text="✓ "..wc.." kata"; statusLbl.TextColor3=P.ok
	Toast("loaded","Siap!","v6 · "..wc.." kata",3)
	print("[NightHubX v6] "..wc.." kata dimuat")
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
local function TypoC(c)
	local n=QWERTY[c]; if n and #n>0 then return n[math.random(1,#n)] end
	return c=="a" and "s" or "a"
end

local function TypeWord(rem,ts)
	local dl=TYPING.deadline-(tick()-ts)
	if dl<=1.0 then BillboardUpd:FireServer(rem); return true end

	local charD=CharDelay
	local est=#rem*charD+TYPING.subMax+(TypoEnabled and #rem*0.18*0.5 or 0)
	local sp=est>dl-0.5 and math.max((dl-0.5)/est,0.3) or 1.0

	local typed=""
	for i=1,#rem do
		if not AutoEnabled then return false end
		if TYPING.deadline-(tick()-ts)<=0.8 then BillboardUpd:FireServer(rem); return true end

		local c=string.sub(rem,i,i)

		if TypoEnabled and math.random()<0.18 and i<#rem then
			local wrong=TypoC(c)

			-- 1. Ketik karakter salah + suara
			typed=typed..wrong
			BillboardUpd:FireServer(typed)
			FireTypeSound()
			task.wait(math.random(15,45)/100*sp)
			if not AutoEnabled then return false end

			-- 2. Hapus perlahan karakter per karakter dengan delay
			for _=1,#wrong do
				if not AutoEnabled then return false end
				typed=string.sub(typed,1,#typed-1)
				BillboardUpd:FireServer(typed)
				task.wait(TYPING.bsDelay*sp)  -- hapus lambat
			end
			if not AutoEnabled then return false end
		end

		-- 3. Ketik karakter benar + suara
		typed=typed..c
		BillboardUpd:FireServer(typed)
		FireTypeSound()

		local d=charD*sp
		if math.random()<TYPING.pChance and i<#rem then
			d=d+(TYPING.pMin+math.random()*(TYPING.pMax-TYPING.pMin))*sp
		end
		task.wait(d)
	end
	return true
end

local function DoAuto(ts)
	if not CurrentLetter or not AutoEnabled then return end
	Options=FindOpts(CurrentLetter)
	local cands=Options
	if AntiHardEnabled then
		local safe={}
		for _,w in ipairs(Options) do
			if not HARD_END[string.sub(w,-1)] then table.insert(safe,w) end
		end
		if #safe>0 then cands=safe end
	end
	if not cands or #cands==0 then
		autoStat.Text="❌ Tidak ada kata"; autoStat.TextColor3=P.err; return
	end
	local word=cands[1]; MarkUsed(word); LastWord=word
	local tags=(AntiHardEnabled and "🛡" or "")..(TypoEnabled and "⚡" or "")
	autoStat.Text='⏳ "'..word..'" '..string.format("%.2f",CharDelay).."s "..tags
	autoStat.TextColor3=P.acc

	local td=TYPING.thinkMin+math.random()*(TYPING.thinkMax-TYPING.thinkMin)
	local tl=TYPING.deadline-(tick()-ts)
	if tl<td+2 then td=math.max(0.2,tl-2) end
	task.wait(td); if not AutoEnabled then return end

	local rem=string.sub(word,#CurrentLetter+1)
	if not TypeWord(rem,ts) or not AutoEnabled then return end

	local sd=TYPING.subMin+math.random()*(TYPING.subMax-TYPING.subMin)
	local tn=TYPING.deadline-(tick()-ts)
	if tn<sd+0.3 then sd=math.max(0.1,tn-0.3) end
	task.wait(sd); if not AutoEnabled then return end

	SubmitWord:FireServer(rem)
	local lc=string.sub(word,-1)
	local dt=Danger(word)
	local t2=string.format("%.1f",tick()-ts)
	autoStat.Text='✅ "'..word..'" ('..t2..'s)'; autoStat.TextColor3=P.ok
	Toast("auto","Auto",'"'..word..'" → '..lc:upper().." "..dt,2)
	UpdatePreview()
end

local function TriggerAuto()
	if not CurrentLetter or AutoAnswered or not AutoEnabled then return end
	AutoAnswered=true
	local ts=tick()
	task.spawn(function()
		local to=0
		while not AutoReady and to<10 do task.wait(0.5); to=to+0.5 end
		if AutoReady and AutoEnabled then DoAuto(ts) end
	end)
end

local function ResetMatch()
	local n=0; for _ in pairs(UsedWords) do n=n+1 end
	UsedWords={}; AutoRound=0; AutoAnswered=false; LastWord=nil
	if AutoEnabled then autoStat.Text="🔄 Reset "..n; autoStat.TextColor3=P.info end
	if CurrentLetter then UpdatePreview() end
	Toast("info","Match Baru","Reset "..n.." kata",2)
end

-- ─────────────────────────────────────────────
-- EVENTS
-- ─────────────────────────────────────────────
MatchUI.OnClientEvent:Connect(function(ev,data)
	if not ScriptActive then return end
	if ev=="UpdateServerLetter" then
		if type(data)=="string" then
			CurrentLetter=string.lower(data):gsub("[^a-z]","")
			AutoAnswered=false; UpdatePreview()
			if AutoEnabled then autoStat.Text="⏳ "..CurrentLetter:upper(); autoStat.TextColor3=P.acc end
		end
	elseif ev=="StartTurn" then
		AutoRound=AutoRound+1; AutoAnswered=false; TriggerAuto()
	elseif ev=="Mistake" then
		AutoAnswered=false
		if AutoEnabled then
			autoStat.Text="🔄 Salah!"; autoStat.TextColor3=P.orange
			Toast("wrong","Salah","Coba lagi",1.5)
			UpdatePreview(); task.wait(0.5); TriggerAuto()
		else Toast("wrong","Jawaban Salah","",2) end
	elseif ev=="CorrectAnswer" then
		if type(data)=="string" and #data>0 then
			local aw=string.lower(data):gsub("%s",""); if #aw>=3 then MarkUsed(aw) end
		elseif LastWord then MarkUsed(LastWord) end
		if AutoEnabled then Toast("correct","Benar!","Ronde "..AutoRound,2)
		else Toast("correct","Benar!","",2) end
		UpdatePreview()
	elseif ev=="EndTurn" then
		CurrentLetter=nil; AutoAnswered=false
		if AutoEnabled then autoStat.Text="⏸ Selesai" end
	elseif ev=="MatchStart" or ev=="NewMatch" or ev=="GameStart"
		or ev=="MatchEnd" or ev=="GameEnd" or ev=="EndMatch" then
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
		if AutoRound>3 and AutoRound<lastR then ResetMatch() end
		lastR=AutoRound; task.wait(2)
	end
end)

print("[NightHubX v6] Loaded. Sound via OnClientEvent. No shadow. Slow backspace typo.")
