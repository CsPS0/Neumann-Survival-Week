-- The entity holding someone (Hide and Seek, and the attack demos). The entity pins its victim and bites; the
-- victim fights back by mashing the defend key (X by default): each press fills a meter that drains on its own.
-- Fill it and you shove the entity off. Too slow: it takes the left arm after a third of the time, an eye after
-- two thirds, and eats you at the end. Friends can still free you (Hide and Seek: hit it from behind, pull you).
-- The server owns the meter (presses are rate-limited), the client shows it (StruggleUi.luau).
-- Remote "Grab" (server -> victim): ("start", {entity, endsAt, hold}), ("bite"), ("maim", part), ("meter", 0..1),
-- ("end", "self" | "rescued" | "eaten" | "stopped"). Remote "Struggle" (victim -> server): one press.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Characters = require(script.Parent.Characters)

local Grab = {}

Grab.STEP = 0.075 -- meter per press
Grab.DECAY = 0.14 -- meter lost per second
Grab.MIN_GAP = 1 / 14 -- seconds between counted presses (no macro faster than a human)
Grab.BITE_EVERY = 1.3

export type Opts = {
	victim: Player,
	entity: Model, -- the body that holds (the computer entity's model, or a player entity's character)
	hold: number, -- seconds until it eats the victim
	remotes: Folder,
	onMaim: (part: string) -> (),
	onEaten: () -> (),
	onFree: (by: Player?) -> (), -- by = nil when the victim fought it off
}

type Handle = {
	opts: Opts,
	meter: number,
	lastPress: number,
	started: number,
	maimed: number,
	over: boolean,
	free: (self: Handle, by: Player?) -> (),
	stop: (self: Handle) -> (),
}

local active: { [Player]: Handle } = {}
local remote: RemoteEvent? = nil

local function fire(player: Player, kind: string, data: any?)
	if remote and player.Parent then
		remote:FireClient(player, kind, data)
	end
end

local function bodyOf(entity: Model): Instance
	return entity:FindFirstChild("EntityLook") or entity
end

local function sound(opts: Opts, name: string, at: Vector3)
	local r = opts.remotes:FindFirstChild("Sound") :: RemoteEvent?
	if r then
		r:FireAllClients(name, at)
	end
end

local function finish(h: Handle, result: string, by: Player?)
	if h.over then
		return
	end
	h.over = true
	local o = h.opts
	active[o.victim] = nil
	local entityRoot = o.entity:FindFirstChild("HumanoidRootPart") :: BasePart?
	bodyOf(o.entity):SetAttribute("Biting", nil)
	if entityRoot then
		if result == "self" then
			-- Shoved off: it staggers back (not on a rescue: the rescuer may be standing right behind it).
			entityRoot.CFrame = entityRoot.CFrame * CFrame.new(0, 0, 4)
		end
		entityRoot.Anchored = false
	end
	local victimRoot = Characters.root(o.victim)
	if victimRoot and result ~= "eaten" then
		victimRoot.Anchored = false
	end
	o.victim:SetAttribute("Grabbed", nil)
	fire(o.victim, "end", result)
	if result == "self" then
		o.onFree(nil)
	elseif result == "rescued" then
		o.onFree(by)
	elseif result == "eaten" then
		o.onEaten()
	end
end

function Grab.start(opts: Opts): Handle?
	local victimRoot = Characters.root(opts.victim)
	local entityRoot = opts.entity:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not victimRoot or not entityRoot or active[opts.victim] then
		return nil
	end
	-- Face to face: the entity right in front of the victim, both held still.
	local flat = Vector3.new(entityRoot.Position.X - victimRoot.Position.X, 0, entityRoot.Position.Z - victimRoot.Position.Z)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else victimRoot.CFrame.LookVector
	victimRoot.Anchored = true
	victimRoot.CFrame = CFrame.lookAt(victimRoot.Position, victimRoot.Position + dir)
	local at = victimRoot.Position + dir * 3.6
	entityRoot.Anchored = true
	entityRoot.CFrame = CFrame.lookAt(Vector3.new(at.X, entityRoot.Position.Y, at.Z),
		Vector3.new(victimRoot.Position.X, entityRoot.Position.Y, victimRoot.Position.Z))
	bodyOf(opts.entity):SetAttribute("Biting", true)
	opts.victim:SetAttribute("Grabbed", true)

	local h: Handle = {
		opts = opts,
		meter = 0,
		lastPress = 0,
		started = os.clock(),
		maimed = 0,
		over = false,
		free = function(self: Handle, by: Player?)
			finish(self, "rescued", by)
		end,
		stop = function(self: Handle)
			finish(self, "stopped", nil)
		end,
	}
	active[opts.victim] = h
	fire(opts.victim, "start", { entity = opts.entity, hold = opts.hold, endsAt = workspace:GetServerTimeNow() + opts.hold })
	sound(opts, "scream", victimRoot.Position)
	sound(opts, "sting", victimRoot.Position)

	task.spawn(function()
		local nextBite = os.clock() + 0.8
		local lastSent = -1
		while not h.over do
			local dt = RunService.Heartbeat:Wait()
			local elapsed = os.clock() - h.started
			h.meter = math.max(0, h.meter - Grab.DECAY * dt)
			if math.abs(h.meter - lastSent) > 0.02 then
				lastSent = h.meter
				fire(opts.victim, "meter", h.meter)
			end
			if os.clock() >= nextBite then
				nextBite = os.clock() + Grab.BITE_EVERY
				fire(opts.victim, "bite")
				sound(opts, "bump", victimRoot.Position)
			end
			if h.maimed == 0 and elapsed >= opts.hold / 3 then
				h.maimed = 1
				fire(opts.victim, "maim", "LostArm")
				opts.onMaim("LostArm")
			elseif h.maimed == 1 and elapsed >= opts.hold * 2 / 3 then
				h.maimed = 2
				fire(opts.victim, "maim", "LostEye")
				opts.onMaim("LostEye")
			end
			if elapsed >= opts.hold then
				sound(opts, "scream", victimRoot.Position)
				finish(h, "eaten", nil)
			elseif not opts.victim.Parent or not opts.entity.Parent then
				finish(h, "stopped", nil)
			end
		end
	end)
	return h
end

function Grab.isHeld(player: Player): boolean
	return active[player] ~= nil
end

function Grab.init(remotes: Folder)
	remote = remotes:WaitForChild("Grab") :: RemoteEvent
	local struggle = remotes:WaitForChild("Struggle") :: RemoteEvent
	struggle.OnServerEvent:Connect(function(player)
		local h = active[player]
		if not h or h.over then
			return
		end
		local now = os.clock()
		if now - h.lastPress < Grab.MIN_GAP then
			return
		end
		h.lastPress = now
		h.meter += Grab.STEP
		if h.meter >= 1 then
			finish(h, "self", nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local h = active[player]
		if h then
			finish(h, "stopped", nil)
		end
	end)
end

return Grab
