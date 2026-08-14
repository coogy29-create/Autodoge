local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ENABLED = false
local DODGING = false

local EnemyProj = nil
local ProjectileData = {}

local PREDICT_TIME = 0.48
local SAMPLE_STEP = 0.03
local DECISION_INTERVAL = 0.025

local TRIGGER_TIME = 0.30
local HARD_TRIGGER_TIME = 0.14

local PLAYER_RADIUS = 2.35
local EXTRA_MARGIN = 0.55
local SAFE_EXTRA = 0.35

local MIN_PROJECTILE_SPEED = 3
local MAX_TRACK_DISTANCE = 70

local VELOCITY_SMOOTH = 0.52
local ACCELERATION_SMOOTH = 0.08
local MAX_ACCELERATION = 3500

local WALL_CHECK_DISTANCE = 6.5
local FLOOR_CHECK_DISTANCE = 7
local WALL_SOFT_DISTANCE = 3.5

local MIN_DODGE_HOLD = 0.045
local MAX_DODGE_HOLD = 0.24
local DODGE_COOLDOWN = 0.025
local MIN_DODGE_COMMIT = 0.045

local DIRECT_HIT_DOT = 0.78
local DIRECT_HIT_RADIUS_FACTOR = 0.82
local SIDE_CLEARANCE_BUFFER = 0.45

local MIN_REQUIRED_IMPROVEMENT = 0.20
local MOVE_PENALTY = 0.35
local TURN_PENALTY = 0.24
local REVERSE_PENALTY = 0.5
local STOP_BONUS = 0.10

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

local function environmentRisk(character, root, direction)
	if direction.Magnitude < 0.01 then
		return 0
	end

	local dir = direction.Unit
	local params = getRayParams(character)
	local risk = 0
	local origin = root.Position + Vector3.new(0, 1, 0)

	local wall = workspace:Raycast(
		origin,
		dir * WALL_CHECK_DISTANCE,
		params
	)

	if wall then
		local dist = (wall.Position - origin).Magnitude

		if dist <= WALL_SOFT_DISTANCE then
			risk += 65 + (WALL_SOFT_DISTANCE - dist) * 20
		else
			risk += 10
		end
	end

	local future = root.Position + dir * 3

	local floor = workspace:Raycast(
		future + Vector3.new(0, 2, 0),
		Vector3.new(0, -FLOOR_CHECK_DISTANCE, 0),
		params
	)

	if not floor then
		risk += 100
	end

	return risk
end

local function projectileThreat(rootPosition, playerVelocity, data)
	if not data.Ready or not data.Part or not data.Part.Parent then
		return 0, math.huge, math.huge
	end

	if data.Velocity.Magnitude < MIN_PROJECTILE_SPEED then
		return 0, math.huge, math.huge
	end

	local currentDistance = (data.Part.Position - rootPosition).Magnitude

	if currentDistance > MAX_TRACK_DISTANCE then
		return 0, math.huge, currentDistance
	end

	local dangerRadius =
		PLAYER_RADIUS
		+ projectileRadius(data.Part)
		+ EXTRA_MARGIN

	local safeRadius = dangerRadius + SAFE_EXTRA

	local minDistance = math.huge
	local closestTime = math.huge

	local t = 0

	while t <= PREDICT_TIME do
		local bulletFuture = predictProjectile(data, t)
		local playerFuture = rootPosition + playerVelocity * t
		local distance = (bulletFuture - playerFuture).Magnitude

		if distance < minDistance then
			minDistance = distance
			closestTime = t
		end

		t += SAMPLE_STEP
	end

	if closestTime > TRIGGER_TIME then
		return 0, closestTime, minDistance
	end

	if minDistance > safeRadius then
		return 0, closestTime, minDistance
	end

	local distanceFactor =
		1 - math.clamp(minDistance / safeRadius, 0, 1)

	local timeFactor =
		1 - math.clamp(closestTime / TRIGGER_TIME, 0, 1)

	local risk =
		distanceFactor * 10
		+ timeFactor * 9

	if minDistance <= dangerRadius then
		risk += 24
	end

	if closestTime <= HARD_TRIGGER_TIME then
		risk += 18
	end

	return risk, closestTime, minDistance
end

local function totalRisk(character, humanoid, root, direction)
	local playerVelocity = Vector3.zero

	if direction.Magnitude > 0.01 then
		playerVelocity = direction.Unit * humanoid.WalkSpeed
	end

	local worstRisk = 0
	local secondRisk = 0
	local nearestImpact = math.huge
	local dominantData = nil
	local dominantMinDistance = math.huge

	for _, data in pairs(ProjectileData) do
		local risk, impactTime, minDistance = projectileThreat(
			root.Position,
			playerVelocity,
			data
		)

		if risk > worstRisk then
			secondRisk = worstRisk
			worstRisk = risk
			dominantData = data
			dominantMinDistance = minDistance
		elseif risk > secondRisk then
			secondRisk = risk
		end

		if risk > 0 and impactTime < nearestImpact then
			nearestImpact = impactTime
		end
	end

	local projectileScore = worstRisk + secondRisk * 0.25
	local envScore = environmentRisk(character, root, direction)

	return projectileScore + envScore, nearestImpact, worstRisk, dominantData, dominantMinDistance
end

local function flatUnit(v)
	local flat = Vector3.new(v.X, 0, v.Z)

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

local function getDirectIncomingInfo(root, data, minDistance)
	if not data or not data.Part or not data.Part.Parent then
		return false, nil, nil, 0
	end

	local velocity = flatUnit(data.Velocity)
	local toPlayer = flatUnit(root.Position - data.Part.Position)

	if velocity.Magnitude < 0.01 or toPlayer.Magnitude < 0.01 then
		return false, nil, nil, 0
	end

	local towardDot = velocity:Dot(toPlayer)
	local dangerRadius =
		PLAYER_RADIUS
		+ projectileRadius(data.Part)
		+ EXTRA_MARGIN

	local direct =
		towardDot >= DIRECT_HIT_DOT
		and minDistance <= dangerRadius * DIRECT_HIT_RADIUS_FACTOR

	if not direct then
		return false, nil, nil, towardDot
	end

	local sideA = Vector3.new(-velocity.Z, 0, velocity.X)
	local sideB = -sideA

	return true, sideA.Unit, sideB.Unit, towardDot
end

local function requiredSideHold(humanoid, data, predictedMinDistance)
	if not data or not data.Part then
		return MIN_DODGE_HOLD
	end

	local dangerRadius =
		PLAYER_RADIUS
		+ projectileRadius(data.Part)
		+ EXTRA_MARGIN
		+ SIDE_CLEARANCE_BUFFER

	local needed =
		math.max(
			0.55,
			dangerRadius - math.max(predictedMinDistance or 0, 0)
		)

	local speed = math.max(humanoid.WalkSpeed, 1)
	local time = needed / speed

	return math.clamp(
		time,
		MIN_DODGE_HOLD,
		MAX_DODGE_HOLD
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

local ANGLE_OFFSETS = {
	0,
	15, -15,
	30, -30,
	45, -45,
	60, -60,
	90, -90,
	120, -120,
	150, -150,
	180
}

local function candidatePenalty(direction, currentDirection, degrees)
	if direction.Magnitude < 0.01 then
		return -STOP_BONUS
	end

	local penalty = MOVE_PENALTY
	penalty += (math.abs(degrees) / 180) * TURN_PENALTY

	if currentDirection.Magnitude > 0.01 then
		local dot = math.clamp(currentDirection.Unit:Dot(direction.Unit), -1, 1)

		if dot < -0.25 then
			penalty += REVERSE_PENALTY
		end
	end

	return penalty
end

local function chooseDirection(character, humanoid, root)
	local currentDirection = flatUnit(humanoid.MoveDirection)

	local currentRisk, currentImpact, _, dominantData, dominantMinDistance =
		totalRisk(
			character,
			humanoid,
			root,
			currentDirection
		)

	if currentRisk <= 0 then
		return nil, 0, math.huge, nil, math.huge, false
	end

	local direct, sideA, sideB =
		getDirectIncomingInfo(
			root,
			dominantData,
			dominantMinDistance
		)

	if direct then
		local sideARisk =
			totalRisk(
				character,
				humanoid,
				root,
				sideA
			)

		local sideBRisk =
			totalRisk(
				character,
				humanoid,
				root,
				sideB
			)

		local chosenSide
		local chosenRisk

		if sideARisk <= sideBRisk then
			chosenSide = sideA
			chosenRisk = sideARisk
		else
			chosenSide = sideB
			chosenRisk = sideBRisk
		end

		if chosenRisk < currentRisk then
			return chosenSide, currentRisk, currentImpact, dominantData, dominantMinDistance, true
		end
	end

	local baseDirection = getBaseDirection(humanoid, root)
	local bestDirection = nil
	local bestRisk = currentRisk
	local bestScore = currentRisk

	local stopRisk =
		totalRisk(
			character,
			humanoid,
			root,
			Vector3.zero
		)

	local stopScore = stopRisk - STOP_BONUS

	if stopScore < bestScore then
		bestScore = stopScore
		bestRisk = stopRisk
		bestDirection = Vector3.zero
	end

	for _, degrees in ipairs(ANGLE_OFFSETS) do
		local direction = rotateY(baseDirection, degrees)

		local risk =
			totalRisk(
				character,
				humanoid,
				root,
				direction
			)

		local score =
			risk
			+ candidatePenalty(
				direction,
				currentDirection,
				degrees
			)

		if score < bestScore then
			bestScore = score
			bestRisk = risk
			bestDirection = direction
		end
	end

	if not bestDirection then
		return nil, currentRisk, currentImpact, dominantData, dominantMinDistance, false
	end

	local improvement = currentRisk - bestRisk

	if improvement < MIN_REQUIRED_IMPROVEMENT then
		return nil, currentRisk, currentImpact, dominantData, dominantMinDistance, false
	end

	return bestDirection, currentRisk, currentImpact, dominantData, dominantMinDistance, false
end

local function calculateHoldTime(humanoid, impactTime, dominantData, dominantMinDistance, direct)
	if direct then
		return requiredSideHold(
			humanoid,
			dominantData,
			dominantMinDistance
		)
	end

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
			+ 0.08 * urgency,
		MIN_DODGE_HOLD,
		0.13
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

			local direction, risk, impactTime, dominantData, dominantMinDistance, direct =
				chooseDirection(
					character,
					humanoid,
					root
				)

			lastRisk = risk
			lastImpactTime = impactTime

			if DODGING and now - dodgeStarted >= MIN_DODGE_COMMIT then
				local dodgeRisk =
					totalRisk(
						character,
						humanoid,
						root,
						dodgeDirection
					)

				if dodgeRisk <= 0 then
					DODGING = false
					dodgeUntil = now
					nextDodgeAllowed = now + DODGE_COOLDOWN
					enableControls()
				end
			end

			if direction and not DODGING and now >= nextDodgeAllowed then
				dodgeDirection = direction
				dodgeStarted = now
				dodgeUntil =
					now
					+ calculateHoldTime(
						humanoid,
						impactTime,
						dominantData,
						dominantMinDistance,
						direct
					)

				DODGING = true
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
		Status.Text = "짧게 회피 중"
		Status.TextColor3 = Color3.fromRGB(255, 120, 90)

	elseif lastRisk > 0 then
		Status.Text = "충돌 임박 감시"
		Status.TextColor3 = Color3.fromRGB(240, 190, 80)

	else
		Status.Text = "안전 - 조작 유지"
		Status.TextColor3 = Color3.fromRGB(100, 220, 140)
	end
end)
