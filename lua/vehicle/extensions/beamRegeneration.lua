-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local regenEnabled = false
local regenRate = 0.05
local repairErrorMargin = 0.0015
local regenTime = 0

local regenBeamStates = {}
local regenBeamCache = {}

local regenProgress = 0
local regenCancelled = false
local ready = false

local state = {}

local function cancelRegenerate()
  regenEnabled = false
  regenCancelled = true
  M.sendState()
end

local function getBeamPartOrigin(b, getEndNode)
  local x = nil
  
  if not getEndNode then
    x = v.data.nodes[b.id1].partOrigin
  else
    x = v.data.nodes[b.id2].partOrigin
  end
  
  if x == nil then x = "" end
  return x
end

local function validRegenPart(partName)
  local isValid = true
  local po = partName:lower()
  if string.find(po, "driveshaft") or string.find(po,"coilover") or string.find(po,"suspension") or  string.find(po,"steering") or  string.find(po,"swaybar") or  string.find(po,"brake") or string.find(po,"spring") or string.find(po,"wheel") or string.find(po,"mudflap") or string.find(po,"cape") or string.find(po,"flag") then isValid = false end
  return isValid
end

local function regenerate()
  if regenEnabled then return end
  regenCancelled = false
  
  --no idea, copied from old mod
  local i,beam
  for i, beam in pairs (v.data.beams) do
      obj:setBeamSpringDamp(beam.cid, beam.beamSpring or -1, beam.beamDamp or -1, beam.springExpansion or -1, beam.dampExpansion or -1)
  end
  
  --reset beam states
  regenBeamStates = {}
  regenBeamCache = {}
  regenTime = 0
  
  --build the cache
  for k,beam in pairs(v.data.beams) do
    --do some checks
    --local isValid = validRegenPart(getBeamPartOrigin(beam,false)) and validRegenPart(getBeamPartOrigin(beam,true)) and (beam.beamType == "|NORMAL" or beam.beamType == "|BOUNDED")
    -- Got beamtypes from BeamNG.drive\lua\vehicle\jbeam, checking if beam is NORMAL or BOUNDED
    local isValid = validRegenPart(getBeamPartOrigin(beam,false)) and validRegenPart(getBeamPartOrigin(beam,true)) and (beam.beamType == 0 or beam.beamType == 2)
    if not isValid or obj:beamIsBroken(beam.cid) then goto next end --skip!
    
    --get beam length, check if this is a 'weird' beam?
    local currentLengthRatio = obj:getBeamLengthRefRatio(beam.cid)
    if currentLengthRatio < 0.001 then goto next end
    
    --check if this is a 0 length beam
    local currentLength = obj:getBeamLength(beam.cid)
    if currentLength < 0.001 then goto next end
    
    --add to cache
    table.insert(regenBeamCache, beam)
    
    ::next::
  end

  --finally, flag for regen
  regenEnabled = true
end

local function doRegen(dt)
    local timeScaledRate = (regenRate * bullettime.get()) * dt
    local numFull = 0
    local numTotal = 0
    for k,beam in pairs(regenBeamCache) do
      --is this beam already done?
      --if regenBeamStates[beam.cid] ~= nil and regenBeamStates[beam.cid] == true then 
        --numTotal = numTotal + 1 
        --numFull = numFull + 1
        --goto next 
      --end 
      
      --add one to the total calculations
      numTotal = numTotal + 1
      
      --change length if we need to
      local currentLengthRatio = obj:getBeamLengthRefRatio(beam.cid)
      local currentLength = obj:getBeamLength(beam.cid)
      local targetLength = (currentLength / currentLengthRatio)
      local remainingLengthChange = math.abs(targetLength - currentLength)
      local lengthScaledRate = math.min(timeScaledRate / targetLength, math.abs(1 - currentLengthRatio))
      
      --are we done repairing this beam?
      if remainingLengthChange < math.max(repairErrorMargin, repairErrorMargin * (regenTime / 30)) then
        regenBeamStates[beam.cid] = true
        numFull = numFull + 1
        goto next
      end
      
      --repair this beam!
      if currentLength < targetLength then
        obj:setBeamLengthRefRatio(beam.cid,currentLengthRatio + lengthScaledRate)
      else
        obj:setBeamLengthRefRatio(beam.cid,currentLengthRatio - lengthScaledRate)
      end
      
      ::next::
    end
    
    --we're done?
    regenProgress = numFull / numTotal
    if numFull == numTotal then 
      M.sendState()
      regenEnabled = false 
      material.reset()
    end
end

local function onReset()
  regenEnabled = false
  regenCancelled = false
  regenTime = 0
  
  regenBeamStates = {}
  regenBeamCache = {}
  
  M.sendState("Ready!")
end

local function updateGFX(dt)
  if not regenEnabled then
    if not ready then M.sendState("Ready!") ready = true end
    return
  end

  doRegen(dt)
  M.sendState()
  regenTime = regenTime + dt
end


local function sendState(forceStatusText)
  state.progress = regenProgress
  state.enabled = regenEnabled
  
  if forceStatusText ~= nil then
    state.status = forceStatusText
  elseif regenEnabled then
    state.status = "Regeneration in progress..."
    if regenProgress > 0.99 then state.status = state.status .. " (Sit tight)" end
  elseif regenCancelled then
    state.status = "Regeneration cancelled."
  else
    state.status = "Regeneration complete!"
  end
  
  if not playerInfo.firstPlayerSeated then return end
  guihooks.trigger('BeamRegeneratorState', state)
end

-- public interface
M.regenerate = regenerate
M.cancelRegenerate = cancelRegenerate
M.onReset   = onReset
M.updateGFX = updateGFX
M.sendState = sendState

return M
