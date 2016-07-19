-- Vengeance Demon Hunter WeakAura for displaying your accumulated health
-- includes: Soul Shards, Soul Cleave, Soul Carver, Feast of Souls, Devour Souls
-- and Soul Barrier

----------------------- configure stuff here ----------------------------------
local crit_enabled = true -- whether crit is included in the heal prediction
local feast_of_souls_hot = true -- should the Feast of Souls Hot be shown?
local feast_of_souls_prediction = true -- predict the healing of Feast of Souls
local soul_carver_prediction = true -- predict the resulting healing of Soul Cleaver

------------------------probably no change required here-----------------------
local soul_cleave_formula = function(ap) return ap * 5 end -- formula for calculating the minimal heal of Soul Cleave
local soul_cleave_min_cost = 30 -- the minimal cost of Soul Cleave
local soul_cleave_max_cost = 60 -- the maximal cost of Soul Cleave
local feast_of_souls_id = 207697 -- spell ID of Feast of Souls
local shear_id = 203783 -- spell ID for Shear
local soul_carver_soul_fragment_count = 5 -- how many Soul Fragments are spawned by Soul Carver
-------------------------------------------------------------------------------


---------------------- fetching info once -------------------------------------
local devour_souls_scalar = 1
local soul_carver_unlocked = false
local feast_of_souls_talented = false
-------------------------------------------------------------------------------


----------------------- persisting stuff --------------------------------------
local SoulCarverReady = true

--------------------------------------------------------------------------------


----------------------- functions for calculating things ----------------------

local function GetAP()
  local b,p,n = UnitAttackPower(p)
  return b + p + n
end

local function GetCrit()
  return crit_enabled and (GetCritChance() / 100) + 1 or 1
end

-- invokes the proper event handlers for the given event
aura_env.EventHandlerDispatcher = function(e,...)

  -- early return if no updates have to be made
  if not HandleSoulCarverStatus(e,...) then return false

  -- check for talent changes
  if e == "PLAYER_TALENT_UPDATE" then

  elseif e == "SPELLS_CHANGED" or e == "PLAYER_ENTERING_WORLD" then

  else

  end

end

local function HandleTalentUpdate()
end

-- returns true if passed COMBAT_LOG_EVENT_UNFILTERED or SPELL_UPDATE_USABLE info
-- was related to Soul Carver. Returns false if such info woul be related to
-- Soul Carver, but Soul Carver prediction was disabled in config.
local function HandleSoulCarverStatus(e,...)
  -- check if Soul Carver related
  if e == "SPELL_UPDATE_USABLE" then
    local s = GetSpellCooldown("Soul Carver")
    if s and s == 0 and not SoulCarverReady then
      SoulCarverReady = true
      return true
    else
      return false
    end
  elseif e == "COMBAT_LOG_EVENT_UNFILTERED"
    if select(2,...) == "SPELL_CAST_SUCCESS" and select(4,...) == UnitGUID("player") and select(13,...) == "Soul Carver" then
      SoulCarverReady = false
      return true
    else
      return false
    end
  end
  -- if not Soul Sarver related, must have been triggered by HEALTH_UPDATE_FREQUENT, so return true
  return true
end

-- Feast of Souls Hot and prediction
local function GetFeastOfSoulsHotAndPrediction(power)

  local hot,pre = 0,0
  if not feast_of_souls_talented then return hot, pre end

      local buffed,_,_,_,_,duration,expirationTime = UnitBuff(p, "Feast of Souls")
      if buffed or power >= soul_cleave_min_cost then
        local h1,h2 = GetSpellDescription(feast_of_souls_id):match("(%d+),(%d+)")
        local heal = tonumber(h1 .. h2)
        hot = b and (expirationTime - GetTime()) / duration * heal or 0
        pre = power >= soul_cleave_min_cost and heal or 0
      end

  return hot, pre
end


-- Soul Cleave and Soul Carver prediction
local function GetSoulCleaveAndSoulCarverPrediction(power)

  -- early return
  if not power < soul_cleave_min_cost or not (soul_carver_prediction and soul_carver_unlocked and SoulCarverReady) then return 0,0 end

  local soulCleaveHeal = 0

  -- shared
  local h1,h2 = GetSpellDescription(shear_id):match("(%d+),(%d+)")
  local soulFragmentBaseHeal = tonumber(h1 .. h2)
  local soulFragmentHeal = GetSpellCount("Soul Cleave") * soulFragmentBaseHeal

  -- Soul Cleave
  if power >= soul_cleave_min_cost then
    power = power > soul_cleave_max_cost and soul_cleave_max_cost or power
    local minHeal = soul_cleave_formula(GetAP())
    soulCleaveHeal = (minHeal * (power / soul_cleave_max_cost) * 2 * devour_souls_scalar +
      soulFragmentHeal) * crit
  end

  -- Soul Carver
  local soulCarverHeal = soul_carver_unlocked and soul_carver_prediction and SoulCarverReady and soul_carver_soul_fragment_count * soulFragmentHeal * crit or 0

  return soulCleaveHeal, soulCarverHeal
end


-------------------------------------------------------------------------------

-- event based trigger function:
-- UNIT_HEALTH_FREQUENT, UNIT_AURA, SPELL_UPDATE_USABLE, COMBAT_LOG_EVENT_UNFILTERED
function(e,id)
  local p = "player"
  if id == p then

    local health, healthMax = UnitHealth(p), UnitHealthMax(p)
    local power = UnitPower(p)



    -- Feast of Souls

end
