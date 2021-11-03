// auto staging logic, returns boolean

@lazyGlobal off.


global function stagingSetup // initialization
{
  local tree is list().
  local fuels is list().
  local stageResources is list().
  until tree:length > stage:number
  {
    tree:add(list()).
    fuels:add(list()).
    stageResources:add(list()).
  }
  local engineList is list().
  list engines in engineList.
  // staging tree and clamps
  local clamp is 9000.
  for part in ship:parts
  {
    for module in part:modules
      if module:matchespattern("LaunchClamp") and clamp > part:stage + 1
        set clamp to part:stage + 1.
    if part:resources:length > 0
    {
      if part:hasmodule("moduleEnginesFX")
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
    until y <= engine:separatedin or y = 0
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
    for tank in tree[x]
    {
      for resource in tank:resources
      {
        for fuel in stageList
        {
          if resource:name = fuel
          {
            local check is true.
            if stageResources[x]:contains(resource)
              set check to false.
            if check
            {
              stageResources[x]:add(resource).
              break.
            }
          }
        }
      }
    }
    set x to x + 1.
  }
  return list(fuels, stageResources, clamp).
}

global function autoStaging // loop
{
  parameter stagingList.
  local fuels is stagingList[0].
  local stageResources is stagingList[1].
  local clamp is stagingList[2].
  if stage:ready
  {
    local shouldStage is false.
    local x is ship:stagenum.
    for resource in stageResources[x]
    {
      if fuels[x]:contains(resource:name) // way faster than manually checking the entire list
      {
        if resource:amount / resource:capacity < 1e-4
        {
          set shouldStage to true.
          break.
        }
      }
    }
    if x >= clamp
      return true.
    else if shouldStage
    {
      until x < 1
      {
        set x to x - 1.
        if stageResources[x]:length > 0
        {
          return true.
        }
      }
    }
  }
  return false.
}