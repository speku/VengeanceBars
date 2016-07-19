-- Vengeance Demon Hunter WeakAura for displaying your accumulated health
-- includes: Soul Shards, Soul Cleave, Soul Carver, Feast of Souls, Devour Souls
-- and Soul Barrier

----------------------- configure stuff here ----------------------------------

-- health
local crit_enabled = true -- whether crit is included in the heal prediction
local feast_of_souls_hot = true -- should the Feast of Souls Hot be shown?
local feast_of_souls_prediction = true -- predict the healing of Feast of Souls
local soul_carver_prediction = true -- predict the resulting healing of Soul Cleaver
local soul_cleave_prediction = true -- predict soul cleave heals

-- power
local immolation_aura_prediction = true -- predict pain gains from Immolation Aura
local immolation_aura_gain = true -- forecast pain gains from Immolation Aura
local metamorphosis_gain = true -- forecast pain gains from Metamorphosis
local consume_magic_prediction = false -- predict pain gains from successfull Consume Magic interrupts
local blade_turning_gain = true -- forecasts pain gains from Blade Turning
-------------------------------------------------------------------------------


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
-- spells
local spellAvailability = {
  ["Soul Carver"] = {true, UpdateHealthPrediction}
  ["Immolation Aura"] = {true, UpdatePowerPrediction)
}

-- bar values
local health, healthMax = 0, 0
local power, powerMax = 0, 0
local absorbs = 0
local soulCleavePrediction = 0
local feastOfSoulsPrediction, feastOfSoulsHot = 0, 0
local soulCarverPrediciton = 0
local painGainMetamorphosis = 0
local painGainImmolationAura = 0
local immolationAuraPrediction = 0
local consumeMagicPrediction = 0
--------------------------------------------------------------------------------


------------------------ needfull things ---------------------------------------

-- "localizing" globals for faster access
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local GetSpellCooldown, GetSpellDescription = GetSpellCooldown, GetSpellDescription
local UnitAttackPower, GetCritChance = UnitAttackPower, GetCritChance
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs

-- shortcuts
local p = "player"
-------------------------------------------------------------------------------

local handlers = {
  ["SPELL_UPDATE_USABLE"] = UpdateSpellAvailability,
  ["COMBAT_LOG_EVENT_UNFILTERED"] = UpdateSpellAvailability,
  ["PLAYER_TALENT_UPDATE"] = UpdateTalents,
  ["SPELLS_CHANGED"] = UpdateArtifactTraits,
  ["PLAYER_ENTERING_WORLD"] = UpdateArtifactTraits,
  ["UNIT_AURA"] = function() UpdateSoulCleaveAndSoulCarverPrediction(); UpdatePowerGain();
  ["UNIT_ABSORB_AMOUNT_CHANGED"] = UpdateAbsorbs,
  ["UNIT_HEALTH_FREQUENT"] = function() UpdateHealth(); UpdateFeastOfSoulsHotAndPrediction() end
  ["UNIT_POWER_FREQUENT"] = function() UpdatePower(); UpdateSoulCleaveAndSoulCarverPrediction(); UpdateFeastOfSoulsHotAndPrediction() end
}

----------------------- functions for calculating things ----------------------

local function GetAP()
  local b,p,n = UnitAttackPower(p)
  return b + p + n
end

local function GetCrit()
  return crit_enabled and (GetCritChance() / 100) + 1 or 1
end

-- invokes the proper event handlers for the given event
function aura_env.EventHandlerDispatchern(e,...)
  handlers[e](e,...)
end

local function UpdatePowerGain(spell)

end

local function UpdatePowerPrediction(spell, available)

end

local function UpdateHealthGain(spell)

end

local function UpdateHealthPrediction(spell, available)

end

local function UpdateArtifactTraits()

end

local function UpdateTalents()

end

local function UpdateAbsorbs()
  absorbs = UnitGetTotalAbsorbs(p)
end

local function UpdatePower()
  power = UnitPower(p)
  powerMax = UnitPowerMax(p)
end

local function UpdateHealth()
  health = UnitHealth(p)
  healthMax = UnitHealthMax(p)
end


local function DispatchOnSpellAvailability(spell,e,...)
  if e == "SPELL_UPDATE_USABLE" then
    local s = GetSpellCooldown(spell)
    if s and s == 0 and not spellAvailability[spell] then
      spellAvailability[spell][1] = true
      spellAvailability[spell][2](spell, true)
    end
  elseif e == "COMBAT_LOG_EVENT_UNFILTERED"
    if select(2,...) == "SPELL_CAST_SUCCESS" and select(4,...) == UnitGUID(p) and select(13,...) == spell then
      spellAvailability[spell][1] = false
      spellAvailability[spell][2](spell, false)
    end
  end
end

-- returns true if passed COMBAT_LOG_EVENT_UNFILTERED or SPELL_UPDATE_USABLE info
-- was related to Soul Carver. Returns false if such info woul be related to
-- Soul Carver, but Soul Carver prediction was disabled in config.
local function HandleSoulCarverStatus(e,...)
  -- check if Soul Carver related
  if e == "SPELL_UPDATE_USABLE" then
    local s = GetSpellCooldown("Soul Carver")
    if s and s == 0 and not soulCarverReady then
      soulCarverReady = true
      return true
    else
      return false
    end
  elseif e == "COMBAT_LOG_EVENT_UNFILTERED"
    if select(2,...) == "SPELL_CAST_SUCCESS" and select(4,...) == UnitGUID("player") and select(13,...) == "Soul Carver" then
      soulCarverReady = false
      return true
    else
      return false
    end
  end
  -- if not Soul Sarver related, must have been triggered by HEALTH_UPDATE_FREQUENT, so return true
  return true
end

-- Feast of Souls Hot and prediction
local function UpdateFeastOfSoulsHotAndPrediction(power)

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
local function UpdateSoulCleaveAndSoulCarverPrediction()
  local power = UnitPower("player")

  -- early return
  if not power < soul_cleave_min_cost or not (soul_carver_prediction and soul_carver_unlocked and soulCarverReady) then return 0,0 end

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
  local soulCarverHeal = soul_carver_unlocked and soul_carver_prediction and soulCarverReady and soul_carver_soul_fragment_count * soulFragmentHeal * crit or 0

  return soulCleaveHeal, soulCarverHeal
end


-------------------------------------------------------------------------------

-- event based trigger function:
-- UNIT_HEALTH_FREQUENT, UNIT_AURA, SPELL_UPDATE_USABLE, COMBAT_LOG_EVENT_UNFILTERED, UNIT_ABSORB_AMOUNT_CHANGED
function(e,id)
  local p = "player"
  if id == p then

    local health, healthMax = UnitHealth(p), UnitHealthMax(p)
    local power = UnitPower(p)



    -- Feast of Souls

end
