// deltav calculations, doesn't work with different flameout times (but does with asparagus(it's weird))
// dependencies: /lib/staging.ks - stagingSetup result has to be passed as a parameter
// TODO exclude resources that aren't consumed from drymass

@lazyGlobal off.

global function deltavSetup
{
  parameter stagingList is lexicon().
  if not(exists("/lib/staging.ks"))
    copypath("0:/lib/staging.ks", "/lib/staging.ks").
  runOncePath("/lib/staging.ks").
  if stagingList:length = 0
    set stagingList to stagingSetup().
  local engineList is list().
  list engines in engineList.
  local engineStages is list().
  local stageResources is stagingList:stageResources.
  local tempList is deltavStageMasses(stageResources).
  local stageMass is tempList[0].
  local fuelLines is tempList[1].
  local stageISP is list().
  local stageBurnTime is list().
  for currentStage in stageResources
    engineStages:add(list()).
  for engine in engineList
  {
    local endStage is engine:separatedin + 1.
    local startStage is engine:stage.
    until startStage < endStage
    {
      engineStages[startStage]:add(engine).
      set startStage to startStage - 1.
    }
  }
  local i is 0.
  until i > ship:stagenum
  {
    if engineStages[i]:length <> 0
    {
      stageISP:add(deltavISPCalc(engineStages[i])).
      stageBurnTime:add(deltavBurnTime(engineStages[i], stageResources[i])).
    }
    else
    {
      stageISP:add(0).
      stageBurnTime:add(0).
    }
    set i to i + 1.
  }
  deletepath("0:/deltav.log").
  log "stagingList:" to "0:/deltav.log".
  log stageResources to "0:/deltav.log".
  log "engineStages:" to "0:/deltav.log".
  log engineStages to "0:/deltav.log".
  log "stageISP:" to "0:/deltav.log".
  log stageISP to "0:/deltav.log".
  log "stageBurnTime:" to "0:/deltav.log".
  log stageBurnTime to "0:/deltav.log".
  log "stageMass:" to "0:/deltav.log".
  log stageMass to "0:/deltav.log".
  log "fuelLines:" to "0:/deltav.log".
  log fuelLines to "0:/deltav.log".
  return lexicon("stageMass", stageMass, "stageISP", stageISP, "engineStages", engineStages).
}

global function deltavISPCalc // weighted average of all ISP
{
  parameter engines.
  local averageISP is 0.
  local totalThrust is 0.
  for engine in engines
  {
    set averageISP to averageISP + engine:possiblethrustat(0) * engine:visp.
    set totalThrust to totalThrust + engine:possiblethrustat(0).
  }
  set averageISP to averageISP / totalThrust.
  return averageISP.
}

global function deltavBurnTime // maybe later to add support to more rockets
{
  parameter engines, fuel.

}

global function deltavFuelCheck // add not used resources to drymass
{
  parameter stageResources, part.
  local addedMass is 0.
  for resource in part:resources
  {
    local addMass is true.
    for check in stageResources[part:decoupledin + 1]
      if resource:name = check[0]:name
      {
        set addMass to false.
        break.
      }
    if addMass
    {
      set addedMass to addedMass + resource:density * resource:amount.
    }
  }
  return addedMass.
}

global function deltavStageMasses // stage mass and fuel lines
{
  parameter stageResources.
  local stageMass is list().
  local fuelLine is list().
  until stageMass:length > ship:stagenum
  {
    stageMass:add(list(0, 0)).
    fuelLine:add(false).
  }
  for part in ship:parts
  {
    if part:stage < 0
    {
      set stageMass[part:decoupledin + 1][0] to stageMass[part:decoupledin + 1][0] + part:drymass + deltavFuelCheck(stageResources, part).
      set stageMass[part:decoupledin + 1][1] to stageMass[part:decoupledin + 1][1] + part:mass.
    }
    else if not(part:hasmodule("ModuleDecouple") or part:hasmodule("ModuleAnchoredDecoupler"))
    {
      local shouldAdd is true.
      for module in part:modules
        if module:matchespattern("LaunchClamp")
          set shouldAdd to false.
      if shouldAdd
      {
        set stageMass[part:decoupledin + 1][0] to stageMass[part:decoupledin + 1][0] + part:drymass + deltavFuelCheck(stageResources, part).
        set stageMass[part:decoupledin + 1][1] to stageMass[part:decoupledin + 1][1] + part:mass.
      }
    }
    else
    {
      set stageMass[part:stage + 1][0] to stageMass[part:stage + 1][0] + part:drymass.
      set stageMass[part:stage + 1][1] to stageMass[part:stage + 1][1] + part:mass.
    }
    for child in part:children
    {
      if fuelLine[part:decoupledin + 1]
        break.
      set fuelLine[part:decoupledin + 1] to child:hasmodule("CModuleFuelLine").
    }
  }
  local i is -1.
  for thisMass in stageMass
  {
    if i >= 0
    {
      set thisMass[0] to thisMass[0] + stageMass[i][1].
      set thisMass[1] to thisMass[1] + stageMass[i][1].
    }
    set i to i + 1.
  }
  return list(stageMass, fuelLine).
}

global function deltavUpdate
{
  parameter x.
  local stageMass is x:stageMass.
  local stageISP is x:stageISP.
  local stageDeltav is list().
  until stageDeltav:length > ship:stagenum
    stageDeltav:add(0).
  local i is 0.
  until i = ship:stagenum
  {
    set stageDeltav[i] to stageISP[i] * constant:g0 * ln(stageMass[i][1] / stageMass[i][0]).
    set i to i + 1.
  }
  if ship:status <> "preLaunch"
    set stageDeltav[i] to stageISP[i] * constant:g0 * ln(ship:mass / stageMass[i][0]).
  else
    set stageDeltav[i] to stageISP[i] * constant:g0 * ln(stageMass[i][1] / stageMass[i][0]).
  log "stageDeltav:" to "0:/deltav.log".
  log stageDeltav to "0:/deltav.log".
  return stageDeltav.
}