-- Hide and Seek (HORROR-GAME/docs/multiplayer-modes.md, match.gd): 25 s to hide, a 4 minute hunt. The entity is the
-- computer (default) or a random player. Lockers hide, the torch flash stuns. A caught survivor is held by the
-- entity for 25 s; teammates free them by hitting the entity from behind (it lashes out: -15 health for the one who
-- hits) or by pulling them free (hold E 3 s; -25 health for the one pulled). Nobody comes: after a third of the time
-- the entity takes their left arm, after two thirds an eye, at the end it eats them (out). Lost limbs stay lost
-- for the round. Survivors win when time runs out with one of them not out.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Characters = require(script.Parent.Characters)
local EntityAI = require(script.Parent.EntityAI)
local EntityModel = require(script.Parent.EntityModel)
local Lockers = require(script.Parent.Lockers)
local Maim = require(script.Parent.Maim)
local Grab = require(script.Parent.Grab)
local People = require(script.Parent.People)
local Torch = require(script.Parent.Torch)

local HS = Config.HideSeek
local S = Config.studs

local HideAndSeek = {}

local ctx = nil
local seeker: Player? = nil
local ai = nil
local entityModel: Model? = nil
local survivors: { [Player]: string } = {}
local downCount: { [Player]: number } = {}
local prompts: { Instance } = {}
local seekerFrozenUntil = 0
local round = 0
local grabs: { [Player]: any } = {} -- the entity holding a survivor (Grab.luau)

local function remote(name: string): RemoteEvent
	return ctx.remotes:FindFirstChild(name) :: RemoteEvent
end

local function setSurvivor(player: Player, state: string)
	survivors[player] = state
	if player.Parent then
		player:SetAttribute("State", state)
	end
end

local function finish(summary: string)
	if ctx then
		ctx.finish(summary)
	end
end

local function check(timeUp: boolean)
	local result = Rules.hideSeekResult(survivors, timeUp)
	if result == "survivors" then
		finish("Time is up. The survivors win!")
	elseif result == "entity" then
		finish("Nobody is left standing. The entity wins.")
	end
end

local function removePromptsOf(player: Player)
	for i = #prompts, 1, -1 do
		local p = prompts[i]
		if p:GetAttribute("Owner") == player.UserId and p.Name ~= "Catch" then
			p:Destroy()
			table.remove(prompts, i)
		end
	end
end

local function addPrompt(player: Player, name: string, action: string, kind: string, hold: number,
	onTrigger: (by: Player) -> ()): ProximityPrompt?
	local root = Characters.root(player)
	if not root then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = hold
	-- No line-of-sight test: the target's own body would block it; the server checks state and distance.
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = S(2.5) + 2
	prompt:SetAttribute("For", kind)
	prompt:SetAttribute("Owner", player.UserId)
	prompt.Triggered:Connect(onTrigger)
	prompt.Parent = root
	table.insert(prompts, prompt)
	return prompt
end

local function out(player: Player)
	if survivors[player] == nil or survivors[player] == "out" then
		return
	end
	local grab = grabs[player]
	grabs[player] = nil
	if grab then
		grab:stop()
	end
	removePromptsOf(player)
	Lockers.release(player)
	setSurvivor(player, "out")
	Characters.despawn(player)
	if player.Parent then
		ctx.banner("You are out. Watch the others.", 4, player)
	end
	check(false)
end

local function hurt(player: Player, amount: number): boolean
	local humanoid = Characters.humanoid(player)
	if not humanoid then
		return false
	end
	humanoid.Health = math.max(0, humanoid.Health - amount)
	return humanoid.Health > 0
end

local function revive(player: Player, by: Player, pulled: boolean)
	if survivors[player] ~= "downed" or survivors[by] ~= "alive" then
		return
	end
	local grab = grabs[player]
	grabs[player] = nil
	if grab then
		grab:free(by)
	end
	removePromptsOf(player)
	if pulled and not hurt(player, 25) then
		out(player)
		return
	end
	Characters.setSpeed(player, nil)
	setSurvivor(player, "alive")
	ctx.banner(if pulled then `{by.DisplayName} pulled you free! (-25 health)` else `{by.DisplayName} got you free!`, 3,
		player)
end

-- What the entity takes from a held survivor: the left arm, then an eye (visible to everyone, the rest of the round).
local function maim(player: Player, part: string)
	local character = player.Character
	if not character or player:GetAttribute(part) then
		return
	end
	player:SetAttribute(part, true)
	Maim.apply(character, part)
	ctx.banner(if part == "LostArm" then "The entity tears at you. Your left arm is gone. Someone help!"
		else "You lose an eye. It is starting to eat you!", 4, player)
	remote("Sound"):FireAllClients("scream", (Characters.root(player) :: BasePart).Position)
end

local function down(player: Player)
	if survivors[player] ~= "alive" or Lockers.isHidden(player) then
		return
	end
	setSurvivor(player, "downed")
	Characters.setSpeed(player, 0)
	Torch.off(player)
	remote("Sound"):FireAllClients("sting", (Characters.root(player) :: BasePart).Position)
	ctx.banner("The entity has you! A teammate can hit it from behind or pull you free.", 5, player)
	addPrompt(player, "Revive", "Pull free (-25 health)", "survivor", HS.reviveHold, function(by)
		local a, b = Characters.root(by), Characters.root(player)
		if a and b and (a.Position - b.Position).Magnitude < S(3) + 3 then
			revive(player, by, true)
		end
	end)
	-- The entity holds them (Grab.luau): they mash the defend key to fight it off; each hold gets its own 25 s.
	downCount[player] = (downCount[player] or 0) + 1
	local myRound = round
	local body = entityModel or (seeker and seeker.Character)
	local hold = HS.downed * ctx.timeScale
	if ai then
		ai:stun(hold + 1) -- it stays and eats
	elseif seeker then
		Characters.setSpeed(seeker, 0)
	end
	local function release(stunFor: number)
		if ai then
			ai:stun(stunFor)
		elseif seeker then
			seekerFrozenUntil = os.clock() + stunFor
			task.delay(stunFor, function()
				if myRound == round and seeker and os.clock() >= seekerFrozenUntil then
					Characters.setSpeed(seeker, Config.Player.seeker)
				end
			end)
		end
	end
	if body then
		grabs[player] = Grab.start({
			victim = player,
			entity = body,
			hold = hold,
			remotes = ctx.remotes,
			onMaim = function(part)
				maim(player, part)
			end,
			onEaten = function()
				grabs[player] = nil
				release(0.1)
				if myRound == round and survivors[player] == "downed" then
					if player.Parent then
						ctx.banner("Too slow. The entity ate you.", 4, player)
					end
					out(player)
				end
			end,
			onFree = function(by)
				grabs[player] = nil
				if by ~= nil then
					-- A teammate got them out: the entity stops eating and comes back after 3 s, time to run (a hit
					-- from behind stuns it longer, set after this in hitFromBehind).
					release(3)
				elseif myRound == round and survivors[player] == "downed" then
					-- Fought it off: free, and it reels for a moment.
					removePromptsOf(player)
					Characters.setSpeed(player, nil)
					setSurvivor(player, "alive")
					release(3)
					ctx.banner(`{player.DisplayName} fought the entity off!`, 4)
				end
			end,
		})
	end
	check(false)
end

-- Hitting the entity from behind (E on its back while someone is held) frees the held survivor nearest to it and
-- stuns it; it lashes out at you (-15 health).
local lastHit: { [Player]: number } = {}
local function hitFromBehind(by: Player)
	if survivors[by] ~= "alive" or os.clock() - (lastHit[by] or 0) < 4 then
		return
	end
	local body = if ai then ai.root else (seeker and Characters.root(seeker))
	local me = Characters.root(by)
	if not body or not me then
		return
	end
	local offset = me.Position - body.Position
	if offset.Magnitude > S(3) + 4 then
		return
	end
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local look = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z)
	if flat.Magnitude < 0.1 or look.Magnitude < 0.1 or flat.Unit:Dot(look.Unit) > -0.2 then
		ctx.banner("Get behind it first!", 2, by)
		return
	end
	lastHit[by] = os.clock()
	local victim, best = nil, math.huge
	for p, state in survivors do
		local r = Characters.root(p)
		if state == "downed" and r and (r.Position - body.Position).Magnitude < best then
			victim, best = p, (r.Position - body.Position).Magnitude
		end
	end
	if not victim or best > S(12) then
		return
	end
	if not hurt(by, 15) then
		out(by)
	end
	revive(victim, by, false)
	if ai then
		ai:stun(4)
	elseif seeker then
		seekerFrozenUntil = os.clock() + 4
		Characters.setSpeed(seeker, 0)
		remote("Stunned"):FireClient(seeker, 4)
		local myRound = round
		task.delay(4, function()
			if myRound == round and seeker and os.clock() >= seekerFrozenUntil then
				Characters.setSpeed(seeker, Config.Player.seeker)
			end
		end)
	end
	ctx.banner(`{by.DisplayName} hit the entity from behind and freed {victim.DisplayName}!`, 4)
end

local function addEntityPrompt()
	local body = if ai then ai.root else (seeker and Characters.root(seeker))
	if not body then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HitEntity"
	prompt.ActionText = "Hit it from behind"
	prompt.ObjectText = "Entity"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = S(3) + 4
	prompt:SetAttribute("For", "survivor")
	prompt.Triggered:Connect(hitFromBehind)
	prompt.Parent = body
	table.insert(prompts, prompt)
end

local function entityPosition(): Vector3?
	if ai then
		return ai.root.Position
	end
	local root = seeker and Characters.root(seeker)
	return root and root.Position
end

local function onFlash(player: Player, origin: Vector3, look: Vector3)
	if not ctx or survivors[player] ~= "alive" or ReplicatedStorage:GetAttribute("Phase") ~= "hunt" then
		return
	end
	local target = entityPosition()
	if not target or not Rules.flashHits(origin, look, target, S(Config.Torch.range), Config.Torch.coneDeg) then
		return
	end
	-- Not through walls.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	local hit = workspace:Raycast(origin, target - origin, params)
	local body = entityModel or (seeker and seeker.Character)
	if hit and body and not hit.Instance:IsDescendantOf(body) then
		return
	end
	if ai then
		ai:stun(Config.Torch.stun)
	elseif seeker then
		seekerFrozenUntil = os.clock() + Config.Torch.stun
		Characters.setSpeed(seeker, 0)
		remote("Stunned"):FireClient(seeker, Config.Torch.stun)
		local myRound = round
		task.delay(Config.Torch.stun, function()
			if myRound == round and seeker and os.clock() >= seekerFrozenUntil then
				Characters.setSpeed(seeker, Config.Player.seeker)
			end
		end)
	end
	ctx.banner(`{player.DisplayName} stunned the entity!`, 3)
end

local function startHunt()
	ctx.setPhase("hunt", HS.hunt, function()
		check(true)
	end)
	if ai then
		ai:start()
	elseif seeker then
		Characters.freeze(seeker, false)
	end
	remote("Sound"):FireAllClients("sting")
	ctx.banner("The entity is awake.", 4)
end

function HideAndSeek.start(c)
	ctx = c
	round += 1
	survivors = {}
	downCount = {}
	prompts = {}
	seeker = nil
	ai = nil
	entityModel = nil
	local players = c.players
	if c.options.entity == "player" then
		seeker = players[math.random(#players)]
	end
	for _, p in players do
		if p == seeker then
			remote("Role"):FireClient(p, "entity")
			p:SetAttribute("Seeker", true)
		else
			survivors[p] = "alive"
			remote("Role"):FireClient(p, "survivor")
		end
	end
	Lockers.canHide = function(p: Player): boolean
		return survivors[p] == "alive"
	end
	Torch.onFlash = onFlash

	local far = c.school.farPoint
	if seeker then
		local character = seeker.Character
		if character then
			EntityModel.attachTo(character)
		end
		Torch.setAllowed(seeker, false)
		Characters.setSpeed(seeker, Config.Player.seeker)
		Characters.place(seeker, CFrame.new(far + Vector3.new(0, 3, 0)))
		Characters.freeze(seeker, true)
		for p in survivors do
			addPrompt(p, "Catch", "Catch", "entity", 0, function(by)
				local a, b = Characters.root(by), Characters.root(p)
				if by == seeker and survivors[p] == "alive" and os.clock() >= seekerFrozenUntil
					and ReplicatedStorage:GetAttribute("Phase") == "hunt"
					and a and b and (a.Position - b.Position).Magnitude < S(2.5) + 5 then
					down(p)
				end
			end)
		end
	else
		local model = EntityModel.build()
		model.Parent = workspace
		entityModel = model
		ai = EntityAI.new(model, c.school, {
			targets = function()
				local list = {}
				for p, state in survivors do
					if state == "alive" and p.Parent then
						table.insert(list, p)
					end
				end
				return list
			end,
			isHidden = Lockers.isHidden,
			holdingBreath = Lockers.holdingBreath,
			lockers = Lockers.occupied,
			onCatch = down,
		})
		ai:placeAt(far)
	end

	-- A few students stayed late: they run from the entity, which can take them (a scream everyone hears).
	People.startVictims({
		count = 5,
		threats = function(): { Vector3 }
			local list = {}
			local body = entityModel and entityModel.PrimaryPart
			if body then
				table.insert(list, body.Position)
			end
			local root = seeker and Characters.root(seeker)
			if root then
				table.insert(list, root.Position)
			end
			return list
		end,
		computer = function(): BasePart?
			return entityModel and entityModel.PrimaryPart or nil
		end,
		canTake = function(by: Player): boolean
			return by == seeker and os.clock() >= seekerFrozenUntil
		end,
		active = function(): boolean
			return ReplicatedStorage:GetAttribute("Phase") == "hunt"
		end,
		bodies = false,
	})

	addEntityPrompt()
	for _, p in players do
		p:SetAttribute("LostArm", nil)
		p:SetAttribute("LostEye", nil)
	end
	c.banner(if seeker then `Hide! {seeker.DisplayName} is the entity and hunts in 25 seconds.`
		else "Hide! The entity wakes in 25 seconds.", 6)
	c.setPhase("hiding", HS.hide, startHunt)
end

function HideAndSeek.playerLeft(player: Player)
	if not ctx then
		return
	end
	if player == seeker then
		finish("The entity left. The survivors win.")
	elseif survivors[player] then
		survivors[player] = "out"
		check(false)
	end
end

function HideAndSeek.playerDied(player: Player)
	if player == seeker then
		finish("The entity is gone. The survivors win.")
	elseif survivors[player] and survivors[player] ~= "out" then
		out(player)
	end
end

function HideAndSeek.stop()
	round += 1
	for p, grab in grabs do
		grab:stop()
		grabs[p] = nil
	end
	People.stopVictims()
	if ai then
		ai:stop()
	end
	if entityModel then
		entityModel:Destroy()
	end
	for _, p in prompts do
		p:Destroy()
	end
	prompts = {}
	Torch.onFlash = nil
	for p in survivors do
		if p.Parent then
			Characters.setSpeed(p, nil)
		end
	end
	if seeker and seeker.Parent then
		seeker:SetAttribute("Seeker", nil)
		Characters.setSpeed(seeker, nil)
	end
	seeker = nil
	ai = nil
	entityModel = nil
	ctx = nil
end

return HideAndSeek
