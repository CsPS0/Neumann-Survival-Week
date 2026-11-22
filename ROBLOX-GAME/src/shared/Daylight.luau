--!strict
-- How much daylight there is at a time of day (Lighting.ClockTime, hours): 0 at night, 1 from 07:00 to 17:00, rising
-- at dawn (05:00-07:00) and falling at dusk (17:00-19:30). The server's lighting and the client's sounds both use it.

local Daylight = {}

function Daylight.at(clock: number): number
	if clock >= 7 and clock <= 17 then
		return 1
	elseif clock > 5 and clock < 7 then
		return (clock - 5) / 2
	elseif clock > 17 and clock < 19.5 then
		return 1 - (clock - 17) / 2.5
	end
	return 0
end

return Daylight
