--[[
	Trial by Fire - co-op performance score

	HOW THE SCORE IS CALCULATED
	For each player side (PLAYER_SIDES):

		Performance = floor(Alive + Kills - Lost)

	Alive : total cost of the player's non-leader units still alive when the
	        score is shown (units on the map plus units in the recall list).
	        Computed at that moment.
	Kills : total cost of enemy non-leader units killed by this player's units,
	        across the whole campaign. Accumulated by the die event in the
	        WML variable score_kills_<side>.
	Lost  : total cost of this player's own non-leader units that died,
	        across the whole campaign. Accumulated by the die event in the
	        WML variable score_lost_<side>.

	Rules:
	- "cost" is the unit type's recruit cost (an advanced unit counts at its
	  new type's cost).
	- Kill credit goes to the owner of the killer. Kills by allied AI units or
	  by scripted deaths (no killer) give no credit.
	- Losses go to the owner of the dying unit, whoever killed it.
	- Leaders (canrecruit) are ignored everywhere.
	- The side with the higher total is the best player; equal totals are a tie.
	- Counters are WML variables, so they persist through saves and carry over
	  between scenarios.

	USAGE
	- [event] name=die  ->  track_death()                (scenarios 01-04)
	- Epilogue start    ->  show_performance_scores()
]]

local res = {}

local PLAYER_SIDES = { 1, 2 }

local function is_player_side(side)
	for _, s in ipairs(PLAYER_SIDES) do
		if s == side then return true end
	end
	return false
end

local function add_var(name, amount)
	wml.variables[name] = (wml.variables[name] or 0) + amount
end

---Sum the cost of non-leader units, on the map and in the recall list.
local function alive_cost(side)
	local total = 0
	local function add(units)
		for _, unit in ipairs(units) do
			if not unit.canrecruit then
				total = total + unit.cost
			end
		end
	end
	add(wesnoth.units.find_on_map { side = side })
	add(wesnoth.units.find_on_recall { side = side })
	return total
end

---Leader's name, falling back to "Player N".
local function player_name(side)
	local leader = wesnoth.units.find_on_map { side = side, canrecruit = true }[1]
		or wesnoth.units.find_on_recall { side = side, canrecruit = true }[1]
	return leader and tostring(leader.name) or ("Player " .. side)
end

---Call from [event] name=die via [lua] code="mymodule.track_death()"
function res.track_death()
	local ctx = wesnoth.current.event_context
	local dying = wesnoth.units.get(ctx.x1, ctx.y1)
	if not dying or dying.canrecruit then return end

	local cost = dying.cost

	-- Loss for the player who owned the unit.
	if is_player_side(dying.side) then
		add_var("score_lost_" .. dying.side, cost)
	end

	-- Kill credit for the player who killed an enemy unit.
	local killer = wesnoth.units.get(ctx.x2, ctx.y2)
	if killer and is_player_side(killer.side)
		and wesnoth.sides.is_enemy(killer.side, dying.side) then
		add_var("score_kills_" .. killer.side, cost)
	end
end

---@return table<integer, {alive:integer, kills:integer, lost:integer, total:integer}>
function res.calc_performance_scores()
	local scores = {}
	for _, side in ipairs(PLAYER_SIDES) do
		local alive = alive_cost(side)
		local kills = wml.variables["score_kills_" .. side] or 0
		local lost = wml.variables["score_lost_" .. side] or 0
		scores[side] = {
			alive = alive,
			kills = kills,
			lost = lost,
			total = math.floor(alive + kills - lost),
		}
	end
	return scores
end

function res.show_performance_scores()
	local scores = res.calc_performance_scores()
	local lines = {}
	local best_side, best_total, tie = nil, nil, false

	for _, side in ipairs(PLAYER_SIDES) do
		local s = scores[side]
		local color = wesnoth.colors[wesnoth.sides[side].color].pango_color
		table.insert(lines, string.format(
			"<span foreground='%s'>%s</span>: Alive %d + Kills %d - Lost %d\nPerformance: <b>%d</b>",
			color, player_name(side), s.alive, s.kills, s.lost, s.total))

		if best_total == nil or s.total > best_total then
			best_side, best_total, tie = side, s.total, false
		elseif s.total == best_total then
			tie = true
		end
	end

	local verdict
	if tie then
		verdict = "It's a tie. Both heroes were equally matched!"
	else
		local color = wesnoth.colors[wesnoth.sides[best_side].color].pango_color
		verdict = string.format(
			"<span foreground='%s'>%s</span> is the best player of this campaign run!",
			color, player_name(best_side))
	end

	-- Shown to players for transparency
	local explanation =
		"<small><b>How the score works</b>\n" ..
		"Performance = Alive + Kills - Lost\n" ..
		"Alive: value of your surviving units (leaders excluded)\n" ..
		"Kills: value of enemy units your units defeated\n" ..
		"Lost: value of your units that fell\n" ..
		"Unit value is its recruit cost.</small>"

	gui.show_popup("Campaign Performance",
		table.concat(lines, "\n\n") .. "\n\n" .. verdict .. "\n\n" .. explanation)
end

return res