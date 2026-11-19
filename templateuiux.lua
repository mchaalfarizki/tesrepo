--!strict
-- Roblox Dark Glassmorphism UI/UX Template (.lua) — FULL VERSION
-- Bilingual (EN / ID), Re-Execute Reload System + Animations,
-- Floating Draggable Mini Bar (FPS, CPU, GPU + IDLE/ACTIVE) on Minimize,
-- Create/Save/Load Config + Capped History (Max 12 entries).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ============================================================================
-- 1. RE-EXECUTE RUNTIME CLEANUP & REGISTRY
-- ============================================================================
local function getRuntimeRegistry(): { [string]: any }
	local envTable = (type(getgenv) == "function" and getgenv()) or shared
	if not envTable._AetherRuntimeRegistry then
		envTable._AetherRuntimeRegistry = {
			activeCleanup = nil,
			store = nil,
			reloadCount = 0,
		}
	end
	return envTable._AetherRuntimeRegistry
end

local RuntimeRegistry = getRuntimeRegistry()
local isReExecuteReload = type(RuntimeRegistry.activeCleanup) == "function"

if isReExecuteReload then
	pcall(RuntimeRegistry.activeCleanup)
	RuntimeRegistry.activeCleanup = nil
end
RuntimeRegistry.reloadCount += 1

-- ============================================================================
-- 2. THEME & CONFIG TOKENS
-- ============================================================================
local TOPBAR_HEIGHT = 44
local TELEMETRY_HEIGHT = 38
local RELOAD_BAR_HEIGHT = 3
local MINIMIZED_HEIGHT = TOPBAR_HEIGHT + TELEMETRY_HEIGHT
local MAX_HISTORY = 12

local CONFIG_DIR = "AetherHubConfigs"
local CONFIG_FILE = CONFIG_DIR .. "/configs_store.json"

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
	StrokeSubtle = Color3.fromRGB(255, 255, 255),
	StrokeAlpha = 0.86,
	Accent = Color3.fromRGB(96, 165, 250),
	Good = Color3.fromRGB(74, 222, 128),
	Warn = Color3.fromRGB(250, 204, 21),
	Bad = Color3.fromRGB(248, 113, 113),

	CornerRadius = UDim.new(0, 12),
	SmallRadius = UDim.new(0, 8),
	PillRadius = UDim.new(0, 6),

	TweenFast = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	TweenTab = TweenInfo.new(0.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	TweenPop = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	TweenReload = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
}

-- ============================================================================
-- 3. BILINGUAL DICTIONARY (ENGLISH & INDONESIAN)
-- ============================================================================
type LangCode = "en" | "id"

local Locales: { [LangCode]: { [string]: string } } = {
	en = {
		subTag = "v1.6 • FULL",
		tabMain = "Main",
		tabConfigs = "Configs",
		tabSettings = "Settings",
		statusIdle = "IDLE",
		statusRunning = "RUNNING",
		statusActiveFmt = "ACTIVE (#%d)",
		autoLoopTitle = "Auto Action Loop",
		autoLoopSub = "Runs background task safely with cooldown",
		compactTickTitle = "Compact Tick Rate (0.25s)",
		compactTickSub = "Faster loop cadence (higher CPU usage)",
		langTitle = "Language / Bahasa",
		langSub = "Switch UI text between English & Indonesia",
		langBtnLabel = "EN",
		configMetaFmt = "Active: %s  •  Saved Profiles: %d",
		configPlaceholder = "Config name (e.g. farming_v1)",
		btnCreateNew = "Create New",
		btnSaveConfig = "Save Config",
		btnLoadConfig = "Load Config",
		historyTitle = "Config History (Max 12 • Persisted)",
		historyEmpty = "No config history yet.",
	},
	id = {
		subTag = "v1.6 • LENGKAP",
		tabMain = "Utama",
		tabConfigs = "Konfig",
		tabSettings = "Pengaturan",
		statusIdle = "IDLE",
		statusRunning = "JALAN",
		statusActiveFmt = "AKTIF (#%d)",
		autoLoopTitle = "Loop Aksi Otomatis",
		autoLoopSub = "Menjalankan tugas latar belakang dengan jeda aman",
		compactTickTitle = "Tick Rate Cepat (0.25d)",
		compactTickSub = "Interval loop lebih cepat (beban CPU lebih tinggi)",
		langTitle = "Bahasa / Language",
		langSub = "Ganti teks antarmuka antara Indonesia & English",
		langBtnLabel = "ID",
		configMetaFmt = "Aktif: %s  •  Profil Tersimpan: %d",
		configPlaceholder = "Nama konfig (mis. farming_v1)",
		btnCreateNew = "Buat Baru",
		btnSaveConfig = "Simpan Konfig",
		btnLoadConfig = "Muat Konfig",
		historyTitle = "Riwayat Konfig (Maks 12 • Tersimpan)",
		historyEmpty = "Belum ada riwayat konfig.",
	},
}

-- ============================================================================
-- 4. TYPES & PERSISTENT STORAGE (CAPPED AT MAX_HISTORY = 12)
-- ============================================================================
export type ConfigProfile = {
	AutoLoopEnabled: boolean,
	CompactTick: boolean,
}

export type HistoryEntry = {
	action: string,
	configName: string,
	timeLabel: string,
}

export type PersistedStore = {
	language: LangCode,
	selectedConfig: string,
	profiles: { [string]: ConfigProfile },
	history: { HistoryEntry },
}

local function trimHistory(list: { HistoryEntry }, maxLen: number)
	while #list > maxLen do
		table.remove(list, #list)
	end
end

local function makeDefaultStore(): PersistedStore
	return {
		language = "id",
		selectedConfig = "default",
		profiles = {
			default = {
				AutoLoopEnabled = false,
				CompactTick = false,
			},
		},
		history = {
			{
				action = "INIT",
				configName = "default",
				timeLabel = os.date("%H:%M:%S") :: string,
			},
		},
	}
end

local function hasFileIO(): boolean
	return type(writefile) == "function"
		and type(readfile) == "function"
		and type(isfile) == "function"
end

local function loadPersistedStore(): PersistedStore
	if not RuntimeRegistry.store then
		if hasFileIO() then
			local ok, raw = pcall(function()
				if isfile(CONFIG_FILE) then
					return readfile(CONFIG_FILE)
				end
				return nil
			end)
			if ok and type(raw) == "string" and #raw > 0 then
				local decodedOk, decoded = pcall(function()
					return HttpService:JSONDecode(raw)
				end)
				if decodedOk and type(decoded) == "table" and type(decoded.profiles) == "table" then
					decoded.language = if decoded.language == "en" then "en" else "id"
					decoded.selectedConfig = type(decoded.selectedConfig) == "string" and decoded.selectedConfig or "default"
					if not decoded.profiles[decoded.selectedConfig] then
						decoded.profiles[decoded.selectedConfig] = { AutoLoopEnabled = false, CompactTick = false }
					end
					decoded.history = type(decoded.history) == "table" and decoded.history or {}
					trimHistory(decoded.history, MAX_HISTORY)
					RuntimeRegistry.store = decoded
				end
			end
		end
	end

	if not RuntimeRegistry.store then
		RuntimeRegistry.store = makeDefaultStore()
	end

	local loaded = RuntimeRegistry.store :: PersistedStore
	trimHistory(loaded.history, MAX_HISTORY)
	return loaded
end

local function savePersistedStore(storeData: PersistedStore)
	trimHistory(storeData.history, MAX_HISTORY)
	RuntimeRegistry.store = storeData
	if hasFileIO() then
		pcall(function()
			if type(makefolder) == "function" and type(isfolder) == "function" then
				if not isfolder(CONFIG_DIR) then
					makefolder(CONFIG_DIR)
				end
			end
			writefile(CONFIG_FILE, HttpService:JSONEncode(storeData))
		end)
	end
end

local Store: PersistedStore = loadPersistedStore()
local activeProfile: ConfigProfile = Store.profiles[Store.selectedConfig] or {
	AutoLoopEnabled = false,
	CompactTick = false,
}
Store.profiles[Store.selectedConfig] = activeProfile

local State = {
	Language = Store.language :: LangCode,
	AutoLoopEnabled = activeProfile.AutoLoopEnabled,
	LoopInterval = activeProfile.CompactTick and 0.25 or 0.5,
	CompactTick = activeProfile.CompactTick,
	ActiveTab = "Main",
	Minimized = false,
	SelectedConfig = Store.selectedConfig,
	LastTickCount = 0,
	Alive = true,
}

local function tr(key: string): string
	local dict = Locales[State.Language] or Locales.en
	return dict[key] or Locales.en[key] or key
end

-- ============================================================================
-- 5. UI & ANIMATION HELPER BUILDERS
-- ============================================================================
local function addCorner(instance: GuiObject, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.CornerRadius
	corner.Parent = instance
	return corner
end

local function addStroke(instance: GuiObject, transparency: number?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.StrokeSubtle
	stroke.Transparency = transparency or Theme.StrokeAlpha
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

local function addPadding(instance: GuiObject, pad: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, pad)
	padding.PaddingBottom = UDim.new(0, pad)
	padding.PaddingLeft = UDim.new(0, pad)
	padding.PaddingRight = UDim.new(0, pad)
	padding.Parent = instance
	return padding
end

local function tween(instance: Instance, info: TweenInfo, props: { [string]: any })
	local anim = TweenService:Create(instance, info, props)
	anim:Play()
	return anim
end

local function pulseButton(btn: GuiButton, flashColor: Color3?)
	local origColor = btn.BackgroundColor3
	if flashColor then
		btn.BackgroundColor3 = flashColor
	end
	local scale = btn:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = btn
	end
	scale.Scale = 0.94
	tween(scale, Theme.TweenPop, { Scale = 1 })
	if flashColor then
		tween(btn, Theme.TweenFast, { BackgroundColor3 = origColor })
	end
end

-- ============================================================================
-- 6. ROOT SCREEN GUI, RELOAD BAR & MAIN GLASS WINDOW
-- ============================================================================
local function getParentGui(): Instance
	local ok, res = pcall(function()
		return CoreGui
	end)
	if ok and res then
		return res
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local existing = getParentGui():FindFirstChild("GlassHubTemplate")
if existing then
	existing:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GlassHubTemplate"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getParentGui()

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = Theme.WindowSize
MainFrame.Position = Theme.WindowPos
MainFrame.BackgroundColor3 = Theme.BgMain
MainFrame.BackgroundTransparency = Theme.BgMainAlpha
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
addCorner(MainFrame, Theme.CornerRadius)
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

-- Animated Reload Progress Strip
local ReloadTrack = Instance.new("Frame")
ReloadTrack.Name = "ReloadTrack"
ReloadTrack.Size = UDim2.new(1, 0, 0, RELOAD_BAR_HEIGHT)
ReloadTrack.Position = UDim2.fromOffset(0, 0)
ReloadTrack.BackgroundTransparency = 1
ReloadTrack.ZIndex = 5
ReloadTrack.Parent = MainFrame

local ReloadFill = Instance.new("Frame")
ReloadFill.Name = "ReloadFill"
ReloadFill.Size = UDim2.new(0, 0, 1, 0)
ReloadFill.BackgroundColor3 = Theme.Accent
ReloadFill.BorderSizePixel = 0
ReloadFill.Parent = ReloadTrack

-- ============================================================================
-- 7. TOP BAR & PERSISTENT TELEMETRY BAR (FPS, CPU, GPU + IDLE/ACTIVE)
-- ============================================================================
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT)
TopBar.BackgroundColor3 = Theme.BgHeader
TopBar.BackgroundTransparency = Theme.BgHeaderAlpha
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, -195, 1, 0)
TitleLabel.Position = UDim2.fromOffset(16, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "AETHER // UI TEMPLATE"
TitleLabel.TextColor3 = Theme.TextPrimary
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.Parent = TopBar

local SubLabel = Instance.new("TextLabel")
SubLabel.Name = "SubLabel"
SubLabel.Size = UDim2.new(0, 110, 1, 0)
SubLabel.Position = UDim2.new(1, -186, 0, 0)
SubLabel.BackgroundTransparency = 1
SubLabel.Text = tr("subTag")
SubLabel.TextColor3 = Theme.TextSecondary
SubLabel.TextXAlignment = Enum.TextXAlignment.Right
SubLabel.Font = Enum.Font.GothamMedium
SubLabel.TextSize = 11
SubLabel.Parent = TopBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.fromOffset(28, 28)
MinimizeBtn.Position = UDim2.new(1, -68, 0.5, -14)
MinimizeBtn.BackgroundColor3 = Theme.BgButtonOff
MinimizeBtn.BackgroundTransparency = 0.25
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Theme.TextPrimary
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 15
MinimizeBtn.AutoButtonColor = false
MinimizeBtn.Parent = TopBar
addCorner(MinimizeBtn, Theme.SmallRadius)
addStroke(MinimizeBtn, 0.85, 1)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.fromOffset(28, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(185, 28, 28)
CloseBtn.BackgroundTransparency = 0.3
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Theme.TextPrimary
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = TopBar
addCorner(CloseBtn, Theme.SmallRadius)
addStroke(CloseBtn, 0.85, 1)

local TelemetryBar = Instance.new("Frame")
TelemetryBar.Name = "TelemetryBar"
TelemetryBar.Size = UDim2.new(1, 0, 0, TELEMETRY_HEIGHT)
TelemetryBar.Position = UDim2.fromOffset(0, TOPBAR_HEIGHT)
TelemetryBar.BackgroundColor3 = Theme.BgCard
TelemetryBar.BackgroundTransparency = 0.35
TelemetryBar.BorderSizePixel = 0
TelemetryBar.Parent = MainFrame

local metricsHolder = Instance.new("Frame")
metricsHolder.Name = "MetricsHolder"
metricsHolder.Size = UDim2.new(0.72, -10, 1, -10)
metricsHolder.Position = UDim2.fromOffset(10, 5)
metricsHolder.BackgroundTransparency = 1
metricsHolder.Parent = TelemetryBar

local metricsLayout = Instance.new("UIListLayout")
metricsLayout.FillDirection = Enum.FillDirection.Horizontal
metricsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
metricsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
metricsLayout.Padding = UDim.new(0, 6)
metricsLayout.SortOrder = Enum.SortOrder.LayoutOrder
metricsLayout.Parent = metricsHolder

local function makeMetricPill(tag: string, order: number, width: number): TextLabel
	local pill = Instance.new("Frame")
	pill.Name = tag .. "Pill"
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(width, 24)
	pill.BackgroundColor3 = Theme.BgPill
	pill.BackgroundTransparency = 0.25
	pill.BorderSizePixel = 0
	pill.Parent = metricsHolder
	addCorner(pill, Theme.PillRadius)
	addStroke(pill, 0.88, 1)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = tag .. " --"
	lbl.TextColor3 = Theme.TextPrimary
	lbl.Font = Enum.Font.GothamSemiBold
	lbl.TextSize = 11
	lbl.Parent = pill
	return lbl
end

local FpsLabel = makeMetricPill("FPS", 1, 66)
local CpuLabel = makeMetricPill("CPU", 2, 78)
local GpuLabel = makeMetricPill("GPU", 3, 78)

local StatusValueLabel = Instance.new("TextLabel")
StatusValueLabel.Name = "StatusValue"
StatusValueLabel.Size = UDim2.new(0.28, -14, 1, 0)
StatusValueLabel.Position = UDim2.new(0.72, 0, 0, 0)
StatusValueLabel.BackgroundTransparency = 1
StatusValueLabel.Text = State.AutoLoopEnabled and tr("statusRunning") or tr("statusIdle")
StatusValueLabel.TextColor3 = State.AutoLoopEnabled and Theme.Accent or Theme.TextPrimary
StatusValueLabel.TextXAlignment = Enum.TextXAlignment.Right
StatusValueLabel.Font = Enum.Font.GothamBold
StatusValueLabel.TextSize = 11
StatusValueLabel.Parent = TelemetryBar

-- Dragging on TopBar
do
	local dragging = false
	local dragStart = Vector2.zero
	local startPos = MainFrame.Position

	TopBar.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = MainFrame.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
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

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- ============================================================================
-- 8. FLOATING DRAGGABLE MINI BAR (SHOWN WHEN MINIMIZED)
-- ============================================================================
local FloatingMini = Instance.new("Frame")
FloatingMini.Name = "FloatingMini"
FloatingMini.Size = UDim2.fromOffset(278, 52)
FloatingMini.Position = UDim2.new(0.5, -139, 0.06, 0)
FloatingMini.BackgroundColor3 = Theme.BgMain
FloatingMini.BackgroundTransparency = 0.14
FloatingMini.BorderSizePixel = 0
FloatingMini.Visible = false
FloatingMini.ZIndex = 10
FloatingMini.Parent = ScreenGui
addCorner(FloatingMini, Theme.SmallRadius)
addStroke(FloatingMini, Theme.StrokeAlpha, 1)

local MiniGradient = Instance.new("UIGradient")
MiniGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 35, 48)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 14, 20)),
})
MiniGradient.Rotation = 135
MiniGradient.Parent = FloatingMini

local MiniScale = Instance.new("UIScale")
MiniScale.Scale = 0.9
MiniScale.Parent = FloatingMini

local MiniMetrics = Instance.new("Frame")
MiniMetrics.Size = UDim2.new(1, -66, 0, 22)
MiniMetrics.Position = UDim2.fromOffset(8, 6)
MiniMetrics.BackgroundTransparency = 1
MiniMetrics.Parent = FloatingMini

local miniList = Instance.new("UIListLayout")
miniList.FillDirection = Enum.FillDirection.Horizontal
miniList.Padding = UDim.new(0, 4)
miniList.SortOrder = Enum.SortOrder.LayoutOrder
miniList.Parent = MiniMetrics

local function makeMiniPill(tag: string, order: number, width: number): TextLabel
	local pill = Instance.new("Frame")
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(width, 20)
	pill.BackgroundColor3 = Theme.BgPill
	pill.BackgroundTransparency = 0.25
	pill.BorderSizePixel = 0
	pill.Parent = MiniMetrics
	addCorner(pill, Theme.PillRadius)
	addStroke(pill, 0.88, 1)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = tag .. " --"
	lbl.TextColor3 = Theme.TextPrimary
	lbl.Font = Enum.Font.GothamSemiBold
	lbl.TextSize = 10
	lbl.Parent = pill
	return lbl
end

local MiniFpsLabel = makeMiniPill("FPS", 1, 56)
local MiniCpuLabel = makeMiniPill("CPU", 2, 68)
local MiniGpuLabel = makeMiniPill("GPU", 3, 68)

local MiniStatusLabel = Instance.new("TextLabel")
MiniStatusLabel.Size = UDim2.new(1, -66, 0, 16)
MiniStatusLabel.Position = UDim2.fromOffset(10, 30)
MiniStatusLabel.BackgroundTransparency = 1
MiniStatusLabel.Text = State.AutoLoopEnabled and tr("statusRunning") or tr("statusIdle")
MiniStatusLabel.TextColor3 = State.AutoLoopEnabled and Theme.Accent or Theme.TextPrimary
MiniStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
MiniStatusLabel.Font = Enum.Font.GothamBold
MiniStatusLabel.TextSize = 10
MiniStatusLabel.Parent = FloatingMini

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
ExpandBtn.Parent = FloatingMini
addCorner(ExpandBtn, Theme.PillRadius)
addStroke(ExpandBtn, 0.85, 1)

-- Dragging support for FloatingMini
do
	local dragging = false
	local dragStart = Vector2.zero
	local startPos = FloatingMini.Position

	FloatingMini.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = FloatingMini.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			FloatingMini.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function setMinimizedState(minimized: boolean)
	State.Minimized = minimized
	if minimized then
		local shrink = tween(MainScale, Theme.TweenFast, { Scale = 0.92 })
		shrink.Completed:Connect(function()
			if State.Minimized then
				MainFrame.Visible = false
				FloatingMini.Visible = true
				MiniScale.Scale = 0.88
				tween(MiniScale, Theme.TweenPop, { Scale = 1 })
			end
		end)
	else
		local miniShrink = tween(MiniScale, Theme.TweenFast, { Scale = 0.88 })
		miniShrink.Completed:Connect(function()
			if not State.Minimized then
				FloatingMini.Visible = false
				MainFrame.Visible = true
				MainScale.Scale = 0.94
				tween(MainScale, Theme.TweenPop, { Scale = 1 })
			end
		end)
	end
end

MinimizeBtn.MouseButton1Click:Connect(function()
	pulseButton(MinimizeBtn, nil)
	setMinimizedState(true)
end)

ExpandBtn.MouseButton1Click:Connect(function()
	pulseButton(ExpandBtn, nil)
	setMinimizedState(false)
end)

-- ============================================================================
-- 9. SIDEBAR NAVIGATION & ANIMATED CONTENT PAGES
-- ============================================================================
local BodyFrame = Instance.new("Frame")
BodyFrame.Name = "BodyFrame"
BodyFrame.Size = UDim2.new(1, 0, 1, -MINIMIZED_HEIGHT)
BodyFrame.Position = UDim2.fromOffset(0, MINIMIZED_HEIGHT)
BodyFrame.BackgroundTransparency = 1
BodyFrame.Parent = MainFrame

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 132, 1, 0)
Sidebar.BackgroundColor3 = Theme.BgHeader
Sidebar.BackgroundTransparency = 0.45
Sidebar.BorderSizePixel = 0
Sidebar.Parent = BodyFrame
addPadding(Sidebar, 10)

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 6)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Parent = Sidebar

local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -132, 1, 0)
ContentArea.Position = UDim2.fromOffset(132, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = BodyFrame
addPadding(ContentArea, 12)

local Pages: { [string]: ScrollingFrame } = {}
local TabButtons: { [string]: TextButton } = {}

local function animatePageEnter(page: ScrollingFrame)
	page.Position = UDim2.new(0.04, 0, 0, 0)
	tween(page, Theme.TweenTab, { Position = UDim2.fromScale(0, 0) })
end

local function createPage(name: string): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Theme.Accent
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = (name == State.ActiveTab)
	page.Parent = ContentArea

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = page

	Pages[name] = page
	return page
end

local function switchTab(tabName: string)
	State.ActiveTab = tabName
	for name, page in pairs(Pages) do
		local isTarget = (name == tabName)
		page.Visible = isTarget
		if isTarget then
			animatePageEnter(page)
		end
	end
	for name, btn in pairs(TabButtons) do
		local active = (name == tabName)
		tween(btn, Theme.TweenTab, {
			BackgroundColor3 = active and Theme.BgButtonOn or Theme.BgButtonOff,
			BackgroundTransparency = active and 0.25 or 0.55,
			TextColor3 = active and Theme.TextPrimary or Theme.TextSecondary,
		})
	end
end

local function createTabButton(tabKey: string, labelKey: string, order: number)
	local btn = Instance.new("TextButton")
	btn.Name = tabKey .. "Tab"
	btn.LayoutOrder = order
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = (tabKey == State.ActiveTab) and Theme.BgButtonOn or Theme.BgButtonOff
	btn.BackgroundTransparency = (tabKey == State.ActiveTab) and 0.25 or 0.55
	btn.Text = tr(labelKey)
	btn.TextColor3 = (tabKey == State.ActiveTab) and Theme.TextPrimary or Theme.TextSecondary
	btn.Font = Enum.Font.GothamSemiBold
	btn.TextSize = 12
	btn.AutoButtonColor = false
	btn.Parent = Sidebar
	addCorner(btn, Theme.SmallRadius)
	addStroke(btn, 0.88, 1)

	btn.MouseButton1Click:Connect(function()
		pulseButton(btn, nil)
		switchTab(tabKey)
	end)

	TabButtons[tabKey] = btn
end

local MainPage = createPage("Main")
local ConfigsPage = createPage("Configs")
local SettingsPage = createPage("Settings")
createTabButton("Main", "tabMain", 1)
createTabButton("Configs", "tabConfigs", 2)
createTabButton("Settings", "tabSettings", 3)

-- ============================================================================
-- 10. ANIMATED TOGGLE & LANGUAGE WIDGETS
-- ============================================================================
local function syncStatusTexts()
	if State.AutoLoopEnabled then
		local activeStr = if State.LastTickCount > 0
			then string.format(tr("statusActiveFmt"), State.LastTickCount)
			else tr("statusRunning")
		StatusValueLabel.Text = activeStr
		StatusValueLabel.TextColor3 = Theme.Accent
		MiniStatusLabel.Text = activeStr
		MiniStatusLabel.TextColor3 = Theme.Accent
	else
		local idleStr = tr("statusIdle")
		StatusValueLabel.Text = idleStr
		StatusValueLabel.TextColor3 = Theme.TextPrimary
		MiniStatusLabel.Text = idleStr
		MiniStatusLabel.TextColor3 = Theme.TextPrimary
	end
end

local function createToggleCard(
	parent: Instance,
	titleKey: string,
	subtitleKey: string,
	defaultState: boolean,
	onToggle: (boolean) -> ()
): ((boolean) -> (), () -> ())
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -4, 0, 62)
	card.BackgroundColor3 = defaultState and Theme.BgCardActive or Theme.BgCard
	card.BackgroundTransparency = Theme.BgCardAlpha
	card.BorderSizePixel = 0
	card.Parent = parent
	addCorner(card, Theme.SmallRadius)
	addStroke(card, 0.88, 1)

	local lblTitle = Instance.new("TextLabel")
	lblTitle.Size = UDim2.new(1, -90, 0, 20)
	lblTitle.Position = UDim2.fromOffset(12, 10)
	lblTitle.BackgroundTransparency = 1
	lblTitle.Text = tr(titleKey)
	lblTitle.TextColor3 = Theme.TextPrimary
	lblTitle.TextXAlignment = Enum.TextXAlignment.Left
	lblTitle.Font = Enum.Font.GothamSemiBold
	lblTitle.TextSize = 13
	lblTitle.Parent = card

	local lblSub = Instance.new("TextLabel")
	lblSub.Size = UDim2.new(1, -90, 0, 16)
	lblSub.Position = UDim2.fromOffset(12, 32)
	lblSub.BackgroundTransparency = 1
	lblSub.Text = tr(subtitleKey)
	lblSub.TextColor3 = Theme.TextSecondary
	lblSub.TextXAlignment = Enum.TextXAlignment.Left
	lblSub.Font = Enum.Font.Gotham
	lblSub.TextSize = 11
	lblSub.Parent = card

	local switchBg = Instance.new("TextButton")
	switchBg.Size = UDim2.fromOffset(46, 24)
	switchBg.Position = UDim2.new(1, -58, 0.5, -12)
	switchBg.BackgroundColor3 = defaultState and Theme.BgButtonOn or Theme.BgButtonOff
	switchBg.BackgroundTransparency = 0.15
	switchBg.Text = ""
	switchBg.AutoButtonColor = false
	switchBg.Parent = card
	addCorner(switchBg, UDim.new(1, 0))

	local knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(18, 18)
	knob.Position = defaultState and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3)
	knob.BackgroundColor3 = Theme.TextPrimary
	knob.BorderSizePixel = 0
	knob.Parent = switchBg
	addCorner(knob, UDim.new(1, 0))

	local active = defaultState
	local function setVisual(state: boolean)
		active = state
		tween(card, Theme.TweenFast, {
			BackgroundColor3 = active and Theme.BgCardActive or Theme.BgCard,
		})
		tween(switchBg, Theme.TweenFast, {
			BackgroundColor3 = active and Theme.BgButtonOn or Theme.BgButtonOff,
		})
		tween(knob, Theme.TweenPop, {
			Position = active and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
		})
	end

	switchBg.MouseButton1Click:Connect(function()
		setVisual(not active)
		onToggle(active)
	end)

	local function refreshText()
		lblTitle.Text = tr(titleKey)
		lblSub.Text = tr(subtitleKey)
	end

	return function(newState: boolean)
		setVisual(newState)
	end, refreshText
end

local setAutoLoopVisual: ((boolean) -> ())?
local setCompactTickVisual: ((boolean) -> ())?
local refreshAutoLoopText: (() -> ())?
local refreshCompactTickText: (() -> ())?

local function applyStateToRuntime(newAuto: boolean, newCompact: boolean)
	State.AutoLoopEnabled = newAuto
	State.CompactTick = newCompact
	State.LoopInterval = newCompact and 0.25 or 0.5

	if setAutoLoopVisual then
		setAutoLoopVisual(newAuto)
	end
	if setCompactTickVisual then
		setCompactTickVisual(newCompact)
	end

	syncStatusTexts()
end

-- ============================================================================
-- 11. CONFIG MANAGER & CAPPED PERSISTENT HISTORY (MAX 12)
-- ============================================================================
local HistoryContainer: Frame?
local ConfigMetaLabel: TextLabel?
local ConfigNameInput: TextBox?
local BtnCreateNew: TextButton?
local BtnSaveConfig: TextButton?
local BtnLoadConfig: TextButton?
local HistoryTitleLabel: TextLabel?
local LangToggleBtn: TextButton?

local function renderHistoryList()
	if not HistoryContainer then
		return
	end
	for _, child in ipairs(HistoryContainer:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	if #Store.history == 0 then
		local emptyLbl = Instance.new("TextLabel")
		emptyLbl.Size = UDim2.new(1, 0, 0, 20)
		emptyLbl.BackgroundTransparency = 1
		emptyLbl.Text = tr("historyEmpty")
		emptyLbl.TextColor3 = Theme.TextSecondary
		emptyLbl.TextXAlignment = Enum.TextXAlignment.Left
		emptyLbl.Font = Enum.Font.Gotham
		emptyLbl.TextSize = 11
		emptyLbl.Parent = HistoryContainer
		return
	end

	for i, item in ipairs(Store.history) do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 18)
		row.BackgroundTransparency = 1
		row.Text = string.format("[%s] %s -> %s", item.timeLabel, item.action, item.configName)
		row.TextColor3 = if item.action == "SAVE" or item.action == "CREATE"
			then Theme.Good
			elseif item.action == "LOAD" or item.action == "RELOAD" or item.action == "EXECUTE" then Theme.Accent
			else Theme.TextSecondary
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = Enum.Font.Code
		row.TextSize = 11
		row.Parent = HistoryContainer

		if i == 1 then
			row.Position = UDim2.fromOffset(8, 0)
			tween(row, Theme.TweenFast, { Position = UDim2.fromOffset(0, 0) })
		end
	end
end

local function refreshConfigMeta()
	if ConfigMetaLabel then
		local count = 0
		for _ in pairs(Store.profiles) do
			count += 1
		end
		ConfigMetaLabel.Text = string.format(tr("configMetaFmt"), State.SelectedConfig, count)
	end
end

local function refreshLanguageUI()
	SubLabel.Text = tr("subTag")
	if TabButtons.Main then
		TabButtons.Main.Text = tr("tabMain")
	end
	if TabButtons.Configs then
		TabButtons.Configs.Text = tr("tabConfigs")
	end
	if TabButtons.Settings then
		TabButtons.Settings.Text = tr("tabSettings")
	end
	if refreshAutoLoopText then
		refreshAutoLoopText()
	end
	if refreshCompactTickText then
		refreshCompactTickText()
	end
	if ConfigNameInput then
		ConfigNameInput.PlaceholderText = tr("configPlaceholder")
	end
	if BtnCreateNew then
		BtnCreateNew.Text = tr("btnCreateNew")
	end
	if BtnSaveConfig then
		BtnSaveConfig.Text = tr("btnSaveConfig")
	end
	if BtnLoadConfig then
		BtnLoadConfig.Text = tr("btnLoadConfig")
	end
	if HistoryTitleLabel then
		HistoryTitleLabel.Text = tr("historyTitle")
	end
	if LangToggleBtn then
		LangToggleBtn.Text = tr("langBtnLabel")
	end

	syncStatusTexts()
	refreshConfigMeta()
	renderHistoryList()
end

local lastHistoryStamp = 0
local lastHistoryKey = ""

local function pushHistory(action: string, configName: string)
	local now = os.clock()
	local dedupKey = action .. ":" .. configName
	if dedupKey == lastHistoryKey and (now - lastHistoryStamp) < 0.5 then
		return
	end
	lastHistoryStamp = now
	lastHistoryKey = dedupKey

	table.insert(Store.history, 1, {
		action = action,
		configName = configName,
		timeLabel = os.date("%H:%M:%S") :: string,
	})
	trimHistory(Store.history, MAX_HISTORY)
	savePersistedStore(Store)
	renderHistoryList()
end

local function sanitizeConfigName(rawName: string): string
	local trimmed = string.gsub(rawName, "^%s*(.-)%s*$", "%1")
	local cleaned = string.gsub(trimmed, "[^%w_%-]", "_")
	return if #cleaned > 0 then string.sub(cleaned, 1, 24) else "default"
end

local function createNewConfig(nameInput: string)
	local cleanName = sanitizeConfigName(nameInput)
	Store.profiles[cleanName] = {
		AutoLoopEnabled = State.AutoLoopEnabled,
		CompactTick = State.CompactTick,
	}
	State.SelectedConfig = cleanName
	Store.selectedConfig = cleanName
	if ConfigNameInput then
		ConfigNameInput.Text = cleanName
	end
	refreshConfigMeta()
	pushHistory("CREATE", cleanName)
end

local function saveCurrentConfig(nameInput: string)
	local cleanName = sanitizeConfigName(nameInput)
	Store.profiles[cleanName] = {
		AutoLoopEnabled = State.AutoLoopEnabled,
		CompactTick = State.CompactTick,
	}
	State.SelectedConfig = cleanName
	Store.selectedConfig = cleanName
	refreshConfigMeta()
	pushHistory("SAVE", cleanName)
end

local function loadSelectedConfig(nameInput: string)
	local cleanName = sanitizeConfigName(nameInput)
	local profile = Store.profiles[cleanName]
	if not profile then
		pushHistory("MISSING", cleanName)
		return
	end
	State.SelectedConfig = cleanName
	Store.selectedConfig = cleanName
	if ConfigNameInput then
		ConfigNameInput.Text = cleanName
	end
	applyStateToRuntime(profile.AutoLoopEnabled, profile.CompactTick)
	savePersistedStore(Store)
	refreshConfigMeta()
	pushHistory("LOAD", cleanName)
end

-- Build Configs Page
do
	local managerCard = Instance.new("Frame")
	managerCard.Name = "ConfigManagerCard"
	managerCard.Size = UDim2.new(1, -4, 0, 118)
	managerCard.BackgroundColor3 = Theme.BgCard
	managerCard.BackgroundTransparency = Theme.BgCardAlpha
	managerCard.BorderSizePixel = 0
	managerCard.Parent = ConfigsPage
	addCorner(managerCard, Theme.SmallRadius)
	addStroke(managerCard, 0.88, 1)

	ConfigMetaLabel = Instance.new("TextLabel")
	ConfigMetaLabel.Size = UDim2.new(1, -24, 0, 20)
	ConfigMetaLabel.Position = UDim2.fromOffset(12, 10)
	ConfigMetaLabel.BackgroundTransparency = 1
	ConfigMetaLabel.Text = ""
	ConfigMetaLabel.TextColor3 = Theme.TextSecondary
	ConfigMetaLabel.TextXAlignment = Enum.TextXAlignment.Left
	ConfigMetaLabel.Font = Enum.Font.GothamMedium
	ConfigMetaLabel.TextSize = 11
	ConfigMetaLabel.Parent = managerCard

	ConfigNameInput = Instance.new("TextBox")
	ConfigNameInput.Size = UDim2.new(1, -24, 0, 32)
	ConfigNameInput.Position = UDim2.fromOffset(12, 34)
	ConfigNameInput.BackgroundColor3 = Theme.BgInput
	ConfigNameInput.BackgroundTransparency = 0.2
	ConfigNameInput.Text = State.SelectedConfig
	ConfigNameInput.PlaceholderText = tr("configPlaceholder")
	ConfigNameInput.PlaceholderColor3 = Theme.TextSecondary
	ConfigNameInput.TextColor3 = Theme.TextPrimary
	ConfigNameInput.TextXAlignment = Enum.TextXAlignment.Left
	ConfigNameInput.ClearTextOnFocus = false
	ConfigNameInput.Font = Enum.Font.GothamMedium
	ConfigNameInput.TextSize = 12
	ConfigNameInput.Parent = managerCard
	addCorner(ConfigNameInput, Theme.PillRadius)
	addStroke(ConfigNameInput, 0.85, 1)
	addPadding(ConfigNameInput, 8)

	local function makeActionBtn(labelKey: string, xScale: number, widthScale: number, bgColor: Color3): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(widthScale, -10, 0, 30)
		btn.Position = UDim2.new(xScale, 12, 0, 74)
		btn.BackgroundColor3 = bgColor
		btn.BackgroundTransparency = 0.2
		btn.Text = tr(labelKey)
		btn.TextColor3 = Theme.TextPrimary
		btn.Font = Enum.Font.GothamSemiBold
		btn.TextSize = 11
		btn.AutoButtonColor = false
		btn.Parent = managerCard
		addCorner(btn, Theme.PillRadius)
		addStroke(btn, 0.85, 1)
		return btn
	end

	BtnCreateNew = makeActionBtn("btnCreateNew", 0, 0.34, Theme.BgButtonOff)
	BtnSaveConfig = makeActionBtn("btnSaveConfig", 0.34, 0.33, Theme.BgSuccess)
	BtnLoadConfig = makeActionBtn("btnLoadConfig", 0.67, 0.33, Theme.BgButtonOn)

	BtnCreateNew.MouseButton1Click:Connect(function()
		pulseButton(BtnCreateNew, nil)
		createNewConfig(ConfigNameInput.Text)
	end)

	BtnSaveConfig.MouseButton1Click:Connect(function()
		pulseButton(BtnSaveConfig, Theme.Good)
		saveCurrentConfig(ConfigNameInput.Text)
	end)

	BtnLoadConfig.MouseButton1Click:Connect(function()
		pulseButton(BtnLoadConfig, Theme.Accent)
		loadSelectedConfig(ConfigNameInput.Text)
	end)

	local historyCard = Instance.new("Frame")
	historyCard.Name = "ConfigHistoryCard"
	historyCard.Size = UDim2.new(1, -4, 0, 152)
	historyCard.BackgroundColor3 = Theme.BgCard
	historyCard.BackgroundTransparency = Theme.BgCardAlpha
	historyCard.BorderSizePixel = 0
	historyCard.Parent = ConfigsPage
	addCorner(historyCard, Theme.SmallRadius)
	addStroke(historyCard, 0.88, 1)

	HistoryTitleLabel = Instance.new("TextLabel")
	HistoryTitleLabel.Size = UDim2.new(1, -24, 0, 22)
	HistoryTitleLabel.Position = UDim2.fromOffset(12, 8)
	HistoryTitleLabel.BackgroundTransparency = 1
	HistoryTitleLabel.Text = tr("historyTitle")
	HistoryTitleLabel.TextColor3 = Theme.TextPrimary
	HistoryTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	HistoryTitleLabel.Font = Enum.Font.GothamSemiBold
	HistoryTitleLabel.TextSize = 12
	HistoryTitleLabel.Parent = historyCard

	local histScroll = Instance.new("ScrollingFrame")
	histScroll.Size = UDim2.new(1, -20, 1, -38)
	histScroll.Position = UDim2.fromOffset(10, 32)
	histScroll.BackgroundColor3 = Theme.BgInput
	histScroll.BackgroundTransparency = 0.35
	histScroll.BorderSizePixel = 0
	histScroll.ScrollBarThickness = 3
	histScroll.ScrollBarImageColor3 = Theme.Accent
	histScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	histScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	histScroll.Parent = historyCard
	addCorner(histScroll, Theme.PillRadius)
	addPadding(histScroll, 6)

	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.Parent = histScroll

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 3)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder

	HistoryContainer = holder
	refreshConfigMeta()
	renderHistoryList()
end

-- ============================================================================
-- 12. POPULATE MAIN & SETTINGS PAGES + RELOAD ENTRY ANIMATION
-- ============================================================================
setAutoLoopVisual, refreshAutoLoopText = createToggleCard(
	MainPage,
	"autoLoopTitle",
	"autoLoopSub",
	State.AutoLoopEnabled,
	function(enabled: boolean)
		State.AutoLoopEnabled = enabled
		syncStatusTexts()
	end
)

setCompactTickVisual, refreshCompactTickText = createToggleCard(
	SettingsPage,
	"compactTickTitle",
	"compactTickSub",
	State.CompactTick,
	function(fast: boolean)
		State.CompactTick = fast
		State.LoopInterval = fast and 0.25 or 0.5
	end
)

do
	local langCard = Instance.new("Frame")
	langCard.Size = UDim2.new(1, -4, 0, 62)
	langCard.BackgroundColor3 = Theme.BgCard
	langCard.BackgroundTransparency = Theme.BgCardAlpha
	langCard.BorderSizePixel = 0
	langCard.Parent = SettingsPage
	addCorner(langCard, Theme.SmallRadius)
	addStroke(langCard, 0.88, 1)

	local lblTitle = Instance.new("TextLabel")
	lblTitle.Size = UDim2.new(1, -90, 0, 20)
	lblTitle.Position = UDim2.fromOffset(12, 10)
	lblTitle.BackgroundTransparency = 1
	lblTitle.Text = tr("langTitle")
	lblTitle.TextColor3 = Theme.TextPrimary
	lblTitle.TextXAlignment = Enum.TextXAlignment.Left
	lblTitle.Font = Enum.Font.GothamSemiBold
	lblTitle.TextSize = 13
	lblTitle.Parent = langCard

	local lblSub = Instance.new("TextLabel")
	lblSub.Size = UDim2.new(1, -90, 0, 16)
	lblSub.Position = UDim2.fromOffset(12, 32)
	lblSub.BackgroundTransparency = 1
	lblSub.Text = tr("langSub")
	lblSub.TextColor3 = Theme.TextSecondary
	lblSub.TextXAlignment = Enum.TextXAlignment.Left
	lblSub.Font = Enum.Font.Gotham
	lblSub.TextSize = 11
	lblSub.Parent = langCard

	local langBtn = Instance.new("TextButton")
	langBtn.Size = UDim2.fromOffset(48, 26)
	langBtn.Position = UDim2.new(1, -60, 0.5, -13)
	langBtn.BackgroundColor3 = Theme.BgButtonOn
	langBtn.BackgroundTransparency = 0.2
	langBtn.Text = tr("langBtnLabel")
	langBtn.TextColor3 = Theme.TextPrimary
	langBtn.Font = Enum.Font.GothamBold
	langBtn.TextSize = 12
	langBtn.AutoButtonColor = false
	langBtn.Parent = langCard
	addCorner(langBtn, Theme.PillRadius)
	addStroke(langBtn, 0.85, 1)

	LangToggleBtn = langBtn

	langBtn.MouseButton1Click:Connect(function()
		pulseButton(langBtn, nil)
		State.Language = if State.Language == "id" then "en" else "id"
		Store.language = State.Language
		lblTitle.Text = tr("langTitle")
		lblSub.Text = tr("langSub")
		savePersistedStore(Store)
		refreshLanguageUI()
	end)
end

pushHistory(if isReExecuteReload then "RELOAD" else "EXECUTE", State.SelectedConfig)

-- Boot / Re-Execute Reload Animation
tween(MainScale, Theme.TweenPop, { Scale = 1 })
ReloadFill.Size = UDim2.new(0, 0, 1, 0)
ReloadFill.BackgroundTransparency = 0
local reloadAnim = tween(ReloadFill, Theme.TweenReload, { Size = UDim2.new(1, 0, 1, 0) })
reloadAnim.Completed:Connect(function()
	tween(ReloadFill, Theme.TweenFast, { BackgroundTransparency = 1 })
end)

-- ============================================================================
-- 13. LIVE TELEMETRY (FPS, CPU, GPU) & BACKGROUND WORKER
-- ============================================================================
local frameCount = 0
local elapsed = 0

local function readPerfStatMs(statName: string): number?
	local ok, val = pcall(function()
		local perfFolder = Stats:FindFirstChild("PerformanceStats")
		if perfFolder then
			local item = perfFolder:FindFirstChild(statName)
			if item and item:IsA("StatsItem") then
				return item:GetValue()
			end
		end
		return nil
	end)
	if ok and type(val) == "number" then
		return val
	end
	return nil
end

local renderConn: RBXScriptConnection?
renderConn = RunService.RenderStepped:Connect(function(dt: number)
	frameCount += 1
	elapsed += dt
	if elapsed >= 0.5 then
		local fps = math.floor((frameCount / elapsed) + 0.5)
		frameCount = 0
		elapsed = 0

		local fpsColor = if fps >= 50 then Theme.Good elseif fps >= 30 then Theme.Warn else Theme.Bad
		local fpsText = string.format("FPS %d", fps)
		FpsLabel.Text = fpsText
		FpsLabel.TextColor3 = fpsColor
		MiniFpsLabel.Text = fpsText
		MiniFpsLabel.TextColor3 = fpsColor

		local fallbackMs = (1000 / math.max(fps, 1))
		local cpuMs = readPerfStatMs("CPU") or (fallbackMs * 0.45)
		local gpuMs = readPerfStatMs("GPU") or (fallbackMs * 0.55)

		local cpuColor = if cpuMs <= 16.6 then Theme.Good elseif cpuMs <= 25 then Theme.Warn else Theme.Bad
		local cpuText = string.format("CPU %.1fms", cpuMs)
		CpuLabel.Text = cpuText
		CpuLabel.TextColor3 = cpuColor
		MiniCpuLabel.Text = cpuText
		MiniCpuLabel.TextColor3 = cpuColor

		local gpuColor = if gpuMs <= 16.6 then Theme.Good elseif gpuMs <= 25 then Theme.Warn else Theme.Bad
		local gpuText = string.format("GPU %.1fms", gpuMs)
		GpuLabel.Text = gpuText
		GpuLabel.TextColor3 = gpuColor
		MiniGpuLabel.Text = gpuText
	end
end)

local function cleanupRuntime()
	State.Alive = false
	State.AutoLoopEnabled = false
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if ScreenGui.Parent then
		ScreenGui:Destroy()
	end
end

RuntimeRegistry.activeCleanup = cleanupRuntime

CloseBtn.MouseButton1Click:Connect(function()
	pulseButton(CloseBtn, nil)
	cleanupRuntime()
	RuntimeRegistry.activeCleanup = nil
end)

task.spawn(function()
	while State.Alive and ScreenGui.Parent do
		if State.AutoLoopEnabled then
			State.LastTickCount += 1
			syncStatusTexts()
		end
		task.wait(State.LoopInterval)
	end
end)
