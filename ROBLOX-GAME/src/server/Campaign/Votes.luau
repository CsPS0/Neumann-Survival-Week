-- Team votes (the accusation, cure or destroy, the deal). Living players vote with TeamVoteCast; a majority of the
-- living ends it early, otherwise the deadline picks the most-voted option (ties at random). `onResult(nil)` when
-- nobody voted. One vote at a time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampaignRules = require(ReplicatedStorage.Shared.CampaignRules)

local Votes = {}

local current = nil :: { id: number, options: { string }, votes: { [Player]: number }, voters: () -> { Player },
	onResult: (number?) -> (), done: boolean, strict: boolean }?
local nextId = 0
local remotes: Folder? = nil
local connection: RBXScriptConnection? = nil

local function close(result: number?)
	local vote = current
	if not vote or vote.done then
		return
	end
	vote.done = true
	current = nil
	if remotes then
		(remotes:FindFirstChild("TeamVote") :: RemoteEvent):FireAllClients(nil)
	end
	vote.onResult(result)
end

local function check()
	local vote = current
	if not vote then
		return
	end
	local living = vote.voters()
	local votes = {}
	for _, p in living do
		if vote.votes[p] then
			votes[p] = vote.votes[p]
		end
	end
	local pick = CampaignRules.voteOutcome(votes, #living)
	if pick then
		close(pick)
	end
end

function Votes.init(remoteFolder: Folder)
	remotes = remoteFolder
	if connection then
		connection:Disconnect()
	end
	connection = (remoteFolder:FindFirstChild("TeamVoteCast") :: RemoteEvent).OnServerEvent:Connect(function(player, id, option)
		local vote = current
		if not vote or vote.id ~= id or type(option) ~= "number" or option < 1 or option > #vote.options
			or option % 1 ~= 0 or vote.votes[player] then
			return
		end
		if not table.find(vote.voters(), player) then
			return
		end
		vote.votes[player] = option
		check()
	end)
end

-- Opens a vote for everyone (only `voters()` may vote). `seconds` is real time. `strict`: the deadline needs more
-- than half of the living too (else nil), so one player cannot decide alone for a team that did not vote.
function Votes.ask(title: string, options: { string }, seconds: number, voters: () -> { Player },
	onResult: (number?) -> (), strict: boolean?)
	close(nil)
	nextId += 1
	local vote = { id = nextId, options = options, votes = {}, voters = voters, onResult = onResult, done = false,
		strict = strict == true }
	current = vote
	if remotes then
		(remotes:FindFirstChild("TeamVote") :: RemoteEvent):FireAllClients({ id = vote.id, title = title,
			options = options, endsAt = workspace:GetServerTimeNow() + seconds })
	end
	task.delay(seconds, function()
		if current == vote and not vote.done then
			local living = vote.voters()
			local votes = {}
			for p, o in vote.votes do
				if table.find(living, p) then -- votes of players who went out meanwhile do not count
					votes[p] = o
				end
			end
			if vote.strict then
				close(CampaignRules.voteOutcome(votes, #living))
			else
				close(CampaignRules.voteAtDeadline(votes, math.random))
			end
		end
	end)
end

-- A voter left or went out: maybe the rest already decided.
function Votes.recheck()
	check()
end

function Votes.cancel()
	local vote = current
	if vote then
		vote.done = true
		current = nil
		if remotes then
			(remotes:FindFirstChild("TeamVote") :: RemoteEvent):FireAllClients(nil)
		end
	end
end

function Votes.isOpen(): boolean
	return current ~= nil
end

return Votes
