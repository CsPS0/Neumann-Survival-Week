-- The school's games, in the lobby and in free roam (not during a story or a night round):
--   * ping pong at the Aula's table: E at an end takes that side, left click hits the ball when it reaches you.
--     Alone you play the computer. First to 5 wins. The server runs the ball; clients only draw it (SchoolGamesUi).
--   * basketball in the gym: E picks the ball up, left click throws it. Aimed roughly at the hoop from up to 14 m, the
--     throw arcs to the hoop (with a little error); anywhere else it goes where you look. Baskets are counted.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Achievements = require(ReplicatedStorage.Shared.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local FloorData = require(ReplicatedStorage.Shared.FloorData)
local AchievementService = require(script.Parent.AchievementService)
local Characters = require(script.Parent.Characters)

local S = Config.studs

local SchoolGames = {}

local remotes: Folder
local function remote(name: string): RemoteEvent
	return remotes:FindFirstChild(name) :: RemoteEvent
end
local function sound(name: string, at: Vector3)
	remote("Sound"):FireAllClients(name, at)
end
local function banner(text: string, to: Player?)
	if to then
		remote("Banner"):FireClient(to, text, 3)
	else
		remote("Banner"):FireAllClients(text, 3)
	end
end

local function open(): boolean
	local mode = ReplicatedStorage:GetAttribute("Mode")
	return mode == nil or mode == "none" or mode == "freeroam"
end

-- Ping pong ----------------------------------------------------------------------------------------------------

local WIN = 5
local HIT_EARLY = 0.45 -- seconds before the ball reaches you that a swing counts
local HIT_LATE = 0.2
local pong = {
	sides = {} :: { [string]: Player? }, -- "W" | "E" -> player (nil: the computer)
	score = { W = 0, E = 0 },
	from = "W", -- who hit last
	t0 = 0,
	dur = 1.2,
	rally = 0,
	active = false,
	token = 0,
}
local tableTop: BasePart
local endPos: { [string]: Vector3 } = {}

local function other(side: string): string
	return if side == "W" then "E" else "W"
end

local function names(): { W: string, E: string }
	local function n(side: string): string
		local p = pong.sides[side]
		return if p then p.DisplayName else "Computer"
	end
	return { W = n("W"), E = n("E") }
end

local function broadcast()
	remote("PingPongState"):FireAllClients({
		active = pong.active,
		a = endPos[pong.from],
		b = endPos[other(pong.from)],
		t0 = pong.t0,
		dur = pong.dur,
		score = pong.score,
		names = names(),
		top = tableTop.Position.Y + tableTop.Size.Y / 2,
	})
end

local nextShot: (string) -> ()

local function point(winner: string)
	pong.score[winner] += 1
	pong.rally = 0
	if pong.score[winner] >= WIN then
		local who = pong.sides[winner]
		banner(`Ping pong: {names()[winner]} wins {pong.score[winner]} : {pong.score[other(winner)]}!`)
		if who then
			AchievementService.award(who, "ping_pong")
		end
		pong.score = { W = 0, E = 0 }
	end
	pong.active = false
	broadcast()
	pong.token += 1
	local token = pong.token
	task.delay(1.5, function()
		if token == pong.token and (pong.sides.W or pong.sides.E) and open() then
			pong.dur = 1.2
			nextShot(other(winner)) -- the loser of the point serves
		end
	end)
end

nextShot = function(striker: string)
	pong.from = striker
	pong.t0 = workspace:GetServerTimeNow()
	pong.active = true
	pong.token += 1
	local token = pong.token
	sound("pong", endPos[striker])
	broadcast()
	local receiver = other(striker)
	local arrive = pong.dur
	if not pong.sides[receiver] then
		-- The computer: it reaches most balls, fewer as the rally speeds up.
		task.delay(arrive - 0.05, function()
			if token ~= pong.token then
				return
			end
			if math.random() < math.clamp(0.93 - pong.rally * 0.05, 0.45, 0.93) then
				pong.rally += 1
				pong.dur = math.max(0.55, pong.dur * 0.94)
				nextShot(receiver)
			end
		end)
	end
	task.delay(arrive + HIT_LATE + 0.05, function()
		if token == pong.token then
			point(striker) -- nobody hit it back
		end
	end)
end

local function hit(player: Player)
	if not pong.active or not open() then
		return
	end
	local receiver = other(pong.from)
	if pong.sides[receiver] ~= player then
		return
	end
	local t = workspace:GetServerTimeNow() - pong.t0
	if t < pong.dur - HIT_EARLY or t > pong.dur + HIT_LATE then
		return -- too early or too late: the swing misses (the point is lost when the ball passes)
	end
	pong.rally += 1
	pong.dur = math.max(0.55, pong.dur * 0.94)
	nextShot(receiver)
end

local function take(player: Player, side: string)
	if not open() then
		return
	end
	if pong.sides[side] and pong.sides[side] ~= player then
		banner(`{pong.sides[side].DisplayName} is playing there.`, player)
		return
	end
	for s, p in pong.sides do
		if p == player then
			pong.sides[s] = nil
		end
	end
	pong.sides[side] = player
	player:SetAttribute("PingPong", side)
	banner("Ping pong: left click hits the ball when it reaches you. First to 5.", player)
	if not pong.active then
		pong.score = { W = 0, E = 0 }
		pong.dur = 1.2
		task.delay(1.5, function()
			if pong.sides[side] == player and not pong.active then
				nextShot(other(side))
			end
		end)
	end
	broadcast()
end

local function release(player: Player)
	for s, p in pong.sides do
		if p == player then
			pong.sides[s] = nil
		end
	end
	if player.Parent then
		player:SetAttribute("PingPong", nil)
	end
	if not pong.sides.W and not pong.sides.E then
		pong.active = false
		pong.token += 1
		pong.score = { W = 0, E = 0 }
	end
	broadcast()
end

local function setupPong(model: Model)
	tableTop = model:FindFirstChild("TableTop") :: BasePart
	local c = tableTop.Position
	local topY = c.Y + tableTop.Size.Y / 2
	for _, side in { "W", "E" } do
		local dir = if side == "W" then -1 else 1
		endPos[side] = Vector3.new(c.X + dir * (tableTop.Size.X / 2 + S(0.1)), topY + S(0.3), c.Z)
		local spot = Instance.new("Part")
		spot.Name = "PaddleSpot" .. side
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.CanTouch = false
		spot.Transparency = 1
		spot.Size = Vector3.new(1, 1, 1)
		spot.Position = Vector3.new(c.X + dir * (tableTop.Size.X / 2 + S(0.5)), topY, c.Z)
		spot.Parent = model
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Play ping pong"
		prompt.ObjectText = if side == "W" then "West end" else "East end"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("For", "all")
		prompt.Parent = spot
		prompt.Triggered:Connect(function(player)
			take(player, side)
		end)
	end
	-- Walking away from your end, or the games closing, ends your game.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for side, p in pong.sides do
				local r = p and Characters.root(p)
				local spot = model:FindFirstChild("PaddleSpot" .. side) :: BasePart
				if p and (not p.Parent or not r or (r.Position - spot.Position).Magnitude > S(4) or not open()) then
					release(p)
				end
			end
		end
	end)
end

-- Basketball ---------------------------------------------------------------------------------------------------

local ball: Part
local ballHome: Vector3
local holder: Player? = nil
local thrower: Player? = nil
local lastThrow: { [Player]: number } = {}
local baskets: { [Player]: number } = {}
local rims: { BasePart } = {}
local gymRect: any = nil
local idleSince = 0
local weld: WeldConstraint? = nil

local function resetBall()
	if weld then
		weld:Destroy()
		weld = nil
	end
	if holder and holder.Parent then
		holder:SetAttribute("HoldingBall", nil)
	end
	holder = nil
	ball.Anchored = false
	ball.CanCollide = true
	ball.Massless = false
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.CFrame = CFrame.new(ballHome)
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	idleSince = os.clock()
end

local function pickUp(player: Player)
	local r = Characters.root(player)
	if not open() or holder or not r or player:GetAttribute("State") == "out" then
		return
	end
	holder = player
	player:SetAttribute("HoldingBall", true)
	ball.CanCollide = false
	ball.Massless = true
	ball.CFrame = r.CFrame * CFrame.new(S(0.25), S(0.1), -S(0.45))
	local w = Instance.new("WeldConstraint")
	w.Part0 = r
	w.Part1 = ball
	w.Parent = ball
	weld = w
	banner("Left click throws. Aim at the hoop.", player)
end

local function throw(player: Player, look: any)
	if holder ~= player or typeof(look) ~= "Vector3" or look.Magnitude < 0.5 then
		return
	end
	if os.clock() - (lastThrow[player] or 0) < 0.6 then
		return
	end
	lastThrow[player] = os.clock()
	local r = Characters.root(player)
	if not r then
		return
	end
	look = look.Unit
	if weld then
		weld:Destroy()
		weld = nil
	end
	holder = nil
	thrower = player
	player:SetAttribute("HoldingBall", nil)
	local from = r.Position + Vector3.new(0, S(0.55), 0) + look * S(0.5)
	ball.CFrame = CFrame.new(from)
	ball.Massless = false
	ball.CanCollide = true
	pcall(function()
		ball:SetNetworkOwner(nil)
	end)
	-- Aim assist: roughly at a hoop and close enough, the ball arcs into it.
	local velocity = look * S(9) + Vector3.new(0, S(3), 0)
	for _, rim in rims do
		local to = rim.Position + Vector3.new(0, S(0.15), 0)
		local d = to - from
		local flat = Vector3.new(d.X, 0, d.Z)
		local aim = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < S(14) and aim.Magnitude > 0.1 and flat.Unit:Dot(aim.Unit) > math.cos(math.rad(15)) then
			local t = math.clamp(flat.Magnitude / S(6), 0.55, 1.3)
			local miss = (flat.Magnitude / S(14)) * S(0.25)
			local target = to + Vector3.new((math.random() - 0.5) * miss, 0, (math.random() - 0.5) * miss)
			velocity = (target - from) / t + Vector3.new(0, 0.5 * workspace.Gravity * t, 0)
			break
		end
	end
	ball.AssemblyLinearVelocity = velocity
	idleSince = os.clock()
end

local function setupBall(parent: Instance, school: any)
	local r = FloorData.roomRect(0, "Tornaterem")
	if not r then
		return
	end
	gymRect = r
	ballHome = Vector3.new(S((r.x0 + r.x1) / 2), S(1), S((r.z0 + r.z1) / 2))
	for _, d in parent:GetDescendants() do
		if d.Name == "Rim" and d:IsA("BasePart") then
			local m = d.Position / Config.STUDS_PER_METRE
			if FloorData.roomLabelAt(0, m.X, m.Z) == "Tornaterem" then
				table.insert(rims, d)
			end
		end
	end
	ball = Instance.new("Part")
	ball.Name = "Basketball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(S(0.24), S(0.24), S(0.24))
	ball.Color = Color3.fromRGB(214, 106, 40)
	ball.Material = Enum.Material.Fabric
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.5, 0.75, 1, 1)
	ball.CanTouch = false
	ball.Parent = workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = "Basketball"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("For", "all")
	prompt.Parent = ball
	prompt.Triggered:Connect(pickUp)
	resetBall()
	local _ = school

	local lastY = ball.Position.Y
	RunService.Heartbeat:Connect(function()
		if not open() then
			if ball.Parent then
				resetBall()
				ball.Parent = nil
			end
			return
		elseif not ball.Parent then
			ball.Parent = workspace
			resetBall()
		end
		prompt.Enabled = holder == nil
		if holder and (not holder.Parent or not Characters.root(holder)) then
			resetBall()
		end
		local p = ball.Position
		-- A basket: the ball drops through a rim.
		if not holder then
			for _, rim in rims do
				local flat = Vector3.new(p.X - rim.Position.X, 0, p.Z - rim.Position.Z).Magnitude
				if lastY > rim.Position.Y and p.Y <= rim.Position.Y and ball.AssemblyLinearVelocity.Y < 0
					and flat < S(0.26) then
					local who = thrower
					sound("bounce", rim.Position)
					if who and who.Parent then
						baskets[who] = (baskets[who] or 0) + 1
						banner(`Basket! {who.DisplayName}: {baskets[who]}`)
						if baskets[who] >= Achievements.BASKETS then
							AchievementService.award(who, "hoops")
						end
					end
				end
			end
		end
		lastY = p.Y
		-- Lost or left lying around: back to the middle of the gym.
		local m = p / Config.STUDS_PER_METRE
		local outside = m.X < gymRect.x0 - 1 or m.X > gymRect.x1 + 1 or m.Z < gymRect.z0 - 1 or m.Z > gymRect.z1 + 1
			or m.Y < -2
		if not holder and (outside and os.clock() - idleSince > 5 or os.clock() - idleSince > 45) then
			resetBall()
		end
	end)
end

function SchoolGames.init(school: any, remoteFolder: Folder, schoolFolder: Instance)
	remotes = remoteFolder
	setupPong(school.pingPong)
	setupBall(schoolFolder, school)
	remote("PingPongHit").OnServerEvent:Connect(hit)
	remote("BallThrow").OnServerEvent:Connect(throw)
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		if holder == player then
			resetBall()
		end
		baskets[player] = nil
		lastThrow[player] = nil
	end)
end

return SchoolGames
