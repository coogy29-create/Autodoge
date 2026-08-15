local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ENABLED = false
local DODGING = false
local EnemyProj = nil
local ProjectileData = {}

local PREDICT_TIME = 1.05
local SAMPLE_STEP = 0.04
local DECISION_INTERVAL = 0.030
local DECISION_INTERVAL_URGENT = 0.018
local DECISION_INTERVAL_IDLE = 0.050

local TRIGGER_TIME = 0.28
local DODGE_REACTION_BUFFER = 0.075
local DODGE_ACTUATION_DELAY = 0.060
local MAX_DYNAMIC_TRIGGER_TIME = 0.72
local PLAYER_RADIUS = 2.30
local EXTRA_MARGIN = 0.45
local SAFE_EXTRA = 0.65
local PLAYER_HITBOX_EXTRA = 0.40
local BASE_UNCERTAINTY_MARGIN = 0.55
local MAX_UNCERTAINTY_MARGIN = 3.25
local PREDICTION_ERROR_WEIGHT = 1.65
local SPEED_UNCERTAINTY_WEIGHT = 0.006
local CONTACT_RADIUS_EXTRA = 0.30
local NETWORK_LEAD_FALLBACK = 0.035
local NETWORK_LEAD_MIN = 0.015
local NETWORK_LEAD_MAX = 0.085
local EFFECTIVE_DODGE_SPEED_FACTOR = 0.78
local PROACTIVE_ROUTE_TIME = 0.82
local GAP_SEARCH_ANGLES = 48
local GAP_SEARCH_TOP = 8
local GAP_ROUTE_MARGIN = 0.18
local GAP_MIN_TIME = 0.16
local GAP_MAX_TIME = 0.72
local GAP_RADII = {0.55, 0.78, 1.00}
local GAP_BLOCK_PENALTY = 1000000
local ROUTE_PLANNER_ENABLED = true
local ROUTE_SEED_COUNT = 8
local ROUTE_BEAM_WIDTH = 12
local ROUTE_SAMPLE_DT = 0.055
local ROUTE_MIN_HORIZON = 0.62
local ROUTE_MAX_HORIZON = 0.84
local ROUTE_SECOND_OFFSETS = {-80, -50, -28, 0, 28, 50, 80}
local ROUTE_THIRD_OFFSETS = {-55, -28, 0, 28, 55}
local ROUTE_TURN_COST = 1.8
local ROUTE_REVERSE_COST = 7.5
local ROUTE_MOVE_COST = 0.8
local ROUTE_RESERVE_COST = 4.0
local ROUTE_NEAR_MISS_COST = 5.0

local LARGE_PROJECTILE_RADIUS = 3.5
local LARGE_PROJECTILE_EXTRA_SCALE = 0.18
local LARGE_PROJECTILE_EXTRA_MAX = 2.8
local LARGE_PROJECTILE_TRIGGER_BONUS = 0.18
local LARGE_PROJECTILE_TRIGGER_MAX = 0.42

local MIN_PROJECTILE_SPEED = 0.75

local PERF_DENSE_SKIP_REFINE = 12

local VELOCITY_SMOOTH = 0.72
local ACCELERATION_SMOOTH = 0.18
local MAX_ACCELERATION = 3500
local REVERSE_MIN_SPEED = 4.0
local REVERSE_STOP_SPEED = 2.2
local REVERSE_DOT_THRESHOLD = -0.30
local REVERSE_WATCH_TIME = 0.34
local REVERSE_STABILIZE_TIME = 0.22
local REVERSE_PREDICTION_ERROR_FLOOR = 1.15
local REVERSE_UNCERTAINTY_EXTRA = 0.85
local REVERSE_DIRECTION_HOLD = 0.075
local REVERSE_SWITCH_MARGIN_MULTIPLIER = 2.4
local REVERSE_ROUTE_SEED_COUNT = 5
local REVERSE_ROUTE_BEAM_WIDTH = 7
local REVERSE_ROUTE_MAX_HORIZON = 0.66
local REVERSE_FORWARD_MODE_TIME = 1.05
local REVERSE_FORWARD_IDLE_MAGNITUDE = 0.68
local REVERSE_FORWARD_DODGE_MAGNITUDE = 0.88
local REVERSE_FORWARD_SCORE_BONUS = 16
local REVERSE_FORWARD_BACKWARD_PENALTY = 26
local REVERSE_FORWARD_ROUTE_BONUS = 5.5
local REVERSE_FORWARD_ROUTE_BACKWARD_PENALTY = 12
local REVERSE_FORWARD_COMPARE_DOT = 0.14
local REVERSE_FORWARD_SAFE_CLEARANCE = 0.20
local REVERSE_FORWARD_ANGLES = {-45, -28, -14, 0, 14, 28, 45}
local CORRIDOR_EARLY_TIME = 0.56
local CORRIDOR_EARLY_MIN_THREATS = 3
local CORRIDOR_EARLY_MIN_UNSAFE = 2
local CORRIDOR_EARLY_CLEARANCE = -0.28

local MICRO_REFINE_ANGLES = {-9, -6, -3, 3, 6, 9}

local URGENT_DODGE_TIME = 0.20
local URGENT_DODGE_MAGNITUDE = 0.84
local NEAR_DODGE_TIME = 0.34
local NEAR_DODGE_MAGNITUDE = 0.66
local DENSE_DODGE_MAGNITUDE = 0.54

local ESCAPE_FAN_TOP_CANDIDATES = 5
local ESCAPE_FAN_ANGLES = 12
local ESCAPE_FAN_FIRST_TIME = 0.30
local ESCAPE_FAN_SECOND_TIME = 0.50
local ESCAPE_FAN_STEP_TIME = 0.17
local ESCAPE_FAN_MIN_DISTANCE = 2.0
local ESCAPE_FAN_MAX_DISTANCE = 4.5
local ESCAPE_HARD_LANE_COMPARE = 2
local ESCAPE_SAFE_LANE_COMPARE = 2
local ESCAPE_CLEARANCE_COMPARE = 0.22
local NO_HIT_RESCUE_ANGLES = 72
local NO_HIT_RESCUE_MAGNITUDES = {1.00, 0.84, 0.68}
local NO_HIT_RESCUE_ROUTE_OFFSETS = {-18, -10, -5, 0, 5, 10, 18}
local NO_HIT_FORCE_REPLAN = true
local UI_UPDATE_INTERVAL = 0.12
local DEEP_PLANNER_ONLY_WHEN_NEEDED = true

local WALL_CHECK_DISTANCE = 9
local FLOOR_CHECK_DISTANCE = 7
local WALL_HARD_DISTANCE = 2.8
local WALL_COMFORT_DISTANCE = 6.5
local WALL_FUTURE_DISTANCE = 4.5
local WALL_RADIAL_RAYS = 8
local WALL_PROXIMITY_WEIGHT = 18
local WALL_CORNER_WEIGHT = 24
local WALL_APPROACH_WEIGHT = 28

local SPACE_RAYS = 12
local SPACE_CHECK_DISTANCE = 14
local SPACE_COMFORT_DISTANCE = 7
local SPACE_HARD_CLEARANCE = 2.4
local SPACE_CORNER_CLOSE_RAYS = 7
local SPACE_PATH_TIMES = {0.04, 0.08, 0.12, 0.18}
local SPACE_LOSS_WEIGHT = 90
local SPACE_CORNER_WEIGHT = 120
local SPACE_HARD_PENALTY = 1800
local SPACE_ESCAPE_BONUS = 18
local SPACE_PATH_BLOCK_PENALTY = 5000
local SPACE_PATH_RADIUS = 1.8

local WALL_STICK_CLEARANCE = 4.2
local WALL_STICK_HARD_CLEARANCE = 3.0
local WALL_STICK_PENALTY = 220
local WALL_STICK_HARD_PENALTY = 2600
local WALL_APPROACH_DOT_WEIGHT = 180
local WALL_ESCAPE_BONUS = 65

local BARRIER_HARD_MIN_DISTANCE = 3.5
local BARRIER_STRONG_MIN_DISTANCE = 6.0
local BARRIER_COMFORT_DISTANCE = 9.0
local BARRIER_PROACTIVE_DISTANCE = 17.0
local BARRIER_DISTANCE_EPSILON = 0.20

local BARRIER_RESERVE_TARGET = 12.0
local BARRIER_RESERVE_TRIGGER = 10.5
local BARRIER_RESERVE_RELEASE = 12.4
local BARRIER_RESERVE_LOOKAHEAD = 0.32
local BARRIER_RESERVE_MIN_MOVE = 0.28
local BARRIER_RESERVE_MAX_MOVE = 0.88
local BARRIER_RESERVE_EMERGENCY_DISTANCE = 6.0
local BARRIER_RESERVE_COMPARE_EPSILON = 0.22

local SHOW_WALL_RANGES = true
local BARRIER_VIZ_HEIGHT = 0.08
local BARRIER_VIZ_Y_OFFSET = -2.6
local WALL_VIZ_RAYS = 36
local WALL_SENSOR_DISTANCE = 60
local WALL_VIZ_DISTANCE = WALL_SENSOR_DISTANCE
local WALL_VIZ_UPDATE_INTERVAL = 0.18
local SOLID_WALL_RAY_MAX_SKIPS = 10
local SOLID_WALL_RAY_EPSILON = 0.05
local BARRIER_HARD_REJECT_SCORE = 100000

local DENSE_THREAT_COUNT = 10
local DENSE_SPACE_MULTIPLIER = 1.8
local DENSE_LOOKAHEAD_BONUS = 0.20

local MIN_DODGE_HOLD = 0.035
local MAX_DODGE_HOLD = 0.16
local DODGE_COOLDOWN = 0.0
local MIN_DODGE_COMMIT = 0.025
local MAX_CONTINUOUS_DODGE = 0.80
local DODGE_REFRESH_HOLD = 0.09

local COLLISION_PENALTY = 600
local NEAR_MISS_WEIGHT = 34
local MULTI_THREAT_WEIGHT = 10
local MOVE_PENALTY = 2.5
local TURN_PENALTY = 1.35
local DODGE_CONTINUITY_PENALTY = 1.0

local CANDIDATE_COUNT = 36
local REFINE_ANGLE = 5
local REFINE_MAGNITUDES = {0.50, 0.75, 1.00}

local PLAYER_RESPONSE_TIME = 0.16
local THREAT_RELEVANCE_MARGIN = 1.25
local THREAT_KNOTS = {
	0.00, 0.020, 0.045, 0.075, 0.115, 0.17,
	0.24, 0.34, 0.47, 0.63, 0.82, 1.05
}
local BARRIER_PLAN_TIMES = {0.08, 0.16, 0.28, 0.44}
local MINIMAL_DODGE_MAGNITUDES = {0.30, 0.42, 0.55, 0.70, 0.85, 1.00}
local SWITCH_SCORE_MARGIN = 8.0
local SWITCH_CLEARANCE_MARGIN = 0.22
local URGENT_IMPACT_TIME = 0.30
local ACTIVE_IMPACT_TIME = 0.55
local UNKNOWN_DAMAGE_ESTIMATE = 18

local SIDE_PREFERENCE_WEIGHT = 18.0
local BACKWARD_BASE_PENALTY = 30
local BACKWARD_DOT_LIMIT = -0.15
local BACKWARD_EXTRA_WEIGHT = 28
local LATERAL_TIE_BREAK_DOT = 0.42
local LATERAL_TIE_BREAK_CLEARANCE = 6.0

local LEARNING_KNOWN_SIDE_BONUS = 22
local LEARNING_KNOWN_BACKWARD_PENALTY = 55
local LEARNING_KNOWN_REAR_BARRIER_EXTRA = 95

local REAR_BARRIER_CHECK_DISTANCE = 12
local REAR_BARRIER_PENALTY = 70
local REAR_BARRIER_HARD_DISTANCE = 3.8
local REAR_BARRIER_HARD_PENALTY = 110

local DAMAGE_MATCH_WINDOW = 0.24
local DAMAGE_MATCH_EXTRA = 3.0
local DAMAGE_ROUND_STEP = 1
local DAMAGE_MIN_SAMPLES = 3
local DAMAGE_MIN_CONFIDENCE = 0.60
local DAMAGE_REFERENCE = 20
local DAMAGE_MAX_WEIGHT = 8
local LETHAL_DAMAGE_MULTIPLIER = 7
local HEAVY_DAMAGE_MULTIPLIER = 2.8
local MEDIUM_DAMAGE_MULTIPLIER = 1.6

local LEARNING_MODE = false
local LEARNING_MIN_HEALTH_RATIO = 0.65
local LEARNING_MAX_TARGET_DISTANCE = 55
local LEARNING_MIN_PROJECTILE_SPEED = 5
local LEARNING_TARGET_TIMEOUT = 8.0
local LEARNING_AIM_LEAD = 0.12
local LEARNING_STOP_DISTANCE = 1.2
local LEARNING_MOVE_MAGNITUDE = 1.0
local LEARNING_PATH_PREDICT_TIME = 1.20
local LEARNING_PATH_STEP = 0.08
local LEARNING_ARRIVAL_BUFFER = 0.06
local LEARNING_PATH_HOLD_RADIUS = 1.65

local LearningTarget = nil
local LearningTargetStarted = 0
local CurrentModeKey = "UnknownMode"

local SAVE_FOLDER = "AutoDodge"
local SAVE_FILE = SAVE_FOLDER .. "/damage_data.json"
local SAVE_VERSION = 1
local SAVE_DEBOUNCE = 0.35
local lastSaveRequest = 0
local saveQueued = false

local DamageProfiles = {}
local RecentProjectiles = {}
local HealthConnection = nil
local LastHealth = nil

local lastDecision = 0
local dodgeUntil = 0
local dodgeStarted = 0
local nextDodgeAllowed = 0
local dodgeDirection = Vector3.zero
local lastRisk = 0
local lastImpactTime = math.huge
local StableReferenceDirection = Vector3.zero
local lastEvaluatedThreats = 0
local lastRelevantThreats = 0
local lastPlanClearance = math.huge
local lastBarrierReserveDistance = math.huge
local lastRouteStages = 1
local lastRouteScore = 0
local lastReverseEventTime = -math.huge
local reverseEventCount = 0
local lastDodgeDirectionChange = -math.huge
local lastEscapeHardLanes = 0
local lastEscapeSafeLanes = 0
local lastEscapeClearance = -math.huge
local lastNoHitRescueUsed = false
local lastAvoidableHit = false
local DecisionCandidateEvalCache = nil
local DecisionGeometryCacheActive = false
local DecisionRootPosition = nil
local DecisionRootBarrierInfo = nil
local DecisionRootBarrierInfoCached = false
local DecisionRootBarrierDistance = math.huge
local DecisionRootBarrierDistanceCached = false
local BarrierReserveActive = false
local lastDecisionError = ""

local Controls = nil
local ControlsDisabled = false

local oldGui = PlayerGui:FindFirstChild("AutoDodgeUI")
if oldGui then
	oldGui:Destroy()
end

local Gui = Instance.new("ScreenGui")
Gui.Name = "AutoDodgeUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = false
Gui.DisplayOrder = 999999
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(235, 255)
Main.Position = UDim2.new(0.5, -117, 0.68, 0)
Main.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
Main.BorderSizePixel = 0
Main.Active = true
Main.ZIndex = 10
Main.Parent = Gui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 13)
MainCorner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(75, 75, 88)
Stroke.Thickness = 1
Stroke.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 0, 30)
Title.Position = UDim2.fromOffset(10, 5)
Title.BackgroundTransparency = 1
Title.Text = "AUTO DODGE"
Title.TextColor3 = Color3.fromRGB(240, 240, 245)
Title.TextSize = 17
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 11
Title.Parent = Main

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 22)
Status.Position = UDim2.fromOffset(10, 36)
Status.BackgroundTransparency = 1
Status.Text = "EnemyProj 대기 중..."
Status.TextColor3 = Color3.fromRGB(230, 190, 80)
Status.TextSize = 13
Status.Font = Enum.Font.Gotham
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.ZIndex = 11
Status.Parent = Main

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(1, -20, 0, 34)
Info.Position = UDim2.fromOffset(10, 57)
Info.BackgroundTransparency = 1
Info.Text = "Projectile : 0\nRisk : 0.00"
Info.TextColor3 = Color3.fromRGB(155, 155, 165)
Info.TextSize = 12
Info.Font = Enum.Font.Gotham
Info.TextXAlignment = Enum.TextXAlignment.Left
Info.TextYAlignment = Enum.TextYAlignment.Top
Info.ZIndex = 11
Info.Parent = Main

local Toggle = Instance.new("TextButton")
Toggle.Size = UDim2.new(1, -20, 0, 39)
Toggle.Position = UDim2.fromOffset(10, 98)
Toggle.BackgroundColor3 = Color3.fromRGB(58, 58, 66)
Toggle.BorderSizePixel = 0
Toggle.Text = "OFF"
Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
Toggle.TextSize = 15
Toggle.Font = Enum.Font.GothamBold
Toggle.ZIndex = 12
Toggle.Parent = Main

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 10)
ToggleCorner.Parent = Toggle

local LearningToggle = Instance.new("TextButton")
LearningToggle.Size = UDim2.new(1, -20, 0, 39)
LearningToggle.Position = UDim2.fromOffset(10, 143)
LearningToggle.BackgroundColor3 = Color3.fromRGB(58, 58, 66)
LearningToggle.BorderSizePixel = 0
LearningToggle.Text = "학습모드 OFF"
LearningToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
LearningToggle.TextSize = 14
LearningToggle.Font = Enum.Font.GothamBold
LearningToggle.ZIndex = 12
LearningToggle.Parent = Main

local LearningCorner = Instance.new("UICorner")
LearningCorner.CornerRadius = UDim.new(0, 10)
LearningCorner.Parent = LearningToggle

local WallVizToggle = Instance.new("TextButton")
WallVizToggle.Size = UDim2.new(1, -20, 0, 39)
WallVizToggle.Position = UDim2.fromOffset(10, 188)
WallVizToggle.BackgroundColor3 = Color3.fromRGB(112, 96, 48)
WallVizToggle.BorderSizePixel = 0
WallVizToggle.Text = "Barrier 범위 표시 ON"
WallVizToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
WallVizToggle.TextSize = 14
WallVizToggle.Font = Enum.Font.GothamBold
WallVizToggle.ZIndex = 12
WallVizToggle.Parent = Main

local WallVizCorner = Instance.new("UICorner")
WallVizCorner.CornerRadius = UDim.new(0, 10)
WallVizCorner.Parent = WallVizToggle

local ModeLabel = Instance.new("TextLabel")
ModeLabel.Size = UDim2.new(1, -20, 0, 20)
ModeLabel.Position = UDim2.fromOffset(10, 229)
ModeLabel.BackgroundTransparency = 1
ModeLabel.Text = "Mode : UnknownMode"
ModeLabel.TextColor3 = Color3.fromRGB(145, 145, 160)
ModeLabel.TextSize = 11
ModeLabel.Font = Enum.Font.Gotham
ModeLabel.TextXAlignment = Enum.TextXAlignment.Left
ModeLabel.ZIndex = 11
ModeLabel.Parent = Main

local dragging = false
local dragStart
local startPos
local dragInput

Main.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

Main.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if not dragging or input ~= dragInput or not dragStart or not startPos then
		return
	end
	local delta = input.Position - dragStart
	Main.Position = UDim2.new(
		startPos.X.Scale,
		startPos.X.Offset + delta.X,
		startPos.Y.Scale,
		startPos.Y.Offset + delta.Y
	)
end)

local function getCharacter()
	local character = LocalPlayer.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then return nil end
	return character, humanoid, root
end

task.spawn(function()
	pcall(function()
		local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts", 10)
		if not PlayerScripts then return end
		local module = PlayerScripts:WaitForChild("PlayerModule", 10)
		if not module then return end
		Controls = require(module):GetControls()
	end)
end)

local function disableControls()
	if Controls and not ControlsDisabled then
		pcall(function() Controls:Disable() end)
		ControlsDisabled = true
	end
end

local function enableControls()
	if Controls and ControlsDisabled then
		pcall(function() Controls:Enable() end)
		ControlsDisabled = false
	end
end

local function flatVector(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function roundTo(value, step)
	step = step or 1
	return math.floor(value / step + 0.5) * step
end

local function safeName(text)
	text = tostring(text or "Projectile")
	text = text:gsub("[^%w%._%-]", "_")
	if #text > 80 then
		text = text:sub(1, 80)
	end
	return text
end

local function numberKey(value)
	return tostring(roundTo(value, DAMAGE_ROUND_STEP))
end

local DifficultyValue = ReplicatedStorage
	:WaitForChild("ServerSettings")
	:WaitForChild("Difficulty")

local CurrentDifficulty = tonumber(DifficultyValue.Value) or 1

local function getDifficulty()
	local value = tonumber(DifficultyValue.Value)
	if not value or value <= 0 then
		return 1
	end
	return value
end

local function refreshModeKey()
	CurrentDifficulty = getDifficulty()
	CurrentModeKey = string.format("Difficulty_%.2f", CurrentDifficulty)
end

DifficultyValue:GetPropertyChangedSignal("Value"):Connect(function()
	refreshModeKey()
	LearningTarget = nil
	LearningTargetStarted = 0
end)

refreshModeKey()

local function getProjectileSignature(obj, part)
	local size = part.Size
	local meshId = ""
	local textureId = ""
	if part:IsA("MeshPart") then
		meshId = part.MeshId or ""
		textureId = part.TextureID or ""
	end

	return table.concat({
		tostring(obj.Name),
		tostring(part.Name),
		string.format("%.2f,%.2f,%.2f", size.X, size.Y, size.Z),
		tostring(part.Shape),
		tostring(part.Material),
		meshId,
		textureId
	}, "|")
end

local function canUseFileSystem()
	return type(writefile) == "function"
		and type(readfile) == "function"
		and type(isfile) == "function"
end

local function ensureSaveFolder()
	if type(isfolder) == "function"
		and type(makefolder) == "function"
	then
		if not isfolder(SAVE_FOLDER) then
			pcall(makefolder, SAVE_FOLDER)
		end
	end
end

local function serializeProfiles()
	local payload = {
		Version = SAVE_VERSION,
		Profiles = {}
	}

	for signature, profile in pairs(DamageProfiles) do
		payload.Profiles[signature] = {
			Samples = profile.Samples or {},
			BaseSamples = profile.BaseSamples or {},
			ContactSamples = profile.ContactSamples or {}
		}
	end

	return payload
end

local function saveProfilesNow()
	if not canUseFileSystem() then
		return false
	end

	ensureSaveFolder()

	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(serializeProfiles())
	end)

	if not ok then
		return false
	end

	return pcall(writefile, SAVE_FILE, encoded)
end

local function queueSave()
	if not canUseFileSystem() then
		return
	end

	lastSaveRequest = os.clock()

	if saveQueued then
		return
	end

	saveQueued = true

	task.spawn(function()
		while true do
			local remaining =
				SAVE_DEBOUNCE
				- (os.clock() - lastSaveRequest)

			if remaining <= 0 then
				break
			end

			task.wait(math.min(remaining, 0.1))
		end

		saveQueued = false
		saveProfilesNow()
	end)
end

local function rebuildProfile(profile)
	profile.Histogram = {}
	profile.BaseHistogram = {}

	for _, sample in ipairs(profile.Samples or {}) do
		local key = tostring(sample)
		profile.Histogram[key] =
			(profile.Histogram[key] or 0) + 1
	end

	for _, sample in ipairs(profile.BaseSamples or {}) do
		local key = string.format("%.2f", sample)
		profile.BaseHistogram[key] =
			(profile.BaseHistogram[key] or 0) + 1
	end

	local bestDamage, bestCount = nil, 0
	for key, count in pairs(profile.Histogram) do
		if count > bestCount then
			bestDamage = tonumber(key)
			bestCount = count
		end
	end

	local bestBase, bestBaseCount = nil, 0
	for key, count in pairs(profile.BaseHistogram) do
		if count > bestBaseCount then
			bestBase = tonumber(key)
			bestBaseCount = count
		end
	end

	profile.ModeDamage = bestDamage
	profile.ModeCount = bestCount
	profile.BaseDamage = bestBase
	profile.BaseModeCount = bestBaseCount
	profile.SampleCount = #(profile.Samples or {})
	profile.Confidence =
		profile.SampleCount > 0
		and bestCount / profile.SampleCount
		or 0
	profile.BaseConfidence =
		#(profile.BaseSamples or {}) > 0
		and bestBaseCount / #profile.BaseSamples
		or 0

	profile.Stable =
		#(profile.BaseSamples or {}) >= DAMAGE_MIN_SAMPLES
		and profile.BaseConfidence >= DAMAGE_MIN_CONFIDENCE

	local contacts = {}
	for _, value in ipairs(profile.ContactSamples or {}) do
		if type(value) == "number" and value > 0 then
			contacts[#contacts + 1] = value
		end
	end

	table.sort(contacts)

	if #contacts > 0 then
		local index =
			math.clamp(
				math.ceil(#contacts * 0.80),
				1,
				#contacts
			)

		profile.LearnedContactRadius =
			contacts[index] + CONTACT_RADIUS_EXTRA
	else
		profile.LearnedContactRadius = 0
	end
end

local function loadProfilesFromDisk()
	if not canUseFileSystem() then
		return false, "filesystem unsupported"
	end

	ensureSaveFolder()

	if not isfile(SAVE_FILE) then
		return true, "no save yet"
	end

	local okRead, raw = pcall(readfile, SAVE_FILE)
	if not okRead or type(raw) ~= "string" or raw == "" then
		return false, "read failed"
	end

	local okDecode, payload = pcall(function()
		return HttpService:JSONDecode(raw)
	end)

	if not okDecode
		or type(payload) ~= "table"
		or type(payload.Profiles) ~= "table"
	then
		return false, "decode failed"
	end

	for signature, saved in pairs(payload.Profiles) do
		if type(signature) == "string"
			and type(saved) == "table"
		then
			local profile = {
				Signature = signature,
				Samples = type(saved.Samples) == "table"
					and saved.Samples or {},
				BaseSamples = type(saved.BaseSamples) == "table"
					and saved.BaseSamples or {},
				ContactSamples = type(saved.ContactSamples) == "table"
					and saved.ContactSamples or {},
				LearnedContactRadius = 0,
				Histogram = {},
				BaseHistogram = {},
				ModeDamage = nil,
				BaseDamage = nil,
				ModeCount = 0,
				BaseModeCount = 0,
				SampleCount = 0,
				Confidence = 0,
				BaseConfidence = 0,
				Stable = false
			}

			while #profile.Samples > 40 do
				table.remove(profile.Samples, 1)
			end

			while #profile.BaseSamples > 40 do
				table.remove(profile.BaseSamples, 1)
			end

			while #profile.ContactSamples > 24 do
				table.remove(profile.ContactSamples, 1)
			end

			rebuildProfile(profile)
			DamageProfiles[signature] = profile
		end
	end

	return true, "loaded"
end

local AutoDodgeDataFolder = workspace:FindFirstChild("AutoDodge")
if not AutoDodgeDataFolder then
	AutoDodgeDataFolder = Instance.new("Folder")
	AutoDodgeDataFolder.Name = "AutoDodge"
	AutoDodgeDataFolder.Parent = workspace
end

local DamageDataFolder = AutoDodgeDataFolder:FindFirstChild("DamageData")
if not DamageDataFolder then
	DamageDataFolder = Instance.new("Folder")
	DamageDataFolder.Name = "DamageData"
	DamageDataFolder.Parent = AutoDodgeDataFolder
end

local solidWallRaycast

local WallVizFolder =
	AutoDodgeDataFolder:FindFirstChild("ActualBarrierVisualization")

if not WallVizFolder then
	WallVizFolder = Instance.new("Folder")
	WallVizFolder.Name = "ActualBarrierVisualization"
	WallVizFolder.Parent = AutoDodgeDataFolder
end

local LastWallVizHits = 0
local WallVizLastUpdate = 0
local WallVizVersion = -1
local BarrierVizParts = {}

local WallVizBands = {
	{
		Name = "Proactive_17",
		Distance = BARRIER_PROACTIVE_DISTANCE,
		Color = Color3.fromRGB(255, 235, 110),
		Transparency = 0.82
	},
	{
		Name = "Comfort_9",
		Distance = BARRIER_COMFORT_DISTANCE,
		Color = Color3.fromRGB(255, 195, 65),
		Transparency = 0.72
	},
	{
		Name = "Strong_6",
		Distance = BARRIER_STRONG_MIN_DISTANCE,
		Color = Color3.fromRGB(255, 125, 55),
		Transparency = 0.60
	},
	{
		Name = "Hard_3_5",
		Distance = BARRIER_HARD_MIN_DISTANCE,
		Color = Color3.fromRGB(255, 65, 65),
		Transparency = 0.48
	}
}

local function clearWallVisualization()
	for _, child in ipairs(WallVizFolder:GetChildren()) do
		child:Destroy()
	end

	table.clear(BarrierVizParts)
end

local function rebuildWallVisualization()
	clearWallVisualization()
	WallVizVersion = BarrierVersion

	if not SHOW_WALL_RANGES then
		LastWallVizHits = 0
		return
	end

	for index, barrier in ipairs(BarrierParts) do
		if barrier and barrier.Parent then
			BarrierVizParts[barrier] = {}

			for _, band in ipairs(WallVizBands) do
				local part = Instance.new("Part")
				part.Name =
					"Barrier_"
					.. tostring(index)
					.. "_"
					.. band.Name

				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.CastShadow = false
				part.Material = Enum.Material.Neon
				part.Color = band.Color
				part.Transparency = band.Transparency
				part.Size = Vector3.new(1, BARRIER_VIZ_HEIGHT, 1)
				part.Parent = WallVizFolder

				BarrierVizParts[barrier][band.Name] = part
			end
		end
	end

	LastWallVizHits = #BarrierParts
end

local function hideWallVisualization()
	for _, map in pairs(BarrierVizParts) do
		for _, part in pairs(map) do
			if part and part.Parent then
				part.Transparency = 1
			end
		end
	end

	LastWallVizHits = 0
end

local function updateWallVisualization(force)
	if not SHOW_WALL_RANGES then
		hideWallVisualization()
		return
	end

	local now = os.clock()

	if not force
		and now - WallVizLastUpdate < 0.10
	then
		return
	end

	WallVizLastUpdate = now

	local character, _, root = getCharacter()

	if not character or not root then
		hideWallVisualization()
		return
	end

	if WallVizVersion ~= BarrierVersion
		or next(BarrierVizParts) == nil
	then
		rebuildWallVisualization()
	end

	local displayY =
		root.Position.Y + BARRIER_VIZ_Y_OFFSET

	for barrier, map in pairs(BarrierVizParts) do
		if barrier and barrier.Parent then
			for _, band in ipairs(WallVizBands) do
				local part = map[band.Name]

				if part and part.Parent then
					-- Keep the Barrier's real X/Z orientation and dimensions,
					-- but force the visualization to the player's floor height.
					local barrierPos = barrier.Position

					part.Size =
						Vector3.new(
							barrier.Size.X
								+ band.Distance * 2,
							BARRIER_VIZ_HEIGHT,
							barrier.Size.Z
								+ band.Distance * 2
						)

					local rotationOnly =
						barrier.CFrame
							- barrier.CFrame.Position

					part.CFrame =
						CFrame.new(
							barrierPos.X,
							displayY,
							barrierPos.Z
						)
						* rotationOnly

					part.Transparency = band.Transparency
				end
			end
		end
	end

	LastWallVizHits = #BarrierParts
end

local function getOrCreateString(parent, name)
	local value = parent:FindFirstChild(name)
	if not value then
		value = Instance.new("StringValue")
		value.Name = name
		value.Parent = parent
	end
	return value
end

local function getDamageProfile(signature)
	local profile = DamageProfiles[signature]
	if profile then
		return profile
	end

	profile = {
		Signature = signature,
		Samples = {},
		BaseSamples = {},
		ContactSamples = {},
		LearnedContactRadius = 0,
		Histogram = {},
		BaseHistogram = {},
		ModeDamage = nil,
		BaseDamage = nil,
		ModeCount = 0,
		BaseModeCount = 0,
		SampleCount = 0,
		Confidence = 0,
		BaseConfidence = 0,
		Stable = false
	}

	DamageProfiles[signature] = profile
	return profile
end

local function updateDamageWorkspace(profile)
	local folderName = safeName(profile.Signature)
	local folder = DamageDataFolder:FindFirstChild(folderName)

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = DamageDataFolder
	end

	getOrCreateString(folder, "Signature").Value = profile.Signature
	getOrCreateString(folder, "CurrentDifficulty").Value =
		string.format("%.2f", getDifficulty())

	local sampleText = {}
	for i, sample in ipairs(profile.Samples) do
		sampleText[i] = tostring(sample)
	end

	local baseText = {}
	for i, sample in ipairs(profile.BaseSamples) do
		baseText[i] = string.format("%.2f", sample)
	end

	getOrCreateString(folder, "ObservedDamageSamples").Value =
		table.concat(sampleText, ", ")
	getOrCreateString(folder, "BaseDamageSamples").Value =
		table.concat(baseText, ", ")
	getOrCreateString(folder, "ObservedModeDamage").Value =
		profile.ModeDamage and tostring(profile.ModeDamage) or "Unknown"
	getOrCreateString(folder, "BaseDamage").Value =
		profile.BaseDamage and string.format("%.2f", profile.BaseDamage) or "Unknown"
	getOrCreateString(folder, "PredictedCurrentDamage").Value =
		profile.BaseDamage
			and string.format("%.2f", profile.BaseDamage * getDifficulty())
			or "Unknown"
	getOrCreateString(folder, "SampleCount").Value = tostring(#profile.Samples)
	getOrCreateString(folder, "Confidence").Value =
		string.format("%.1f%%", profile.BaseConfidence * 100)
	getOrCreateString(folder, "Stable").Value = profile.Stable and "true" or "false"
	getOrCreateString(folder, "LearnedContactRadius").Value =
		string.format("%.2f", profile.LearnedContactRadius or 0)
	getOrCreateString(folder, "LastObserved").Value =
		os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function recordDamageSample(signature, damage)
	refreshModeKey()

	if damage <= 0 then
		return
	end

	local difficulty = getDifficulty()
	local observedDamage = roundTo(damage, DAMAGE_ROUND_STEP)
	local baseDamage = damage / difficulty
	local baseRounded = roundTo(baseDamage, 0.25)

	local profile = getDamageProfile(signature)

	table.insert(profile.Samples, observedDamage)
	table.insert(profile.BaseSamples, baseRounded)

	if #profile.Samples > 40 then
		table.remove(profile.Samples, 1)
	end
	if #profile.BaseSamples > 40 then
		table.remove(profile.BaseSamples, 1)
	end

	profile.Histogram = {}
	profile.BaseHistogram = {}

	for _, sample in ipairs(profile.Samples) do
		local key = tostring(sample)
		profile.Histogram[key] = (profile.Histogram[key] or 0) + 1
	end

	for _, sample in ipairs(profile.BaseSamples) do
		local key = string.format("%.2f", sample)
		profile.BaseHistogram[key] = (profile.BaseHistogram[key] or 0) + 1
	end

	local bestDamage, bestCount = nil, 0
	for key, count in pairs(profile.Histogram) do
		if count > bestCount then
			bestDamage = tonumber(key)
			bestCount = count
		end
	end

	local bestBase, bestBaseCount = nil, 0
	for key, count in pairs(profile.BaseHistogram) do
		if count > bestBaseCount then
			bestBase = tonumber(key)
			bestBaseCount = count
		end
	end

	profile.ModeDamage = bestDamage
	profile.ModeCount = bestCount
	profile.BaseDamage = bestBase
	profile.BaseModeCount = bestBaseCount
	profile.SampleCount = #profile.Samples
	profile.Confidence =
		#profile.Samples > 0 and bestCount / #profile.Samples or 0
	profile.BaseConfidence =
		#profile.BaseSamples > 0 and bestBaseCount / #profile.BaseSamples or 0

	profile.Stable =
		#profile.BaseSamples >= DAMAGE_MIN_SAMPLES
		and profile.BaseConfidence >= DAMAGE_MIN_CONFIDENCE

	updateDamageWorkspace(profile)
	queueSave()
end

local function recordContactRadius(signature, distance)
	if not signature
		or type(distance) ~= "number"
		or distance <= 0
	then
		return
	end

	local profile = getDamageProfile(signature)
	profile.ContactSamples = profile.ContactSamples or {}

	-- Avoid one bad source match permanently making a projectile enormous.
	-- Only keep plausible contact distances.
	if distance > 30 then
		return
	end

	profile.ContactSamples[#profile.ContactSamples + 1] = distance

	while #profile.ContactSamples > 24 do
		table.remove(profile.ContactSamples, 1)
	end

	rebuildProfile(profile)
	updateDamageWorkspace(profile)
	queueSave()
end


local function mirrorLoadedProfilesToWorkspace()
	for _, profile in pairs(DamageProfiles) do
		updateDamageWorkspace(profile)
	end
end

local function segmentDistance(point, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 <= 0.0001 then
		return (point - b).Magnitude
	end

	local t = math.clamp((point - a):Dot(ab) / len2, 0, 1)
	local closest = a + ab * t
	return (point - closest).Magnitude
end

local function cleanupRecentProjectiles()
	local now = os.clock()
	for i = #RecentProjectiles, 1, -1 do
		if now - RecentProjectiles[i].Time > DAMAGE_MATCH_WINDOW then
			table.remove(RecentProjectiles, i)
		end
	end
end

local function findDamageSource(root)
	cleanupRecentProjectiles()

	local best = nil
	local bestDistance = math.huge

	local function consider(signature, part, previousPosition, currentPosition)
		if not part then
			return
		end

		local radius = projectileRadius and projectileRadius(part)
			or math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5

		local threshold = PLAYER_RADIUS + radius + DAMAGE_MATCH_EXTRA
		local distance = segmentDistance(
			root.Position,
			previousPosition or currentPosition,
			currentPosition
		)

		if distance <= threshold and distance < bestDistance then
			bestDistance = distance
			best = signature
		end
	end

	for _, data in pairs(ProjectileData) do
		if data.Part and data.Part.Parent then
			consider(
				data.Signature,
				data.Part,
				data.PreviousPosition,
				data.LastPosition
			)
		end
	end

	for _, recent in ipairs(RecentProjectiles) do
		consider(
			recent.Signature,
			recent.Part,
			recent.PreviousPosition,
			recent.Position
		)
	end

	return best, bestDistance
end

local function bindDamageLearning(character)
	if HealthConnection then
		HealthConnection:Disconnect()
		HealthConnection = nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	LastHealth = humanoid.Health

	HealthConnection = humanoid.HealthChanged:Connect(function(newHealth)
		if LastHealth == nil then
			LastHealth = newHealth
			return
		end

		local lost = LastHealth - newHealth
		LastHealth = newHealth

		if lost <= 0.01 then
			return
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local signature, contactDistance = findDamageSource(root)
		if signature then
			recordDamageSample(signature, lost)
			recordContactRadius(signature, contactDistance)
		end
	end)
end

local loadOk, loadMessage = loadProfilesFromDisk()
if loadOk then
	mirrorLoadedProfilesToWorkspace()
end

if LocalPlayer.Character then
	task.defer(bindDamageLearning, LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(0.15)
	bindDamageLearning(character)
end)

local function flatUnit(v)
	local f = flatVector(v)
	if f.Magnitude < 0.001 then return Vector3.zero end
	return f.Unit
end

local function rotateY(v, degrees)
	local r = math.rad(degrees)
	local c = math.cos(r)
	local s = math.sin(r)
	return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

local function getProjectilePart(obj)
	if obj:IsA("BasePart") then return obj end
	if obj:IsA("Model") and obj.PrimaryPart then return obj.PrimaryPart end
	return obj:FindFirstChildWhichIsA("BasePart", true)
end

local function projectileRadius(part, obj)
	local radius =
		math.max(
			part.Size.X,
			part.Size.Y,
			part.Size.Z
		) * 0.5

	if obj and obj:IsA("Model") then
		local ok, _, size = pcall(function()
			return obj:GetBoundingBox()
		end)

		if ok and size then
			radius =
				math.max(
					radius,
					math.max(
						size.X,
						size.Y,
						size.Z
					) * 0.5
				)
		end
	end

	return radius
end

local function projectileCenterOffset(obj, part)
	if obj and obj:IsA("Model") then
		local ok, boxCFrame = pcall(function()
			local cf = obj:GetBoundingBox()
			return cf
		end)

		if ok and boxCFrame then
			return part.CFrame:PointToObjectSpace(boxCFrame.Position)
		end
	end

	return Vector3.zero
end

local function getProjectileCenter(dataOrObj, part, offset)
	if offset and part then
		return part.CFrame:PointToWorldSpace(offset)
	end

	if part then
		return part.Position
	end

	return Vector3.zero
end

local function getNetworkLead()
	local lead = NETWORK_LEAD_FALLBACK

	pcall(function()
		local ping = LocalPlayer:GetNetworkPing()
		if type(ping) == "number" and ping > 0 then
			-- GetNetworkPing is generally one-way; keep a conservative clamp.
			lead = ping
		end
	end)

	return math.clamp(
		lead,
		NETWORK_LEAD_MIN,
		NETWORK_LEAD_MAX
	)
end


local function addProjectile(obj)
	task.defer(function()
		local part = getProjectilePart(obj)

		if not part then
			task.wait(0.02)
			part = getProjectilePart(obj)
		end

		if not part then
			return
		end

		local signature =
			getProjectileSignature(obj, part)

		local centerOffset =
			projectileCenterOffset(obj, part)

		local center =
			getProjectileCenter(
				obj,
				part,
				centerOffset
			)

		local initialVelocity =
			part.AssemblyLinearVelocity

		ProjectileData[obj] = {
			Object = obj,
			Part = part,
			CenterOffset = centerOffset,
			Radius = (function()
				local ok, radius =
					pcall(
						projectileRadius,
						part,
						obj
					)

				if ok and radius then
					return radius
				end

				return math.max(
					part.Size.X,
					part.Size.Y,
					part.Size.Z
				) * 0.5
			end)(),
			Signature = signature,
			PreviousPosition = center,
			LastPosition = center,
			Velocity = initialVelocity,
			LastVelocity = initialVelocity,
			Acceleration = Vector3.zero,
			PredictionError = 0,
			ReverseUntil = 0,
			ReverseWatchUntil = 0,
			PreReverseDirection =
				initialVelocity.Magnitude >= REVERSE_MIN_SPEED
				and initialVelocity.Unit
				or nil,
			LastStrongDirection =
				initialVelocity.Magnitude >= REVERSE_MIN_SPEED
				and initialVelocity.Unit
				or nil,
			Samples = 0,
			Ready =
				initialVelocity.Magnitude
					>= MIN_PROJECTILE_SPEED
		}
	end)
end

local function removeProjectile(obj)
	local data = ProjectileData[obj]
	if data and data.Part then
		RecentProjectiles[#RecentProjectiles + 1] = {
			Time = os.clock(),
			Signature = data.Signature,
			Part = data.Part,
			PreviousPosition = data.PreviousPosition or data.LastPosition,
			Position = data.LastPosition
		}
	end
	ProjectileData[obj] = nil
end

task.spawn(function()
	while true do
		local core = workspace:FindFirstChild("Core__Game")
		local folder = core and core:FindFirstChild("EnemyProj")
		if folder then
			EnemyProj = folder
			break
		end
		Status.Text = "EnemyProj 대기 중..."
		Status.TextColor3 = Color3.fromRGB(230, 190, 80)
		task.wait(0.25)
	end

	for _, obj in ipairs(EnemyProj:GetChildren()) do
		addProjectile(obj)
	end

	EnemyProj.ChildAdded:Connect(addProjectile)
	EnemyProj.ChildRemoved:Connect(removeProjectile)

	Status.Text = "준비됨"
	Status.TextColor3 = Color3.fromRGB(165, 165, 175)
end)

RunService.Heartbeat:Connect(function(dt)
	if not EnemyProj
		or dt <= 0
		or dt > 0.25
	then
		return
	end

	for obj, data in pairs(ProjectileData) do
		if not obj.Parent then
			ProjectileData[obj] = nil
			continue
		end

		local part = data.Part

		if not part or not part.Parent then
			part = getProjectilePart(obj)

			if not part then
				ProjectileData[obj] = nil
				continue
			end

			data.Part = part
			data.CenterOffset =
				projectileCenterOffset(obj, part)

			do
				local ok, radius =
					pcall(
						projectileRadius,
						part,
						obj
					)

				data.Radius =
					(ok and radius)
					and radius
					or math.max(
						part.Size.X,
						part.Size.Y,
						part.Size.Z
					) * 0.5
			end

			local center =
				getProjectileCenter(
					obj,
					part,
					data.CenterOffset
				)

			data.PreviousPosition = center
			data.LastPosition = center
			data.Velocity =
				part.AssemblyLinearVelocity
			data.LastVelocity =
				data.Velocity
			data.Acceleration = Vector3.zero
			data.PredictionError = 0
			data.ReverseUntil = 0
			data.ReverseWatchUntil = 0
			data.PreReverseDirection =
				data.Velocity.Magnitude >= REVERSE_MIN_SPEED
				and data.Velocity.Unit
				or nil
			data.LastStrongDirection =
				data.PreReverseDirection
			data.Samples = 0
			data.Ready =
				data.Velocity.Magnitude
					>= MIN_PROJECTILE_SPEED

			continue
		end

		local position =
			getProjectileCenter(
				obj,
				part,
				data.CenterOffset
			)

		data.PreviousPosition =
			data.LastPosition

		local rawVelocity =
			(position - data.LastPosition)
			/ dt

		local assemblyVelocity =
			part.AssemblyLinearVelocity

		local measuredVelocity =
			rawVelocity

		if assemblyVelocity.Magnitude
			>= MIN_PROJECTILE_SPEED
		then
			measuredVelocity =
				rawVelocity:Lerp(
					assemblyVelocity,
					0.30
				)
		end

		if data.Samples > 0 then
			local predictedNow =
				data.LastPosition
				+ data.Velocity * dt
				+ data.Acceleration
					* (0.5 * dt * dt)

			local error =
				(position - predictedNow).Magnitude

			data.PredictionError =
				(data.PredictionError or 0)
					* 0.72
				+ error * 0.28
		end

		local now = os.clock()
		local measuredSpeed = measuredVelocity.Magnitude
		local previousSpeed = data.Velocity.Magnitude

		-- Remember the pre-stop direction. Many reverse bullets decelerate
		-- almost to zero before launching back the other way.
		if measuredSpeed <= REVERSE_STOP_SPEED
			and previousSpeed >= REVERSE_MIN_SPEED
		then
			data.PreReverseDirection =
				data.Velocity.Unit
			data.ReverseWatchUntil =
				now + REVERSE_WATCH_TIME
		end

		local strongReverse = false

		if previousSpeed >= REVERSE_MIN_SPEED
			and measuredSpeed >= REVERSE_MIN_SPEED
		then
			local dot =
				math.clamp(
					data.Velocity.Unit:Dot(
						measuredVelocity.Unit
					),
					-1,
					1
				)

			strongReverse =
				dot <= REVERSE_DOT_THRESHOLD
		end

		local watchedReverse = false

		if measuredSpeed >= REVERSE_MIN_SPEED
			and data.PreReverseDirection
			and now <= (data.ReverseWatchUntil or 0)
		then
			local dot =
				math.clamp(
					data.PreReverseDirection:Dot(
						measuredVelocity.Unit
					),
					-1,
					1
				)

			watchedReverse =
				dot <= REVERSE_DOT_THRESHOLD
		end

		local reversing =
			strongReverse or watchedReverse

		if data.Samples == 0 then
			data.Velocity = measuredVelocity
			data.LastVelocity = measuredVelocity

		elseif reversing then
			-- Critical: do NOT blend old and new opposite velocities.
			-- Snap immediately to the newly measured reverse direction and
			-- discard stale acceleration from the pre-reverse trajectory.
			data.Velocity = measuredVelocity
			data.LastVelocity = measuredVelocity
			data.Acceleration = Vector3.zero

			data.PredictionError =
				math.max(
					data.PredictionError or 0,
					REVERSE_PREDICTION_ERROR_FLOOR
				)

			data.ReverseUntil =
				now + REVERSE_STABILIZE_TIME

			data.ReverseWatchUntil = 0
			data.PreReverseDirection =
				measuredVelocity.Unit
			data.LastStrongDirection =
				measuredVelocity.Unit

			lastReverseEventTime = now
			reverseEventCount += 1

		else
			data.Velocity =
				data.Velocity:Lerp(
					measuredVelocity,
					VELOCITY_SMOOTH
				)

			local rawAcceleration =
				(measuredVelocity
					- data.LastVelocity)
				/ dt

			if rawAcceleration.Magnitude
				<= MAX_ACCELERATION
			then
				data.Acceleration =
					data.Acceleration:Lerp(
						rawAcceleration,
						ACCELERATION_SMOOTH
					)
			end

			data.LastVelocity =
				measuredVelocity
		end

		if measuredSpeed >= REVERSE_MIN_SPEED then
			data.LastStrongDirection =
				measuredVelocity.Unit
		end

		data.LastPosition = position
		data.Samples += 1

		if data.Samples >= 1
			or data.Velocity.Magnitude
				>= MIN_PROJECTILE_SPEED
		then
			data.Ready = true
		end
	end
end)

local function predictProjectile(data, t)
	if os.clock() < (data.ReverseUntil or 0) then
		return data.LastPosition
			+ data.Velocity * t
	end

	return data.LastPosition
		+ data.Velocity * t
		+ data.Acceleration
			* (0.5 * t * t)
end

local CachedRayParams = nil
local CachedRayCharacter = nil
local CachedRayEnemyProj = nil

local function getRayParams(character)
	if CachedRayParams
		and CachedRayCharacter == character
		and CachedRayEnemyProj == EnemyProj
	then
		return CachedRayParams
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {character}
	if EnemyProj then
		table.insert(exclude, EnemyProj)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	CachedRayParams = params
	CachedRayCharacter = character
	CachedRayEnemyProj = EnemyProj

	return params
end

local BarrierParts = {}
local BarrierSet = {}
local BarrierVersion = 0

local function isActualBarrier(obj)
	return obj:IsA("BasePart")
		and string.lower(obj.Name) == "barrier"
end

local function rebuildBarrierParts()
	local list = {}

	for part in pairs(BarrierSet) do
		if part and part.Parent then
			list[#list + 1] = part
		end
	end

	BarrierParts = list
	BarrierVersion += 1
end

local function scanActualBarriers()
	table.clear(BarrierSet)

	for _, obj in ipairs(workspace:GetDescendants()) do
		if isActualBarrier(obj) then
			BarrierSet[obj] = true
		end
	end

	rebuildBarrierParts()
end

scanActualBarriers()

workspace.DescendantAdded:Connect(function(obj)
	if isActualBarrier(obj) then
		BarrierSet[obj] = true
		rebuildBarrierParts()
	end
end)

workspace.DescendantRemoving:Connect(function(obj)
	if BarrierSet[obj] then
		BarrierSet[obj] = nil
		rebuildBarrierParts()
	end
end)

local function closestPointOnBarrier(part, worldPoint)
	local localPoint =
		part.CFrame:PointToObjectSpace(worldPoint)

	local half = part.Size * 0.5

	local clamped =
		Vector3.new(
			math.clamp(localPoint.X, -half.X, half.X),
			math.clamp(localPoint.Y, -half.Y, half.Y),
			math.clamp(localPoint.Z, -half.Z, half.Z)
		)

	-- If the point is inside the box, choose the nearest face rather than
	-- returning the point itself.
	if math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
	then
		local dx = half.X - math.abs(localPoint.X)
		local dy = half.Y - math.abs(localPoint.Y)
		local dz = half.Z - math.abs(localPoint.Z)

		if dx <= dy and dx <= dz then
			clamped =
				Vector3.new(
					(localPoint.X >= 0 and half.X or -half.X),
					localPoint.Y,
					localPoint.Z
				)
		elseif dy <= dz then
			clamped =
				Vector3.new(
					localPoint.X,
					(localPoint.Y >= 0 and half.Y or -half.Y),
					localPoint.Z
				)
		else
			clamped =
				Vector3.new(
					localPoint.X,
					localPoint.Y,
					(localPoint.Z >= 0 and half.Z or -half.Z)
				)
		end
	end

	return part.CFrame:PointToWorldSpace(clamped)
end

local function rayBarrierIntersection(origin, direction, part)
	local maxDistance = direction.Magnitude

	if maxDistance <= 0.0001 then
		return nil
	end

	local unit = direction.Unit

	local localOrigin =
		part.CFrame:PointToObjectSpace(origin)

	local localDirection =
		part.CFrame:VectorToObjectSpace(unit)

	local half = part.Size * 0.5

	local tMin = 0
	local tMax = maxDistance

	local function slab(originAxis, directionAxis, minAxis, maxAxis)
		if math.abs(directionAxis) < 0.000001 then
			if originAxis < minAxis or originAxis > maxAxis then
				return false
			end
			return true
		end

		local inv = 1 / directionAxis
		local t1 = (minAxis - originAxis) * inv
		local t2 = (maxAxis - originAxis) * inv

		if t1 > t2 then
			t1, t2 = t2, t1
		end

		tMin = math.max(tMin, t1)
		tMax = math.min(tMax, t2)

		return tMax >= tMin
	end

	if not slab(localOrigin.X, localDirection.X, -half.X, half.X) then
		return nil
	end

	if not slab(localOrigin.Y, localDirection.Y, -half.Y, half.Y) then
		return nil
	end

	if not slab(localOrigin.Z, localDirection.Z, -half.Z, half.Z) then
		return nil
	end

	if tMin < 0 or tMin > maxDistance then
		return nil
	end

	return {
		Distance = tMin,
		Position = origin + unit * tMin,
		Instance = part
	}
end

solidWallRaycast = function(origin, direction)
	local nearest = nil

	for _, barrier in ipairs(BarrierParts) do
		if barrier and barrier.Parent then
			local hit =
				rayBarrierIntersection(
					origin,
					direction,
					barrier
				)

			if hit
				and (
					not nearest
					or hit.Distance < nearest.Distance
				)
			then
				nearest = hit
			end
		end
	end

	if nearest then
		return {
			Position = nearest.Position,
			Instance = nearest.Instance,
			Normal = Vector3.zero,
			Distance = nearest.Distance
		}
	end

	return nil
end

local function getSpaceField(position)
	local nearest = math.huge
	local total = 0
	local closeRays = 0
	local origin = position + Vector3.new(0, 1.25, 0)

	for i = 0, SPACE_RAYS - 1 do
		local angle = (i / SPACE_RAYS) * math.pi * 2

		local direction =
			Vector3.new(
				math.cos(angle),
				0,
				math.sin(angle)
			)

		local result =
			solidWallRaycast(
				origin,
				direction * SPACE_CHECK_DISTANCE
			)

		local distance =
			result
				and result.Distance
				or SPACE_CHECK_DISTANCE

		nearest = math.min(nearest, distance)
		total += distance

		if distance < SPACE_COMFORT_DISTANCE then
			closeRays += 1
		end
	end

	return {
		Nearest = nearest,
		Average = total / SPACE_RAYS,
		CloseRays = closeRays,
		Corner =
			closeRays
				>= SPACE_CORNER_CLOSE_RAYS
	}
end

local function getNearestBarrierInfo(position)
	local useRootCache =
		DecisionGeometryCacheActive
		and DecisionRootPosition ~= nil
		and position == DecisionRootPosition

	if useRootCache
		and DecisionRootBarrierInfoCached
	then
		return DecisionRootBarrierInfo
	end

	local samplePoint =
		position + Vector3.new(0, 1.25, 0)

	local best = nil

	for _, barrier in ipairs(BarrierParts) do
		if barrier and barrier.Parent then
			local point =
				closestPointOnBarrier(
					barrier,
					samplePoint
				)

			local delta = point - samplePoint
			local horizontal =
				Vector3.new(
					delta.X,
					0,
					delta.Z
				)

			local distance = horizontal.Magnitude

			if not best or distance < best.Distance then
				local direction =
					distance > 0.001
					and horizontal.Unit
					or Vector3.zero

				best = {
					Distance = distance,
					HitPosition = point,
					RayDirection = direction,
					Normal = -direction,
					Instance = barrier
				}
			end
		end
	end

	if useRootCache then
		DecisionRootBarrierInfo = best
		DecisionRootBarrierInfoCached = true
		DecisionRootBarrierDistance =
			best and best.Distance or math.huge
		DecisionRootBarrierDistanceCached = true
	end

	return best
end

local function getNearestBarrierDistance(position)
	local useRootCache =
		DecisionGeometryCacheActive
		and DecisionRootPosition ~= nil
		and position == DecisionRootPosition

	if useRootCache
		and DecisionRootBarrierDistanceCached
	then
		return DecisionRootBarrierDistance
	end

	local samplePoint =
		position + Vector3.new(0, 1.25, 0)
	local nearest = math.huge

	for _, barrier in ipairs(BarrierParts) do
		if barrier and barrier.Parent then
			local point =
				closestPointOnBarrier(
					barrier,
					samplePoint
				)

			local dx = point.X - samplePoint.X
			local dz = point.Z - samplePoint.Z
			local distance = math.sqrt(dx * dx + dz * dz)

			if distance < nearest then
				nearest = distance
			end
		end
	end

	if useRootCache then
		DecisionRootBarrierDistance = nearest
		DecisionRootBarrierDistanceCached = true
	end

	return nearest
end

local predictPlayerOffset
local barrierPathBlocked

local function getBarrierReserveVector(position)
	local samplePoint =
		position + Vector3.new(0, 1.25, 0)

	local sum = Vector3.zero
	local nearestDistance = math.huge

	for _, barrier in ipairs(BarrierParts) do
		if barrier and barrier.Parent then
			local point =
				closestPointOnBarrier(
					barrier,
					samplePoint
				)

			local delta =
				Vector3.new(
					samplePoint.X - point.X,
					0,
					samplePoint.Z - point.Z
				)

			local distance = delta.Magnitude
			nearestDistance =
				math.min(
					nearestDistance,
					distance
				)

			if distance < BARRIER_RESERVE_TARGET + 2.0 then
				local away

				if distance > 0.001 then
					away = delta.Unit
				else
					local info =
						getNearestBarrierInfo(position)

					away =
						info
						and (-info.RayDirection)
						or Vector3.zero
				end

				local deficit =
					math.max(
						0,
						BARRIER_RESERVE_TARGET
							- distance
					)

				local normalized =
					math.clamp(
						deficit
							/ BARRIER_RESERVE_TARGET,
						0,
						1
					)

				local weight =
					normalized
					* normalized
					+ 0.08

				sum += away * weight
			end
		end
	end

	return sum, nearestDistance
end

local function getBarrierReserveMove(root)
	if not predictPlayerOffset
		or not barrierPathBlocked
	then
		BarrierReserveActive = false
		return nil, getNearestBarrierDistance(root.Position)
	end

	local reserveVector, distance =
		getBarrierReserveVector(root.Position)

	lastBarrierReserveDistance = distance

	if BarrierReserveActive then
		if distance >= BARRIER_RESERVE_RELEASE then
			BarrierReserveActive = false
		end
	elseif distance < BARRIER_RESERVE_TRIGGER then
		BarrierReserveActive = true
	end

	if not BarrierReserveActive
		or reserveVector.Magnitude < 0.01
	then
		return nil, distance
	end

	local deficit =
		math.max(
			0,
			BARRIER_RESERVE_TARGET - distance
		)

	local magnitude =
		BARRIER_RESERVE_MIN_MOVE
		+ math.clamp(
			deficit
				/ math.max(
					BARRIER_RESERVE_TARGET
						- BARRIER_RESERVE_EMERGENCY_DISTANCE,
					0.001
				),
			0,
			1
		)
			* (
				BARRIER_RESERVE_MAX_MOVE
					- BARRIER_RESERVE_MIN_MOVE
			)

	if distance <= BARRIER_RESERVE_EMERGENCY_DISTANCE then
		magnitude = BARRIER_RESERVE_MAX_MOVE
	end

	local direction =
		reserveVector.Unit * magnitude

	local currentVelocity =
		flatVector(root.AssemblyLinearVelocity)

	local targetVelocity =
		direction * (
			root.Parent
			and root.Parent:FindFirstChildOfClass("Humanoid")
			and root.Parent:FindFirstChildOfClass("Humanoid").WalkSpeed
			or 16
		)

	local future =
		root.Position
		+ predictPlayerOffset(
			currentVelocity,
			targetVelocity,
			BARRIER_RESERVE_LOOKAHEAD
		)

	local blocked =
		barrierPathBlocked(
			root.Position,
			future
		)

	if blocked then
		return nil, distance
	end

	return direction, distance
end


barrierPathBlocked = function(fromPosition, toPosition)
	local delta = toPosition - fromPosition
	local distance = delta.Magnitude

	if distance < 0.01 then
		return false, math.huge
	end

	local unit = delta / distance
	local right = Vector3.new(-unit.Z, 0, unit.X)
	local baseOrigin =
		fromPosition + Vector3.new(0, 1.25, 0)

	local result = solidWallRaycast(baseOrigin, delta)
	if result then
		return true, result.Distance
	end

	local sideOffset = right * SPACE_PATH_RADIUS
	local leftOrigin = baseOrigin + sideOffset
	result = solidWallRaycast(leftOrigin, delta)
	if result then
		return true, result.Distance
	end

	local rightOrigin = baseOrigin - sideOffset
	result = solidWallRaycast(rightOrigin, delta)
	if result then
		return true, result.Distance
	end

	return false, math.huge
end

predictPlayerOffset = function(currentVelocity, targetVelocity, t)
	if t <= 0 then
		return Vector3.zero
	end

	if t <= DODGE_ACTUATION_DELAY then
		return currentVelocity * t
	end

	local before =
		currentVelocity * DODGE_ACTUATION_DELAY

	local activeTime =
		t - DODGE_ACTUATION_DELAY

	if activeTime <= PLAYER_RESPONSE_TIME then
		local acceleration =
			(targetVelocity - currentVelocity)
			/ PLAYER_RESPONSE_TIME

		return before
			+ currentVelocity * activeTime
			+ acceleration
				* (0.5 * activeTime * activeTime)
	end

	local responseOffset =
		(currentVelocity + targetVelocity)
		* 0.5
		* PLAYER_RESPONSE_TIME

	return before
		+ responseOffset
		+ targetVelocity
			* (activeTime - PLAYER_RESPONSE_TIME)
end

local function evaluateSpacePath(root, humanoid, direction, threatCount)
	local currentBarrierDistance =
		getNearestBarrierDistance(root.Position)

	local currentVelocity =
		flatVector(root.AssemblyLinearVelocity)

	local targetVelocity =
		direction * humanoid.WalkSpeed

	local result = {
		Risk = 0,
		MinClearance = currentBarrierDistance,
		WorstCloseRays = 0,
		Fatal = false,
		EscapeGain = 0,
		PathBlocked = false,
		MovingTowardWall = false,
		BarrierDistanceLoss = 0,
		FutureBarrierDistance = currentBarrierDistance,
		EndBarrierDistance = currentBarrierDistance,
		ReserveDeficit =
			math.max(
				0,
				BARRIER_RESERVE_TARGET
					- currentBarrierDistance
			),
		ReserveSatisfied =
			currentBarrierDistance
				>= BARRIER_RESERVE_TARGET
	}

	local nearestBarrier =
		getNearestBarrierInfo(root.Position)

	if direction.Magnitude > 0.01
		and nearestBarrier
	then
		local towardDot =
			direction.Unit:Dot(
				nearestBarrier.RayDirection
			)

		result.MovingTowardWall = towardDot > 0
	end

	local previousPosition = root.Position

	for _, t in ipairs(BARRIER_PLAN_TIMES) do
		local future =
			root.Position
			+ predictPlayerOffset(
				currentVelocity,
				targetVelocity,
				t
			)

		local blocked =
			barrierPathBlocked(
				previousPosition,
				future
			)

		if blocked then
			result.PathBlocked = true
			result.Fatal = true
			result.Risk = BARRIER_HARD_REJECT_SCORE
			result.MinClearance = 0
			result.FutureBarrierDistance = 0
			result.EndBarrierDistance = 0
			result.ReserveDeficit =
				BARRIER_RESERVE_TARGET
			result.ReserveSatisfied = false
			return result
		end

		local distance =
			getNearestBarrierDistance(future)

		result.MinClearance =
			math.min(
				result.MinClearance,
				distance
			)

		result.FutureBarrierDistance =
			math.min(
				result.FutureBarrierDistance,
				distance
			)

		result.EndBarrierDistance = distance

		-- Only physical / severe boundary safety contributes raw wall risk.
		-- Ordinary "keep some room" behavior is handled by ReserveDeficit
		-- as a direct planning objective below.
		if distance < BARRIER_HARD_MIN_DISTANCE then
			result.Fatal = true

			local penetration =
				BARRIER_HARD_MIN_DISTANCE
					- distance

			result.Risk +=
				BARRIER_HARD_REJECT_SCORE
				+ penetration * 4000

		elseif distance < BARRIER_STRONG_MIN_DISTANCE then
			result.Risk +=
				1200
				+ (
					BARRIER_STRONG_MIN_DISTANCE
						- distance
				) * 650
		end

		previousPosition = future
	end

	if currentBarrierDistance < math.huge
		and result.EndBarrierDistance < math.huge
	then
		local delta =
			result.EndBarrierDistance
				- currentBarrierDistance

		if delta < -BARRIER_DISTANCE_EPSILON then
			result.BarrierDistanceLoss = -delta
		elseif delta > BARRIER_DISTANCE_EPSILON then
			result.EscapeGain = delta
		end
	end

	result.ReserveDeficit =
		math.max(
			0,
			BARRIER_RESERVE_TARGET
				- result.EndBarrierDistance
		)

	result.ReserveSatisfied =
		result.EndBarrierDistance
			>= BARRIER_RESERVE_TARGET

	return result
end

local function barrierDistance(position, direction)
	if direction.Magnitude < 0.01 then
		return math.huge
	end

	local origin = position + Vector3.new(0, 1.25, 0)

	local result =
		solidWallRaycast(
			origin,
			direction.Unit
				* REAR_BARRIER_CHECK_DISTANCE
		)

	if result then
		return (result.Position - origin).Magnitude
	end

	return math.huge
end

local function wallProximityAt(position, params)
	local nearest = math.huge
	local closeCount = 0
	local totalPenalty = 0
	local origin = position + Vector3.new(0, 1.25, 0)

	for i = 0, WALL_RADIAL_RAYS - 1 do
		local angle = (i / WALL_RADIAL_RAYS) * math.pi * 2

		local direction =
			Vector3.new(
				math.cos(angle),
				0,
				math.sin(angle)
			)

		local result =
			solidWallRaycast(
				origin,
				direction * WALL_CHECK_DISTANCE
			)

		if result then
			local distance =
				(result.Position - origin).Magnitude

			nearest = math.min(nearest, distance)

			if distance < WALL_COMFORT_DISTANCE then
				closeCount += 1

				local closeness =
					1 - math.clamp(
						distance / WALL_COMFORT_DISTANCE,
						0,
						1
					)

				totalPenalty +=
					closeness
					* closeness
					* WALL_PROXIMITY_WEIGHT
			end

			if distance < WALL_HARD_DISTANCE then
				local hardCloseness =
					1 - math.clamp(
						distance / WALL_HARD_DISTANCE,
						0,
						1
					)

				totalPenalty +=
					60
					+ hardCloseness * 80
			end
		end
	end

	if closeCount >= 2 then
		totalPenalty +=
			(closeCount - 1)
			* WALL_CORNER_WEIGHT
	end

	return totalPenalty, nearest, closeCount
end

local function environmentRisk(character, humanoid, root, direction)
	if direction.Magnitude < 0.01 then
		return 0
	end

	local currentVelocity =
		flatVector(root.AssemblyLinearVelocity)

	local targetVelocity =
		direction * math.max(
			1,
			humanoid.WalkSpeed
		)

	local future =
		root.Position
		+ predictPlayerOffset(
			currentVelocity,
			targetVelocity,
			0.24
		)

	local floorParams = getRayParams(character)

	local floor =
		workspace:Raycast(
			future + Vector3.new(0, 1.5, 0),
			Vector3.new(0, -FLOOR_CHECK_DISTANCE, 0),
			floorParams
		)

	return floor and 0 or 220
end

local function getBaseDirection(humanoid, root)
	local move = flatUnit(humanoid.MoveDirection)
	if move.Magnitude > 0 then return move end

	local look = flatUnit(root.CFrame.LookVector)
	if look.Magnitude > 0 then return look end

	return Vector3.new(0, 0, -1)
end

local function closestRelativeSegment(r0, r1)
	local delta = r1 - r0
	local lengthSquared = delta:Dot(delta)

	if lengthSquared <= 0.000001 then
		return r0.Magnitude, 0
	end

	local alpha =
		math.clamp(
			-r0:Dot(delta) / lengthSquared,
			0,
			1
		)

	local closest =
		r0 + delta * alpha

	return closest.Magnitude, alpha
end

local function buildThreatSnapshot(root, humanoid, knownOnly)
	local threats = {}
	local relevant = 0
	local networkLead = getNetworkLead()
	local snapshotNow = os.clock()
	local difficulty = getDifficulty()

	local maxPlayerReach =
		humanoid.WalkSpeed
			* PREDICT_TIME
		+ flatVector(
			root.AssemblyLinearVelocity
		).Magnitude
			* DODGE_ACTUATION_DELAY

	for _, data in pairs(ProjectileData) do
		if data.Ready
			and data.Part
			and data.Part.Parent
			and data.Velocity.Magnitude
				>= MIN_PROJECTILE_SPEED
		then
			local profile =
				getDamageProfile(data.Signature)

			if (not knownOnly) or profile.Stable then
				local projRadius =
					data.Radius
					or projectileRadius(
						data.Part,
						data.Object
					)

				local largeExtra = 0

				if projRadius >= LARGE_PROJECTILE_RADIUS then
					largeExtra =
						math.min(
							LARGE_PROJECTILE_EXTRA_MAX,
							projRadius
								* LARGE_PROJECTILE_EXTRA_SCALE
						)
				end

				local geometryDangerRadius =
					PLAYER_RADIUS
					+ PLAYER_HITBOX_EXTRA
					+ projRadius
					+ EXTRA_MARGIN
					+ largeExtra

				local learnedRadius =
					profile.LearnedContactRadius
					or 0

				local dangerRadius =
					math.max(
						geometryDangerRadius,
						learnedRadius
					)

				local predictionError =
					data.PredictionError or 0

				local reverseUncertainty =
					snapshotNow < (data.ReverseUntil or 0)
					and REVERSE_UNCERTAINTY_EXTRA
					or 0

				local uncertaintyMargin =
					math.clamp(
						BASE_UNCERTAINTY_MARGIN
							+ predictionError
								* PREDICTION_ERROR_WEIGHT
							+ data.Velocity.Magnitude
								* SPEED_UNCERTAINTY_WEIGHT
							+ reverseUncertainty,
						BASE_UNCERTAINTY_MARGIN,
						MAX_UNCERTAINTY_MARGIN
					)

				local safetyRadius =
					dangerRadius
					+ SAFE_EXTRA
					+ uncertaintyMargin

				local influenceRadius =
					safetyRadius
					+ 0.65
					+ largeExtra * 0.35

				local positions = {}
				local stationaryMin = math.huge
				local stationaryClosestTime = math.huge
				local previousRelative = nil
				local previousTime = 0

				for i, t in ipairs(THREAT_KNOTS) do
					local projectileTime =
						t + networkLead

					local pos =
						predictProjectile(
							data,
							projectileTime
						)

					positions[i] = pos

					local relative =
						pos - root.Position

					local distance =
						relative.Magnitude

					if distance < stationaryMin then
						stationaryMin = distance
						stationaryClosestTime = t
					end

					if previousRelative then
						local sweptDistance, alpha =
							closestRelativeSegment(
								previousRelative,
								relative
							)

						if sweptDistance < stationaryMin then
							stationaryMin = sweptDistance
							stationaryClosestTime =
								previousTime
								+ (
									t - previousTime
								) * alpha
						end
					end

					previousRelative = relative
					previousTime = t
				end

				local canMatter =
					stationaryMin
						<= influenceRadius
							+ maxPlayerReach
							+ THREAT_RELEVANCE_MARGIN

				if canMatter then
					relevant += 1

					threats[#threats + 1] = {
						Signature = data.Signature,
						Damage =
							profile.BaseDamage
								and (
									profile.BaseDamage
									* difficulty
								)
								or nil,
						BaseDamage = profile.BaseDamage,
						DamageStable = profile.Stable,
						DamageConfidence =
							profile.BaseConfidence
								or profile.Confidence,
						ProjectileRadius = projRadius,
						DangerRadius = dangerRadius,
						SafetyRadius = safetyRadius,
						InfluenceRadius = influenceRadius,
						UncertaintyMargin = uncertaintyMargin,
						Positions = positions,
						InterpolationCache = {},
						StationaryClosestTime =
							stationaryClosestTime,
						Velocity = data.Velocity
					}
				end
			end
		end
	end

	lastRelevantThreats = relevant
	lastEvaluatedThreats = relevant

	return threats
end

local function evaluateProjectileField(
	root,
	humanoid,
	direction,
	threats
)
	local rootPosition = root.Position

	local currentVelocity =
		flatVector(
			root.AssemblyLinearVelocity
		)

	local targetVelocity =
		direction * humanoid.WalkSpeed

	local totalRisk = 0
	local hardHits = 0
	local unsafeHits = 0
	local immediateHits = 0
	local immediateUnsafeHits = 0
	local lethalImmediateHits = 0
	local lethalUnsafeHits = 0
	local nearThreats = 0
	local nearestImpact = math.huge
	local nearestUnsafeImpact = math.huge
	local minimumClearance = math.huge
	local requiredTriggerTime = TRIGGER_TIME
	local urgentDamage = 0
	local dominantThreat = nil
	local dominantUrgency = -math.huge

	local playerPositions = table.create(#THREAT_KNOTS)
	for i, t in ipairs(THREAT_KNOTS) do
		playerPositions[i] =
			rootPosition
			+ predictPlayerOffset(
				currentVelocity,
				targetVelocity,
				t
			)
	end

	for _, threat in ipairs(threats) do
		local minDistance = math.huge
		local closestTime = math.huge
		local previousRelative = nil
		local previousTime = 0

		for i, t in ipairs(THREAT_KNOTS) do
			local playerFuture =
				playerPositions[i]

			local projectileFuture =
				threat.Positions[i]

			local relative =
				projectileFuture
				- playerFuture

			local distance =
				relative.Magnitude

			if distance < minDistance then
				minDistance = distance
				closestTime = t
			end

			if previousRelative then
				local sweptDistance, alpha =
					closestRelativeSegment(
						previousRelative,
						relative
					)

				if sweptDistance < minDistance then
					minDistance = sweptDistance
					closestTime =
						previousTime
						+ (
							t - previousTime
						) * alpha
				end
			end

			previousRelative = relative
			previousTime = t
		end

		local robustClearance =
			minDistance
				- threat.SafetyRadius

		minimumClearance =
			math.min(
				minimumClearance,
				robustClearance
			)

		local estimatedDamage =
			threat.DamageStable
				and threat.Damage
				or UNKNOWN_DAMAGE_ESTIMATE

		local damageWeight =
			math.clamp(
				estimatedDamage
					/ DAMAGE_REFERENCE,
				0.40,
				DAMAGE_MAX_WEIGHT
			)

		local timeFactor =
			1 - math.clamp(
				closestTime
					/ PREDICT_TIME,
				0,
				1
			)

		if minDistance <= threat.InfluenceRadius then
			nearThreats += 1
		end

		local unsafe =
			minDistance <= threat.SafetyRadius

		local hard =
			minDistance <= threat.DangerRadius

		if unsafe then
			unsafeHits += 1

			local effectiveSpeed =
				math.max(
					humanoid.WalkSpeed
						* EFFECTIVE_DODGE_SPEED_FACTOR,
					1
				)

			local requiredMoveTime =
				threat.SafetyRadius
					/ effectiveSpeed
				+ DODGE_REACTION_BUFFER
				+ DODGE_ACTUATION_DELAY

			local threatTriggerTime =
				math.clamp(
					math.max(
						TRIGGER_TIME,
						requiredMoveTime
					),
					TRIGGER_TIME,
					MAX_DYNAMIC_TRIGGER_TIME
				)

			if threat.ProjectileRadius
				>= LARGE_PROJECTILE_RADIUS
			then
				threatTriggerTime =
					math.max(
						threatTriggerTime,
						math.min(
							MAX_DYNAMIC_TRIGGER_TIME,
							LARGE_PROJECTILE_TRIGGER_MAX
								+ LARGE_PROJECTILE_TRIGGER_BONUS
									* 0.45
						)
					)
			end

			requiredTriggerTime =
				math.max(
					requiredTriggerTime,
					threatTriggerTime
				)

			nearestUnsafeImpact =
				math.min(
					nearestUnsafeImpact,
					closestTime
				)

			if closestTime <= threatTriggerTime then
				immediateUnsafeHits += 1
				urgentDamage += estimatedDamage

				if estimatedDamage >= humanoid.Health then
					lethalUnsafeHits += 1
				end
			end

			local safetyPenetration =
				1 - math.clamp(
					minDistance
						/ math.max(
							threat.SafetyRadius,
							0.001
						),
					0,
					1
				)

			totalRisk +=
				(
					180
					+ safetyPenetration * 220
					+ timeFactor * 170
				)
				* damageWeight

			local urgency =
				(1 / math.max(closestTime, 0.020))
				* (
					1
					+ safetyPenetration * 2.4
				)
				* damageWeight

			if urgency > dominantUrgency then
				dominantUrgency = urgency
				dominantThreat = threat
			end
		end

		if hard then
			hardHits += 1

			nearestImpact =
				math.min(
					nearestImpact,
					closestTime
				)

			if closestTime <= requiredTriggerTime then
				immediateHits += 1

				if estimatedDamage >= humanoid.Health then
					lethalImmediateHits += 1
				end
			end

			local normalizedPenetration =
				1 - math.clamp(
					minDistance
						/ math.max(
							threat.DangerRadius,
							0.001
						),
					0,
					1
				)

			local baseRisk =
				COLLISION_PENALTY
				+ normalizedPenetration * 320
				+ timeFactor * 260

			local healthMultiplier = 1

			if estimatedDamage >= humanoid.Health then
				healthMultiplier =
					LETHAL_DAMAGE_MULTIPLIER
			elseif estimatedDamage >= humanoid.Health * 0.5 then
				healthMultiplier =
					HEAVY_DAMAGE_MULTIPLIER
			elseif estimatedDamage >= humanoid.Health * 0.25 then
				healthMultiplier =
					MEDIUM_DAMAGE_MULTIPLIER
			end

			totalRisk +=
				baseRisk
				* damageWeight
				* healthMultiplier

		elseif minDistance <= threat.InfluenceRadius then
			local buffer =
				math.max(
					threat.InfluenceRadius
						- threat.SafetyRadius,
					0.001
				)

			local nearFactor =
				1 - math.clamp(
					(minDistance
						- threat.SafetyRadius)
						/ buffer,
					0,
					1
				)

			totalRisk +=
				nearFactor
				* nearFactor
				* NEAR_MISS_WEIGHT
				* (0.65 + timeFactor)
				* damageWeight
		end
	end

	if nearThreats > 1 then
		totalRisk +=
			(nearThreats - 1)
			* (nearThreats - 1)
			* MULTI_THREAT_WEIGHT
	end

	return {
		Risk = totalRisk,
		HardHits = hardHits,
		UnsafeHits = unsafeHits,
		ImmediateHits = immediateHits,
		ImmediateUnsafeHits = immediateUnsafeHits,
		LethalImmediateHits = lethalImmediateHits,
		LethalUnsafeHits = lethalUnsafeHits,
		UrgentDamage = urgentDamage,
		NearThreats = nearThreats,
		NearestImpact = nearestImpact,
		NearestUnsafeImpact = nearestUnsafeImpact,
		MinimumClearance = minimumClearance,
		RequiredTriggerTime = requiredTriggerTime,
		DominantThreat = dominantThreat
	}
end

local function isReverseForwardMode()
	return os.clock() - lastReverseEventTime
		< REVERSE_FORWARD_MODE_TIME
end


local function movementPenalty(direction, referenceDirection, root, learningKnownDodge)
	if direction.Magnitude < 0.01 then
		return 0
	end

	local magnitudePenalty = direction.Magnitude * MOVE_PENALTY
	local anglePenalty = 0
	local preferencePenalty = 0
	local reversePenalty = 0

	if referenceDirection.Magnitude > 0.01 then
		local reference = referenceDirection.Unit
		local dir = direction.Unit

		local dot = math.clamp(reference:Dot(dir), -1, 1)
		anglePenalty = (1 - dot) * TURN_PENALTY

		local sideways = 1 - math.abs(dot)
		preferencePenalty -= sideways * SIDE_PREFERENCE_WEIGHT

		if isReverseForwardMode() then
			if dot > 0 then
				preferencePenalty -=
					dot
					* REVERSE_FORWARD_SCORE_BONUS
			else
				reversePenalty +=
					(-dot)
					* REVERSE_FORWARD_BACKWARD_PENALTY
			end
		end

		if dot < BACKWARD_DOT_LIMIT then
			local backwardAmount = math.clamp(-dot, 0, 1)

			reversePenalty +=
				BACKWARD_BASE_PENALTY
				+ backwardAmount * BACKWARD_EXTRA_WEIGHT
				+ backwardAmount
					* direction.Magnitude
					* 18

			local rearDistance =
				barrierDistance(
					root.Position,
					-reference
				)

			if rearDistance < REAR_BARRIER_CHECK_DISTANCE then
				local closeness =
					1 - math.clamp(
						rearDistance / REAR_BARRIER_CHECK_DISTANCE,
						0,
						1
					)

				reversePenalty +=
					closeness
					* closeness
					* REAR_BARRIER_PENALTY

				if learningKnownDodge then
					reversePenalty +=
						closeness
						* closeness
						* LEARNING_KNOWN_REAR_BARRIER_EXTRA
				end

				if rearDistance < REAR_BARRIER_HARD_DISTANCE then
					reversePenalty += REAR_BARRIER_HARD_PENALTY
				end
			end
		end
	end

	local continuityPenalty = 0

	if DODGING
		and dodgeDirection.Magnitude > 0.01
		and direction.Magnitude > 0.01
	then
		local dodgeDot =
			math.clamp(
				dodgeDirection.Unit:Dot(direction.Unit),
				-1,
				1
			)

		continuityPenalty =
			(1 - dodgeDot)
			* DODGE_CONTINUITY_PENALTY
	end

	return
		magnitudePenalty
		+ anglePenalty
		+ preferencePenalty
		+ reversePenalty
		+ continuityPenalty
end

local function evaluateCandidate(
	character,
	humanoid,
	root,
	direction,
	referenceDirection,
	threats,
	learningKnownDodge
)
	local cacheX, cacheZ, cacheY

	if DecisionCandidateEvalCache then
		cacheX = DecisionCandidateEvalCache[direction.X]
		if cacheX then
			cacheZ = cacheX[direction.Z]
			if cacheZ then
				local cached = cacheZ[direction.Y]
				if cached then
					return cached
				end
			end
		end
	end

	local field =
		evaluateProjectileField(
			root,
			humanoid,
			direction,
			threats
		)

	local space =
		evaluateSpacePath(
			root,
			humanoid,
			direction,
			#threats
		)

	local floorRisk =
		environmentRisk(
			character,
			humanoid,
			root,
			direction
		)

	field.EnvironmentRisk = floorRisk
	field.SpaceRisk = space.Risk
	field.SpaceFatal = space.Fatal
	field.SpacePathBlocked = space.PathBlocked
	field.SpaceMovingTowardWall = space.MovingTowardWall
	field.SpaceBarrierDistanceLoss =
		space.BarrierDistanceLoss or 0
	field.SpaceFutureBarrierDistance =
		space.FutureBarrierDistance or math.huge
	field.SpaceEndBarrierDistance =
		space.EndBarrierDistance or math.huge
	field.BarrierReserveDeficit =
		space.ReserveDeficit or 0
	field.BarrierReserveSatisfied =
		space.ReserveSatisfied == true
	field.SpaceMinClearance = space.MinClearance
	field.SpaceCloseRays = space.WorstCloseRays

	field.MovePenalty =
		movementPenalty(
			direction,
			referenceDirection,
			root,
			learningKnownDodge
		)

	if direction.Magnitude > 0.01
		and referenceDirection.Magnitude > 0.01
	then
		local preferenceDot =
			math.clamp(
				referenceDirection.Unit:Dot(
					direction.Unit
				),
				-1,
				1
			)

		field.ReferenceDot = preferenceDot
		field.LateralAmount =
			1 - math.abs(preferenceDot)
		field.RetreatAmount =
			math.max(
				0,
				-preferenceDot
			)
	else
		field.ReferenceDot = 0
		field.LateralAmount = 0
		field.RetreatAmount = 0
	end

	field.MoveMagnitude =
		direction.Magnitude

	local coreRisk =
		math.max(
			0,
			field.Risk
				+ field.SpaceRisk
				+ floorRisk * 5
		)

	field.Score =
		coreRisk
		+ field.MovePenalty

	if DecisionCandidateEvalCache then
		cacheX = cacheX or {}
		DecisionCandidateEvalCache[direction.X] = cacheX
		cacheZ = cacheZ or {}
		cacheX[direction.Z] = cacheZ
		cacheZ[direction.Y] = field
	end

	return field
end

local function betterCandidate(a, b)
	if not b then
		return true
	end

	if a.Eval.SpacePathBlocked ~= b.Eval.SpacePathBlocked then
		return not a.Eval.SpacePathBlocked
	end

	-- Actual predicted damage is the primary objective.
	if a.Eval.LethalImmediateHits ~= b.Eval.LethalImmediateHits then
		return a.Eval.LethalImmediateHits
			< b.Eval.LethalImmediateHits
	end

	if a.Eval.ImmediateHits ~= b.Eval.ImmediateHits then
		return a.Eval.ImmediateHits
			< b.Eval.ImmediateHits
	end

	if a.Eval.HardHits ~= b.Eval.HardHits then
		return a.Eval.HardHits
			< b.Eval.HardHits
	end

	if a.Eval.HardHits > 0
		and b.Eval.HardHits > 0
		and math.abs(
			a.Eval.NearestImpact
				- b.Eval.NearestImpact
		) > 0.018
	then
		return a.Eval.NearestImpact
			> b.Eval.NearestImpact
	end

	-- Only after physical collision counts are equal do we use the
	-- uncertainty/safety envelope.
	if a.Eval.LethalUnsafeHits ~= b.Eval.LethalUnsafeHits then
		return a.Eval.LethalUnsafeHits
			< b.Eval.LethalUnsafeHits
	end

	if a.Eval.ImmediateUnsafeHits ~= b.Eval.ImmediateUnsafeHits then
		return a.Eval.ImmediateUnsafeHits
			< b.Eval.ImmediateUnsafeHits
	end

	if a.Eval.UnsafeHits ~= b.Eval.UnsafeHits then
		return a.Eval.UnsafeHits
			< b.Eval.UnsafeHits
	end

	if a.Eval.UnsafeHits > 0
		and b.Eval.UnsafeHits > 0
		and math.abs(
			a.Eval.NearestUnsafeImpact
				- b.Eval.NearestUnsafeImpact
		) > 0.020
	then
		return a.Eval.NearestUnsafeImpact
			> b.Eval.NearestUnsafeImpact
	end

	if a.Eval.SpaceFatal ~= b.Eval.SpaceFatal then
		return not a.Eval.SpaceFatal
	end

	local reserveRelevant =
		(a.Eval.BarrierReserveDeficit or 0) > 0
		or (b.Eval.BarrierReserveDeficit or 0) > 0
		or BarrierReserveActive

	if reserveRelevant then
		local aDeficit =
			a.Eval.BarrierReserveDeficit or 0

		local bDeficit =
			b.Eval.BarrierReserveDeficit or 0

		if math.abs(aDeficit - bDeficit)
			> BARRIER_RESERVE_COMPARE_EPSILON
		then
			return aDeficit < bDeficit
		end

		-- If both end inside the reserve zone, favor the one that preserves
		-- more minimum clearance along the path.
		if aDeficit > 0
			and bDeficit > 0
			and math.abs(
				a.Eval.SpaceMinClearance
					- b.Eval.SpaceMinClearance
			) > 0.20
		then
			return a.Eval.SpaceMinClearance
				> b.Eval.SpaceMinClearance
		end
	end

	if isReverseForwardMode() then
		local aForward = a.Eval.ReferenceDot or 0
		local bForward = b.Eval.ReferenceDot or 0

		if math.abs(aForward - bForward)
			> REVERSE_FORWARD_COMPARE_DOT
		then
			return aForward > bForward
		end
	end

	-- If immediate safety is equivalent, prefer a heading that still has
	-- multiple physical exits 0.3~0.5s later instead of entering a pocket.
	if a.Eval.EscapeHardLanes ~= nil
		and b.Eval.EscapeHardLanes ~= nil
	then
		if math.abs(
			a.Eval.EscapeHardLanes
				- b.Eval.EscapeHardLanes
		) >= ESCAPE_HARD_LANE_COMPARE
		then
			return a.Eval.EscapeHardLanes
				> b.Eval.EscapeHardLanes
		end

		if math.abs(
			a.Eval.EscapeSafeLanes
				- b.Eval.EscapeSafeLanes
		) >= ESCAPE_SAFE_LANE_COMPARE
		then
			return a.Eval.EscapeSafeLanes
				> b.Eval.EscapeSafeLanes
		end

		if math.abs(
			a.Eval.EscapeBestClearance
				- b.Eval.EscapeBestClearance
		) > ESCAPE_CLEARANCE_COMPARE
		then
			return a.Eval.EscapeBestClearance
				> b.Eval.EscapeBestClearance
		end
	end

	if math.abs(
		a.Eval.MinimumClearance
			- b.Eval.MinimumClearance
	) > 0.18
	then
		return a.Eval.MinimumClearance
			> b.Eval.MinimumClearance
	end

	if math.abs(a.Eval.Score - b.Eval.Score) > 0.35 then
		return a.Eval.Score < b.Eval.Score
	end

	if math.abs(
		(a.Eval.RetreatAmount or 0)
			- (b.Eval.RetreatAmount or 0)
	) > 0.06
	then
		return (a.Eval.RetreatAmount or 0)
			< (b.Eval.RetreatAmount or 0)
	end

	if math.abs(
		(a.Eval.MoveMagnitude or 0)
			- (b.Eval.MoveMagnitude or 0)
	) > 0.04
	then
		return (a.Eval.MoveMagnitude or 0)
			< (b.Eval.MoveMagnitude or 0)
	end

	if math.abs(
		(a.Eval.LateralAmount or 0)
			- (b.Eval.LateralAmount or 0)
	) > 0.08
	then
		return (a.Eval.LateralAmount or 0)
			> (b.Eval.LateralAmount or 0)
	end

	return false
end

local function profileNeedsLearning(signature)
	local profile = getDamageProfile(signature)
	return not profile.Stable
end

local function isLearningTargetValid(target)
	if not target then
		return false
	end

	local data = ProjectileData[target]
	if not data
		or not data.Part
		or not data.Part.Parent
		or not data.Ready
	then
		return false
	end

	if not profileNeedsLearning(data.Signature) then
		return false
	end

	return true
end

local function chooseLearningTarget(root)
	if isLearningTargetValid(LearningTarget) then
		local data = ProjectileData[LearningTarget]
		if (data.Part.Position - root.Position).Magnitude <= LEARNING_MAX_TARGET_DISTANCE
			and os.clock() - LearningTargetStarted <= LEARNING_TARGET_TIMEOUT
		then
			return LearningTarget
		end
	end

	LearningTarget = nil

	local bestObj = nil
	local bestScore = math.huge

	for obj, data in pairs(ProjectileData) do
		if data.Ready
			and data.Part
			and data.Part.Parent
			and data.Velocity.Magnitude >= LEARNING_MIN_PROJECTILE_SPEED
			and profileNeedsLearning(data.Signature)
		then
			local distance = (data.Part.Position - root.Position).Magnitude

			if distance <= LEARNING_MAX_TARGET_DISTANCE then
				local towardPlayer = 0
				local toPlayer = root.Position - data.Part.Position

				if toPlayer.Magnitude > 0.01 then
					towardPlayer =
						math.max(
							0,
							data.Velocity.Unit:Dot(toPlayer.Unit)
						)
				end

				local score =
					distance
					- towardPlayer * 10

				if score < bestScore then
					bestScore = score
					bestObj = obj
				end
			end
		end
	end

	if bestObj then
		LearningTarget = bestObj
		LearningTargetStarted = os.clock()
	end

	return LearningTarget
end

local function getLearningPathPoint(data, humanoid, root)
	if not data or not data.Part or not data.Part.Parent then
		return nil
	end

	local walkSpeed = math.max(humanoid.WalkSpeed, 1)
	local bestReachable = nil
	local bestReachableTime = math.huge
	local bestFallback = nil
	local bestFallbackScore = math.huge

	local t = math.max(LEARNING_PATH_STEP, LEARNING_AIM_LEAD)
	while t <= LEARNING_PATH_PREDICT_TIME do
		local future =
			data.Part.Position
			+ data.Velocity * t
			+ data.Acceleration * (0.5 * t * t)

		local flatFuture = Vector3.new(future.X, root.Position.Y, future.Z)
		local distance = (flatFuture - root.Position).Magnitude
		local arrivalTime = distance / walkSpeed

		if arrivalTime + LEARNING_ARRIVAL_BUFFER <= t then
			if t < bestReachableTime then
				bestReachableTime = t
				bestReachable = flatFuture
			end
		else
			local timingMiss = math.max(0, arrivalTime - t)
			local score = timingMiss * 20 + distance * 0.03
			if score < bestFallbackScore then
				bestFallbackScore = score
				bestFallback = flatFuture
			end
		end

		t += LEARNING_PATH_STEP
	end

	return bestReachable or bestFallback
end

local function getLearningMoveDirection(character, humanoid, root)
	if not LEARNING_MODE then
		return nil
	end

	if humanoid.MaxHealth <= 0 then
		return nil
	end

	local healthRatio = humanoid.Health / humanoid.MaxHealth
	if healthRatio < LEARNING_MIN_HEALTH_RATIO then
		return nil
	end

	refreshModeKey()

	local targetObj = chooseLearningTarget(root)
	if not targetObj then
		return nil
	end

	local data = ProjectileData[targetObj]
	if not data or not data.Part then
		return nil
	end

	local pathPoint = getLearningPathPoint(data, humanoid, root)
	if not pathPoint then
		return nil
	end

	local delta = flatVector(pathPoint - root.Position)
	local distance = delta.Magnitude

	if distance <= LEARNING_PATH_HOLD_RADIUS then
		return Vector3.zero
	end

	if distance < 0.01 then
		return nil
	end

	return delta.Unit * LEARNING_MOVE_MAGNITUDE
end

local function addUniqueDirection(list, direction)
	if not direction
		or direction.Magnitude < 0.01
	then
		return
	end

	local unit = direction.Unit

	for _, existing in ipairs(list) do
		if existing.Magnitude > 0.01
			and existing.Unit:Dot(unit) > 0.997
		then
			return
		end
	end

	list[#list + 1] = direction
end

local function nearestThreatKnotIndex(targetTime)
	local bestIndex = 1
	local bestDelta = math.huge

	for i, t in ipairs(THREAT_KNOTS) do
		local delta = math.abs(t - targetTime)

		if delta < bestDelta then
			bestDelta = delta
			bestIndex = i
		end
	end

	return bestIndex
end

local function scoreGapPoint(
	root,
	humanoid,
	point,
	threats,
	targetTime
)
	local knotIndex =
		nearestThreatKnotIndex(targetTime)

	local hardOverlaps = 0
	local safetyOverlaps = 0
	local minimumHardClearance = math.huge
	local minimumSafetyClearance = math.huge
	local risk = 0

	for _, threat in ipairs(threats) do
		local projectilePosition =
			threat.Positions[knotIndex]

		if projectilePosition then
			local flatProjectile =
				Vector3.new(
					projectilePosition.X,
					point.Y,
					projectilePosition.Z
				)

			local distance =
				(flatProjectile - point).Magnitude

			local hardClearance =
				distance
				- threat.DangerRadius
				- GAP_ROUTE_MARGIN

			local safetyClearance =
				distance
				- threat.SafetyRadius

			minimumHardClearance =
				math.min(
					minimumHardClearance,
					hardClearance
				)

			minimumSafetyClearance =
				math.min(
					minimumSafetyClearance,
					safetyClearance
				)

			if hardClearance <= 0 then
				hardOverlaps += 1

				risk +=
					5000
					+ math.abs(hardClearance) * 700
			elseif safetyClearance <= 0 then
				safetyOverlaps += 1

				risk +=
					60
					+ math.abs(safetyClearance) * 18
			else
				risk +=
					1
					/ math.max(
						hardClearance,
						0.25
					)
			end
		end
	end

	local blocked =
		barrierPathBlocked(
			root.Position,
			point
		)

	if blocked then
		risk += GAP_BLOCK_PENALTY
	end

	local barrierDistance =
		getNearestBarrierDistance(point)

	if barrierDistance < BARRIER_HARD_MIN_DISTANCE then
		risk += GAP_BLOCK_PENALTY
	elseif barrierDistance < BARRIER_STRONG_MIN_DISTANCE then
		risk += 4500
	elseif barrierDistance < BARRIER_COMFORT_DISTANCE then
		risk +=
			(BARRIER_COMFORT_DISTANCE
				- barrierDistance)
			* 160
	end

	return {
		Point = point,
		Risk = risk,
		HardOverlaps = hardOverlaps,
		SafetyOverlaps = safetyOverlaps,
		MinHardClearance = minimumHardClearance,
		MinSafetyClearance = minimumSafetyClearance,
		BarrierDistance = barrierDistance,
		Blocked = blocked
	}
end

local function betterGap(a, b)
	if not b then
		return true
	end

	if a.Blocked ~= b.Blocked then
		return not a.Blocked
	end

	-- Physical passability comes first.
	if a.HardOverlaps ~= b.HardOverlaps then
		return a.HardOverlaps < b.HardOverlaps
	end

	if math.abs(
		a.MinHardClearance
			- b.MinHardClearance
	) > 0.08 then
		return a.MinHardClearance
			> b.MinHardClearance
	end

	-- Robust margin is only a secondary preference.
	if a.SafetyOverlaps ~= b.SafetyOverlaps then
		return a.SafetyOverlaps
			< b.SafetyOverlaps
	end

	if math.abs(
		a.MinSafetyClearance
			- b.MinSafetyClearance
	) > 0.10 then
		return a.MinSafetyClearance
			> b.MinSafetyClearance
	end

	if math.abs(a.Risk - b.Risk) > 0.05 then
		return a.Risk < b.Risk
	end

	return a.BarrierDistance
		> b.BarrierDistance
end

local function addGapRouteDirections(
	directions,
	root,
	humanoid,
	threats,
	impactTime,
	referenceDirection
)
	if #threats == 0 then
		return
	end

	local targetTimes = {}

	local mainTime =
		math.clamp(
			impactTime == math.huge
				and 0.42
				or impactTime,
			GAP_MIN_TIME,
			GAP_MAX_TIME
		)

	targetTimes[#targetTimes + 1] = mainTime

	if mainTime > GAP_MIN_TIME + 0.08 then
		targetTimes[#targetTimes + 1] =
			math.max(
				GAP_MIN_TIME,
				mainTime - 0.10
			)
	end

	if mainTime < GAP_MAX_TIME - 0.08 then
		targetTimes[#targetTimes + 1] =
			math.min(
				GAP_MAX_TIME,
				mainTime + 0.12
			)
	end

	local gapCandidates = {}
	local walkSpeed = math.max(humanoid.WalkSpeed, 1)

	for _, targetTime in ipairs(targetTimes) do
		local usableTime =
			math.max(
				0.05,
				targetTime
					- DODGE_ACTUATION_DELAY
			)

		local maxReach =
			walkSpeed
				* usableTime
				* EFFECTIVE_DODGE_SPEED_FACTOR

		for _, radiusFactor in ipairs(GAP_RADII) do
			local radius =
				math.max(
					1.0,
					maxReach * radiusFactor
				)

			for i = 0, GAP_SEARCH_ANGLES - 1 do
				local angle =
					i
					* (360 / GAP_SEARCH_ANGLES)

				local direction =
					rotateY(
						referenceDirection,
						angle
					)

				local point =
					root.Position
					+ direction.Unit * radius

				local scored =
					scoreGapPoint(
						root,
						humanoid,
						point,
						threats,
						targetTime
					)

				scored.Direction = direction.Unit
				scored.TargetTime = targetTime

				gapCandidates[#gapCandidates + 1] =
					scored
			end
		end
	end

	table.sort(
		gapCandidates,
		function(a, b)
			return betterGap(a, b)
		end
	)

	local added = 0

	for _, gap in ipairs(gapCandidates) do
		if not gap.Blocked
			and gap.HardOverlaps == 0
		then
			addUniqueDirection(
				directions,
				gap.Direction
			)

			added += 1

			if added >= GAP_SEARCH_TOP then
				break
			end
		end
	end

	-- If every sampled point is physically occupied, still add the least bad
	-- escape routes. Receding-horizon replanning can route around the cluster.
	if added == 0 then
		for i = 1, math.min(GAP_SEARCH_TOP, #gapCandidates) do
			local gap = gapCandidates[i]

			if not gap.Blocked then
				addUniqueDirection(
					directions,
					gap.Direction
				)
			end
		end
	end
end


local function interpolateThreatPosition(threat, t)
	local cache = threat.InterpolationCache
	if cache then
		local cached = cache[t]
		if cached then
			return cached
		end
	end

	local result

	if t <= THREAT_KNOTS[1] then
		result = threat.Positions[1]
	else
		for i = 2, #THREAT_KNOTS do
			local rightTime = THREAT_KNOTS[i]

			if t <= rightTime then
				local leftTime = THREAT_KNOTS[i - 1]
				local span =
					math.max(
						rightTime - leftTime,
						0.0001
					)

				local alpha =
					math.clamp(
						(t - leftTime) / span,
						0,
						1
					)

				result = threat.Positions[i - 1]:Lerp(
					threat.Positions[i],
					alpha
				)
				break
			end
		end
	end

	result = result or threat.Positions[#threat.Positions]

	if cache then
		cache[t] = result
	end

	return result
end

local function routeDirectionAt(plan, t)
	if t < plan.Switch1 then
		return plan.D1
	elseif t < plan.Switch2 then
		return plan.D2
	end

	return plan.D3
end

local function routeTurnAmount(a, b)
	if a.Magnitude < 0.01
		or b.Magnitude < 0.01
	then
		return 0
	end

	local dot =
		math.clamp(
			a.Unit:Dot(b.Unit),
			-1,
			1
		)

	return math.acos(dot) / math.pi
end

local function evaluateRoutePlan(
	root,
	humanoid,
	plan,
	threats,
	referenceDirection
)
	local position = root.Position

	local velocity =
		flatVector(
			root.AssemblyLinearVelocity
		)

	local walkSpeed =
		math.max(
			humanoid.WalkSpeed,
			1
		)

	local hardSeen = {}
	local unsafeSeen = {}
	local immediateSeen = {}
	local immediateUnsafeSeen = {}
	local lethalSeen = {}
	local lethalUnsafeSeen = {}

	local hardHits = 0
	local unsafeHits = 0
	local immediateHits = 0
	local immediateUnsafeHits = 0
	local lethalImmediateHits = 0
	local lethalUnsafeHits = 0

	local nearestImpact = math.huge
	local nearestUnsafeImpact = math.huge
	local minimumClearance = math.huge
	local minimumBarrierClearance =
		getNearestBarrierDistance(position)

	local pathBlocked = false
	local spaceFatal = false
	local risk = 0

	local previousRelatives = {}

	for index, threat in ipairs(threats) do
		previousRelatives[index] =
			interpolateThreatPosition(
				threat,
				0
			) - position
	end

	local t = 0
	local previousPosition = position

	while t < plan.Horizon - 0.0001 do
		local nextT =
			math.min(
				plan.Horizon,
				t + ROUTE_SAMPLE_DT
			)

		local dt =
			nextT - t

		local command =
			routeDirectionAt(
				plan,
				(t + nextT) * 0.5
			)

		local targetVelocity =
			command * walkSpeed

		local nextVelocity = velocity

		if nextT > DODGE_ACTUATION_DELAY then
			local alpha =
				math.clamp(
					dt
						/ math.max(
							PLAYER_RESPONSE_TIME,
							0.001
						),
					0,
					1
				)

			nextVelocity =
				velocity:Lerp(
					targetVelocity,
					alpha
				)
		end

		local nextPosition =
			position
			+ (velocity + nextVelocity)
				* 0.5
				* dt

		local blocked =
			barrierPathBlocked(
				previousPosition,
				nextPosition
			)

		if blocked then
			pathBlocked = true
			spaceFatal = true
			risk += GAP_BLOCK_PENALTY
			break
		end

		local barrierDistance =
			getNearestBarrierDistance(
				nextPosition
			)

		minimumBarrierClearance =
			math.min(
				minimumBarrierClearance,
				barrierDistance
			)

		if barrierDistance
			< BARRIER_HARD_MIN_DISTANCE
		then
			spaceFatal = true

			risk +=
				BARRIER_HARD_REJECT_SCORE
				+ (
					BARRIER_HARD_MIN_DISTANCE
						- barrierDistance
				) * 4000

		elseif barrierDistance
			< BARRIER_STRONG_MIN_DISTANCE
		then
			risk +=
				1200
				+ (
					BARRIER_STRONG_MIN_DISTANCE
						- barrierDistance
				) * 500
		end

		for index, threat in ipairs(threats) do
			local projectilePosition =
				interpolateThreatPosition(
					threat,
					nextT
				)

			local relative =
				projectilePosition
				- nextPosition

			local previousRelative =
				previousRelatives[index]

			local sweptDistance =
				relative.Magnitude

			local sweptAlpha = 1

			if previousRelative then
				sweptDistance,
				sweptAlpha =
					closestRelativeSegment(
						previousRelative,
						relative
					)
			end

			local hitTime =
				t + dt * sweptAlpha

			local hardClearance =
				sweptDistance
					- threat.DangerRadius

			local safeClearance =
				sweptDistance
					- threat.SafetyRadius

			minimumClearance =
				math.min(
					minimumClearance,
					safeClearance
				)

			local estimatedDamage =
				threat.DamageStable
					and threat.Damage
					or UNKNOWN_DAMAGE_ESTIMATE

			local requiredMoveTime =
				threat.SafetyRadius
					/ math.max(
						walkSpeed
							* EFFECTIVE_DODGE_SPEED_FACTOR,
						1
					)
				+ DODGE_REACTION_BUFFER
				+ DODGE_ACTUATION_DELAY

			local trigger =
				math.clamp(
					math.max(
						TRIGGER_TIME,
						requiredMoveTime
					),
					TRIGGER_TIME,
					MAX_DYNAMIC_TRIGGER_TIME
				)

			if hardClearance <= 0 then
				if not hardSeen[index] then
					hardSeen[index] = true
					hardHits += 1
				end

				nearestImpact =
					math.min(
						nearestImpact,
						hitTime
					)

				if hitTime <= trigger
					and not immediateSeen[index]
				then
					immediateSeen[index] = true
					immediateHits += 1

					if estimatedDamage
						>= humanoid.Health
					then
						lethalSeen[index] = true
						lethalImmediateHits += 1
					end
				end

				risk +=
					1200
					+ math.abs(hardClearance)
						* 700
					+ (
						1
						- math.clamp(
							hitTime
								/ plan.Horizon,
							0,
							1
						)
					) * 450

			elseif safeClearance <= 0 then
				if not unsafeSeen[index] then
					unsafeSeen[index] = true
					unsafeHits += 1
				end

				nearestUnsafeImpact =
					math.min(
						nearestUnsafeImpact,
						hitTime
					)

				if hitTime <= trigger
					and not immediateUnsafeSeen[index]
				then
					immediateUnsafeSeen[index] = true
					immediateUnsafeHits += 1

					if estimatedDamage
						>= humanoid.Health
					then
						lethalUnsafeSeen[index] = true
						lethalUnsafeHits += 1
					end
				end

				risk +=
					ROUTE_NEAR_MISS_COST
					* (
						1
						+ math.abs(safeClearance)
					)
			end

			previousRelatives[index] = relative
		end

		previousPosition = nextPosition
		position = nextPosition
		velocity = nextVelocity
		t = nextT
	end

	local endBarrierDistance =
		getNearestBarrierDistance(
			position
		)

	local forwardProgress = 0

	if referenceDirection.Magnitude > 0.01 then
		forwardProgress =
			(position - root.Position):Dot(
				referenceDirection.Unit
			)
	end

	if isReverseForwardMode() then
		if forwardProgress >= 0 then
			risk -=
				forwardProgress
				* REVERSE_FORWARD_ROUTE_BONUS
		else
			risk +=
				(-forwardProgress)
				* REVERSE_FORWARD_ROUTE_BACKWARD_PENALTY
		end
	end

	local reserveDeficit =
		math.max(
			0,
			BARRIER_RESERVE_TARGET
				- endBarrierDistance
		)

	if BarrierReserveActive
		or reserveDeficit > 0
	then
		risk +=
			reserveDeficit
			* ROUTE_RESERVE_COST
	end

	local turnCost =
		routeTurnAmount(
			plan.D1,
			plan.D2
		)
		+ routeTurnAmount(
			plan.D2,
			plan.D3
		)

	risk +=
		turnCost
			* ROUTE_TURN_COST

	local reverseAmount = 0
	local lateralAmount = 0

	if referenceDirection.Magnitude > 0.01
		and plan.D1.Magnitude > 0.01
	then
		local dot =
			math.clamp(
				referenceDirection.Unit:Dot(
					plan.D1.Unit
				),
				-1,
				1
			)

		reverseAmount =
			math.max(
				0,
				-dot
			)

		lateralAmount =
			1 - math.abs(dot)
	end

	risk +=
		reverseAmount
			* ROUTE_REVERSE_COST

	risk +=
		(
			plan.D1.Magnitude
			+ plan.D2.Magnitude * 0.5
			+ plan.D3.Magnitude * 0.25
		)
		* ROUTE_MOVE_COST

	return {
		Risk = risk,
		Score = risk,

		HardHits = hardHits,
		UnsafeHits = unsafeHits,
		ImmediateHits = immediateHits,
		ImmediateUnsafeHits = immediateUnsafeHits,
		LethalImmediateHits = lethalImmediateHits,
		LethalUnsafeHits = lethalUnsafeHits,

		NearestImpact = nearestImpact,
		NearestUnsafeImpact = nearestUnsafeImpact,
		MinimumClearance = minimumClearance,

		SpacePathBlocked = pathBlocked,
		SpaceFatal = spaceFatal,
		SpaceMovingTowardWall = false,
		SpaceBarrierDistanceLoss = 0,
		SpaceFutureBarrierDistance =
			minimumBarrierClearance,
		SpaceEndBarrierDistance =
			endBarrierDistance,
		SpaceMinClearance =
			minimumBarrierClearance,
		SpaceCloseRays = 0,

		BarrierReserveDeficit =
			reserveDeficit,
		BarrierReserveSatisfied =
			reserveDeficit <= 0,

		MovePenalty = 0,
		ReferenceDot =
			referenceDirection.Magnitude > 0.01
				and plan.D1.Magnitude > 0.01
				and math.clamp(
					referenceDirection.Unit:Dot(
						plan.D1.Unit
					),
					-1,
					1
				)
				or 0,
		LateralAmount = lateralAmount,
		RetreatAmount = reverseAmount,
		MoveMagnitude = plan.D1.Magnitude,
		ForwardProgress = forwardProgress,
		RouteStages = 3,
		RouteEndPosition = position
	}
end

local function betterRouteCandidate(a, b)
	if not b then
		return true
	end

	if a.Eval.SpacePathBlocked ~= b.Eval.SpacePathBlocked then
		return not a.Eval.SpacePathBlocked
	end

	if a.Eval.LethalImmediateHits ~= b.Eval.LethalImmediateHits then
		return a.Eval.LethalImmediateHits
			< b.Eval.LethalImmediateHits
	end

	if a.Eval.ImmediateHits ~= b.Eval.ImmediateHits then
		return a.Eval.ImmediateHits
			< b.Eval.ImmediateHits
	end

	if a.Eval.HardHits ~= b.Eval.HardHits then
		return a.Eval.HardHits
			< b.Eval.HardHits
	end

	if a.Eval.HardHits > 0
		and b.Eval.HardHits > 0
		and math.abs(
			a.Eval.NearestImpact
				- b.Eval.NearestImpact
		) > 0.015
	then
		return a.Eval.NearestImpact
			> b.Eval.NearestImpact
	end

	if a.Eval.ImmediateUnsafeHits ~= b.Eval.ImmediateUnsafeHits then
		return a.Eval.ImmediateUnsafeHits
			< b.Eval.ImmediateUnsafeHits
	end

	if a.Eval.UnsafeHits ~= b.Eval.UnsafeHits then
		return a.Eval.UnsafeHits
			< b.Eval.UnsafeHits
	end

	if a.Eval.SpaceFatal ~= b.Eval.SpaceFatal then
		return not a.Eval.SpaceFatal
	end

	if math.abs(
		a.Eval.BarrierReserveDeficit
			- b.Eval.BarrierReserveDeficit
	) > BARRIER_RESERVE_COMPARE_EPSILON
	then
		return a.Eval.BarrierReserveDeficit
			< b.Eval.BarrierReserveDeficit
	end

	if isReverseForwardMode() then
		local aProgress =
			a.Eval.ForwardProgress or 0

		local bProgress =
			b.Eval.ForwardProgress or 0

		if math.abs(aProgress - bProgress) > 0.45 then
			return aProgress > bProgress
		end
	end

	if math.abs(
		a.Eval.MinimumClearance
			- b.Eval.MinimumClearance
	) > 0.12
	then
		return a.Eval.MinimumClearance
			> b.Eval.MinimumClearance
	end

	if math.abs(a.Eval.Score - b.Eval.Score) > 0.10 then
		return a.Eval.Score < b.Eval.Score
	end

	if math.abs(
		a.Eval.RetreatAmount
			- b.Eval.RetreatAmount
	) > 0.05
	then
		return a.Eval.RetreatAmount
			< b.Eval.RetreatAmount
	end

	return a.Eval.MoveMagnitude
		< b.Eval.MoveMagnitude
end

local function makeRoutePlan(
	d1,
	d2,
	d3,
	impactTime
)
	local impact =
		impactTime == math.huge
		and 0.48
		or impactTime

	local switch1 =
		math.clamp(
			impact * 0.42,
			0.10,
			0.20
		)

	local switch2 =
		math.clamp(
			math.max(
				switch1 + 0.16,
				impact * 0.88
			),
			0.28,
			0.46
		)

	local routeMaxHorizon =
		os.clock() - lastReverseEventTime
			< REVERSE_STABILIZE_TIME
		and REVERSE_ROUTE_MAX_HORIZON
		or ROUTE_MAX_HORIZON

	local horizon =
		math.clamp(
			math.max(
				ROUTE_MIN_HORIZON,
				impact + 0.20
			),
			ROUTE_MIN_HORIZON,
			routeMaxHorizon
		)

	return {
		D1 = d1,
		D2 = d2,
		D3 = d3,
		Switch1 = switch1,
		Switch2 = switch2,
		Horizon = horizon
	}
end

local function findMultiStageRoute(
	root,
	humanoid,
	threats,
	referenceDirection,
	impactTime,
	seedCandidates
)
	if not ROUTE_PLANNER_ENABLED
		or #threats == 0
		or #seedCandidates == 0
	then
		return nil
	end

	table.sort(
		seedCandidates,
		function(a, b)
			return betterCandidate(a, b)
		end
	)

	local seeds = {}

	local recentReverse =
		os.clock() - lastReverseEventTime
			< REVERSE_STABILIZE_TIME

	local routeSeedCount =
		recentReverse
		and REVERSE_ROUTE_SEED_COUNT
		or ROUTE_SEED_COUNT

	for i = 1, math.min(
		routeSeedCount,
		#seedCandidates
	) do
		local candidate = seedCandidates[i]

		if candidate.Direction.Magnitude > 0.01
			and not candidate.Eval.SpacePathBlocked
		then
			seeds[#seeds + 1] =
				candidate.Direction
		end
	end

	if #seeds == 0 then
		return nil
	end

	local stage2Beam = {}

	for _, first in ipairs(seeds) do
		local secondDirections = {}

		for _, offset in ipairs(ROUTE_SECOND_OFFSETS) do
			secondDirections[#secondDirections + 1] =
				rotateY(
					first.Unit,
					offset
				)
		end

		if isReverseForwardMode()
			and referenceDirection.Magnitude > 0.01
		then
			secondDirections[#secondDirections + 1] =
				referenceDirection.Unit
			secondDirections[#secondDirections + 1] =
				rotateY(referenceDirection, -25)
			secondDirections[#secondDirections + 1] =
				rotateY(referenceDirection, 25)
		end

		for _, second in ipairs(secondDirections) do

			local plan =
				makeRoutePlan(
					first,
					second,
					second,
					impactTime
				)

			local eval =
				evaluateRoutePlan(
					root,
					humanoid,
					plan,
					threats,
					referenceDirection
				)

			stage2Beam[#stage2Beam + 1] = {
				Direction = first,
				Plan = plan,
				Eval = eval
			}
		end
	end

	table.sort(
		stage2Beam,
		function(a, b)
			return betterRouteCandidate(a, b)
		end
	)

	local finalCandidates = {}
	local routeBeamWidth =
		recentReverse
		and REVERSE_ROUTE_BEAM_WIDTH
		or ROUTE_BEAM_WIDTH

	local beamCount =
		math.min(
			routeBeamWidth,
			#stage2Beam
		)

	for i = 1, beamCount do
		local partial =
			stage2Beam[i]

		local thirdDirections = {}

		for _, offset in ipairs(ROUTE_THIRD_OFFSETS) do
			thirdDirections[#thirdDirections + 1] =
				rotateY(
					partial.Plan.D2.Unit,
					offset
				)
		end

		if isReverseForwardMode()
			and referenceDirection.Magnitude > 0.01
		then
			thirdDirections[#thirdDirections + 1] =
				referenceDirection.Unit
			thirdDirections[#thirdDirections + 1] =
				rotateY(referenceDirection, -18)
			thirdDirections[#thirdDirections + 1] =
				rotateY(referenceDirection, 18)
		end

		for _, third in ipairs(thirdDirections) do
			local sameAsStage2 =
				(third - partial.Plan.D2).Magnitude < 0.0001

			local plan
			local eval

			if sameAsStage2 then
				plan = partial.Plan
				eval = partial.Eval
			else
				plan =
					makeRoutePlan(
						partial.Plan.D1,
						partial.Plan.D2,
						third,
						impactTime
					)

				eval =
					evaluateRoutePlan(
						root,
						humanoid,
						plan,
						threats,
						referenceDirection
					)
			end

			finalCandidates[#finalCandidates + 1] = {
				Direction = plan.D1,
				Plan = plan,
				Eval = eval
			}
		end
	end

	local bestRoute = nil

	for _, candidate in ipairs(finalCandidates) do
		if betterRouteCandidate(
			candidate,
			bestRoute
		) then
			bestRoute = candidate
		end
	end

	return bestRoute
end


local function evaluateEscapeFan(
	root,
	humanoid,
	direction,
	threats
)
	if direction.Magnitude < 0.01 then
		return 0, 0, -math.huge
	end

	local walkSpeed =
		math.max(
			humanoid.WalkSpeed,
			1
		)

	local currentVelocity =
		flatVector(
			root.AssemblyLinearVelocity
		)

	local targetVelocity =
		direction.Unit
			* walkSpeed
			* math.clamp(
				direction.Magnitude,
				0,
				1
			)

	local probeDistance =
		math.clamp(
			walkSpeed
				* ESCAPE_FAN_STEP_TIME,
			ESCAPE_FAN_MIN_DISTANCE,
			ESCAPE_FAN_MAX_DISTANCE
		)

	local persistentHardLanes = 0
	local persistentSafeLanes = 0
	local bestPersistentClearance = -math.huge

	for i = 0, ESCAPE_FAN_ANGLES - 1 do
		local angle =
			i * (360 / ESCAPE_FAN_ANGLES)

		local escapeDirection =
			rotateY(
				direction.Unit,
				angle
			)

		local laneHardOpen = true
		local laneSafeOpen = true
		local laneMinClearance = math.huge

		for _, baseTime in ipairs({
			ESCAPE_FAN_FIRST_TIME,
			ESCAPE_FAN_SECOND_TIME
		}) do
			local center =
				root.Position
				+ predictPlayerOffset(
					currentVelocity,
					targetVelocity,
					baseTime
				)

			local escapePoint =
				center
				+ escapeDirection
					* probeDistance

			if barrierPathBlocked(
				center,
				escapePoint
			) then
				laneHardOpen = false
				laneSafeOpen = false
				laneMinClearance = -math.huge
				break
			end

			local futureTime =
				math.min(
					ROUTE_MAX_HORIZON,
					baseTime
						+ ESCAPE_FAN_STEP_TIME
				)

			for _, threat in ipairs(threats) do
				local projectileStart =
					interpolateThreatPosition(
						threat,
						baseTime
					)

				local projectileEnd =
					interpolateThreatPosition(
						threat,
						futureTime
					)

				local startRelative =
					projectileStart
						- center

				local endRelative =
					projectileEnd
						- escapePoint

				local sweptDistance =
					closestRelativeSegment(
						startRelative,
						endRelative
					)

				local hardClearance =
					sweptDistance
						- threat.DangerRadius

				local safeClearance =
					sweptDistance
						- threat.SafetyRadius

				laneMinClearance =
					math.min(
						laneMinClearance,
						safeClearance
					)

				if hardClearance <= 0 then
					laneHardOpen = false
					laneSafeOpen = false
					break
				elseif safeClearance <= 0 then
					laneSafeOpen = false
				end
			end

			if not laneHardOpen then
				break
			end
		end

		if laneHardOpen then
			persistentHardLanes += 1

			if laneSafeOpen then
				persistentSafeLanes += 1
			end

			bestPersistentClearance =
				math.max(
					bestPersistentClearance,
					laneMinClearance
				)
		end
	end

	return
		persistentHardLanes,
		persistentSafeLanes,
		bestPersistentClearance
end

local function attachEscapeFanData(
	root,
	humanoid,
	threats,
	candidate
)
	if not candidate
		or candidate.Direction.Magnitude < 0.01
	then
		return
	end

	local hardLanes,
		safeLanes,
		bestClearance =
			evaluateEscapeFan(
				root,
				humanoid,
				candidate.Direction,
				threats
			)

	candidate.Eval.EscapeHardLanes =
		hardLanes
	candidate.Eval.EscapeSafeLanes =
		safeLanes
	candidate.Eval.EscapeBestClearance =
		bestClearance
end

local function getUrgentMinimumMagnitude(
	currentEval
)
	if currentEval.HardHits <= 0 then
		return 0
	end

	local impact =
		currentEval.NearestImpact

	if impact <= URGENT_DODGE_TIME then
		return URGENT_DODGE_MAGNITUDE
	end

	if impact <= NEAR_DODGE_TIME then
		return NEAR_DODGE_MAGNITUDE
	end

	if currentEval.NearThreats
		>= CORRIDOR_EARLY_MIN_THREATS
	then
		return DENSE_DODGE_MAGNITUDE
	end

	return 0
end


local function isPhysicallyNoHit(eval)
	return eval
		and not eval.SpacePathBlocked
		and not eval.SpaceFatal
		and eval.LethalImmediateHits == 0
		and eval.ImmediateHits == 0
		and eval.HardHits == 0
end

local function isRobustlySafeCandidate(eval)
	return isPhysicallyNoHit(eval)
		and eval.LethalUnsafeHits == 0
		and eval.ImmediateUnsafeHits == 0
		and eval.UnsafeHits == 0
		and (eval.EnvironmentRisk or 0) == 0
end

local function betterNoHitRescue(a, b)
	if not b then
		return true
	end

	if a.Eval.LethalUnsafeHits ~= b.Eval.LethalUnsafeHits then
		return a.Eval.LethalUnsafeHits < b.Eval.LethalUnsafeHits
	end

	if a.Eval.ImmediateUnsafeHits ~= b.Eval.ImmediateUnsafeHits then
		return a.Eval.ImmediateUnsafeHits < b.Eval.ImmediateUnsafeHits
	end

	if a.Eval.UnsafeHits ~= b.Eval.UnsafeHits then
		return a.Eval.UnsafeHits < b.Eval.UnsafeHits
	end

	local aDeficit = a.Eval.BarrierReserveDeficit or 0
	local bDeficit = b.Eval.BarrierReserveDeficit or 0

	if math.abs(aDeficit - bDeficit)
		> BARRIER_RESERVE_COMPARE_EPSILON
	then
		return aDeficit < bDeficit
	end

	if math.abs(
		a.Eval.MinimumClearance
			- b.Eval.MinimumClearance
	) > 0.10
	then
		return a.Eval.MinimumClearance
			> b.Eval.MinimumClearance
	end

	return (a.Eval.MoveMagnitude or 1)
		< (b.Eval.MoveMagnitude or 1)
end

local function findNoHitRescue(
	character,
	humanoid,
	root,
	threats,
	referenceDirection,
	learningKnownDodge,
	seedDirection
)
	local best = nil

	-- Dense 5-degree fan, only when the normal planner cannot find a no-hit path.
	for i = 0, NO_HIT_RESCUE_ANGLES - 1 do
		local degrees =
			i * (360 / NO_HIT_RESCUE_ANGLES)

		local base =
			rotateY(
				referenceDirection,
				degrees
			)

		for _, magnitude in ipairs(
			NO_HIT_RESCUE_MAGNITUDES
		) do
			local direction =
				base * magnitude

			local eval =
				evaluateCandidate(
					character,
					humanoid,
					root,
					direction,
					referenceDirection,
					threats,
					learningKnownDodge
				)

			if isPhysicallyNoHit(eval) then
				local candidate = {
					Direction = direction,
					Eval = eval
				}

				if betterNoHitRescue(
					candidate,
					best
				) then
					best = candidate
				end
			end
		end
	end

	-- Fine refinement around the first physically clean lane.
	if best
		and best.Direction.Magnitude > 0.01
	then
		local baseDirection =
			best.Direction.Unit
		local baseMagnitude =
			best.Direction.Magnitude

		for _, offset in ipairs(
			NO_HIT_RESCUE_ROUTE_OFFSETS
		) do
			local direction =
				rotateY(
					baseDirection,
					offset
				)
				* baseMagnitude

			local eval =
				evaluateCandidate(
					character,
					humanoid,
					root,
					direction,
					referenceDirection,
					threats,
					learningKnownDodge
				)

			if isPhysicallyNoHit(eval) then
				local candidate = {
					Direction = direction,
					Eval = eval
				}

				if betterNoHitRescue(
					candidate,
					best
				) then
					best = candidate
				end
			end
		end
	end

	return best
end


local function chooseDirection(character, humanoid, root, knownOnly, learningKnownDodge)
	lastNoHitRescueUsed = false
	lastAvoidableHit = false

	DecisionCandidateEvalCache = {}
	DecisionGeometryCacheActive = true
	DecisionRootPosition = root.Position
	DecisionRootBarrierInfo = nil
	DecisionRootBarrierInfoCached = false
	DecisionRootBarrierDistance = math.huge
	DecisionRootBarrierDistanceCached = false

	local liveUserDirection =
		flatVector(humanoid.MoveDirection)

	if liveUserDirection.Magnitude > 1 then
		liveUserDirection = liveUserDirection.Unit
	end

	local liveBaseDirection =
		getBaseDirection(
			humanoid,
			root
		)

	if not DODGING then
		if liveUserDirection.Magnitude > 0.01 then
			StableReferenceDirection =
				liveUserDirection.Unit
		elseif liveBaseDirection.Magnitude > 0.01 then
			StableReferenceDirection =
				liveBaseDirection.Unit
		end
	end

	local referenceDirection =
		StableReferenceDirection.Magnitude > 0.01
		and StableReferenceDirection
		or liveBaseDirection

	if referenceDirection.Magnitude < 0.01 then
		referenceDirection =
			Vector3.new(0, 0, -1)
	end

	-- While already dodging, evaluate the movement actually being executed.
	-- Older versions evaluated referenceDirection here, so they could think
	-- the current path was safe even while dodgeDirection was heading into a hit.
	local userDirection =
		DODGING
		and dodgeDirection
		or liveUserDirection

	local threats =
		buildThreatSnapshot(
			root,
			humanoid,
			knownOnly
		)

	if #threats == 0 then
		lastRouteStages = 1
		lastEscapeHardLanes = 0
		lastEscapeSafeLanes = 0
		lastEscapeClearance = -math.huge
		lastPlanClearance =
			getNearestBarrierDistance(root.Position)

		local reserveMove =
			getBarrierReserveMove(root)

		if reserveMove then
			return reserveMove, 0, math.huge
		end

		if isReverseForwardMode()
			and referenceDirection.Magnitude > 0.01
		then
			return referenceDirection.Unit
				* REVERSE_FORWARD_IDLE_MAGNITUDE,
				0,
				math.huge
		end

		return nil, 0, math.huge
	end

	local currentEval =
		evaluateCandidate(
			character,
			humanoid,
			root,
			userDirection,
			referenceDirection,
			threats,
			learningKnownDodge
		)

	local triggerTime =
		currentEval.RequiredTriggerTime
		or TRIGGER_TIME

	local actualCollisionSoon =
		currentEval.HardHits > 0
		and currentEval.NearestImpact
			<= PROACTIVE_ROUTE_TIME

	local robustCollisionImmediate =
		currentEval.ImmediateUnsafeHits > 0
		and currentEval.NearestUnsafeImpact
			<= triggerTime

	local denseCorridorClosing =
		currentEval.NearThreats
			>= CORRIDOR_EARLY_MIN_THREATS
		and currentEval.UnsafeHits
			>= CORRIDOR_EARLY_MIN_UNSAFE
		and currentEval.NearestUnsafeImpact
			<= CORRIDOR_EARLY_TIME
		and currentEval.MinimumClearance
			<= CORRIDOR_EARLY_CLEARANCE

	local predictedPhysicalHit =
		currentEval.HardHits > 0

	local shouldIntervene =
		(NO_HIT_FORCE_REPLAN and predictedPhysicalHit)
		or actualCollisionSoon
		or robustCollisionImmediate
		or denseCorridorClosing

	if not shouldIntervene then
		lastRouteStages = 1
		lastEscapeHardLanes = 0
		lastEscapeSafeLanes = 0
		lastEscapeClearance = -math.huge
		lastPlanClearance =
			currentEval.MinimumClearance

		local reserveMove =
			getBarrierReserveMove(root)

		if reserveMove then
			return reserveMove,
				currentEval.Risk,
				math.min(
					currentEval.NearestImpact,
					currentEval.NearestUnsafeImpact
				)
		end

		if isReverseForwardMode()
			and referenceDirection.Magnitude > 0.01
		then
			local forwardPush =
				referenceDirection.Unit
				* REVERSE_FORWARD_IDLE_MAGNITUDE

			local forwardEval =
				evaluateCandidate(
					character,
					humanoid,
					root,
					forwardPush,
					referenceDirection,
					threats,
					learningKnownDodge
				)

			local forwardSafe =
				not forwardEval.SpacePathBlocked
				and not forwardEval.SpaceFatal
				and forwardEval.HardHits == 0
				and forwardEval.ImmediateUnsafeHits == 0
				and forwardEval.MinimumClearance
					>= REVERSE_FORWARD_SAFE_CLEARANCE

			if forwardSafe then
				return forwardPush,
					currentEval.Risk,
					math.min(
						currentEval.NearestImpact,
						currentEval.NearestUnsafeImpact
					)
			end
		end

		return nil,
			currentEval.Risk,
			math.min(
				currentEval.NearestImpact,
				currentEval.NearestUnsafeImpact
			)
	end

	local directions = {}

	local reserveMove =
		getBarrierReserveMove(root)

	if reserveMove
		and reserveMove.Magnitude > 0.01
	then
		addUniqueDirection(
			directions,
			reserveMove
		)
	end

	for i = 0, CANDIDATE_COUNT - 1 do
		local degrees =
			i * (360 / CANDIDATE_COUNT)

		addUniqueDirection(
			directions,
			rotateY(
				referenceDirection,
				degrees
			)
		)
	end

	if isReverseForwardMode() then
		for _, degrees in ipairs(REVERSE_FORWARD_ANGLES) do
			addUniqueDirection(
				directions,
				rotateY(
					referenceDirection,
					degrees
				)
				* REVERSE_FORWARD_DODGE_MAGNITUDE
			)
		end
	end

	-- Add exact lateral directions for the dominant incoming projectile.
	local dominant =
		currentEval.DominantThreat

	if dominant
		and dominant.Velocity
	then
		local incoming =
			flatUnit(
				dominant.Velocity
			)

		if incoming.Magnitude > 0.01 then
			local lateral =
				Vector3.new(
					-incoming.Z,
					0,
					incoming.X
				)

			addUniqueDirection(
				directions,
				lateral
			)

			addUniqueDirection(
				directions,
				-lateral
			)
		end
	end

	local best = nil
	local directionCandidates = {}

	-- Stopping is considered only when it actually improves the physical
	-- collision forecast. It must not win merely because movement is cheaper.
	local stopEval =
		evaluateCandidate(
			character,
			humanoid,
			root,
			Vector3.zero,
			referenceDirection,
			threats,
			learningKnownDodge
		)

	local stopActuallyHelps =
		stopEval.HardHits
			< currentEval.HardHits
		or stopEval.ImmediateHits
			< currentEval.ImmediateHits
		or (
			currentEval.HardHits > 0
			and stopEval.NearestImpact
				> currentEval.NearestImpact + 0.08
		)

	if stopActuallyHelps then
		best = {
			Direction = Vector3.zero,
			Eval = stopEval
		}
	end

	for _, direction in ipairs(directions) do
		local eval =
			evaluateCandidate(
				character,
				humanoid,
				root,
				direction,
				referenceDirection,
				threats,
				learningKnownDodge
			)

		local candidate = {
			Direction = direction,
			Eval = eval
		}

		directionCandidates[#directionCandidates + 1] =
			candidate

		if betterCandidate(candidate, best) then
			best = candidate
		end
	end

	-- The old planner paid for 48-angle × radius × time gap scans on every
	-- intervention. If the coarse fan already found a fully robust no-hit lane,
	-- that work cannot improve physical safety, so skip it.
	local needGapSearch =
		not DEEP_PLANNER_ONLY_WHEN_NEEDED
		or not best
		or not isRobustlySafeCandidate(best.Eval)
		or denseCorridorClosing

	if needGapSearch then
		local oldDirectionCount = #directions

		addGapRouteDirections(
			directions,
			root,
			humanoid,
			threats,
			currentEval.NearestImpact ~= math.huge
				and currentEval.NearestImpact
				or currentEval.NearestUnsafeImpact,
			referenceDirection
		)

		for i = oldDirectionCount + 1, #directions do
			local direction = directions[i]
			local eval =
				evaluateCandidate(
					character,
					humanoid,
					root,
					direction,
					referenceDirection,
					threats,
					learningKnownDodge
				)

			local candidate = {
				Direction = direction,
				Eval = eval
			}

			directionCandidates[#directionCandidates + 1] =
				candidate

			if betterCandidate(candidate, best) then
				best = candidate
			end
		end
	end

	if not best then
		return nil,
			currentEval.Risk,
			currentEval.NearestImpact
	end

	-- Search how little movement is actually enough in the winning direction.
	if best.Direction.Magnitude > 0.01 then
		local refinedBest = best
		local urgentMinimumMagnitude =
			getUrgentMinimumMagnitude(
				currentEval
			)

		for _, magnitude in ipairs(MINIMAL_DODGE_MAGNITUDES) do
			if magnitude < urgentMinimumMagnitude then
				continue
			end
			local direction =
				best.Direction.Unit
				* magnitude

			local eval =
				evaluateCandidate(
					character,
					humanoid,
					root,
					direction,
					referenceDirection,
					threats,
					learningKnownDodge
				)

			local candidate = {
				Direction = direction,
				Eval = eval
			}

			if betterCandidate(
				candidate,
				refinedBest
			) then
				refinedBest = candidate
			end
		end

		for _, offset in ipairs({
			-REFINE_ANGLE,
			REFINE_ANGLE
		}) do
			local direction =
				rotateY(
					refinedBest.Direction.Unit,
					offset
				)
				* refinedBest.Direction.Magnitude

			local eval =
				evaluateCandidate(
					character,
					humanoid,
					root,
					direction,
					referenceDirection,
					threats,
					learningKnownDodge
				)

			local candidate = {
				Direction = direction,
				Eval = eval
			}

			if betterCandidate(
				candidate,
				refinedBest
			) then
				refinedBest = candidate
			end
		end

		-- Cheap sub-bin refinement around the coarse winner.
		if refinedBest.Direction.Magnitude > 0.01 then
			local microBase =
				refinedBest.Direction

			for _, offset in ipairs(MICRO_REFINE_ANGLES) do
				local direction =
					rotateY(
						microBase.Unit,
						offset
					)
					* math.max(
						microBase.Magnitude,
						urgentMinimumMagnitude
					)

				local eval =
					evaluateCandidate(
						character,
						humanoid,
						root,
						direction,
						referenceDirection,
						threats,
						learningKnownDodge
					)

				local candidate = {
					Direction = direction,
					Eval = eval
				}

				directionCandidates[#directionCandidates + 1] =
					candidate

				if betterCandidate(
					candidate,
					refinedBest
				) then
					refinedBest = candidate
				end
			end
		end

		best = refinedBest

		directionCandidates[#directionCandidates + 1] =
			refinedBest
	end

	-- Future-exit analysis is useful only when the current winner still
	-- overlaps a safety envelope / dense corridor. A robustly clean 1.05s path
	-- does not need another 5 × 12-lane scan.
	local needDeepPlanner =
		not DEEP_PLANNER_ONLY_WHEN_NEEDED
		or not isRobustlySafeCandidate(best.Eval)
		or denseCorridorClosing

	if needDeepPlanner then
		local rankedForEscape = {}

		for _, candidate in ipairs(directionCandidates) do
			rankedForEscape[#rankedForEscape + 1] =
				candidate
		end

		table.sort(
			rankedForEscape,
			function(a, b)
				return betterCandidate(a, b)
			end
		)

		local escapeBest = nil

		for i = 1, math.min(
			ESCAPE_FAN_TOP_CANDIDATES,
			#rankedForEscape
		) do
			local candidate =
				rankedForEscape[i]

			if not candidate.Eval.SpacePathBlocked
				and candidate.Eval.HardHits
					<= best.Eval.HardHits
			then
				attachEscapeFanData(
					root,
					humanoid,
					threats,
					candidate
				)

				if betterCandidate(
					candidate,
					escapeBest
				) then
					escapeBest = candidate
				end
			end
		end

		if escapeBest
			and betterCandidate(
				escapeBest,
				best
			)
		then
			best = escapeBest
		end
	end

	-- Evaluate curved 3-stage routes. The route planner may deliberately
	-- take a small first step toward a gap, turn through it, then exit.
	local routeImpactTime =
		math.min(
			currentEval.NearestImpact,
			currentEval.NearestUnsafeImpact
		)

	local routeBest = nil

	if needDeepPlanner then
		routeBest =
			findMultiStageRoute(
				root,
				humanoid,
				threats,
				referenceDirection,
				routeImpactTime,
				directionCandidates
			)
	end

	if routeBest
		and not routeBest.Eval.SpacePathBlocked
	then
		attachEscapeFanData(
			root,
			humanoid,
			threats,
			routeBest
		)
	end

	if needDeepPlanner
		and best
		and best.Direction.Magnitude > 0.01
		and best.Eval.EscapeHardLanes == nil
	then
		attachEscapeFanData(
			root,
			humanoid,
			threats,
			best
		)
	end

	if routeBest
		and betterCandidate(
			routeBest,
			best
		)
	then
		best = routeBest
		lastRouteStages = 3
		lastRouteScore =
			routeBest.Eval.Score or 0
	else
		lastRouteStages = 1
		lastRouteScore =
			best
			and best.Eval.Score
			or 0
	end

	-- No-Free-Hit invariant:
	-- If the actually executed path will collide and the normal planner still
	-- contains a physical hit, do an emergency dense search. Any clean path
	-- beats style weights, forward preference, reserve preference and cost.
	if currentEval.HardHits > 0
		and (
			not best
			or best.Eval.HardHits > 0
			or best.Eval.ImmediateHits > 0
		)
	then
		local rescue =
			findNoHitRescue(
				character,
				humanoid,
				root,
				threats,
				referenceDirection,
				learningKnownDodge,
				best and best.Direction or nil
			)

		if rescue then
			best = rescue
			lastNoHitRescueUsed = true
			lastAvoidableHit = true
			lastRouteStages = 1
			lastRouteScore =
				rescue.Eval.Score or 0
		end
	end

	-- Hysteresis: if the current dodge direction is already essentially as
	-- safe, keep it instead of jittering left/right every decision.
	if DODGING
		and dodgeDirection.Magnitude > 0.01
	then
		local currentDodgeEval =
			evaluateCandidate(
				character,
				humanoid,
				root,
				dodgeDirection,
				referenceDirection,
				threats,
				learningKnownDodge
			)

		local currentDodge = {
			Direction = dodgeDirection,
			Eval = currentDodgeEval
		}

		local sameHardSafety =
			currentDodgeEval.SpacePathBlocked
				== best.Eval.SpacePathBlocked
			and currentDodgeEval.LethalUnsafeHits
				== best.Eval.LethalUnsafeHits
			and currentDodgeEval.ImmediateUnsafeHits
				== best.Eval.ImmediateUnsafeHits
			and currentDodgeEval.UnsafeHits
				== best.Eval.UnsafeHits
			and currentDodgeEval.LethalImmediateHits
				== best.Eval.LethalImmediateHits
			and currentDodgeEval.ImmediateHits
				== best.Eval.ImmediateHits
			and currentDodgeEval.HardHits
				== best.Eval.HardHits

		local routeHasPhysicalAdvantage =
			best.Eval.HardHits
				< currentDodgeEval.HardHits
			or best.Eval.ImmediateHits
				< currentDodgeEval.ImmediateHits
			or best.Eval.UnsafeHits
				< currentDodgeEval.UnsafeHits
			or best.Eval.MinimumClearance
				> currentDodgeEval.MinimumClearance + 0.18

		local switchMargin =
			os.clock() - lastReverseEventTime
				< REVERSE_STABILIZE_TIME
			and (
				SWITCH_SCORE_MARGIN
				* REVERSE_SWITCH_MARGIN_MULTIPLIER
			)
			or SWITCH_SCORE_MARGIN

		local noHitWinner =
			isPhysicallyNoHit(best.Eval)
			and currentDodgeEval.HardHits > 0

		if sameHardSafety
			and not noHitWinner
			and not routeHasPhysicalAdvantage
			and currentDodgeEval.Score
				<= best.Eval.Score
					+ switchMargin
		then
			best = currentDodge
			lastRouteStages = 1
		end
	end

	local forcedNoHit =
		currentEval.HardHits > 0
		and isPhysicallyNoHit(best.Eval)

	local safer =
		forcedNoHit
		or (
			not best.Eval.SpacePathBlocked
			and (
				best.Eval.LethalImmediateHits
					< currentEval.LethalImmediateHits
				or best.Eval.ImmediateHits
					< currentEval.ImmediateHits
				or best.Eval.HardHits
					< currentEval.HardHits
				or (
					currentEval.HardHits > 0
					and best.Eval.NearestImpact
						> currentEval.NearestImpact + 0.015
				)
				or (
					best.Eval.HardHits
						== currentEval.HardHits
					and best.Eval.LethalUnsafeHits
						< currentEval.LethalUnsafeHits
				)
				or (
					best.Eval.HardHits
						== currentEval.HardHits
					and best.Eval.ImmediateUnsafeHits
						< currentEval.ImmediateUnsafeHits
				)
				or (
					best.Eval.HardHits
						== currentEval.HardHits
					and best.Eval.UnsafeHits
						< currentEval.UnsafeHits
				)
				or (
					best.Eval.HardHits
						== currentEval.HardHits
					and best.Eval.MinimumClearance
						> currentEval.MinimumClearance + 0.10
				)
			)
		)

	if not safer then
		local emergencyTry =
			currentEval.HardHits > 0
			and best.Direction.Magnitude > 0.01
			and not best.Eval.SpacePathBlocked
			and best.Eval.LethalImmediateHits
				<= currentEval.LethalImmediateHits
			and best.Eval.ImmediateHits
				<= currentEval.ImmediateHits
			and best.Eval.HardHits
				<= currentEval.HardHits
			and (
				best.Eval.NearestImpact
					>= currentEval.NearestImpact
				or best.Eval.MinimumClearance
					> currentEval.MinimumClearance
			)

		if not emergencyTry then
			if currentEval.HardHits > 0
				and best.Direction.Magnitude > 0.01
				and not best.Eval.SpacePathBlocked
			then
				lastNoHitRescueUsed = true
			else
				return nil,
					currentEval.Risk,
					math.min(
						currentEval.NearestImpact,
						currentEval.NearestUnsafeImpact
					)
			end
		end
	end

	lastPlanClearance =
		best.Eval.MinimumClearance

	lastEscapeHardLanes =
		best.Eval.EscapeHardLanes or 0
	lastEscapeSafeLanes =
		best.Eval.EscapeSafeLanes or 0
	lastEscapeClearance =
		best.Eval.EscapeBestClearance
			or -math.huge

	lastBarrierReserveDistance =
		getNearestBarrierDistance(root.Position)

	return best.Direction,
		currentEval.Risk,
		math.min(
			currentEval.NearestImpact,
			currentEval.NearestUnsafeImpact
		)
end

local function safeChooseDirection(...)
	local ok, direction, risk, impactTime =
		pcall(
			chooseDirection,
			...
		)

	DecisionCandidateEvalCache = nil
	DecisionGeometryCacheActive = false
	DecisionRootPosition = nil

	if not ok then
		lastDecisionError = tostring(direction)
		return nil, 0, math.huge
	end

	lastDecisionError = ""
	return direction, risk, impactTime
end


local function calculateHoldTime(impactTime)
	if impactTime == math.huge then
		return MIN_DODGE_HOLD
	end

	local urgency =
		1 - math.clamp(
			impactTime
				/ MAX_DYNAMIC_TRIGGER_TIME,
			0,
			1
		)

	return math.clamp(
		MIN_DODGE_HOLD
			+ urgency * 0.11,
		MIN_DODGE_HOLD,
		MAX_DODGE_HOLD
	)
end

local function getDecisionInterval()
	if lastImpactTime ~= math.huge
		and lastImpactTime <= URGENT_IMPACT_TIME
	then
		return DECISION_INTERVAL_URGENT
	end

	if lastRelevantThreats > 0
		and (
			lastImpactTime == math.huge
			or lastImpactTime <= ACTIVE_IMPACT_TIME
		)
	then
		return DECISION_INTERVAL
	end

	return DECISION_INTERVAL_IDLE
end

RunService:BindToRenderStep(
	"AutoDodgePriority",
	Enum.RenderPriority.Last.Value,
	function()
		if not ENABLED then
			lastRelevantThreats = 0

			if DODGING then
				DODGING = false
				dodgeUntil = 0
				enableControls()
			end
			return
		end

		local character, humanoid, root =
			getCharacter()

		if not character then
			DODGING = false
			StableReferenceDirection =
				Vector3.zero
			enableControls()
			return
		end

		local now = os.clock()
		refreshModeKey()

		if LEARNING_MODE then
			local healthRatio =
				humanoid.MaxHealth > 0
				and (
					humanoid.Health
					/ humanoid.MaxHealth
				)
				or 0

			if healthRatio < LEARNING_MIN_HEALTH_RATIO then
				local emergencyDirection, risk, impactTime =
					safeChooseDirection(
						character,
						humanoid,
						root,
						false,
						false
					)

				lastRisk = risk or 0
				lastImpactTime =
					impactTime or math.huge

				if emergencyDirection then
					DODGING = true
					dodgeDirection =
						emergencyDirection
					disableControls()
					humanoid:Move(
						dodgeDirection,
						false
					)
				else
					DODGING = false
					enableControls()
				end

				return
			end

			local knownDirection, knownRisk, knownImpact =
				safeChooseDirection(
					character,
					humanoid,
					root,
					true,
					true
				)

			lastRisk = knownRisk or 0
			lastImpactTime =
				knownImpact or math.huge

			if knownDirection then
				DODGING = true
				dodgeDirection =
					knownDirection
				disableControls()
				humanoid:Move(
					dodgeDirection,
					false
				)
				return
			end

			DODGING = false

			local learningMove =
				getLearningMoveDirection(
					character,
					humanoid,
					root
				)

			if learningMove ~= nil then
				disableControls()
				humanoid:Move(
					learningMove,
					false
				)
			else
				enableControls()
			end

			return
		end

		local decisionInterval =
			getDecisionInterval()

		if now - lastDecision >= decisionInterval then
			lastDecision = now

			local direction, risk, impactTime =
				safeChooseDirection(
					character,
					humanoid,
					root,
					false,
					false
				)

			lastRisk = risk or 0
			lastImpactTime =
				impactTime or math.huge

			if direction then
				if not DODGING then
					dodgeStarted = now
					lastDodgeDirectionChange = now
				else
					local oldDir = dodgeDirection
					local newDir = direction

					if oldDir.Magnitude > 0.01
						and newDir.Magnitude > 0.01
					then
						local dot =
							math.clamp(
								oldDir.Unit:Dot(
									newDir.Unit
								),
								-1,
								1
							)

						if dot < 0.70 then
							lastDodgeDirectionChange = now
						end
					end
				end

				DODGING = true
				dodgeDirection = direction

				local hold =
					calculateHoldTime(
						lastImpactTime
					)

				if now - lastReverseEventTime
					< REVERSE_STABILIZE_TIME
				then
					hold =
						math.max(
							hold,
							REVERSE_DIRECTION_HOLD
						)
				end

				dodgeUntil =
					math.max(
						dodgeUntil,
						now + hold
					)

			elseif DODGING then
				local reverseGrace =
					now - lastReverseEventTime
						< REVERSE_STABILIZE_TIME

				local holdActive =
					now < dodgeUntil
					or (
						reverseGrace
						and now - lastDodgeDirectionChange
							< REVERSE_DIRECTION_HOLD
					)

				if not holdActive
					and (
						now - dodgeStarted
							>= MIN_DODGE_COMMIT
					)
				then
					DODGING = false
					dodgeDirection =
						Vector3.zero
					enableControls()
				end
			end
		end

		if DODGING then
			disableControls()
			humanoid:Move(
				dodgeDirection,
				false
			)
		else
			enableControls()
		end
	end
)


WallVizToggle.Activated:Connect(function()
	SHOW_WALL_RANGES = not SHOW_WALL_RANGES

	if SHOW_WALL_RANGES then
		WallVizToggle.Text = "Barrier 범위 표시 ON"
		WallVizToggle.BackgroundColor3 = Color3.fromRGB(112, 96, 48)
		updateWallVisualization(true)
	else
		WallVizToggle.Text = "Barrier 범위 표시 OFF"
		WallVizToggle.BackgroundColor3 = Color3.fromRGB(58, 58, 66)
		hideWallVisualization()
	end
end)

LearningToggle.Activated:Connect(function()
	LEARNING_MODE = not LEARNING_MODE
	LearningTarget = nil
	LearningTargetStarted = 0

	if LEARNING_MODE then
		LearningToggle.Text = "학습모드 ON"
		LearningToggle.BackgroundColor3 = Color3.fromRGB(155, 105, 45)
	else
		LearningToggle.Text = "학습모드 OFF"
		LearningToggle.BackgroundColor3 = Color3.fromRGB(58, 58, 66)
	end
end)

Toggle.Activated:Connect(function()
	ENABLED = not ENABLED

	if ENABLED then
		Toggle.Text = "ON"
		Toggle.BackgroundColor3 = Color3.fromRGB(50, 145, 80)
	else
		Toggle.Text = "OFF"
		Toggle.BackgroundColor3 = Color3.fromRGB(58, 58, 66)

		DODGING = false
		dodgeDirection = Vector3.zero
		enableControls()
	end
end)

RunService.Heartbeat:Connect(function()
	updateWallVisualization(false)
end)

local lastUiUpdate = 0

RunService.RenderStepped:Connect(function()
	local uiFrameNow = os.clock()

	if uiFrameNow - lastUiUpdate < UI_UPDATE_INTERVAL then
		return
	end

	lastUiUpdate = uiFrameNow
	refreshModeKey()
	ModeLabel.Text =
	"Difficulty : "
	.. string.format("%.2f", getDifficulty())

	local count = 0
	for _ in pairs(ProjectileData) do
		count += 1
	end

	local impactText = "-"
	if lastImpactTime ~= math.huge then
		impactText = string.format("%.2fs", lastImpactTime)
	end

	local storageText =
		canUseFileSystem()
		and "LocalSave"
		or "SessionOnly"

	local clearanceText = "-"
	if lastPlanClearance ~= math.huge then
		clearanceText =
			string.format(
				"%.1f",
				lastPlanClearance
			)
	end

	local reverseActive = 0
	local uiNow = uiFrameNow

	for _, data in pairs(ProjectileData) do
		if uiNow < (data.ReverseUntil or 0) then
			reverseActive += 1
		end
	end

	Info.Text =
		"Projectile : "
		.. tostring(count)
		.. " / Active : "
		.. tostring(lastRelevantThreats)
		.. " / Rev:"
		.. tostring(reverseActive)
		.. (
			isReverseForwardMode()
			and " FWD"
			or ""
		)
		.. "\nBarrier : "
		.. tostring(#BarrierParts)
		.. " / Reserve:"
		.. (
			lastBarrierReserveDistance < math.huge
			and string.format(
				"%.1f/%.1f",
				lastBarrierReserveDistance,
				BARRIER_RESERVE_TARGET
			)
			or "-/12.0"
		)
		.. (
			BarrierReserveActive
			and " ACTIVE"
			or ""
		)
		.. " / Clear:"
		.. clearanceText
		.. " / Route:"
		.. tostring(lastRouteStages)
		.. " / Exit:"
		.. tostring(lastEscapeHardLanes)
		.. "/"
		.. tostring(lastEscapeSafeLanes)
		.. " / OPT"
		.. (
			lastNoHitRescueUsed
			and " / RESCUE"
			or ""
		)

	if not EnemyProj then
		Status.Text = "EnemyProj 대기 중..."
		Status.TextColor3 = Color3.fromRGB(230, 190, 80)
	elseif lastDecisionError ~= "" then
		Status.Text =
			"오류 : "
			.. string.sub(lastDecisionError, 1, 70)

		Status.TextColor3 = Color3.fromRGB(255, 85, 85)
	elseif not ENABLED then
		Status.Text = "준비됨"
		Status.TextColor3 = Color3.fromRGB(165, 165, 175)
	elseif LEARNING_MODE and DODGING then
		Status.Text = "학습모드 - 학습된 탄 회피"
		Status.TextColor3 = Color3.fromRGB(255, 120, 90)
	elseif LEARNING_MODE and LearningTarget and isLearningTargetValid(LearningTarget) then
		local data = ProjectileData[LearningTarget]
		local profile = data and getDamageProfile(data.Signature)
		local sampleCount = profile and #profile.Samples or 0
		Status.Text = "미학습 탄 경로 진입 (" .. tostring(sampleCount) .. "/" .. tostring(DAMAGE_MIN_SAMPLES) .. ")"
		Status.TextColor3 = Color3.fromRGB(235, 165, 70)
	elseif DODGING then
		Status.Text = "예측 경로 회피 중"
		Status.TextColor3 = Color3.fromRGB(255, 120, 90)
	elseif lastRisk > 0 then
		Status.Text = "궤적 최적화 중"
		Status.TextColor3 = Color3.fromRGB(240, 190, 80)
	else
		Status.Text = "안전 - 조작 유지"
		Status.TextColor3 = Color3.fromRGB(100, 220, 140)
	end
end)


Gui.AncestryChanged:Connect(function(_, parent)
	if parent == nil then
		pcall(saveProfilesNow)
	end
end)
