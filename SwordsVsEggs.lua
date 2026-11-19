--[[
    elena hub  ·  swords vs eggs  ⚔️🥚
    ui/ux    : dark glassmorphism (aether v1.6 reference) · bilingual EN/ID
               re-execute reload bar · floating draggable mini bar (fps/cpu/gpu + state)
               config create/save/load + capped history (12, persisted)
    modules  : speed · auto treadmill · pet/egg/rarity/odds finder · live status
               anti afk · anti ragdoll · anti guard · auto steal → safe zone
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local configOk, GameConfig = pcall(function()
	return require(ReplicatedStorage.SlashGameplay.GameConfig)
end)
if not configOk or type(GameConfig) ~= "table" then
	GameConfig = { ZoneEggs = {}, ZoneNames = {}, Zones = {}, Eggs = {} }
end

-- ============================================================================
-- 0 · runtime registry · a reload kills the previous run before it can stack
-- ============================================================================
local RUN_ID = string.format("%d_%d", math.floor(os.clock() * 1000), math.random(1, 1000000))
local HUB = (type(getgenv) == "function" and getgenv() or shared).ElenaHub

local IS_RELOAD = type(HUB) == "table" and (type(HUB.cleanup) == "function" or type(HUB.destroy) == "function")

if type(HUB) ~= "table" then
	HUB = {}
	;(type(getgenv) == "function" and getgenv() or shared).ElenaHub = HUB
end

if IS_RELOAD then
	pcall(function()
		HUB.cleanup()
	end)
	pcall(function()
		if HUB.destroy and HUB.destroy ~= HUB.cleanup then
			HUB.destroy()
		end
	end)
end

HUB.runId = RUN_ID
HUB.runs = (tonumber(HUB.runs) or 0) + 1
HUB.cleanup = nil

local function alive()
	local hub = (type(getgenv) == "function" and getgenv() or shared).ElenaHub
	return type(hub) == "table" and hub.runId == RUN_ID
end

-- ============================================================================
-- 1 · theme tokens
-- ============================================================================
local TOPBAR_H = 44
local TELEMETRY_H = 38
local RELOAD_H = 3
local BODY_TOP = TOPBAR_H + TELEMETRY_H
local MAX_HISTORY = 12

local CONFIG_DIR = "ElenaHub"
local CONFIG_FILE = CONFIG_DIR .. "/configs.json"

local Theme = {
	WindowSize = UDim2.fromOffset(560, 392),
	WindowPos = UDim2.new(0.5, -280, 0.5, -196),

	BgMain = Color3.fromRGB(16, 18, 24),
	BgMainAlpha = 0.14,
	BgHeader = Color3.fromRGB(22, 25, 34),
	BgHeaderAlpha = 0.22,
	BgCard = Color3.fromRGB(26, 30, 41),
	BgCardAlpha = 0.25,
	BgCardActive = Color3.fromRGB(30, 41, 64),
	BgPill = Color3.fromRGB(18, 21, 30),
	BgInput = Color3.fromRGB(14, 17, 25),
	BgButtonOff = Color3.fromRGB(34, 39, 52),
	BgButtonOn = Color3.fromRGB(59, 130, 246),
	BgSuccess = Color3.fromRGB(22, 101, 52),

	TextPrimary = Color3.fromRGB(241, 245, 249),
	TextSecondary = Color3.fromRGB(148, 163, 184),
	Stroke = Color3.fromRGB(255, 255, 255),
	StrokeAlpha = 0.86,

	Accent = Color3.fromRGB(96, 165, 250),
	Accent2 = Color3.fromRGB(147, 197, 253),
	Good = Color3.fromRGB(74, 222, 128),
	Warn = Color3.fromRGB(250, 204, 21),
	Bad = Color3.fromRGB(248, 113, 113),

	Corner = UDim.new(0, 12),
	Small = UDim.new(0, 8),
	Pill = UDim.new(0, 6),

	Fast = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	TabAnim = TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Pop = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Reload = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

-- ============================================================================
-- 2 · bilingual strings  ·  key = { english, indonesian }
-- ============================================================================
local T = {
	subTag = { "v2 · LIVE", "v2 · AKTIF" },
	tabMain = { "Main", "Utama" },
	tabFarm = { "Farm", "Farm" },
	tabFind = { "Finder", "Finder" },
	tabStatus = { "Status", "Status" },
	tabConfig = { "Configs", "Konfig" },
	tabSet = { "Settings", "Setelan" },

	idle = { "IDLE", "DIAM" },
	running = { "RUNNING", "JALAN" },
	activeFmt = { "ACTIVE #%d", "AKTIF #%d" },

	secWindow = { "Window", "Jendela" },
	secSpeed = { "Movement", "Gerakan" },
	fastWalk = { "Fast walk", "Jalan cepat" },
	fastWalkSub = { "re-applies the slider value every tick", "nilai slider dipakai tiap tick" },
	speedVal = { "Walk speed", "Kecepatan jalan" },
	speedValSub = { "16 = normal · 500 = very fast", "16 = normal · 500 = sangat cepat" },
	keybind = { "Speed key", "Tombol speed" },
	keybindSub = { "press to toggle fast walk", "tekan untuk toggle jalan cepat" },
	resetSpeed = { "Reset to game speed", "Balik ke speed normal" },
	resetSpeedSub = { "drops walk speed back to 16", "walk speed balik ke 16" },
	minimize = { "Minimize to mini bar", "Kecilkan ke mini bar" },
	minimizeSub = { "floating bar stays draggable on screen", "mini bar tetap bisa digeser" },

	secTread = { "Auto treadmill", "Auto treadmill" },
	treadOn = { "Keep treadmill running", "Biarkan treadmill jalan" },
	treadOnSub = { "re-parks you whenever the session drops", "parkir ulang tiap sesi putus" },
	treadStop = { "Stop · step off", "Stop · turun" },
	treadStopSub = { "unpins the deck pose so the session ends", "lepas pose deck biar sesi berakhir" },
	treadPark = { "Park now", "Parkir sekarang" },
	treadParkSub = { "teleport onto your deck", "teleport ke deck kamu" },
	tpPlot = { "Teleport to my plot", "Teleport ke plot" },
	tpPlotSub = { "jump to your spawn point", "pindah ke spawn point kamu" },

	secSteal = { "Auto steal → safe zone", "Auto steal → safe zone" },
	stealOn = { "Auto steal loop", "Loop auto steal" },
	stealOnSub = { "teleport under pet · steal · run to safe zone", "teleport bawah pet · steal · lari ke safe zone" },
	stealDelay = { "Cycle delay", "Jeda siklus" },
	stealDelaySub = { "seconds between attempts", "detik antar percobaan" },
	stealOnce = { "Steal once", "Steal sekali" },
	stealOnceSub = { "one pass, then stop", "sekali jalan lalu stop" },
	stealInfo = { "Steal engine", "Mesin steal" },

	secGuard = { "Protection", "Proteksi" },
	antiAfk = { "Anti AFK", "Anti AFK" },
	antiAfkSub = { "kills the 20-minute idle kick", "matikan kick idle 20 menit" },
	antiRag = { "Anti ragdoll", "Anti ragdoll" },
	antiRagSub = { "clears ragdoll / platform stand states", "bersihkan state ragdoll / platform stand" },
	antiGuard = { "Anti guard", "Anti guard" },
	antiGuardSub = { "dash to safety the moment you're chased", "langsung lari saat dikejar" },

	secFinder = { "Pet · egg · odds finder", "Finder pet · egg · odds" },
	zone = { "Zone", "Zona" },
	zoneSub = { "egg roster and hatch pool per zone", "daftar egg dan pool tiap zona" },
	refreshOwn = { "Refresh ownership", "Refresh kepemilikan" },
	refreshOwnSub = { "re-read your inventory", "baca ulang inventory kamu" },
	scanAll = { "Scan everything", "Scan semua" },
	scanAllSub = { "print every zone to the console", "print semua zona ke console" },
	eggsTitle = { "Eggs", "Egg" },
	poolTitle = { "Hatch pool", "Pool hatch" },
	ownedTitle = { "Owned", "Dimiliki" },

	secLive = { "You", "Kamu" },
	liveTitle = { "Live", "Live" },
	invTitle = { "Inventory by kind", "Inventory per jenis" },
	refreshStatus = { "Refresh", "Refresh" },
	refreshStatusSub = { "pull a fresh profile", "tarik profile baru" },

	secConfig = { "Profiles", "Profil" },
	configMeta = { "active: %s · saved: %d", "aktif: %s · tersimpan: %d" },
	configPlaceholder = { "config name (e.g. farm_v2)", "nama konfig (mis. farm_v2)" },
	btnCreate = { "Create", "Buat" },
	btnSave = { "Save", "Simpan" },
	btnLoad = { "Load", "Muat" },
	historyTitle = { "History · max 12", "Riwayat · maks 12" },
	historyEmpty = { "no history yet", "belum ada riwayat" },

	secUi = { "Interface", "Antarmuka" },
	langTitle = { "Language / Bahasa", "Bahasa / Language" },
	langSub = { "switch every label instantly", "ganti semua label langsung" },
	uiScale = { "UI scale", "Skala UI" },
	uiScaleSub = { "shrink or grow the whole window", "kecilkan atau besarkan jendela" },
	secDanger = { "Session", "Sesi" },
	closeHub = { "Close hub", "Tutup hub" },
	closeHubSub = { "destroys this run completely", "hancurkan run ini sepenuhnya" },
}

local LANG = 2 -- 1 = en, 2 = id

local function L(key)
	local entry = T[key]
	if not entry then
		return tostring(key)
	end
	return entry[LANG] or entry[1] or tostring(key)
end

-- ============================================================================
-- 3 · state + persisted store
-- ============================================================================
local S = {
	instance = RUN_ID,
	lang = LANG,

	speedOn = false,
	speedValue = 180,
	treadmillOn = false,
	leaving = false,
	parking = false,
	reparks = 0,
	misses = 0,

	antiAfk = true,
	antiRag = true,
	antiGuard = true,

	stealOn = false,
	stealAbort = false,
	stealRunning = false,
	stealDelay = 1.2,
	stealCount = 0,
	stealFails = 0,
	stealPhase = "idle",
	stealLast = "-",
	stealWorld = 0,

	zone = nil,
	ownedPets = {},
	ownedKinds = {},
	ownedCount = 0,
	profileLoaded = false,
	profile = {},
	profileAt = 0,
	condensing = false,

	gainValue = 0,
	gainMark = nil,
	lastError = "",

	connections = {},
	threads = {},
	destroyed = false,
}

local DEFAULT_PROFILE = {
	SpeedValue = 180,
	SpeedOn = false,
	Treadmill = false,
	AntiAfk = true,
	AntiRag = true,
	AntiGuard = true,
	StealDelay = 1.2,
}

local Store = {
	language = "id",
	selected = "default",
	profiles = { default = table.clone(DEFAULT_PROFILE) },
	history = {},
}

local function hasFileIO()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function trimHistory(list)
	while #list > MAX_HISTORY do
		table.remove(list, #list)
	end
end

local function loadStore()
	if type(shared.__ElenaStore) == "table" then
		Store = shared.__ElenaStore
		return
	end
	if hasFileIO() then
		pcall(function()
			if not isfile(CONFIG_FILE) then
				return
			end
			local raw = readfile(CONFIG_FILE)
			if type(raw) ~= "string" or #raw == 0 then
				return
			end
			local ok, decoded = pcall(function()
				return HttpService:JSONDecode(raw)
			end)
			if ok and type(decoded) == "table" and type(decoded.profiles) == "table" then
				decoded.language = decoded.language == "en" and "en" or "id"
				decoded.selected = type(decoded.selected) == "string" and decoded.selected or "default"
				decoded.history = type(decoded.history) == "table" and decoded.history or {}
				Store = decoded
			end
		end)
	end
	shared.__ElenaStore = Store
end

local function saveStore()
	trimHistory(Store.history)
	shared.__ElenaStore = Store
	if hasFileIO() then
		pcall(function()
			if type(isfolder) == "function" and type(makefolder) == "function" then
				if not isfolder(CONFIG_DIR) then
					makefolder(CONFIG_DIR)
				end
			end
			writefile(CONFIG_FILE, HttpService:JSONEncode(Store))
		end)
	end
end

loadStore()
if not Store.profiles[Store.selected] then
	Store.profiles[Store.selected] = table.clone(DEFAULT_PROFILE)
end
LANG = Store.language == "en" and 1 or 2
S.lang = LANG

-- ============================================================================
-- 4 · ui primitives
-- ============================================================================
local function addCorner(inst, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Corner
	corner.Parent = inst
	return corner
end

local function addStroke(inst, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Stroke
	stroke.Transparency = transparency or Theme.StrokeAlpha
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = inst
	return stroke
end

local function addPadding(inst, pad)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pad)
	padding.PaddingBottom = UDim.new(0, pad)
	padding.PaddingLeft = UDim.new(0, pad)
	padding.PaddingRight = UDim.new(0, pad)
	padding.Parent = inst
	return padding
end

local function tween(inst, info, props)
	local anim = TweenService:Create(inst, info, props)
	anim:Play()
	return anim
end

local function pulse(btn, flash)
	local original = btn.BackgroundColor3
	if flash then
		btn.BackgroundColor3 = flash
	end
	local scale = btn:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = btn
	end
	scale.Scale = 0.94
	tween(scale, Theme.Pop, { Scale = 1 })
	if flash then
		tween(btn, Theme.Fast, { BackgroundColor3 = original })
	end
end

local function parentGui()
	if type(gethui) == "function" then
		local ok, gui = pcall(gethui)
		if ok and gui then
			return gui
		end
	end
	local ok, gui = pcall(function()
		return CoreGui
	end)
	if ok and gui then
		return gui
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================================
-- 5 · root screen gui · reload bar · main window
-- ============================================================================
for _, old in ipairs(parentGui():GetChildren()) do
	if old.Name == "ElenaHubUI" or old.Name == "WindUI" or old.Name == "ElenaHubRestore" then
		old:Destroy()
	end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ElenaHubUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 2147483647
ScreenGui.Parent = parentGui()

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = Theme.WindowSize
MainFrame.Position = Theme.WindowPos
MainFrame.BackgroundColor3 = Theme.BgMain
MainFrame.BackgroundTransparency = Theme.BgMainAlpha
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Parent = ScreenGui
addCorner(MainFrame, Theme.Corner)
addStroke(MainFrame, Theme.StrokeAlpha, 1)

local MainScale = Instance.new("UIScale")
MainScale.Scale = 0.94
MainScale.Parent = MainFrame

local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 35, 48)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 14, 20)),
})
MainGradient.Rotation = 135
MainGradient.Parent = MainFrame

local ReloadTrack = Instance.new("Frame")
ReloadTrack.Name = "ReloadTrack"
ReloadTrack.Size = UDim2.new(1, 0, 0, RELOAD_H)
ReloadTrack.BackgroundTransparency = 1
ReloadTrack.ZIndex = 5
ReloadTrack.Parent = MainFrame

local ReloadFill = Instance.new("Frame")
ReloadFill.Size = UDim2.new(0, 0, 1, 0)
ReloadFill.BackgroundColor3 = Theme.Accent
ReloadFill.BorderSizePixel = 0
ReloadFill.Parent = ReloadTrack

-- ── top bar
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
TopBar.BackgroundColor3 = Theme.BgHeader
TopBar.BackgroundTransparency = Theme.BgHeaderAlpha
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -210, 1, 0)
TitleLabel.Position = UDim2.fromOffset(16, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "ELENA // SWORDS vs EGGS"
TitleLabel.TextColor3 = Theme.TextPrimary
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.Parent = TopBar

local SubLabel = Instance.new("TextLabel")
SubLabel.Size = UDim2.new(0, 110, 1, 0)
SubLabel.Position = UDim2.new(1, -186, 0, 0)
SubLabel.BackgroundTransparency = 1
SubLabel.Text = L("subTag")
SubLabel.TextColor3 = Theme.TextSecondary
SubLabel.TextXAlignment = Enum.TextXAlignment.Right
SubLabel.Font = Enum.Font.GothamMedium
SubLabel.TextSize = 11
SubLabel.Parent = TopBar

local function windowButton(text, xOffset, bg)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(28, 28)
	btn.Position = UDim2.new(1, xOffset, 0.5, -14)
	btn.BackgroundColor3 = bg
	btn.BackgroundTransparency = 0.25
	btn.Text = text
	btn.TextColor3 = Theme.TextPrimary
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = text == "×" and 16 or 15
	btn.AutoButtonColor = false
	btn.Parent = TopBar
	addCorner(btn, Theme.Small)
	addStroke(btn, 0.85, 1)
	return btn
end

local MinimizeBtn = windowButton("-", -68, Theme.BgButtonOff)
local CloseBtn = windowButton("×", -34, Color3.fromRGB(185, 28, 28))

-- ── telemetry
local TelemetryBar = Instance.new("Frame")
TelemetryBar.Name = "TelemetryBar"
TelemetryBar.Size = UDim2.new(1, 0, 0, TELEMETRY_H)
TelemetryBar.Position = UDim2.fromOffset(0, TOPBAR_H)
TelemetryBar.BackgroundColor3 = Theme.BgCard
TelemetryBar.BackgroundTransparency = 0.35
TelemetryBar.BorderSizePixel = 0
TelemetryBar.Parent = MainFrame

local Metrics = Instance.new("Frame")
Metrics.Size = UDim2.new(0.72, -10, 1, -10)
Metrics.Position = UDim2.fromOffset(10, 5)
Metrics.BackgroundTransparency = 1
Metrics.Parent = TelemetryBar

local MetricsList = Instance.new("UIListLayout")
MetricsList.FillDirection = Enum.FillDirection.Horizontal
MetricsList.VerticalAlignment = Enum.VerticalAlignment.Center
MetricsList.Padding = UDim.new(0, 6)
MetricsList.SortOrder = Enum.SortOrder.LayoutOrder
MetricsList.Parent = Metrics

local function metricPill(tag, order, width)
	local pill = Instance.new("Frame")
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(width, 24)
	pill.BackgroundColor3 = Theme.BgPill
	pill.BackgroundTransparency = 0.25
	pill.BorderSizePixel = 0
	pill.Parent = Metrics
	addCorner(pill, Theme.Pill)
	addStroke(pill, 0.88, 1)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tag .. " --"
	label.TextColor3 = Theme.TextPrimary
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 11
	label.Parent = pill
	return label
end

local FpsLabel = metricPill("FPS", 1, 66)
local CpuLabel = metricPill("CPU", 2, 78)
local GpuLabel = metricPill("GPU", 3, 78)

local StatusValue = Instance.new("TextLabel")
StatusValue.Size = UDim2.new(0.28, -14, 1, 0)
StatusValue.Position = UDim2.new(0.72, 0, 0, 0)
StatusValue.BackgroundTransparency = 1
StatusValue.Text = L("idle")
StatusValue.TextColor3 = Theme.TextPrimary
StatusValue.TextXAlignment = Enum.TextXAlignment.Right
StatusValue.Font = Enum.Font.GothamBold
StatusValue.TextSize = 11
StatusValue.Parent = TelemetryBar

-- ── floating mini bar (shown when minimized)
local Mini = Instance.new("Frame")
Mini.Name = "FloatingMini"
Mini.Size = UDim2.fromOffset(278, 52)
Mini.Position = UDim2.new(0.5, -139, 0.06, 0)
Mini.BackgroundColor3 = Theme.BgMain
Mini.BackgroundTransparency = 0.12
Mini.BorderSizePixel = 0
Mini.Visible = false
Mini.ZIndex = 10
Mini.Active = true
Mini.Parent = ScreenGui
addCorner(Mini, Theme.Small)
addStroke(Mini, Theme.StrokeAlpha, 1)

local MiniGradient = Instance.new("UIGradient")
MiniGradient.Color = MainGradient.Color
MiniGradient.Rotation = 135
MiniGradient.Parent = Mini

local MiniScale = Instance.new("UIScale")
MiniScale.Scale = 0.9
MiniScale.Parent = Mini

local MiniMetrics = Instance.new("Frame")
MiniMetrics.Size = UDim2.new(1, -66, 0, 22)
MiniMetrics.Position = UDim2.fromOffset(8, 6)
MiniMetrics.BackgroundTransparency = 1
MiniMetrics.Parent = Mini

local MiniList = Instance.new("UIListLayout")
MiniList.FillDirection = Enum.FillDirection.Horizontal
MiniList.Padding = UDim.new(0, 4)
MiniList.SortOrder = Enum.SortOrder.LayoutOrder
MiniList.Parent = MiniMetrics

local function miniPill(tag, order, width)
	local pill = Instance.new("Frame")
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(width, 20)
	pill.BackgroundColor3 = Theme.BgPill
	pill.BackgroundTransparency = 0.25
	pill.BorderSizePixel = 0
	pill.Parent = MiniMetrics
	addCorner(pill, Theme.Pill)
	addStroke(pill, 0.88, 1)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = tag .. " --"
	label.TextColor3 = Theme.TextPrimary
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 10
	label.Parent = pill
	return label
end

local MiniFps = miniPill("FPS", 1, 56)
local MiniCpu = miniPill("CPU", 2, 68)
local MiniGpu = miniPill("GPU", 3, 68)

local MiniStatus = Instance.new("TextLabel")
MiniStatus.Size = UDim2.new(1, -66, 0, 16)
MiniStatus.Position = UDim2.fromOffset(10, 30)
MiniStatus.BackgroundTransparency = 1
MiniStatus.Text = L("idle")
MiniStatus.TextColor3 = Theme.TextPrimary
MiniStatus.TextXAlignment = Enum.TextXAlignment.Left
MiniStatus.Font = Enum.Font.GothamBold
MiniStatus.TextSize = 10
MiniStatus.Parent = Mini

local ExpandBtn = Instance.new("TextButton")
ExpandBtn.Size = UDim2.fromOffset(26, 26)
ExpandBtn.Position = UDim2.new(1, -34, 0.5, -13)
ExpandBtn.BackgroundColor3 = Theme.BgButtonOn
ExpandBtn.BackgroundTransparency = 0.2
ExpandBtn.Text = "+"
ExpandBtn.TextColor3 = Theme.TextPrimary
ExpandBtn.Font = Enum.Font.GothamBold
ExpandBtn.TextSize = 15
ExpandBtn.AutoButtonColor = false
ExpandBtn.Parent = Mini
addCorner(ExpandBtn, Theme.Pill)
addStroke(ExpandBtn, 0.85, 1)

-- ── toasts (replaces the old WindUI notification layer)
local ToastHolder = Instance.new("Frame")
ToastHolder.Name = "Toasts"
ToastHolder.Size = UDim2.fromOffset(268, 260)
ToastHolder.Position = UDim2.new(1, -282, 1, -272)
ToastHolder.BackgroundTransparency = 1
ToastHolder.ZIndex = 50
ToastHolder.Parent = ScreenGui

local ToastList = Instance.new("UIListLayout")
ToastList.VerticalAlignment = Enum.VerticalAlignment.Bottom
ToastList.Padding = UDim.new(0, 6)
ToastList.SortOrder = Enum.SortOrder.LayoutOrder
ToastList.Parent = ToastHolder

local toastOrder = 0
local function notify(text, kind)
	if not alive() then
		return
	end
	toastOrder += 1
	local tick = Instance.new("Frame")
	tick.Size = UDim2.new(1, 0, 0, 40)
	tick.BackgroundColor3 = Theme.BgCard
	tick.BackgroundTransparency = 0.08
	tick.BorderSizePixel = 0
	tick.LayoutOrder = toastOrder
	tick.Parent = ToastHolder
	addCorner(tick, Theme.Small)
	addStroke(tick, 0.82, 1)

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 3, 1, -12)
	accent.Position = UDim2.fromOffset(0, 6)
	accent.BackgroundColor3 = kind == "bad" and Theme.Bad or (kind == "good" and Theme.Good or Theme.Accent)
	accent.BorderSizePixel = 0
	accent.Parent = tick

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -22, 1, -8)
	label.Position = UDim2.fromOffset(12, 4)
	label.BackgroundTransparency = 1
	label.Text = tostring(text)
	label.TextColor3 = Theme.TextPrimary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 11
	label.Parent = tick

	local pop = Instance.new("UIScale")
	pop.Scale = 0.92
	pop.Parent = tick
	tween(pop, Theme.Pop, { Scale = 1 })

	task.delay(2.8, function()
		pcall(function()
			tween(tick, Theme.Fast, { BackgroundTransparency = 1 })
			tween(label, Theme.Fast, { TextTransparency = 1 })
			tween(accent, Theme.Fast, { BackgroundTransparency = 1 })
			task.delay(0.25, function()
				pcall(function()
					tick:Destroy()
				end)
			end)
		end)
	end)
end

-- ── drag: whole top bar moves the window
do
	local dragging, dragStart, startPos = false, Vector2.zero, UDim2.new()

	TopBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = MainFrame.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			MainFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- keep the window reachable no matter where it gets dragged
local function clampWindow()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local size = MainFrame.AbsoluteSize
	local pos = MainFrame.AbsolutePosition
	local maxX = math.max(0, viewport.X - size.X)
	local maxY = math.max(0, viewport.Y - size.Y)
	local x = math.clamp(pos.X, 0, maxX)
	local y = math.clamp(pos.Y, 0, maxY)
	if math.abs(x - pos.X) > 1 or math.abs(y - pos.Y) > 1 then
		MainFrame.Position = UDim2.fromOffset(x, y)
	end
end

-- ── drag: mini bar
do
	local dragging, dragStart, startPos = false, Vector2.zero, UDim2.new()

	Mini.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Mini.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			Mini.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local minimized = false
local function setMinimized(state)
	minimized = state
	if state then
		local shrink = tween(MainScale, Theme.Fast, { Scale = 0.92 })
		shrink.Completed:Connect(function()
			if minimized then
				MainFrame.Visible = false
				Mini.Visible = true
				MiniScale.Scale = 0.88
				tween(MiniScale, Theme.Pop, { Scale = 1 })
			end
		end)
	else
		local shrink = tween(MiniScale, Theme.Fast, { Scale = 0.86 })
		shrink.Completed:Connect(function()
			if not minimized then
				Mini.Visible = false
				MainFrame.Visible = true
				MainScale.Scale = 0.94
				tween(MainScale, Theme.Pop, { Scale = 1 })
			end
		end)
	end
end

MiniStatus.InputBegan:Connect(function()
	setMinimized(false)
end)

-- ============================================================================
-- 6 · sidebar · pages
-- ============================================================================
local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Size = UDim2.new(1, 0, 1, -BODY_TOP)
Body.Position = UDim2.fromOffset(0, BODY_TOP)
Body.BackgroundTransparency = 1
Body.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 132, 1, 0)
Sidebar.BackgroundColor3 = Theme.BgHeader
Sidebar.BackgroundTransparency = 0.45
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Body
addPadding(Sidebar, 10)

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 6)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Parent = Sidebar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -132, 1, 0)
Content.Position = UDim2.fromOffset(132, 0)
Content.BackgroundTransparency = 1
Content.Parent = Body
addPadding(Content, 12)

local Pages = {}
local TabButtons = {}
local activeTab = "Main"

local function switchTab(name)
	activeTab = name
	for pageName, page in pairs(Pages) do
		page.Visible = pageName == name
		if pageName == name then
			page.Position = UDim2.new(0.04, 0, 0, 0)
			tween(page, Theme.TabAnim, { Position = UDim2.fromScale(0, 0) })
		end
	end
	for name2, btn in pairs(TabButtons) do
		local on = name2 == name
		tween(btn, Theme.TabAnim, {
			BackgroundColor3 = on and Theme.BgButtonOn or Theme.BgButtonOff,
			BackgroundTransparency = on and 0.25 or 0.55,
			TextColor3 = on and Theme.TextPrimary or Theme.TextSecondary,
		})
	end
end

local function createPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Theme.Accent
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = name == activeTab
	page.Parent = Content

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page

	Pages[name] = page
	return page
end

local function createTabButton(key, labelKey, order)
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = order
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = key == activeTab and Theme.BgButtonOn or Theme.BgButtonOff
	btn.BackgroundTransparency = key == activeTab and 0.25 or 0.55
	btn.Text = L(labelKey)
	btn.TextColor3 = key == activeTab and Theme.TextPrimary or Theme.TextSecondary
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 12
	btn.AutoButtonColor = false
	btn.Parent = Sidebar
	addCorner(btn, Theme.Small)
	addStroke(btn, 0.88, 1)

	btn.MouseButton1Click:Connect(function()
		pulse(btn)
		switchTab(key)
	end)

	TabButtons[key] = btn
	btn:SetAttribute("labelKey", labelKey)
end

local pageMain = createPage("Main")
local pageFarm = createPage("Farm")
local pageFind = createPage("Find")
local pageStatus = createPage("Status")
local pageConfig = createPage("Configs")
local pageSet = createPage("Settings")

createTabButton("Main", "tabMain", 1)
createTabButton("Farm", "tabFarm", 2)
createTabButton("Find", "tabFind", 3)
createTabButton("Status", "tabStatus", 4)
createTabButton("Configs", "tabConfig", 5)
createTabButton("Settings", "tabSet", 6)

-- ============================================================================
-- 7 · widget library
-- ============================================================================
local function fmt(value)
	if type(value) ~= "number" then
		return tostring(value)
	end
	if value ~= value then
		return "-"
	end
	local abs = math.abs(value)
	if abs >= 1e12 then
		return string.format("%.2fT", value / 1e12)
	elseif abs >= 1e9 then
		return string.format("%.2fB", value / 1e9)
	elseif abs >= 1e6 then
		return string.format("%.2fM", value / 1e6)
	elseif abs >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(math.floor(value))
end

local orderSeq = 0
local function nextOrder()
	orderSeq += 1
	return orderSeq
end

local function card(parent, height)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = nextOrder()
	frame.Size = UDim2.new(1, -4, 0, height)
	frame.BackgroundColor3 = Theme.BgCard
	frame.BackgroundTransparency = Theme.BgCardAlpha
	frame.BorderSizePixel = 0
	frame.Parent = parent
	addCorner(frame, Theme.Small)
	addStroke(frame, 0.88, 1)
	return frame
end

local function createSection(parent, key)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -4, 0, 26)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = nextOrder()
	holder.Parent = parent

	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromOffset(3, 14)
	bar.Position = UDim2.fromOffset(2, 6)
	bar.BackgroundColor3 = Theme.Accent
	bar.BorderSizePixel = 0
	bar.Parent = holder
	addCorner(bar, UDim.new(1, 0))

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -18, 1, 0)
	label.Position = UDim2.fromOffset(13, 0)
	label.BackgroundTransparency = 1
	label.Text = string.upper(L(key))
	label.TextColor3 = Theme.TextSecondary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.Parent = holder
	label:SetAttribute("i18nKey", key)
	label:SetAttribute("i18nUpper", true)

	return { Frame = holder, Label = label, Key = key }
end

local function createToggleCard(parent, titleKey, subKey, defaultState, onChange)
	local frame = card(parent, 62)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -90, 0, 20)
	title.Position = UDim2.fromOffset(12, 10)
	title.BackgroundTransparency = 1
	title.Text = L(titleKey)
	title.TextColor3 = Theme.TextPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 13
	title.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -90, 0, 16)
	sub.Position = UDim2.fromOffset(12, 32)
	sub.BackgroundTransparency = 1
	sub.Text = L(subKey)
	sub.TextColor3 = Theme.TextSecondary
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.Parent = frame

	local switch = Instance.new("TextButton")
	switch.Size = UDim2.fromOffset(46, 24)
	switch.Position = UDim2.new(1, -58, 0.5, -12)
	switch.BackgroundColor3 = defaultState and Theme.BgButtonOn or Theme.BgButtonOff
	switch.BackgroundTransparency = 0.15
	switch.Text = ""
	switch.AutoButtonColor = false
	switch.Parent = frame
	addCorner(switch, UDim.new(1, 0))

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = defaultState and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Theme.TextPrimary
	knob.BorderSizePixel = 0
	knob.Parent = switch
	addCorner(knob, UDim.new(1, 0))

	local active = defaultState
	local handle = { State = defaultState }

	function handle.Set(state)
		state = state and true or false
		active = state
		handle.State = state
		tween(frame, Theme.Fast, {
			BackgroundColor3 = state and Theme.BgCardActive or Theme.BgCard,
		})
		tween(switch, Theme.Fast, {
			BackgroundColor3 = state and Theme.BgButtonOn or Theme.BgButtonOff,
		})
		tween(knob, Theme.Pop, {
			Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
		})
	end

	function handle.SetSilent(state)
		handle.Set(state)
	end

	function handle.RefreshText()
		title.Text = L(titleKey)
		sub.Text = L(subKey)
	end

	switch.MouseButton1Click:Connect(function()
		handle.Set(not active)
		if onChange then
			local ok, err = pcall(onChange, active)
			if not ok then
				notify(tostring(err), "bad")
			end
		end
	end)

	return handle
end

local function createSliderCard(parent, titleKey, subKey, min, max, default, step, onChange)
	local frame = card(parent, 62)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -110, 0, 20)
	title.Position = UDim2.fromOffset(12, 10)
	title.BackgroundTransparency = 1
	title.Text = L(titleKey)
	title.TextColor3 = Theme.TextPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 13
	title.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -110, 0, 16)
	sub.Position = UDim2.fromOffset(12, 32)
	sub.BackgroundTransparency = 1
	sub.Text = L(subKey)
	sub.TextColor3 = Theme.TextSecondary
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.Parent = frame

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0, 92, 0, 20)
	valueLabel.Position = UDim2.new(1, -104, 0, 10)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = tostring(default)
	valueLabel.TextColor3 = Theme.Accent
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextSize = 13
	valueLabel.Parent = frame

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, 6)
	track.Position = UDim2.new(0, 12, 1, -11)
	track.BackgroundColor3 = Theme.BgInput
	track.BorderSizePixel = 0
	track.Parent = frame
	addCorner(track, UDim.new(1, 0))

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	addCorner(fill, UDim.new(1, 0))

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(14, 14)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = Theme.TextPrimary
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = track
	addCorner(knob, UDim.new(1, 0))
	addStroke(knob, 0.4, 2)

	local handle = { Value = default }
	local dragSource = nil

	local function render(value)
		local alpha = 0
		if max > min then
			alpha = math.clamp((value - min) / (max - min), 0, 1)
		end
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		valueLabel.Text = tostring(value)
	end

	local function commit(value)
		local snapped = value
		if step and step > 0 then
			snapped = math.floor((value / step) + 0.5) * step
		end
		snapped = math.clamp(snapped, min, max)
		if (step or 1) >= 1 then
			snapped = math.floor(snapped + 0.5)
		else
			snapped = math.floor(snapped * 100 + 0.5) / 100
		end
		handle.Value = snapped
		render(snapped)
		if onChange then
			pcall(onChange, snapped)
		end
	end

	local function valueFromX(x)
		local absPos = track.AbsolutePosition.X
		local absSize = math.max(track.AbsoluteSize.X, 1)
		local alpha = math.clamp((x - absPos) / absSize, 0, 1)
		return min + alpha * (max - min)
	end

	local function beginDrag(input)
		dragSource = input
		commit(valueFromX(input.Position.X))
	end

	for _, target in ipairs({ frame, track }) do
		target.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				beginDrag(input)
			end
		end)
	end

	UserInputService.InputChanged:Connect(function(input)
		if dragSource and (input == dragSource or input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				commit(valueFromX(input.Position.X))
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if dragSource and input == dragSource then
			dragSource = nil
		end
	end)

	function handle.Set(value)
		value = tonumber(value) or default
		handle.Value = math.clamp(value, min, max)
		render(handle.Value)
	end

	function handle.RefreshText()
		title.Text = L(titleKey)
		sub.Text = L(subKey)
	end

	render(default)
	return handle
end

local function createButtonCard(parent, titleKey, subKey, bgColor, onClick)
	local frame = card(parent, 62)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundColor3 = bgColor or Theme.BgButtonOff
	btn.BackgroundTransparency = 0.72
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = frame
	addCorner(btn, Theme.Small)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -50, 0, 20)
	title.Position = UDim2.fromOffset(12, 10)
	title.BackgroundTransparency = 1
	title.Text = L(titleKey)
	title.TextColor3 = Theme.TextPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 13
	title.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -50, 0, 16)
	sub.Position = UDim2.fromOffset(12, 32)
	sub.BackgroundTransparency = 1
	sub.Text = L(subKey)
	sub.TextColor3 = Theme.TextSecondary
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.Parent = frame

	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.fromOffset(24, 24)
	arrow.Position = UDim2.new(1, -36, 0.5, -12)
	arrow.BackgroundTransparency = 1
	arrow.Text = ">"
	arrow.TextColor3 = Theme.Accent
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 13
	arrow.Parent = frame

	local handle = { Frame = frame, Button = btn }
	btn.MouseButton1Click:Connect(function()
		pulse(btn, bgColor)
		if onClick then
			local ok, err = pcall(onClick)
			if not ok then
				notify(tostring(err), "bad")
			end
		end
	end)

	function handle.RefreshText()
		title.Text = L(titleKey)
		sub.Text = L(subKey)
	end

	return handle
end

local function createDropdownCard(parent, titleKey, subKey, values, defaultIndex, onChange)
	local rowHeight = 24
	local frame = card(parent, 62)
	frame.ClipsDescendants = false

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -190, 0, 20)
	title.Position = UDim2.fromOffset(12, 10)
	title.BackgroundTransparency = 1
	title.Text = L(titleKey)
	title.TextColor3 = Theme.TextPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 13
	title.Parent = frame

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -190, 0, 16)
	sub.Position = UDim2.fromOffset(12, 32)
	sub.BackgroundTransparency = 1
	sub.Text = L(subKey)
	sub.TextColor3 = Theme.TextSecondary
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.Parent = frame

	local selector = Instance.new("TextButton")
	selector.Size = UDim2.new(0, 168, 0, 28)
	selector.Position = UDim2.new(1, -180, 0.5, -14)
	selector.BackgroundColor3 = Theme.BgInput
	selector.BackgroundTransparency = 0.2
	selector.Text = tostring(values[defaultIndex] or values[1] or "-")
	selector.TextColor3 = Theme.TextPrimary
	selector.TextXAlignment = Enum.TextXAlignment.Left
	selector.Font = Enum.Font.GothamMedium
	selector.TextSize = 11
	selector.AutoButtonColor = false
	selector.TextTruncate = Enum.TextTruncate.AtEnd
	selector.Parent = frame
	addCorner(selector, Theme.Pill)
	addStroke(selector, 0.85, 1)
	addPadding(selector, 6)

	local chevron = Instance.new("TextLabel")
	chevron.Size = UDim2.fromOffset(20, 20)
	chevron.Position = UDim2.new(1, -24, 0.5, -10)
	chevron.BackgroundTransparency = 1
	chevron.Text = "v"
	chevron.TextColor3 = Theme.TextSecondary
	chevron.Font = Enum.Font.GothamBold
	chevron.TextSize = 10
	chevron.ZIndex = 3
	chevron.Parent = selector

	local listHolder = Instance.new("Frame")
	listHolder.Size = UDim2.new(1, -24, 0, 0)
	listHolder.Position = UDim2.fromOffset(12, 62)
	listHolder.BackgroundColor3 = Theme.BgInput
	listHolder.BackgroundTransparency = 0.08
	listHolder.BorderSizePixel = 0
	listHolder.ClipsDescendants = true
	listHolder.Visible = false
	listHolder.ZIndex = 4
	listHolder.Parent = frame
	addCorner(listHolder, Theme.Pill)
	addStroke(listHolder, 0.88, 1)

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 1)
	listLayout.Parent = listHolder

	local open = false
	local handle = { Value = values[defaultIndex] or values[1], Index = defaultIndex or 1 }
	local rowButtons = {}

	local function setOpen(state)
		open = state
		listHolder.Visible = state
		chevron.Text = state and "^" or "v"
		if state then
			listHolder.Size = UDim2.new(1, -24, 0, #values * rowHeight + 4)
			frame.Size = UDim2.new(1, -4, 0, 68 + #values * rowHeight)
		else
			listHolder.Size = UDim2.new(1, -24, 0, 0)
			frame.Size = UDim2.new(1, -4, 0, 62)
		end
	end

	local function buildRows()
		for _, row in ipairs(rowButtons) do
			row:Destroy()
		end
		rowButtons = {}
		for index, value in ipairs(values) do
			local row = Instance.new("TextButton")
			row.LayoutOrder = index
			row.Size = UDim2.new(1, -8, 0, rowHeight - 1)
			row.Position = UDim2.fromOffset(4, 0)
			row.BackgroundColor3 = index == handle.Index and Theme.BgCardActive or Theme.BgInput
			row.BackgroundTransparency = index == handle.Index and 0.1 or 1
			row.Text = "  " .. tostring(value)
			row.TextColor3 = index == handle.Index and Theme.Accent or Theme.TextPrimary
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Font = Enum.Font.GothamMedium
			row.TextSize = 11
			row.AutoButtonColor = false
			row.TextTruncate = Enum.TextTruncate.AtEnd
			row.ZIndex = 5
			row.Parent = listHolder

			row.MouseButton1Click:Connect(function()
				handle.Index = index
				handle.Value = value
				selector.Text = tostring(value)
				buildRows()
				setOpen(false)
				if onChange then
					local ok, err = pcall(onChange, value, index)
					if not ok then
						notify(tostring(err), "bad")
					end
				end
			end)

			table.insert(rowButtons, row)
		end
	end

	selector.MouseButton1Click:Connect(function()
		pulse(selector)
		setOpen(not open)
		if open then
			buildRows()
		end
	end)

	function handle.Set(values2, index)
		values = values2 or values
		for _, row in ipairs(rowButtons) do
			row:Destroy()
		end
		rowButtons = {}
		handle.Index = index or 1
		handle.Value = values[handle.Index]
		selector.Text = tostring(handle.Value or "-")
		if open then
			buildRows()
			setOpen(true)
		end
	end

	function handle.RefreshText()
		title.Text = L(titleKey)
		sub.Text = L(subKey)
	end

	return handle
end

local function createTextPanel(parent, titleKey, height, note)
	local frame = card(parent, height)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 0, 22)
	label.Position = UDim2.fromOffset(12, 6)
	label.BackgroundTransparency = 1
	label.Text = string.upper(L(titleKey))
	label.TextColor3 = Theme.TextSecondary
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamBold
	label.TextSize = 10
	label.Parent = frame
	label:SetAttribute("i18nKey", titleKey)
	label:SetAttribute("i18nUpper", true)

	local noteLabel
	noteLabel = Instance.new("TextLabel")
	noteLabel.Size = UDim2.new(0, 150, 0, 22)
	noteLabel.Position = UDim2.new(1, -162, 0, 6)
	noteLabel.BackgroundTransparency = 1
	noteLabel.Text = note or ""
	noteLabel.TextColor3 = Theme.Accent
	noteLabel.TextXAlignment = Enum.TextXAlignment.Right
	noteLabel.TextTruncate = Enum.TextTruncate.AtEnd
	noteLabel.Font = Enum.Font.Code
	noteLabel.TextSize = 10
	noteLabel.Parent = frame

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -16, 1, -36)
	scroll.Position = UDim2.fromOffset(8, 30)
	scroll.BackgroundColor3 = Theme.BgInput
	scroll.BackgroundTransparency = 0.45
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Theme.Accent
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
	scroll.ScrollingDirection = Enum.ScrollingDirection.XY
	scroll.Parent = frame
	addCorner(scroll, Theme.Pill)
	addPadding(scroll, 6)

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Text = ""
	text.TextColor3 = Theme.TextPrimary
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = false
	text.Font = Enum.Font.Code
	text.TextSize = 11
	text.AutomaticSize = Enum.AutomaticSize.XY
	text.Size = UDim2.fromOffset(0, 0)
	text.Parent = scroll

	local handle = { Frame = frame, Label = text, Scroll = scroll, Value = "" }

	function handle.Set(value)
		value = tostring(value or "")
		if value == handle.Value then
			return
		end
		handle.Value = value
		text.Text = value
		scroll.CanvasPosition = Vector2.zero
	end

	function handle.SetNote(value)
		if noteLabel then
			noteLabel.Text = tostring(value)
		end
	end

	function handle.RefreshText()
		label.Text = string.upper(L(titleKey))
	end

	return handle
end

-- ============================================================================
-- 8 · game plumbing
-- ============================================================================
local UI = {}

local function norm(value)
	return (string.lower(tostring(value)):gsub("[^%w]", ""))
end

local function humanoid()
	local char = LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function root()
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function myPlot()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("SlashOwnerUserId") == LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function treadmillDeck()
	local session = LocalPlayer:GetAttribute("TreadmillSessionCFrame")
	if typeof(session) == "CFrame" then
		return session
	end
	local plot = myPlot()
	local machine = plot and plot:FindFirstChild("PersonalTreadmill")
	local surface = machine and machine:FindFirstChild("TrainingSurface", true)
	if surface and surface:IsA("Attachment") then
		return surface.WorldCFrame * CFrame.new(0, 3, 0)
	end
	return nil
end

local function applySpeed()
	local hum = humanoid()
	if not hum then
		return
	end
	if S.speedOn and math.abs(hum.WalkSpeed - S.speedValue) > 0.5 then
		hum.WalkSpeed = S.speedValue
	end
end

local function parkOnTreadmill()
	if S.parking then
		return false
	end
	S.parking = true
	local ok, result = pcall(function()
		local hrp = root()
		local deck = treadmillDeck()
		if not hrp or not deck then
			return false
		end
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = deck
		return true
	end)
	S.parking = false
	if not ok then
		S.lastError = "park · " .. tostring(result)
		return false
	end
	if result then
		S.reparks += 1
	end
	return result
end

-- the server pins the root every render frame through this binding. it has to be
-- unbound or no teleport sticks and the session can never be left
local function releasePose()
	pcall(function()
		RunService:UnbindFromRenderStep("SlashTreadmillPose")
	end)
end

local function leaveTreadmill()
	S.treadmillOn = false
	S.misses = 0
	releasePose()

	if UI.treadmillToggle then
		UI.treadmillToggle.SetSilent(false)
	end

	local hrp, deck = root(), treadmillDeck()
	local target = deck and (deck * CFrame.new(0, 2, 18)) or nil
	if hrp and target then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = target
	end

	task.delay(0.3, function()
		if not alive() or S.treadmillOn then
			return
		end
		releasePose()
		local h = root()
		if h and target then
			h.CFrame = target
		end
	end)

	return true
end

-- ============================================================================
-- 9 · zone / egg / pet data
-- ============================================================================
local ZONE_ORDER = {}
for zoneKey, entry in pairs(GameConfig.ZoneEggs or {}) do
	local index = tonumber(tostring(zoneKey):match("%d+"))
	if index then
		table.insert(ZONE_ORDER, {
			index = index,
			key = zoneKey,
			eggs = entry.Eggs or {},
			folder = entry.Folder,
			theme = entry.Theme,
		})
	end
end
table.sort(ZONE_ORDER, function(a, b)
	return a.index < b.index
end)

local RARITY_TIER = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	Legendary = 5,
	Mythic = 6,
	Divine = 7,
	Cosmic = 8,
	Secret = 9,
	Celestial = 10,
	Void = 11,
	Inferno = 12,
	Omega = 13,
}

local function zoneLabel(entry)
	if not entry then
		return "-"
	end
	local name = (GameConfig.ZoneNames or {})[entry.index] or entry.theme or "Zone"
	return string.format("%d · %s", entry.index, name)
end

local function pad(text, width)
	text = tostring(text)
	if #text >= width then
		return text:sub(1, width)
	end
	return text .. string.rep(" ", width - #text)
end

local function petTable(zoneIndex)
	local pool = (GameConfig.Zones or {})[zoneIndex]
	if type(pool) ~= "table" then
		return "no pool data for this zone"
	end
	local sorted = table.clone(pool)
	table.sort(sorted, function(a, b)
		return (RARITY_TIER[a.Rarity] or 99) < (RARITY_TIER[b.Rarity] or 99)
	end)

	local lines = {}
	table.insert(lines, pad("PET", 18) .. pad("RARITY", 10) .. pad("ODDS", 18) .. pad("CASH", 11) .. "OWNED")
	for _, pet in ipairs(sorted) do
		local chance = tonumber(pet.Chance) or 0
		local odds = "-"
		if chance > 0 then
			odds = string.format("%.2f%%  1/%d", chance, math.floor(100 / chance + 0.5))
		end
		local owned = S.ownedPets[norm(pet.Name)] and "YES" or "-"
		table.insert(
			lines,
			pad(pet.Name, 18) .. pad(pet.Rarity or "?", 10) .. pad(odds, 18) .. pad("$" .. fmt(pet.Cash or 0), 11) .. owned
		)
	end
	return table.concat(lines, "\n")
end

local function eggTable(entry)
	if not entry then
		return "-"
	end
	local lines = {}
	for _, eggName in ipairs(entry.eggs) do
		local def = (GameConfig.Eggs or {})[eggName]
		if type(def) == "table" then
			table.insert(
				lines,
				pad(eggName, 20) .. pad("HP " .. tostring(def.Health or "?"), 14) .. "LUCK x" .. tostring(def.Luck or "?")
			)
		else
			table.insert(lines, pad(eggName, 20) .. "no data")
		end
	end
	if #lines == 0 then
		return "no eggs listed"
	end
	return table.concat(lines, "\n")
end

local function findZone(value)
	for _, entry in ipairs(ZONE_ORDER) do
		if zoneLabel(entry) == value then
			return entry
		end
	end
	return ZONE_ORDER[1]
end

-- ============================================================================
-- 10 · profile pull
-- ============================================================================
local function refreshProfile()
	if S.condensing then
		return
	end
	S.condensing = true
	S.profileAt = os.clock()
	task.spawn(function()
		local ok, state = pcall(function()
			return ReplicatedStorage.SlashGameplay.GetState:InvokeServer()
		end)
		if ok and type(state) == "table" and type(state.Profile) == "table" then
			local profile = state.Profile
			S.profile = profile
			S.profileLoaded = true

			local owned, kinds, count = {}, {}, 0
			for _, item in pairs(type(profile.Items) == "table" and profile.Items or {}) do
				if type(item) == "table" then
					local kind = item.Kind or "?"
					kinds[kind] = (kinds[kind] or 0) + 1
					if kind == "Pet" and type(item.DefinitionId) == "string" then
						owned[norm(item.DefinitionId:gsub("^Pet:", ""))] = true
						count += 1
					end
				end
			end
			S.ownedPets = owned
			S.ownedKinds = kinds
			S.ownedCount = count
		elseif not ok then
			S.lastError = "profile · " .. tostring(state)
		end
		S.condensing = false
	end)
end

-- ============================================================================
-- 11 · safe zone · pickups · steal engine
-- ============================================================================
local szCache, szAt = nil, 0

local function safeZone()
	if szCache and szCache.Parent and os.clock() - szAt < 4 then
		return szCache
	end
	local build = workspace:FindFirstChild("Build")
	local hit = build and build:FindFirstChild("ZoneHitboxes")
	local zone = hit and hit:FindFirstChild("SafeZone")
	if zone and zone:IsA("BasePart") then
		szCache, szAt = zone, os.clock()
		return zone
	end
	return nil
end

local function insideSafe()
	local zone, hrp = safeZone(), root()
	if not (zone and hrp) then
		return false
	end
	local localPos = zone.CFrame:PointToObjectSpace(hrp.Position)
	local half = zone.Size / 2 + Vector3.new(2, 8, 2)
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

-- enters from the near face: same side as whoever is coming, just inside the lip
local function dashToSafe(fromPosition)
	local zone, hrp = safeZone(), root()
	if not (zone and hrp) then
		return false
	end
	releasePose()
	local probe = fromPosition or hrp.Position
	local localPos = zone.CFrame:PointToObjectSpace(probe)
	local dir = Vector3.new(localPos.X, 0, localPos.Z)
	if dir.Magnitude < 1 then
		dir = Vector3.new(0, 0, 1)
	end
	dir = dir.Unit

	local x = dir.X * math.max(0, zone.Size.X / 2 - 6)
	local z = dir.Z * math.max(0, zone.Size.Z / 2 - 6)
	local target = zone.CFrame * CFrame.new(x, zone.Size.Y / 2 + 3, z)

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = target
	return true
end

local function pickupsFolder()
	local runtime = workspace:FindFirstChild("SlashRuntime")
	return runtime and runtime:FindFirstChild("Pickups")
end

local function anchorPart(inst)
	if inst:IsA("BasePart") then
		return inst
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function findStealTarget()
	local folder = pickupsFolder()
	local hrp = root()
	if not (folder and hrp) then
		return nil
	end

	local best, bestDist = nil, math.huge
	for _, child in ipairs(folder:GetChildren()) do
		local prompt = child:FindFirstChildWhichIsA("ProximityPrompt", true)
		local part = anchorPart(child)
		if prompt and prompt.Enabled and part then
			local custodian = child:GetAttribute("Custodian")
			local taken = type(custodian) == "number"
				and custodian > 0
				and custodian ~= LocalPlayer.UserId
				and Players:GetPlayerByUserId(custodian) ~= nil
			local endsAt = child:GetAttribute("PickupEndsAt")
			local expired = type(endsAt) == "number" and endsAt > 1e9 and endsAt < os.time()
			if not taken and not expired then
				local dist = (part.Position - hrp.Position).Magnitude
				if dist < bestDist then
					best, bestDist = { object = child, part = part, prompt = prompt, dist = dist }, dist
				end
			end
		end
	end
	return best
end

local function firePrompt(prompt)
	if type(fireproximityprompt) == "function" then
		local ok = pcall(fireproximityprompt, prompt)
		if ok then
			return true
		end
	end
	local held = pcall(function()
		prompt:InputHoldBegin()
	end)
	if held then
		task.wait(math.max(tonumber(prompt.HoldDuration) or 0.4, 0.05) + 0.08)
		pcall(function()
			prompt:InputHoldEnd()
		end)
		return true
	end
	return false
end

local function waitForCarry(seconds)
	local deadline = os.clock() + (seconds or 2)
	while os.clock() < deadline do
		local carrying = LocalPlayer:GetAttribute("SlashCarrying")
		if carrying and carrying ~= false then
			return true
		end
		task.wait(0.06)
	end
	local final = LocalPlayer:GetAttribute("SlashCarrying")
	return final ~= nil and final ~= false
end

local STEAL_OFFSETS = {
	Vector3.new(0, 2.6, 0),
	Vector3.new(0, 1, 5),
	Vector3.new(0, 0, -5),
	Vector3.new(0, -2.5, 0),
}

local function attemptSteal()
	local target = findStealTarget()
	if not target then
		return false, "no pickup"
	end
	local hrp = root()
	if not hrp then
		return false, "no character"
	end

	S.stealPhase = "teleport ke pet"
	local everPlaced = false

	for _, offset in ipairs(STEAL_OFFSETS) do
		local goal = target.part.Position + offset
		local placed = false

		-- the treadmill pose binding snaps the root back every render frame, so
		-- the teleport has to be re-applied after unbinding and then verified
		for _ = 1, 3 do
			releasePose()
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(goal)
			task.wait(0.1)
			if (hrp.Position - target.part.Position).Magnitude < 12 then
				placed = true
				everPlaced = true
				break
			end
		end

		if placed then
			S.stealPhase = "trigger steal"
			firePrompt(target.prompt)
			if waitForCarry(1.2) then
				return true, "carrying"
			end
			if not alive() or S.stealAbort then
				return false, "aborted"
			end
		end
	end

	return false, everPlaced and "prompt denied" or "teleport blocked"
end

local function bankLoop()
	local started = os.clock()
	local timeout = 14
	while alive() and not S.stealAbort do
		if not LocalPlayer:GetAttribute("SlashCarrying") then
			return true, os.clock() - started
		end
		if os.clock() - started > timeout then
			return false, os.clock() - started
		end
		if not insideSafe() then
			dashToSafe()
		end
		if LocalPlayer:GetAttribute("BeingChased") and S.antiGuard then
			dashToSafe()
		end
		task.wait(0.25)
	end
	return false, os.clock() - started
end

local function stealCycle(silent)
	S.stealAbort = false
	-- the treadmill pose binding would drag us straight back to the deck
	if S.treadmillOn then
		leaveTreadmill()
	else
		releasePose()
	end

	S.stealPhase = "cari target"
	local ok, reason = attemptSteal()

	if not ok then
		S.stealFails += 1
		S.stealPhase = reason
		S.stealLast = string.format("gagal · %s", tostring(reason))
		if not silent then
			notify("steal gagal · " .. tostring(reason), "bad")
		end
		return false
	end

	S.stealPhase = "lari ke safe zone"
	dashToSafe()
	task.wait(0.15)

	S.stealPhase = "nahan carry di safe zone"
	local banked, seconds = bankLoop()

	if banked then
		S.stealCount += 1
		S.stealPhase = "banked"
		S.stealLast = string.format("banked · %.1fs", seconds)
		if not silent then
			notify(string.format("pet masuk · total %d", S.stealCount), "good")
		end
	else
		S.stealFails += 1
		S.stealPhase = "carry tidak selesai"
		S.stealLast = string.format("carry %.0fs tanpa bank", seconds)
	end
	return banked
end

local function stealLoop()
	if S.stealRunning then
		return
	end
	S.stealRunning = true

	task.spawn(function()
		while alive() and S.stealOn do
			local carrying = LocalPlayer:GetAttribute("SlashCarrying")
			if carrying then
				-- already holding something: finish the run instead of stacking
				S.stealPhase = "bawa carry lama"
				dashToSafe()
				local banked, seconds = bankLoop()
				S.stealLast = banked and string.format("banked lama · %.1fs", seconds)
					or string.format("carry %.0fs tanpa bank", seconds)
			else
				stealCycle(true)
			end

			local waited = 0
			while alive() and S.stealOn and waited < S.stealDelay do
				task.wait(0.1)
				waited += 0.1
			end
		end
		S.stealRunning = false
		if alive() then
			S.stealPhase = "idle"
		end
	end)
end

-- ============================================================================
-- 12 · protections
-- ============================================================================
local guardCooldown = 0
local function guardTick()
	if not S.antiGuard then
		return
	end
	if os.clock() < guardCooldown then
		return
	end
	if not LocalPlayer:GetAttribute("BeingChased") then
		return
	end
	guardCooldown = os.clock() + 1.2

	if LocalPlayer:GetAttribute("SlashCarrying") then
		dashToSafe()
	elseif not insideSafe() then
		local plot = myPlot()
		local spawn = plot and plot:FindFirstChild("SpawnPoint")
		local hrp = root()
		if spawn and hrp then
			releasePose()
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
		end
	end
end

local function ragTick()
	local hum = humanoid()
	if not hum then
		return
	end
	local state = hum:GetState()
	if state ~= Enum.HumanoidStateType.Ragdoll and state ~= Enum.HumanoidStateType.Physics then
		return
	end
	if S.baseHip == nil then
		S.baseHip = hum.HipHeight
	end
	hum.PlatformStand = false
	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end)
	if S.baseHip and math.abs(hum.HipHeight - S.baseHip) > 0.1 then
		hum.HipHeight = S.baseHip
	end
	local hrp = root()
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
	end
end

local function afkTick()
	if not S.antiAfk then
		return
	end
	pcall(function()
		VirtualUser:CaptureController()
	end)
	pcall(function()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end

-- ============================================================================
-- 13 · main page
-- ============================================================================
local function toggleSpeed(force)
	local state = force
	if state == nil then
		state = not S.speedOn
	end
	S.speedOn = state
	if UI.speedToggle then
		UI.speedToggle.SetSilent(state)
	end
	if state then
		applySpeed()
		notify("speed on · " .. tostring(S.speedValue))
	else
		local hum = humanoid()
		if hum then
			hum.WalkSpeed = 16
		end
		notify("speed off")
	end
end

createSection(pageMain, "secSpeed")

UI.speedToggle = createToggleCard(pageMain, "fastWalk", "fastWalkSub", false, function(state)
	S.speedOn = state
	if state then
		applySpeed()
		notify("speed on · " .. tostring(S.speedValue))
	else
		local hum = humanoid()
		if hum then
			hum.WalkSpeed = 16
		end
	end
end)

UI.speedSlider = createSliderCard(pageMain, "speedVal", "speedValSub", 16, 2000, 180, 1, function(value)
	S.speedValue = value
	applySpeed()
end)

UI.speedKey = createButtonCard(pageMain, "keybind", "keybindSub", Theme.BgButtonOn, function()
	toggleSpeed()
end)

createButtonCard(pageMain, "resetSpeed", "resetSpeedSub", Theme.BgButtonOff, function()
	S.speedOn = false
	UI.speedToggle.SetSilent(false)
	local hum = humanoid()
	if hum then
		hum.WalkSpeed = 16
	end
	notify("walk speed reset")
end)

createSection(pageMain, "secWindow")

createButtonCard(pageMain, "minimize", "minimizeSub", Theme.BgButtonOff, function()
	setMinimized(true)
end)

-- ============================================================================
-- 14 · farm page
-- ============================================================================
createSection(pageFarm, "secTread")

UI.treadmillToggle = createToggleCard(pageFarm, "treadOn", "treadOnSub", false, function(state)
	if state then
		S.treadmillOn = true
		S.misses = 0
		notify("auto treadmill on")
	else
		leaveTreadmill()
		notify("stepped off · released")
	end
end)

createButtonCard(pageFarm, "treadStop", "treadStopSub", Theme.BgButtonOff, function()
	leaveTreadmill()
	notify("stepped off · released")
end)

createButtonCard(pageFarm, "treadPark", "treadParkSub", Theme.BgCardActive, function()
	local ok = parkOnTreadmill()
	notify(ok and "parked on your deck" or "treadmill not found", ok and "good" or "bad")
end)

createButtonCard(pageFarm, "tpPlot", "tpPlotSub", Theme.BgButtonOff, function()
	local plot = myPlot()
	local spawn = plot and plot:FindFirstChild("SpawnPoint")
	local hrp = root()
	if spawn and hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = spawn.CFrame + Vector3.new(0, 4, 0)
		notify("to your plot")
	else
		notify("plot not found", "bad")
	end
end)

UI.sessionPanel = createTextPanel(pageFarm, "liveTitle", 92)

createSection(pageFarm, "secSteal")

UI.stealToggle = createToggleCard(pageFarm, "stealOn", "stealOnSub", false, function(state)
	S.stealOn = state
	S.stealAbort = not state
	if state then
		stealLoop()
		notify("auto steal on")
	else
		S.stealPhase = "idle"
		notify("auto steal off")
	end
end)

UI.stealDelay = createSliderCard(pageFarm, "stealDelay", "stealDelaySub", 0.2, 6, S.stealDelay, 0.1, function(value)
	S.stealDelay = value
end)

createButtonCard(pageFarm, "stealOnce", "stealOnceSub", Theme.BgButtonOn, function()
	task.spawn(function()
		stealCycle(false)
	end)
end)

UI.stealPanel = createTextPanel(pageFarm, "stealInfo", 104)

createSection(pageFarm, "secGuard")

UI.afkToggle = createToggleCard(pageFarm, "antiAfk", "antiAfkSub", S.antiAfk, function(state)
	S.antiAfk = state
	notify("anti afk " .. (state and "on" or "off"))
end)

UI.ragToggle = createToggleCard(pageFarm, "antiRag", "antiRagSub", S.antiRag, function(state)
	S.antiRag = state
	notify("anti ragdoll " .. (state and "on" or "off"))
end)

UI.guardToggle = createToggleCard(pageFarm, "antiGuard", "antiGuardSub", S.antiGuard, function(state)
	S.antiGuard = state
	notify("anti guard " .. (state and "on" or "off"))
end)

-- ============================================================================
-- 15 · finder page
-- ============================================================================
createSection(pageFind, "secFinder")

local zoneValues = {}
for _, entry in ipairs(ZONE_ORDER) do
	table.insert(zoneValues, zoneLabel(entry))
end

UI.eggsPanel = createTextPanel(pageFind, "eggsTitle", 118)
UI.poolPanel = createTextPanel(pageFind, "poolTitle", 196)
UI.ownedPanel = createTextPanel(pageFind, "ownedTitle", 92)

local function renderZone(entry)
	if not entry then
		return
	end
	S.zone = entry
	UI.eggsPanel.Set(eggTable(entry))
	UI.eggsPanel.SetNote(zoneLabel(entry))
	UI.poolPanel.Set(petTable(entry.index))

	local kinds = {}
	for kind, count in pairs(S.ownedKinds) do
		table.insert(kinds, string.format("%s: %d", kind, count))
	end
	table.sort(kinds)
	UI.ownedPanel.Set(string.format("%d pets owned\n%s", S.ownedCount, #kinds > 0 and table.concat(kinds, " · ") or "waiting on profile…"))
end

UI.zoneSelect = createDropdownCard(pageFind, "zone", "zoneSub", zoneValues, 1, function()
	renderZone(findZone(UI.zoneSelect.Value))
end)

createButtonCard(pageFind, "refreshOwn", "refreshOwnSub", Theme.BgCardActive, function()
	refreshProfile()
	task.delay(2.5, function()
		if alive() and S.zone then
			renderZone(S.zone)
			notify("ownership refreshed", "good")
		end
	end)
end)

createButtonCard(pageFind, "scanAll", "scanAllSub", Theme.BgButtonOff, function()
	for _, entry in ipairs(ZONE_ORDER) do
		print(("── zone %d · %s ──"):format(entry.index, zoneLabel(entry)))
		print(eggTable(entry))
		print(petTable(entry.index))
	end
	notify("full map printed to console")
end)

-- ============================================================================
-- 16 · status page
-- ============================================================================
createSection(pageStatus, "secLive")

UI.statusPanel = createTextPanel(pageStatus, "liveTitle", 226)
UI.invPanel = createTextPanel(pageStatus, "invTitle", 128)

createButtonCard(pageStatus, "refreshStatus", "refreshStatusSub", Theme.BgCardActive, function()
	refreshProfile()
	notify("profile requested")
end)

local function buildStatus()
	local gameplay = type(S.profile.Gameplay) == "table" and S.profile.Gameplay or {}
	local hum = humanoid()
	local lines = {
		"speed power    " .. fmt(LocalPlayer:GetAttribute("SpeedPower") or gameplay.Speed or 0),
		"gain / sec     " .. fmt(S.gainValue),
		"walk speed     " .. tostring(hum and hum.WalkSpeed or "?"),
		"cash           $" .. fmt(gameplay.Cash or 0),
		"treadmill lvl  " .. tostring(gameplay.TreadmillLevel or "?"),
		"coop level     " .. tostring(gameplay.CoopLevel or "?"),
		"carrying       " .. tostring(LocalPlayer:GetAttribute("SlashCarrying") or "no"),
		"being chased   " .. tostring(LocalPlayer:GetAttribute("BeingChased") or "no"),
		"inside safe    " .. tostring(insideSafe()),
		"pets owned     " .. tostring(S.ownedCount),
		"re-parks       " .. tostring(S.reparks),
		"last error     " .. (S.lastError ~= "" and S.lastError or "none"),
	}
	UI.statusPanel.Set(table.concat(lines, "\n"))

	local kinds = {}
	for kind, count in pairs(S.ownedKinds) do
		table.insert(kinds, string.format("%-12s %d", kind, count))
	end
	table.sort(kinds)
	UI.invPanel.Set(#kinds > 0 and table.concat(kinds, "\n") or "waiting on profile…")
end

-- ============================================================================
-- 17 · config page
-- ============================================================================
local function captureProfile()
	return {
		SpeedValue = S.speedValue,
		SpeedOn = S.speedOn,
		Treadmill = S.treadmillOn,
		AntiAfk = S.antiAfk,
		AntiRag = S.antiRag,
		AntiGuard = S.antiGuard,
		StealDelay = S.stealDelay,
	}
end

local function applyProfile(profile)
	profile = profile or DEFAULT_PROFILE

	S.speedValue = tonumber(profile.SpeedValue) or 180
	S.speedOn = profile.SpeedOn and true or false
	S.antiAfk = profile.AntiAfk ~= false
	S.antiRag = profile.AntiRag ~= false
	S.antiGuard = profile.AntiGuard ~= false
	S.stealDelay = tonumber(profile.StealDelay) or 1.2

	if UI.speedSlider then
		UI.speedSlider.Set(S.speedValue)
	end
	if UI.speedToggle then
		UI.speedToggle.SetSilent(S.speedOn)
	end
	if UI.afkToggle then
		UI.afkToggle.SetSilent(S.antiAfk)
	end
	if UI.ragToggle then
		UI.ragToggle.SetSilent(S.antiRag)
	end
	if UI.guardToggle then
		UI.guardToggle.SetSilent(S.antiGuard)
	end
	if UI.stealDelay then
		UI.stealDelay.Set(S.stealDelay)
	end

	if S.speedOn then
		applySpeed()
	else
		local hum = humanoid()
		if hum then
			hum.WalkSpeed = 16
		end
	end

	if profile.Treadmill then
		S.treadmillOn = true
		UI.treadmillToggle.SetSilent(true)
	elseif S.treadmillOn then
		leaveTreadmill()
	end
end

do
	local manager = card(pageConfig, 118)

	local meta = Instance.new("TextLabel")
	meta.Size = UDim2.new(1, -24, 0, 18)
	meta.Position = UDim2.fromOffset(12, 10)
	meta.BackgroundTransparency = 1
	meta.Text = ""
	meta.TextColor3 = Theme.TextSecondary
	meta.TextXAlignment = Enum.TextXAlignment.Left
	meta.Font = Enum.Font.GothamMedium
	meta.TextSize = 11
	meta.Parent = manager

	local input = Instance.new("TextBox")
	input.Size = UDim2.new(1, -24, 0, 32)
	input.Position = UDim2.fromOffset(12, 34)
	input.BackgroundColor3 = Theme.BgInput
	input.BackgroundTransparency = 0.2
	input.Text = Store.selected
	input.PlaceholderText = L("configPlaceholder")
	input.PlaceholderColor3 = Theme.TextSecondary
	input.TextColor3 = Theme.TextPrimary
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.ClearTextOnFocus = false
	input.Font = Enum.Font.GothamMedium
	input.TextSize = 12
	input.Parent = manager
	addCorner(input, Theme.Pill)
	addStroke(input, 0.85, 1)
	addPadding(input, 8)

	local function actionButton(labelKey, xScale, widthScale, bg)
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(widthScale, -10, 0, 30)
		btn.Position = UDim2.new(xScale, 12, 0, 74)
		btn.BackgroundColor3 = bg
		btn.BackgroundTransparency = 0.2
		btn.Text = L(labelKey)
		btn.TextColor3 = Theme.TextPrimary
		btn.Font = Enum.Font.GothamSemibold
		btn.TextSize = 11
		btn.AutoButtonColor = false
		btn.Parent = manager
		addCorner(btn, Theme.Pill)
		addStroke(btn, 0.85, 1)
		btn:SetAttribute("i18nKey", labelKey)
		return btn
	end

	local historyCard = card(pageConfig, 152)

	local historyTitle = Instance.new("TextLabel")
	historyTitle.Size = UDim2.new(1, -24, 0, 22)
	historyTitle.Position = UDim2.fromOffset(12, 8)
	historyTitle.BackgroundTransparency = 1
	historyTitle.Text = L("historyTitle")
	historyTitle.TextColor3 = Theme.TextPrimary
	historyTitle.TextXAlignment = Enum.TextXAlignment.Left
	historyTitle.Font = Enum.Font.GothamSemibold
	historyTitle.TextSize = 12
	historyTitle.Parent = historyCard
	historyTitle:SetAttribute("i18nKey", "historyTitle")

	local historyScroll = Instance.new("ScrollingFrame")
	historyScroll.Size = UDim2.new(1, -20, 1, -38)
	historyScroll.Position = UDim2.fromOffset(10, 32)
	historyScroll.BackgroundColor3 = Theme.BgInput
	historyScroll.BackgroundTransparency = 0.35
	historyScroll.BorderSizePixel = 0
	historyScroll.ScrollBarThickness = 3
	historyScroll.ScrollBarImageColor3 = Theme.Accent
	historyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	historyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	historyScroll.Parent = historyCard
	addCorner(historyScroll, Theme.Pill)
	addPadding(historyScroll, 6)

	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = historyScroll

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder

	local function sanitize(raw)
		local trimmed = tostring(raw or ""):gsub("^%s*(.-)%s*$", "%1")
		local cleaned = trimmed:gsub("[^%w_%-]", "_")
		if #cleaned == 0 then
			cleaned = "default"
		end
		return cleaned:sub(1, 24)
	end

	local function renderHistory()
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		if #Store.history == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 18)
			empty.BackgroundTransparency = 1
			empty.Text = L("historyEmpty")
			empty.TextColor3 = Theme.TextSecondary
			empty.TextXAlignment = Enum.TextXAlignment.Left
			empty.Font = Enum.Font.Gotham
			empty.TextSize = 11
			empty.Parent = holder
			return
		end
		for index, item in ipairs(Store.history) do
			local row = Instance.new("TextLabel")
			row.LayoutOrder = index
			row.Size = UDim2.new(1, 0, 0, 17)
			row.BackgroundTransparency = 1
			row.Text = string.format("[%s] %s > %s", tostring(item.timeLabel), tostring(item.action), tostring(item.configName))
			row.TextColor3 = (item.action == "SAVE" or item.action == "CREATE") and Theme.Good
				or (item.action == "LOAD" and Theme.Accent or Theme.TextSecondary)
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Font = Enum.Font.Code
			row.TextSize = 11
			row.Parent = holder
		end
	end

	local function refreshMeta()
		local count = 0
		for _ in pairs(Store.profiles) do
			count += 1
		end
		meta.Text = string.format(L("configMeta"), Store.selected, count)
	end

	local lastStamp, lastKey = 0, ""
	local function pushHistory(action, name)
		local now = os.clock()
		local key = action .. ":" .. name
		if key == lastKey and now - lastStamp < 0.5 then
			return
		end
		lastStamp, lastKey = now, key
		table.insert(Store.history, 1, {
			action = action,
			configName = name,
			timeLabel = os.date("%H:%M:%S"),
		})
		trimHistory(Store.history)
		saveStore()
		renderHistory()
	end

	local btnCreate = actionButton("btnCreate", 0, 0.34, Theme.BgButtonOff)
	local btnSave = actionButton("btnSave", 0.34, 0.33, Theme.BgSuccess)
	local btnLoad = actionButton("btnLoad", 0.67, 0.33, Theme.BgButtonOn)

	btnCreate.MouseButton1Click:Connect(function()
		pulse(btnCreate, Theme.Accent)
		local name = sanitize(input.Text)
		Store.profiles[name] = captureProfile()
		Store.selected = name
		input.Text = name
		saveStore()
		refreshMeta()
		pushHistory("CREATE", name)
		notify("config dibuat · " .. name, "good")
	end)

	btnSave.MouseButton1Click:Connect(function()
		pulse(btnSave, Theme.Good)
		local name = sanitize(input.Text)
		Store.profiles[name] = captureProfile()
		Store.selected = name
		saveStore()
		refreshMeta()
		pushHistory("SAVE", name)
		notify("config disimpan · " .. name, "good")
	end)

	btnLoad.MouseButton1Click:Connect(function()
		pulse(btnLoad, Theme.Accent)
		local name = sanitize(input.Text)
		local profile = Store.profiles[name]
		if not profile then
			pushHistory("MISSING", name)
			notify("config tidak ada · " .. name, "bad")
			return
		end
		Store.selected = name
		input.Text = name
		applyProfile(profile)
		saveStore()
		refreshMeta()
		pushHistory("LOAD", name)
		notify("config dimuat · " .. name, "good")
	end)

	UI.refreshConfigUi = function()
		meta.Text = string.format(L("configMeta"), Store.selected, (function()
			local count = 0
			for _ in pairs(Store.profiles) do
				count += 1
			end
			return count
		end)())
		renderHistory()
	end

	refreshMeta()
	renderHistory()
end

-- ============================================================================
-- 18 · settings page
-- ============================================================================
createSection(pageSet, "secUi")

do
	local langCard = card(pageSet, 58)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -90, 0, 20)
	title.Position = UDim2.fromOffset(12, 8)
	title.BackgroundTransparency = 1
	title.Text = L("langTitle")
	title.TextColor3 = Theme.TextPrimary
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 13
	title.Parent = langCard
	title:SetAttribute("i18nKey", "langTitle")

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -90, 0, 16)
	sub.Position = UDim2.fromOffset(12, 30)
	sub.BackgroundTransparency = 1
	sub.Text = L("langSub")
	sub.TextColor3 = Theme.TextSecondary
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.Parent = langCard
	sub:SetAttribute("i18nKey", "langSub")

	local langBtn = Instance.new("TextButton")
	langBtn.Size = UDim2.fromOffset(48, 26)
	langBtn.Position = UDim2.new(1, -60, 0.5, -13)
	langBtn.BackgroundColor3 = Theme.BgButtonOn
	langBtn.BackgroundTransparency = 0.2
	langBtn.Text = LANG == 1 and "EN" or "ID"
	langBtn.TextColor3 = Theme.TextPrimary
	langBtn.Font = Enum.Font.GothamBold
	langBtn.TextSize = 12
	langBtn.AutoButtonColor = false
	langBtn.Parent = langCard
	addCorner(langBtn, Theme.Pill)
	addStroke(langBtn, 0.85, 1)

	UI.langButton = langBtn
end

UI.scaleSlider = createSliderCard(pageSet, "uiScale", "uiScaleSub", 0.7, 1.3, 1, 0.05, function(value)
	MainScale.Scale = value
	MiniScale.Scale = value * 0.9
end)

createSection(pageSet, "secDanger")

createButtonCard(pageSet, "closeHub", "closeHubSub", Color3.fromRGB(140, 30, 30), function()
	HUB.cleanup()
end)

-- ============================================================================
-- 19 · language pass · every label is re-resolved from its own text
-- ============================================================================
local REVERSE = {}
for key, entry in pairs(T) do
	for index = 1, 2 do
		if type(entry[index]) == "string" then
			REVERSE[string.lower(entry[index])] = key
		end
	end
end

local function refreshLanguage()
	for _, inst in ipairs(ScreenGui:GetDescendants()) do
		local key = inst:GetAttribute("i18nKey")
		if type(key) == "string" then
			local text = L(key)
			if inst:GetAttribute("i18nUpper") then
				text = string.upper(text)
			end
			inst.Text = text
		elseif (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text ~= "" then
			local found = REVERSE[string.lower(inst.Text)]
			if found then
				inst.Text = L(found)
			end
		end
	end
	if UI.langButton then
		UI.langButton.Text = LANG == 1 and "EN" or "ID"
	end
	UI.refreshConfigUi()
end

UI.langButton.MouseButton1Click:Connect(function()
	pulse(UI.langButton)
	LANG = LANG == 1 and 2 or 1
	S.lang = LANG
	Store.language = LANG == 1 and "en" or "id"
	saveStore()
	refreshLanguage()
end)

-- ============================================================================
-- 20 · loops
-- ============================================================================
table.insert(
	S.connections,
	LocalPlayer.Idled:Connect(function()
		afkTick()
	end)
)

table.insert(
	S.connections,
	RunService.Heartbeat:Connect(function()
		if not alive() then
			return
		end
		local now = os.clock()

		if now - (S.speedAt or 0) > 0.25 then
			S.speedAt = now
			if S.speedOn then
				applySpeed()
			end
		end

		if S.antiGuard and now - (S.guardAt or 0) > 0.25 then
			S.guardAt = now
			pcall(guardTick)
		end

		if S.antiRag and now - (S.ragAt or 0) > 0.12 then
			S.ragAt = now
			pcall(ragTick)
		end
	end)
)

table.insert(
	S.connections,
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not alive() then
			return
		end
		if input.KeyCode == Enum.KeyCode.V then
			toggleSpeed()
		end
	end)
)

table.insert(
	S.connections,
	LocalPlayer.CharacterAdded:Connect(function()
		S.baseHip = nil
		task.wait(1)
		if not alive() then
			return
		end
		if S.speedOn then
			applySpeed()
		end
		local hum = humanoid()
		if hum and S.baseHip == nil then
			S.baseHip = hum.HipHeight
		end
	end)
)

-- slow loop: treadmill watchdog, gain sampling, panels
table.insert(
	S.connections,
	task.spawn(function()
		local lastGainSample = os.clock()
		while alive() do
			task.wait(0.5)

			if not alive() then
				return
			end

			-- treadmill watchdog
			pcall(function()
				if not S.treadmillOn then
					return
				end
				if LocalPlayer:GetAttribute("SlashTreadmillActive") == true then
					S.misses = 0
					return
				end
				S.misses += 1
				local hrp, deck = root(), treadmillDeck()
				local far = not (hrp and deck) or (hrp.Position - deck.Position).Magnitude > 3
				if far or S.misses >= 2 then
					parkOnTreadmill()
				end
			end)

			-- gain per second
			local power = LocalPlayer:GetAttribute("SpeedPower")
			if typeof(power) == "number" then
				local delta = os.clock() - lastGainSample
				if S.gainMark and delta > 0.4 then
					S.gainValue = math.max(0, (power - S.gainMark) / delta)
				end
				S.gainMark = power
				lastGainSample = os.clock()
			end

			-- farm session panel
			if UI.sessionPanel then
				UI.sessionPanel.Set(string.format(
					"gain / sec     %s\nsession        %s\nwalk speed     %s\nre-parks       %d",
					fmt(S.gainValue),
					tostring(LocalPlayer:GetAttribute("SlashTreadmillActive")),
					tostring(humanoid() and humanoid().WalkSpeed or "?"),
					S.reparks
				))
			end

			if UI.stealPanel then
				UI.stealPanel.Set(string.format(
					"phase          %s\ncarrying       %s\nbanked         %d\nfails          %d\nlast           %s",
					tostring(S.stealPhase),
					tostring(LocalPlayer:GetAttribute("SlashCarrying") or "no"),
					S.stealCount,
					S.stealFails,
					tostring(S.stealLast)
				))
				UI.stealPanel.SetNote(S.stealOn and "loop" or "idle")
			end

			if activeTab == "Main" then
				pcall(buildStatus)
			end

			if S.profileAt == 0 or os.clock() - S.profileAt > 30 then
				refreshProfile()
			end
		end
	end)
)

-- ============================================================================
-- 21 · telemetry
-- ============================================================================
local function perfMs(name)
	local ok, value = pcall(function()
		local folder = Stats:FindFirstChild("PerformanceStats")
		local item = folder and folder:FindFirstChild(name)
		if item and item:IsA("StatsItem") then
			return item:GetValue()
		end
		return nil
	end)
	return ok and type(value) == "number" and value or nil
end

do
	local frames, elapsed = 0, 0
	table.insert(
		S.connections,
		RunService.RenderStepped:Connect(function(dt)
			if not alive() then
				return
			end
			frames += 1
			elapsed += dt
			if elapsed < 0.5 then
				return
			end

			local fps = math.floor((frames / elapsed) + 0.5)
			frames, elapsed = 0, 0

			local fpsColor = fps >= 50 and Theme.Good or (fps >= 30 and Theme.Warn or Theme.Bad)
			FpsLabel.Text = string.format("FPS %d", fps)
			FpsLabel.TextColor3 = fpsColor
			MiniFps.Text = FpsLabel.Text
			MiniFps.TextColor3 = fpsColor

			local fallback = 1000 / math.max(fps, 1)
			local cpu = perfMs("CPU") or fallback * 0.45
			local gpu = perfMs("GPU") or fallback * 0.55

			local cpuColor = cpu <= 16.6 and Theme.Good or (cpu <= 25 and Theme.Warn or Theme.Bad)
			CpuLabel.Text = string.format("CPU %.1fms", cpu)
			CpuLabel.TextColor3 = cpuColor
			MiniCpu.Text = CpuLabel.Text
			MiniCpu.TextColor3 = cpuColor

			local gpuColor = gpu <= 16.6 and Theme.Good or (gpu <= 25 and Theme.Warn or Theme.Bad)
			GpuLabel.Text = string.format("GPU %.1fms", gpu)
			GpuLabel.TextColor3 = gpuColor
			MiniGpu.Text = GpuLabel.Text
			MiniGpu.TextColor3 = gpuColor
		end)
	)
end

local function syncStatus()
	local busy = S.stealOn or S.treadmillOn or S.speedOn
	local text = busy and L("running") or L("idle")
	StatusValue.Text = text
	StatusValue.TextColor3 = busy and Theme.Accent or Theme.TextPrimary
	MiniStatus.Text = text
	MiniStatus.TextColor3 = busy and Theme.Accent or Theme.TextPrimary
end

table.insert(
	S.connections,
	task.spawn(function()
		while alive() do
			task.wait(0.5)
			pcall(syncStatus)
		end
	end)
)

-- ============================================================================
-- 22 · window controls · boot
-- ============================================================================
MinimizeBtn.MouseButton1Click:Connect(function()
	pulse(MinimizeBtn)
	setMinimized(true)
end)

ExpandBtn.MouseButton1Click:Connect(function()
	pulse(ExpandBtn)
	setMinimized(false)
end)

local function cleanup()
	if HUB.runId ~= RUN_ID then
		return
	end
	HUB.runId = nil
	S.destroyed = true
	S.stealOn = false
	S.treadmillOn = false

	for _, connection in ipairs(S.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	S.connections = {}

	pcall(function()
		releasePose()
	end)
	pcall(function()
		ScreenGui:Destroy()
	end)
	pcall(function()
		shared.__ElenaStore = Store
	end)
end

CloseBtn.MouseButton1Click:Connect(function()
	pulse(CloseBtn)
	notify("hub closed · re-execute to bring it back")
	task.delay(0.35, cleanup)
end)

HUB.state = S
HUB.ui = UI
HUB.instance = RUN_ID
HUB.cleanup = cleanup
HUB.destroy = cleanup
HUB.notify = notify
HUB.leaveTreadmill = leaveTreadmill
HUB.stopTreadmill = leaveTreadmill
HUB.autoToggle = UI.treadmillToggle
HUB.park = parkOnTreadmill
HUB.refresh = refreshProfile
HUB.setSpeed = function(value)
	S.speedValue = tonumber(value) or S.speedValue
	if UI.speedSlider then
		UI.speedSlider.Set(S.speedValue)
	end
	toggleSpeed(true)
end
HUB.stopSpeed = function()
	toggleSpeed(false)
end
HUB.stealOnce = function()
	task.spawn(function()
		stealCycle(false)
	end)
end
HUB.setAutoSteal = function(state)
	S.stealOn = state and true or false
	S.stealAbort = not S.stealOn
	if UI.stealToggle then
		UI.stealToggle.SetSilent(S.stealOn)
	end
	if S.stealOn then
		stealLoop()
	else
		S.stealPhase = "idle"
	end
end
HUB.zone = function(index)
	for position, entry in ipairs(ZONE_ORDER) do
		if entry.index == index then
			renderZone(entry)
			UI.zoneSelect.Set(zoneValues, position)
			return true
		end
	end
	return false
end
HUB.setMinimized = setMinimized
HUB.setTab = function(name)
	if not Pages[name] then
		return false
	end
	switchTab(name)
	return true
end
HUB.debug = {
	insideSafe = function()
		return insideSafe()
	end,
	safeZone = function()
		local zone = safeZone()
		return zone and zone.Position or nil
	end,
	target = function()
		local target = findStealTarget()
		if not target then
			return nil
		end
		return { name = target.object.Name, dist = math.floor(target.dist), prompt = target.prompt.Name }
	end,
	releasePose = function()
		releasePose()
		return true
	end,
	pickupCount = function()
		local folder = pickupsFolder()
		return folder and #folder:GetChildren() or -1
	end,
}

-- window hygiene: never let it drift off-screen, always stay on top
table.insert(
	S.connections,
	task.spawn(function()
		while alive() do
			task.wait(1.5)
			if not alive() then
				return
			end
			pcall(clampWindow)
			if ScreenGui.DisplayOrder ~= 2147483647 then
				ScreenGui.DisplayOrder = 2147483647
			end
		end
	end)
)

-- boot: stored profile first, then the default zone card
applyProfile(Store.profiles[Store.selected])
minimized = false
tween(MainScale, Theme.Pop, { Scale = 1 })
ReloadFill.Size = UDim2.new(0, 0, 1, 0)
ReloadFill.BackgroundTransparency = 0
local reloadAnim = tween(ReloadFill, Theme.Reload, { Size = UDim2.new(1, 0, 1, 0) })
reloadAnim.Completed:Connect(function()
	tween(ReloadFill, Theme.Fast, { BackgroundTransparency = 1 })
end)

task.spawn(function()
	task.wait(1)
	if not alive() then
		return
	end
	refreshProfile()
end)

task.delay(0.3, function()
	local entry = findZone(zoneValues[1])
	renderZone(entry)
	if entry then
		UI.zoneSelect.Set(zoneValues, 1)
	end
end)

task.spawn(function()
	task.wait(1.6)
	if not alive() then
		return
	end
	pcall(buildStatus)
	pcall(syncStatus)
end)

notify(IS_RELOAD and "hub reloaded · run " .. tostring(HUB.runs) or "elena hub loaded", "good")
