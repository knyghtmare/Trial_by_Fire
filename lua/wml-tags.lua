-- to make code shorter
local wml_actions = wesnoth.wml_actions

-- metatable for GUI tags
local T = wml.tag

-- support for translatable strings, custom textdomain
local _ = wesnoth.textdomain "wesnoth-Trial_by_Fire"
-- #textdomain wesnoth-Trial_by_Fire

-- [loot]: replacement for mainline LOOT macro
-- supported parameters:
-- StandardSideFilter
-- amount, raises error if not number
function wml_actions.loot( cfg )
	local gold_amount = tonumber( cfg.amount ) or wml.error( "Missing or wrong amount= value in [loot]" )
	local sides = wesnoth.sides.find( cfg )
	for index, side in ipairs( sides ) do
		wml_actions.message {
			side_for = side.side,
			speaker = "narrator",
			message = string.format( tostring( _"You retrieve %d pieces of gold." ), gold_amount ),
			image = "wesnoth-icon.png",
			sound = "gold.ogg"
		}
		side.gold = side.gold + gold_amount
	end
end