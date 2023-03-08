// auto staging logic, returns boolean

@lazyGlobal off.

global function stagingSetup // initialization
{
  local tree is list().
  local fuels is list().
  local stageResources is list().
  local stages is 0.
  local clamp is 9000.
  if ship:status <> "preLaunch"
  {
    for part in ship:parts
      if part:stage > stages
        set stages to part:stage.
  }
  else
    set clamp to ship:stagenum.
  set stages to choose stage:number if stage:number > stages else stages.
  until tree:length > stages
  {
    tree:add(list()).
    fuels:add(list()).
    stageResources:add(list()).
  }
  local engineList is list().
  list engines in engineList.
  // staging tree and clamps
  for part in ship:parts
  {
    for module in part:modules
      if module:matchespattern("LaunchClamp") and clamp > part:stage
        set clamp to part:stage.
    if part:resources:length > 0
    {
      if part:hassuffix("isp")
      {
        if not(part:stage = part:separatedin)
          tree[part:separatedin + 1]:add(part).
      }
      else
        tree[part:stage + 1]:add(part).
    }
  }
  // fuels used in each stage
  for engine in engineList
  {
    local y is engine:stage.
    local keys is list().
    for fuelKey in engine:consumedResources:keys
      keys:add(fuelKey).
    local fuelType is engine:consumedResources.
    until y <= engine:separatedin or y < 0
    {
      local x is 0.
      until x > fuels[y]:length or x = keys:length
      {
        if x = fuels[y]:length
          fuels[y]:add(fuelType[keys[x]]:name).
        if x < fuels[y]:length
        {
          local z is 0.
          local fuelAdd is true.
          until z = fuels[y]:length
          {
            if fuelType[keys[x]]:name = fuels[y][z]
              set fuelAdd to false.
            set z to z + 1.
          }
          if fuelAdd
            fuels[y]:add(fuelType[keys[x]]:name).
        }
        set x to x + 1.
      }
      set y to y - 1.
    }
  }
  // fuel tanks in each stage
  local x is 0.
  for stageList in fuels
  {
    local y is 0.
    for fuel in stageList
    {
      stageResources[x]:add(list()).
      for tank in tree[x]
      {
        for resource in tank:resources
        {
          if resource:name = fuel
          {
            local check is true.
            if stageResources[x][y]:contains(resource) // way faster than manually checking the entire list
              set check to false.
            if check
            {
              stageResources[x][y]:add(resource).
              break.
            }
          }
        }
      }
      if stageResources[x][y]:length = 0
        stageResources[x]:remove(y).
      else
        set y to y + 1.
    }
    set x to x + 1.
  }
  return list(stageResources, clamp).
}

global function autoStaging // loop
{
  parameter stagingList.
  local stageResources is stagingList[0].
  local clamp is stagingList[1].
  if stage:ready
  {
    if ship:status = "preLaunch"
      return true.
    local shouldStage is true.
    local x is ship:stagenum.
    for resourceType in stageResources[x]
    {
      set shouldStage to true.
      for resource in resourceType
      {
        if resource:amount / resource:capacity > 1e-4
        {
          set shouldStage to false.
          break.
        }
      }
      if shouldStage
        break.
    }
    if x > clamp
      return true.
    else if shouldStage
    {
      until x < 1
      {
        set x to x - 1.
        if stageResources[x]:length > 0
          return true.
      }
    }
  }
  return false.
}