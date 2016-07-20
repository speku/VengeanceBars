-- Vengeance Demon Hunter WeakAura for displaying your accumulated health
-- includes: Soul Shards, Soul Cleave, Soul Carver, Feast of Souls, Devour Souls
-- and Soul Barrier

-- and your accumulated pain
-- includes: Immolation Aura, Metamorphosis, Consume Magic

----------------------- configure stuff here ----------------------------------

local features = {
  -- health prediction
  ["hp"] = {
    ["Feast of Souls"] = true, -- predict the healing of Feast of Souls
    ["Soul Carver"] = true, -- predict the resulting healing of Soul Cleaver
    ["Soul Cleave"] = true -- predict soul cleave heals
  },

  -- health gain
  ["hg"] = {
    ["Feast of Souls"] = true -- should the Feast of Souls Hot be shown?
  },

  -- power prediction
  ["pp"] = {
    ["Immolation Aura"] = true, -- predict pain gains from Immolation Aura
    ["Consume Magic"] = false -- predict pain gains from successfull Consume Magic interrupts
  },

  -- power gain
  ["pg"] = {
    ["Immolation Aura"] = true, -- forecast pain gains from Immolation Aura
    ["Metamorphosis"] = true, -- forecast pain gains from Metamorphosis
    ["Blade Turning"] = true -- forecasts pain gains from Blade Turning

  },
  -- general features
  ["crit"] = true, -- whether crit is included in the heal prediction
  ["ignore cost"] = false -- whether predictions should only be made for spells that are castable (due to their resources cost)
}
-------------------------------------------------------------------------------


------------------------probably no change required here-----------------------
local soul_cleave_formula = function(ap) return ap * 5 end -- formula for calculating the minimal heal of Soul Cleave
local soul_cleave_min_cost = 30 -- the minimal cost of Soul Cleave
local soul_cleave_max_cost = 60 -- the maximal cost of Soul Cleave
local soul_carver_soul_fragment_count = 5 -- how many Soul Fragments are spawned by Soul Carver
local immolation_aura_pain_gain = 20 -- how much pain is gained over the duration of Immolation Aura
local feast_of_souls_location = {row = 2, column = 1} -- where Feast of Souls is located in the talent tab
local metamorphosis_pain_gain = 15 * 7 -- how much pain is generated over the duration of Metamorphosis
local fueled_by_pain_gain = 5 * 7 -- how much pain is generated over the duration of Fueled by Pain procs
local blade_turning_gain = 10 * 0.5 -- how much extra pain is generated by Blade Turning
-------------------------------------------------------------------------------


---------------------- fetching info once -------------------------------------
local devour_souls_scalar = 1
local soul_carver_unlocked = false
local feast_of_souls_talented = false
-------------------------------------------------------------------------------


----------------------- WeakAuras globals -------------------------------------
WeakAuras.VB = {}

WeakAuras.VB.SoulCleavePrediction = 0
WeakAuras.VB.SoulCarverPrediction = 0
WeakAuras.VB.FeastOfSoulsPrediction = 0
WeakAuras.VB.FeastOfSoulsGain = 0

WeakAuras.VB.ImmolationAuraPrediction = 0
WeakAuras.VB.ImmolationAuraGain = 0
WeakAuras.VB.MetamorphosisGain = 0
WeakAuras.VB.BladeTurningGain = 0

WeakAuras.VB.Absorbs = 0
-------------------------------------------------------------------------------



----------------------- persisting stuff --------------------------------------
-- spells
-- first slot: availability
-- second slot: continuation upon availability change
local spellAvailability = {
  ["Soul Carver"] = {true, SoulCarverPrediction}
  ["Immolation Aura"] = {true, ImmolationAuraPrediction)
}

-- bar values
local values = {
  ["hp"] = {},
  ["hg"] = {},
  ["pp"] = {},
  ["pg"] = {}
}

local health, healthMax = 0, 0
local power, powerMax = 0, 0
local absorbs = 0
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
  ["SPELL_UPDATE_USABLE"] = DispatchOnSpellAvailability,
  ["COMBAT_LOG_EVENT_UNFILTERED"] = DispatchOnSpellAvailability,
  ["PLAYER_TALENT_UPDATE"] = UpdateTalents,
  ["SPELLS_CHANGED"] = UpdateArtifactTraits,
  ["PLAYER_ENTERING_WORLD"] = UpdateArtifactTraits,
  ["UNIT_AURA"] = function(_,id) if id == "player" then SoulCleavePrediction() ImmolationAuraGain() MetamorphosisGain() BladeTurningGain() end end,
  ["UNIT_ABSORB_AMOUNT_CHANGED"] = UpdateAbsorbs,
  ["UNIT_HEALTH_FREQUENT"] = UpdateHealth
  ["UNIT_POWER_FREQUENT"] = function() UpdatePower() SoulCleavePrediction() FeastOfSoulsPrediction() end
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
function aura_env.EventHandlerDispatcher(e,...)
  handlers[e](e,...)
end

local function UpdateArtifactTraits()
  -- code by Rainrider from Wowinterface forums
  local u,e,a=UIParent,"ARTIFACT_UPDATE",C_ArtifactUI
   u:UnregisterEvent(e)
   SocketInventoryItem(16)
   local _,_,rank,_,bonusRank = a.GetPowerInfo(select(7,GetSpellInfo("Devour Souls")))
   devour_souls_scalar = 1 + (rank + bonusRank) * 0.03
   soul_carver_unlocked = select(3,a.GetPowerInfo(select(7,GetSpellInfo("Soul Carver")))) > 0
   a.Clear()
   u:RegisterEvent(e)
end

local function UpdateTalents()
  feast_of_souls_talented = select(2, GetTalentTierInfo(feast_of_souls_location.row, feast_of_souls_location.column )) == 1
end


local function UpdateAbsorbs()
  absorbs = UnitGetTotalAbsorbs(p)

  WeakAuras.VB.Absorbs = health + values["hg"]["Feast of Souls"] + values["hp"]["Soul Cleave"] + values["hp"]["Feast of Souls"] + values["hp"]["Soul Carver"] + absorbs
end


local function UpdatePower()
  power = UnitPower(p)
  powerMax = UnitPowerMax(p)
end


local function UpdateHealth()
  health = UnitHealth(p)
  healthMax = UnitHealthMax(p)
end


local function DispatchOnSpellAvailability(e,...)
  for _,spell in pairs{"Immolation Aura", "Soul Carver"} do
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
end


local function FeastOfSoulsPrediction()
  values["hp"]["Feast of Souls"] = (not features["hp"]["Feast of Souls"] or
    not feast_of_souls_talented or
    (not features["ignore cost"] and power < soul_cleave_min_cost)) and 0 or
    GetHeal("Feast of Souls")

    WeakAuras.VB.FeastOfSoulsPrediction = health + values["hg"]["Feast of Souls"] + values["hp"]["Soul Cleave"] + values["hp"]["Feast of Souls"]
end


local function SoulCleavePrediction()
  if not features["hp"]["Soul Cleaver"] or (not features["ignore cost"] and power < soul_cleave_min_cost) then
    values["hp"]["Soul Cleave"] = 0
  else
    local soulFragmentHeal = GetHeal("Shear") * GetSpellCount("Soul Cleave")
    local power = power > soul_cleave_max_cost and soul_cleave_max_cost or power
    local soulCleaveMinHeal = soul_cleave_formula(GetAP())
    values["hp"]["Soul Cleave"] = (soulCleaveMinHeal * (power / soul_cleave_max_cost) * 2 * devour_souls_scalar + soulFragmentHeal) * GetCrit()
  end

    WeakAuras.VB.SoulCleavePrediction = health + values["hg"]["Feast of Souls"] + values["hp"]["Soul Cleave"]
end


local function SoulCarverPrediction()
  values["hp"]["Soul Carver"] = (not features["hp"]["Soul Carver"] or not soul_carver_unlocked or not spellAvailability["Soul Carver"][1]) and 0 or
  soul_carver_soul_fragment_count * GetHeal("Shear") * GetCrit()

  WeakAuras.VB.SoulCarverPrediction = health + values["hg"]["Feast of Souls"] + values["hp"]["Soul Cleave"] + values["hp"]["Feast of Souls"] + values["hp"]["Soul Carver"]
end



local function ImmolationAuraPrediction()
  values["pp"]["Immolation Aura"] = (not features["pp"]["Immolation Aura"] or not spellAvailability["Immolation Aura"][1]) and 0 or immolation_aura_pain_gain

  WeakAuras.VB.ImmolationAuraPrediction = power + values["pg"]["Immolation Aura"] + values["pg"]["Metamorphosis"] + values["pp"]["Immolation Aura"]
end


local function UpdateGain(type, spell, total, talanted)
  if features[type][spell] and (talented == nil or talented) and total ~= 0 then
    local buffed,_,_,_,_,duration,expirationTime = UnitBuff(p, spell)
    values[type][spell] = buffed and (expirationTime - GetTime()) / duration * total or 0
  else
    values[type][spell] = 0
  end
end


local function ImmolationAuraGain()
  UpdateGain("pg", "Immolation Aura", immolation_aura_pain_gain)

  WeakAuras.VB.ImmolationAuraGain = power + values["pg"]["Immolation Aura"]
end


local function MetamorphosisGain()
  UpdateGain("pg", "Metamorphosis", GetSpellCooldown("Metamorphosis") == 0 and metamorphosis_pain_gain or fueled_by_pain_gain)

  WeakAuras.VB.MetamorphosisGain = power + values["pg"]["Immolation Aura"] + values["pg"]["Metamorphosis"]
end


local function FeastOfSoulsGain()
    UpdateGain("hg", "Feast of Souls", GetHeal("Feast of Souls"), feast_of_souls_talented)

      WeakAuras.VB.FeastOfSoulsGain = health + values["hg"]["Feast of Souls"]
end


local function BladeTurningGain()
  UpdateGain("pg", "Blade Turning", blade_turning_gain)

  WeakAuras.VB.BladeTurningGain = power + values["pg"]["Blade Turning"]
end


local function GetHeal(spell,regex)
  local h1,h2 = GetSpellDescription(select(7,GetSpellInfo(spell))):match(regex or "(%d+),(%d+)")
  return tonumber(h1..h2)
end

-- UNIT_HEALTH_FREQUENT, UNIT_AURA, SPELL_UPDATE_USABLE, COMBAT_LOG_EVENT_UNFILTERED, UNIT_ABSORB_AMOUNT_CHANGED
