-- Team votes in the story (who is the entity, cure or destroy, the deal): buttons or keys 1-9 for living players,
-- with the time left. Everyone sees the question; only the living vote.
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local State = require(script.Parent.State)
local StoryUi = require(script.Parent.StoryUi)

local VoteUi = {}

local KEYS = {
	Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
}

function VoteUi.init(remotes: Folder)
	local castRemote = remotes:WaitForChild("TeamVoteCast") :: RemoteEvent
	local gui = StoryUi.gui("TeamVote", 7)
	local panel = StoryUi.panel(gui, 560, 0.7)
	StoryUi.freeMouseWhile(gui, panel)

	local vote = nil :: any
	local voted = false
	local status: TextLabel? = nil
	local timer: TextLabel? = nil

	local function unbindKeys()
		for i = 1, #KEYS do
			ContextActionService:UnbindAction("TeamVote" .. i)
		end
	end

	local function cast(i: number)
		if not vote or voted or not State.alive() then
			return
		end
		voted = true
		castRemote:FireServer(vote.id, i)
		unbindKeys()
		if status then
			status.Text = `You voted: {vote.options[i]}. Waiting for the others...`
		end
		-- Give the mouse back so you can move and look while the others decide.
		local myVote = vote
		task.delay(1.5, function()
			if vote == myVote then
				panel.Visible = false
			end
		end)
	end

	(remotes:WaitForChild("TeamVote") :: RemoteEvent).OnClientEvent:Connect(function(info)
		unbindKeys()
		StoryUi.clear(panel)
		vote = info
		voted = false
		if not info then
			panel.Visible = false
			return
		end
		StoryUi.text(panel, info.title, 20, 1, StoryUi.GOLD)
		timer = StoryUi.text(panel, "", 15, 2, StoryUi.MUTED)
		for i, option in info.options do
			local b = StoryUi.button(panel, if KEYS[i] then `{i}. {option}` else option, 2 + i)
			b.Activated:Connect(function()
				cast(i)
			end)
			if KEYS[i] then
				ContextActionService:BindAction("TeamVote" .. i, function(_, state)
					if state == Enum.UserInputState.Begin then
						cast(i)
					end
					return Enum.ContextActionResult.Pass
				end, false, KEYS[i])
			end
		end
		status = StoryUi.text(panel, if State.alive() then "More than half of the living players decides."
			else "You are out: you watch the vote.", 15, 50, StoryUi.MUTED)
		panel.Visible = true
	end)

	RunService.Heartbeat:Connect(function()
		if vote and timer then
			local left = math.max(0, vote.endsAt - workspace:GetServerTimeNow())
			timer.Text = `{math.ceil(left)} s left`
		end
	end)
end

return VoteUi
