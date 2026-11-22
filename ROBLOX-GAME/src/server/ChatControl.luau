-- Text chat during Social Deduction rounds: the general channel only delivers in the lobby and in meetings (and
-- then only from living players), bubbles are off, and players who are out get their own "Out" channel that the
-- living cannot see. Voice chat is an experience setting (README, Publish). Hide and Seek leaves chat alone.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local ChatControl = {}

local roundActive = false
local meetingOpen = false
local outChannel: TextChannel? = nil

-- Bubbles are off during a round and back to the place's own setting after it.
local bubblesBefore: boolean? = nil
local function setBubbles(on: boolean)
	local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	if not bubbles then
		return
	end
	if not on then
		if bubblesBefore == nil then
			bubblesBefore = bubbles.Enabled
		end
		bubbles.Enabled = false
	elseif bubblesBefore ~= nil then
		bubbles.Enabled = bubblesBefore
		bubblesBefore = nil
	end
end

function ChatControl.init()
	-- Whispers would get around the night rules (and from players who are out to the living): off for the game.
	task.spawn(function()
		local commands = TextChatService:WaitForChild("TextChatCommands", 30)
		local whisper = commands and commands:WaitForChild("RBXWhisperCommand", 30)
		if whisper and whisper:IsA("TextChatCommand") then
			whisper.Enabled = false
		end
	end)
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", 30)
		local channel = channels and channels:WaitForChild("RBXGeneral", 30) :: TextChannel?
		if not channel then
			warn("[chat] RBXGeneral not found; Social Deduction chat rules are off")
			return
		end
		channel.ShouldDeliverCallback = function(message: TextChatMessage, _target: TextSource): boolean
			if not roundActive then
				return true
			end
			if not meetingOpen then
				return false
			end
			local source = message.TextSource
			local sender = source and Players:GetPlayerByUserId(source.UserId)
			return sender ~= nil and sender:GetAttribute("State") == "alive"
		end
	end)
end

function ChatControl.setRound(active: boolean)
	roundActive = active
	meetingOpen = false
	setBubbles(not active)
	if active and not outChannel then
		local channel = Instance.new("TextChannel")
		channel.Name = "Out"
		channel.Parent = TextChatService:FindFirstChild("TextChannels") or TextChatService
		outChannel = channel
	elseif not active and outChannel then
		outChannel:Destroy()
		outChannel = nil
	end
end

function ChatControl.setMeeting(open: boolean)
	meetingOpen = open
end

function ChatControl.setOut(player: Player, out: boolean)
	if out and outChannel then
		local ok, err = pcall(function()
			(outChannel :: TextChannel):AddUserAsync(player.UserId)
		end)
		if not ok then
			warn("[chat] " .. tostring(err))
		end
	end
end

return ChatControl
