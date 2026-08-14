local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ENABLED = false
local DODGING = false

local EnemyProj = nil
local ProjectileData = {}

local PREDICT_TIME = 0.58
local SAMPLE_STEP = 0.04
local DECISION_INTERVAL = 0.025

local TRIGGER_TIME = 0.32
local HARD_TRIGGER_TIME = 0.14

local PLAYER_RADIUS = 2.30
local EXTRA_MARGIN = 0.45
local SAFE_EXTRA = 0.45

local MIN_PROJECTILE_SPEED = 3
local MAX_TRACK_DISTANCE = 85

local VELOCITY_SMOOTH = 0.52
local ACCELERATION_SMOOTH = 0.08
local MAX_ACCELERATION = 3500

local WALL_CHECK_DISTANCE = 9
local FLOOR_CHECK_DISTANCE = 7

local WALL_HARD_DISTANCE = 2.8
local WALL_COMFORT_DISTANCE = 5.5
local WALL_FUTURE_DISTANCE = 4.5

local WALL_RADIAL_RAYS = 12
local WALL_PROXIMITY_WEIGHT = 18
local WALL_CORNER_WEIGHT = 24
local WALL_APPROACH_WEIGHT = 28

local MIN_DODGE_HOLD = 0.035
local MAX_DODGE_HOLD = 0.11
local DODGE_COOLDOWN = 0.018
local MIN_DODGE_COMMIT = 0.035

local INTERVENE_RISK = 18
local COLLISION_PENALTY = 600
local NEAR_MISS_WEIGHT = 34
local MULTI_THREAT_WEIGHT = 10

local MOVE_PENALTY = 2.1
local TURN_PENALTY = 1.1
local REVERSE_PENALTY = 2.2
local DODGE_CONTINUITY_PENALTY = 0.8

local CANDIDATE_COUNT = 32
local REFINE_ANGLE = 5.625
local REFINE_MAGNITUDES = {0.35, 0.50, 0.65, 0.80, 1.00}

local lastDecision = 0
local dodgeUntil = 0
local dodgeStarted = 0
local nextDodgeAllowed = 0
local dodgeDirection = Vector3.zero
local lastRisk = 0
local lastImpactTime = math.huge

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
Main.Size = UDim2.fromOffset(235, 145)
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
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end

	return character, humanoid, root
end

task.spawn(function()
	pcall(function()
		local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts", 10)
		if not PlayerScripts then
			return
		end

		local module = PlayerScripts:WaitForChild("PlayerModule", 10)
		if not module then
			return
		end

		Controls = require(module):GetControls()
	end)
end)

local function disableControls()
	if Controls and not ControlsDisabled then
		pcall(function()
			Controls:Disable()
		end)
		ControlsDisabled = true
	end
end

local function enableControls()
	if Controls and ControlsDisabled then
		pcall(function()
			Controls:Enable()
		end)
		ControlsDisabled = false
	end
end

local function getProjectilePart(obj)
	if obj:IsA("BasePart") then
		return obj
	end

	if obj:IsA("Model") and obj.PrimaryPart then
		return obj.PrimaryPart
	end

	return obj:FindFirstChildWhichIsA("BasePart", true)
end

local function addProjectile(obj)
	task.defer(function()
		local part = getProjectilePart(obj)

		if not part then
			task.wait(0.05)
			part = getProjectilePart(obj)
		end

		if not part then
			return
		end

		ProjectileData[obj] = {
			Part = part,
			LastPosition = part.Position,
			Velocity = Vector3.zero,
			LastVelocity = Vector3.zero,
			Acceleration = Vector3.zero,
			Samples = 0,
			Ready = false
		}
	end)
end

local function removeProjectile(obj)
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
	if not EnemyProj or dt <= 0 or dt > 0.25 then
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
			data.LastPosition = part.Position
			data.Samples = 0
			data.Ready = false
			continue
		end

		local position = part.Position
		local rawVelocity = (position - data.LastPosition) / dt

		if data.Samples == 0 then
			data.Velocity = rawVelocity
			data.LastVelocity = rawVelocity
		else
			data.Velocity = data.Velocity:Lerp(rawVelocity, VELOCITY_SMOOTH)

			local rawAcceleration = (rawVelocity - data.LastVelocity) / dt

			if rawAcceleration.Magnitude <= MAX_ACCELERATION then
				data.Acceleration = data.Acceleration:Lerp(rawAcceleration, ACCELERATION_SMOOTH)
			end

			data.LastVelocity = rawVelocity
		end

		data.LastPosition = position
		data.Samples += 1

		if data.Samples >= 3 then
			data.Ready = true
		end
	end
end)

local function projectileRadius(part)
	local s = part.Size
	return math.max(s.X, s.Y, s.Z) * 0.5
end

local function predictProjectile(data, t)
	return data.Part.Position
		+ data.Velocity * t
		+ data.Acceleration * (0.5 * t * t)
end

local function getRayParams(character)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local exclude = {character}

	if EnemyProj then
		table.insert(exclude, EnemyProj)
	end

	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	return params
end

local function wallProximityAt(position, params)
	local nearest = math.huge
	local closeCount = 0
	local totalPenalty = 0

	for i = 0, WALL_RADIAL_RAYS - 1 do
		local angle =
			(i / WALL_RADIAL_RAYS)
			* math.pi
			* 2

		local direction =
			Vector3.new(
				math.cos(angle),
				0,
				math.sin(angle)
			)

		local result =
			workspace:Raycast(
				position,
				direction * WALL_CHECK_DISTANCE,
				params
			)

		if result then
			local distance =
				(result.Position - position).Magnitude

			if distance < nearest then
				nearest = distance
			end

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

local function environmentRisk(character, root, direction)
	local params = getRayParams(character)

	local currentPosition =
		root.Position
		+ Vector3.new(0, 1, 0)

	local risk = 0

	local currentWallRisk =
		wallProximityAt(
			currentPosition,
			params
		)

	risk += currentWallRisk * 0.35

	if direction.Magnitude > 0.01 then
		local dir = direction.Unit

		local forwardWall =
			workspace:Raycast(
				currentPosition,
				dir * WALL_CHECK_DISTANCE,
				params
			)

		if forwardWall then
			local distance =
				(forwardWall.Position - currentPosition).Magnitude

			if distance < WALL_COMFORT_DISTANCE then
				local approach =
					1 - math.clamp(
						distance / WALL_COMFORT_DISTANCE,
						0,
						1
					)

				risk +=
					approach
					* approach
					* WALL_APPROACH_WEIGHT
			end

			if distance < WALL_HARD_DISTANCE then
				risk += 90
			end
		end

		local futurePosition =
			currentPosition
			+ dir * WALL_FUTURE_DISTANCE

		local futureWallRisk =
			wallProximityAt(
				futurePosition,
				params
			)

		risk += futureWallRisk

		local floor =
			workspace:Raycast(
				futurePosition
				+ Vector3.new(0, 1, 0),

				Vector3.new(
					0,
					-FLOOR_CHECK_DISTANCE,
					0
				),

				params
			)

		if not floor then
			risk += 140
		end
	else
		local floor =
			workspace:Raycast(
				currentPosition
				+ Vector3.new(0, 1, 0),

				Vector3.new(
					0,
					-FLOOR_CHECK_DISTANCE,
					0
				),

				params
			)

		if not floor then
			risk += 140
		end
	end

	return risk
end

local function flatVector(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function flatUnit(v)
	local flat = flatVector(v)

	if flat.Magnitude < 0.001 then
		return Vector3.zero
	end

	return flat.Unit
end

local function rotateY(v, degrees)
	local r = math.rad(degrees)
	local c = math.cos(r)
	local s = math.sin(r)

	return Vector3.new(
		v.X * c - v.Z * s,
		0,
		v.X * s + v.Z * c
	)
end

local function getBaseDirection(humanoid, root)
	local move = flatUnit(humanoid.MoveDirection)

	if move.Magnitude > 0 then
		return move
	end

	local look = flatUnit(root.CFrame.LookVector)

	if look.Magnitude > 0 then
		return look
	end

	return Vector3.new(0, 0, -1)
end

local function buildThreatSnapshot(root)
	local threats = {}
	local steps = math.floor(PREDICT_TIME / SAMPLE_STEP + 0.5)

	for _, data in pairs(ProjectileData) do
		if data.Ready and data.Part and data.Part.Parent then
			local speed = data.Velocity.Magnitude

			if speed >= MIN_PROJECTILE_SPEED then
				local currentDistance =
					(data.Part.Position - root.Position).Magnitude

				if currentDistance <= MAX_TRACK_DISTANCE then
					local dangerRadius =
						PLAYER_RADIUS
						+ projectileRadius(data.Part)
						+ EXTRA_MARGIN

					local threat = {
						DangerRadius = dangerRadius,
						InfluenceRadius = dangerRadius + SAFE_EXTRA,
						Positions = {}
					}

					for i = 0, steps do
						local t = i * SAMPLE_STEP
						threat.Positions[i + 1] =
							predictProjectile(data, t)
					end

					threats[#threats + 1] = threat
				end
			end
		end
	end

	return threats, steps
end

local function evaluateProjectileField(rootPosition, humanoid, direction, threats, steps)
	local playerVelocity = direction * humanoid.WalkSpeed

	local totalRisk = 0
	local hardHits = 0
	local immediateHits = 0
	local nearThreats = 0
	local nearestImpact = math.huge
	local minimumClearance = math.huge

	for _, threat in ipairs(threats) do
		local minDistance = math.huge
		local closestTime = math.huge

		for i = 0, steps do
			local t = i * SAMPLE_STEP
			local playerFuture =
				rootPosition + playerVelocity * t

			local projectileFuture =
				threat.Positions[i + 1]

			local distance =
				(projectileFuture - playerFuture).Magnitude

			if distance < minDistance then
				minDistance = distance
				closestTime = t
			end
		end

		local clearance =
			minDistance - threat.DangerRadius

		if clearance < minimumClearance then
			minimumClearance = clearance
		end

		if minDistance <= threat.InfluenceRadius then
			nearThreats += 1

			local timeFactor =
				1 - math.clamp(
					closestTime / PREDICT_TIME,
					0,
					1
				)

			if minDistance <= threat.DangerRadius then
				hardHits += 1

				if closestTime <= TRIGGER_TIME then
					immediateHits += 1
				end

				if closestTime < nearestImpact then
					nearestImpact = closestTime
				end

				local penetration =
					1 - math.clamp(
						minDistance / math.max(threat.DangerRadius, 0.001),
						0,
						1
					)

				totalRisk +=
					COLLISION_PENALTY
					+ penetration * 180
					+ timeFactor * 160
			else
				local buffer =
					math.max(
						threat.InfluenceRadius - threat.DangerRadius,
						0.001
					)

				local nearFactor =
					1 - math.clamp(
						(minDistance - threat.DangerRadius) / buffer,
						0,
						1
					)

				totalRisk +=
					nearFactor
					* nearFactor
					* NEAR_MISS_WEIGHT
					* (0.65 + timeFactor * 0.75)
			end
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
		ImmediateHits = immediateHits,
		NearThreats = nearThreats,
		NearestImpact = nearestImpact,
		MinimumClearance = minimumClearance
	}
end

local function movementPenalty(direction, userDirection)
	if direction.Magnitude < 0.01 then
		return 0
	end

	local magnitudePenalty =
		direction.Magnitude * MOVE_PENALTY

	local anglePenalty = 0
	local reversePenalty = 0

	if userDirection.Magnitude > 0.01 then
		local dot =
			math.clamp(
				userDirection.Unit:Dot(direction.Unit),
				-1,
				1
			)

		anglePenalty =
			(1 - dot) * TURN_PENALTY

		if dot < -0.2 then
			reversePenalty = REVERSE_PENALTY
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
		+ reversePenalty
		+ continuityPenalty
end

local function evaluateCandidate(
	character,
	humanoid,
	root,
	direction,
	userDirection,
	threats,
	steps
)
	local field =
		evaluateProjectileField(
			root.Position,
			humanoid,
			direction,
			threats,
			steps
		)

	local environment =
		environmentRisk(
			character,
			root,
			direction
		)

	field.EnvironmentRisk = environment
	field.MovePenalty =
		movementPenalty(
			direction,
			userDirection
		)

	field.Score =
		field.Risk
		+ environment * 5
		+ field.MovePenalty

	return field
end

local function betterCandidate(a, b)
	if not b then
		return true
	end

	if a.Eval.ImmediateHits ~= b.Eval.ImmediateHits then
		return a.Eval.ImmediateHits < b.Eval.ImmediateHits
	end

	if a.Eval.HardHits ~= b.Eval.HardHits then
		return a.Eval.HardHits < b.Eval.HardHits
	end

	if math.abs(a.Eval.Score - b.Eval.Score) > 0.05 then
		return a.Eval.Score < b.Eval.Score
	end

	if a.Eval.NearThreats ~= b.Eval.NearThreats then
		return a.Eval.NearThreats < b.Eval.NearThreats
	end

	if math.abs(
		a.Eval.MinimumClearance
		- b.Eval.MinimumClearance
	) > 0.05 then
		return
			a.Eval.MinimumClearance
			> b.Eval.MinimumClearance
	end

	return
		a.Direction.Magnitude
		< b.Direction.Magnitude
end

local function chooseDirection(character, humanoid, root)
	local userDirection =
		flatVector(humanoid.MoveDirection)

	if userDirection.Magnitude > 1 then
		userDirection = userDirection.Unit
	end

	local threats, steps =
		buildThreatSnapshot(root)

	if #threats == 0 then
		return nil, 0, math.huge, 0, 0
	end

	local currentEval =
		evaluateCandidate(
			character,
			humanoid,
			root,
			userDirection,
			userDirection,
			threats,
			steps
		)

	local shouldIntervene =
		currentEval.ImmediateHits > 0
		or (
			currentEval.NearestImpact <= TRIGGER_TIME
			and currentEval.Risk >= INTERVENE_RISK
		)

	if not shouldIntervene then
		return
			nil,
			currentEval.Risk,
			currentEval.NearestImpact,
			currentEval.NearThreats,
			currentEval.HardHits
	end

	local baseDirection =
		getBaseDirection(
			humanoid,
			root
		)

	local best = nil

	local stopEval =
		evaluateCandidate(
			character,
			humanoid,
			root,
			Vector3.zero,
			userDirection,
			threats,
			steps
		)

	best = {
		Direction = Vector3.zero,
		Eval = stopEval
	}

	for i = 0, CANDIDATE_COUNT - 1 do
		local degrees =
			i * (360 / CANDIDATE_COUNT)

		local direction =
			rotateY(
				baseDirection,
				degrees
			)

		local eval =
			evaluateCandidate(
				character,
				humanoid,
				root,
				direction,
				userDirection,
				threats,
				steps
			)

		local candidate = {
			Direction = direction,
			Eval = eval
		}

		if betterCandidate(candidate, best) then
			best = candidate
		end
	end

	if best
		and best.Direction.Magnitude > 0.01
	then
		local refinedBest = best

		for _, offset in ipairs({
			-REFINE_ANGLE,
			0,
			REFINE_ANGLE
		}) do
			local refinedUnit =
				rotateY(
					best.Direction.Unit,
					offset
				)

			for _, magnitude in ipairs(
				REFINE_MAGNITUDES
			) do
				local direction =
					refinedUnit * magnitude

				local eval =
					evaluateCandidate(
						character,
						humanoid,
						root,
						direction,
						userDirection,
						threats,
						steps
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
		end

		best = refinedBest
	end

	if not best then
		return
			nil,
			currentEval.Risk,
			currentEval.NearestImpact,
			currentEval.NearThreats,
			currentEval.HardHits
	end

	local safer =
		best.Eval.ImmediateHits
			< currentEval.ImmediateHits
		or best.Eval.HardHits
			< currentEval.HardHits
		or best.Eval.Score
			< currentEval.Score - 0.15

	if not safer then
		return
			nil,
			currentEval.Risk,
			currentEval.NearestImpact,
			currentEval.NearThreats,
			currentEval.HardHits
	end

	return
		best.Direction,
		currentEval.Risk,
		currentEval.NearestImpact,
		currentEval.NearThreats,
		currentEval.HardHits,
		best.Eval
end

local function calculateHoldTime(impactTime)
	if impactTime == math.huge then
		return MIN_DODGE_HOLD
	end

	local urgency =
		1 - math.clamp(
			impactTime / TRIGGER_TIME,
			0,
			1
		)

	return math.clamp(
		MIN_DODGE_HOLD
		+ urgency * 0.055,
		MIN_DODGE_HOLD,
		MAX_DODGE_HOLD
	)
end

RunService:BindToRenderStep(
	"AutoDodgePriority",
	Enum.RenderPriority.Last.Value,
	function()
		if not ENABLED then
			if DODGING then
				DODGING = false
				enableControls()
			end
			return
		end

		local character, humanoid, root = getCharacter()

		if not character then
			DODGING = false
			enableControls()
			return
		end

		local now = os.clock()

		if DODGING and now >= dodgeUntil then
			DODGING = false
			nextDodgeAllowed = now + DODGE_COOLDOWN
			enableControls()
		end

		if now - lastDecision >= DECISION_INTERVAL then
			lastDecision = now

			local direction, risk, impactTime =
				chooseDirection(
					character,
					humanoid,
					root
				)

			lastRisk = risk or 0
			lastImpactTime =
				impactTime or math.huge

			if direction then
				if DODGING then
					dodgeDirection = direction
					dodgeUntil =
						now
						+ calculateHoldTime(
							lastImpactTime
						)
				elseif now >= nextDodgeAllowed then
					dodgeDirection = direction
					dodgeStarted = now
					dodgeUntil =
						now
						+ calculateHoldTime(
							lastImpactTime
						)

					DODGING = true
				end
			elseif
				DODGING
				and now - dodgeStarted
					>= MIN_DODGE_COMMIT
			then
				DODGING = false
				dodgeUntil = now
				nextDodgeAllowed =
					now + DODGE_COOLDOWN
				enableControls()
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

RunService.RenderStepped:Connect(function()
	local count = 0

	for _ in pairs(ProjectileData) do
		count += 1
	end

	local impactText = "-"

	if lastImpactTime ~= math.huge then
		impactText = string.format("%.2fs", lastImpactTime)
	end

	Info.Text =
		"Projectile : "
		.. tostring(count)
		.. "\nRisk : "
		.. string.format("%.2f", lastRisk)
		.. " / Impact : "
		.. impactText

	if not EnemyProj then
		Status.Text = "EnemyProj 대기 중..."
		Status.TextColor3 = Color3.fromRGB(230, 190, 80)

	elseif not ENABLED then
		Status.Text = "준비됨"
		Status.TextColor3 = Color3.fromRGB(165, 165, 175)

	elseif DODGING then
		Status.Text = "전체 탄 경로 회피 중"
		Status.TextColor3 = Color3.fromRGB(255, 120, 90)

	elseif lastRisk > 0 then
		Status.Text = "다중 탄 위험 분석 중"
		Status.TextColor3 = Color3.fromRGB(240, 190, 80)

	else
		Status.Text = "안전 - 조작 유지"
		Status.TextColor3 = Color3.fromRGB(100, 220, 140)
	end
end)
