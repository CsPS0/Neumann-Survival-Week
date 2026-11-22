-- Head and upper-body pitch: sends your camera's pitch 15 times a second (only when it changed), and eases the
-- other players' Neck and Waist joints towards the pitch they sent, so you see where they look.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local NECK_SHARE = 0.6 -- of the pitch on the neck, the rest on the waist
local EASE = 10

type Joints = { neck: Motor6D?, waist: Motor6D?, neckC0: CFrame, waistC0: CFrame, current: number, locked: boolean? }

local LookSync = {}

function LookSync.init(remotes: Folder)
	local look = remotes:WaitForChild("Look") :: UnreliableRemoteEvent
	local targets: { [Player]: number } = {}
	local joints: { [Model]: Joints } = {}

	look.OnClientEvent:Connect(function(other, pitch)
		if typeof(other) == "Instance" and other:IsA("Player") and type(pitch) == "number" then
			targets[other] = pitch
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		targets[other] = nil
	end)

	local function jointsOf(character: Model): Joints?
		local found = joints[character]
		if found then
			return found
		end
		local head = character:FindFirstChild("Head")
		local upper = character:FindFirstChild("UpperTorso")
		local neck = head and head:FindFirstChild("Neck") :: Motor6D?
		local waist = upper and upper:FindFirstChild("Waist") :: Motor6D?
		if not neck or not waist then
			return nil
		end
		local entry = { neck = neck, waist = waist, neckC0 = neck.C0, waistC0 = waist.C0, current = 0 }
		joints[character] = entry
		character.Destroying:Connect(function()
			joints[character] = nil
		end)
		return entry
	end

	-- Sending.
	local lastSent = 0
	local nextSend = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextSend then
			return
		end
		nextSend = now + 1 / Config.Camera.lookRate
		local pitch = math.asin(math.clamp(workspace.CurrentCamera.CFrame.LookVector.Y, -1, 1))
		if math.abs(pitch - lastSent) > 0.02 and player.Character then
			lastSent = pitch
			look:FireServer(pitch)
		end
	end)

	-- Receiving: ease every other character's joints towards its pitch.
	RunService.Heartbeat:Connect(function(dt)
		local alpha = 1 - math.exp(-EASE * dt)
		for other, target in targets do
			local character = other.Character
			local j = character and jointsOf(character)
			if j and j.neck and j.waist and not j.locked then
				j.current += (target - j.current) * alpha
				-- Roblox can lock another player's joints (C0 read only): then this character keeps its own pose.
				local ok = pcall(function()
					(j.neck :: Motor6D).C0 = j.neckC0 * CFrame.Angles(j.current * NECK_SHARE, 0, 0);
					(j.waist :: Motor6D).C0 = j.waistC0 * CFrame.Angles(j.current * (1 - NECK_SHARE), 0, 0)
				end)
				if not ok then
					j.locked = true
				end
			end
		end
	end)
end

return LookSync
