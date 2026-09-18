--[[
	ArmoryConfig.lua

	Every item the Armory sells for RouteWars, plus what each one does.
	Bought items go into a player's persistent warInventory (PlayerDataService)
	as plain counts; WeaponService spends one on use. Prices are cash, the
	same currency as everything else.

	Fields common to every item:
	  id, name, description, price, cooldown (seconds between uses of THIS
	  item, per player)

	Kind-specific fields are read only by the matching branch in
	WeaponService.lua:
	  hazard   (spikeTrap, mine)   dropped on the road, triggers on contact
	  self     (goatHorn)          instant effect on your own bus
	  zone     (waterBucket)       an area effect that lasts a while
	  ranged   (waterGun)          fired forward at whoever is ahead of you
]]

local ArmoryConfig = {}

ArmoryConfig.Items = {
	{
		id = "spikeTrap",
		name = "Spike Trap",
		description = "Drops behind your bus. Pops anyone who rolls over it: damage plus a slow.",
		price = 150,
		cooldown = 1.5,
		kind = "hazard",
		damage = 18,
		slowMultiplier = 0.55, -- top speed while slowed
		slowSeconds = 3,
		lifetime = 25, -- despawns after this long even if never triggered
		triggerRadius = 7,
		perVictimCooldown = 2, -- so sitting on it doesn't hit the same bus every tick
		maxActive = 3, -- per player, oldest is removed first past this
	},
	{
		id = "mine",
		name = "Trap Mine",
		description = "A hidden charge. Explodes under the next bus that finds it, wrenching the wheel.",
		price = 220,
		cooldown = 2,
		kind = "hazard",
		damage = 26,
		veerSpeed = 46, -- studs/s sideways kick applied on top of their velocity
		veerSeconds = 1.3, -- how long steering stays biased afterwards
		lifetime = 30,
		triggerRadius = 7,
		singleUse = true, -- gone after the first bus it hits
		maxActive = 2,
	},
	{
		id = "goatHorn",
		name = "Goat Horn",
		description = "One honk, one kick of nitrous. Short burst of speed for you.",
		price = 120,
		cooldown = 8,
		kind = "self",
		speedMultiplier = 1.45,
		accelMultiplier = 1.6,
		duration = 3,
	},
	{
		id = "waterBucket",
		name = "Water Bucket",
		description = "Sloshes water across the road. Anyone who drives through loses their grip.",
		price = 140,
		cooldown = 3,
		kind = "zone",
		radius = 18,
		gripMultiplier = 0.4,
		duration = 7, -- how long the puddle stays wet
		lifetime = 22, -- despawns after this long
		maxActive = 2,
	},
	{
		id = "waterGun",
		name = "Water Gun",
		description = "Soaks the windshield of whoever's ahead of you. They'll have to wipe it off.",
		price = 180,
		cooldown = 4,
		kind = "ranged",
		range = 100,
		coneDegrees = 20,
		splashSeconds = 5,
	},
}

function ArmoryConfig.Get(itemId)
	for _, item in ipairs(ArmoryConfig.Items) do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

-- A fresh warInventory table: every item id at 0.
function ArmoryConfig.EmptyInventory()
	local inventory = {}
	for _, item in ipairs(ArmoryConfig.Items) do
		inventory[item.id] = 0
	end
	return inventory
end

return ArmoryConfig
