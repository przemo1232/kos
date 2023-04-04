// auto maneuver node execution
// dependencies: /lib/deltav.ks
// TODO remake the code so that i can actually use it (it works)

@lazyGlobal off.

local function main
{
  if not(exists("deltav.ks"))
    copypath("0:/lib/deltav.ks", "/lib/deltav.ks").
  runOncePath("deltav.ks").
  if not(exists("/lib/staging.ks"))
    copypath("0:/lib/staging.ks", "/lib/staging.ks").
  runOncePath("/lib/staging.ks").
  if hasNode
    executeNode().
  else
    print "no node found".
}

local function executeNode
{
  local stagingInfo is stagingSetup().
  local deltavInfo is deltavSetup(stagingInfo).
  local engineStages is deltavInfo:engineStages.
  local deltav is deltavUpdate(deltavInfo).
  local stageNum is ship:stagenum.
  local requiredDeltav is nextNode:deltav:mag.
  local burnTime is 0.
  local totalMassFlow is 0.
  local stageMass is list().
  local totalThrust is 0.
  local thisBurnTime is 0.
  local deltavCenter is list(0, 0). // center of deltav on time axis as a weighted average
  until deltav[stageNum] > requiredDeltav
  {
    set totalMassFlow to 0.
    set totalThrust to 0.
    for engine in engineStages[stageNum]
    {
      set totalMassFlow to totalMassFlow + engine:maxmassflow.
      set totalThrust to totalThrust + engine:possiblethrustat(0).
    }
    set deltavCenter[1] to deltavCenter[1] + deltav[stageNum].
    set stageMass to deltavInfo:stageMass[stageNum].
    set thisBurnTime to (stageMass[1] - stageMass[0]) / totalMassFlow.
    set deltavCenter[0] to deltavCenter[0] - (totalThrust * (stageMass[1] * ln(1 - totalMassFlow * thisBurnTime / stageMass[1]) + totalMassFlow * thisBurnTime) / totalMassFlow ^ 2) + burnTime * deltav[stageNum].
    // set deltavCenter[0] to deltavCenter[0] + thisBurnTime * (.5 + stageMass[1] / stageMass[0] / 10) * deltav[stageNum].
    set burnTime to burnTime + thisBurnTime.
    set requiredDeltav to requiredDeltav - deltav[stageNum].
    set stageNum to stageNum - 1.
    if stageNum = -1
    {
      print "not enough deltav to execute node. Try anyway? (y/n)".
      local try is terminal:input:getchar().
      if try <> "n" or try <> "N"
        return.
    }
  }
  if stageNum > -1
  {
    set totalMassFlow to 0.
    set totalThrust to 0.
    for engine in engineStages[stageNum]
    {
      set totalMassFlow to totalMassFlow + engine:maxmassflow.
      set totalThrust to totalThrust + engine:possiblethrustat(0).
    }
    set stageMass to deltavInfo:stageMass[stageNum].
    set thisBurnTime to stageMass[1] * (1 - constant:e ^ (-requiredDeltav * totalMassFlow / totalThrust)) / totalMassFlow.
    set deltavCenter[1] to deltavCenter[1] + requiredDeltav.
    set deltavCenter[0] to deltavCenter[0] - (totalThrust * (stageMass[1] * ln(1 - totalMassFlow * thisBurnTime / stageMass[1]) + totalMassFlow * thisBurnTime) / totalMassFlow ^ 2) + burnTime * requiredDeltav.
    // set deltavCenter[0] to deltavCenter[0] + thisBurnTime * (.5 + (stageMass[1] - thisBurnTime * totalMassFlow) / 10) * requiredDeltav.
    set burnTime to burnTime + thisBurnTime.
  }
  local burnStartTime is deltavCenter[0] / deltavCenter[1].
  lock steering to nextnode:deltav.
  // warpto(time:seconds + nextNode:eta - burnStartTime - 10).
  wait until nextnode:eta < burnStartTime.
  lock throttle to 1.
  local startTime is time:seconds.
  until time:seconds - startTime > burnTime
    if autoStaging(stagingInfo)
      stage.
  lock throttle to 0.
  print stageNum.
  print requiredDeltav.
  print burnTime.
  print burnStartTime.
}

main().

// f - thrust
// m - mass
// t - time

// a = f / m
// da = f / dm
// dm = maxmassflow * dt
// a = f / (m - maxmassflow * t)
// dv = -f * ln(m - maxmassflow * t) / maxmassflow + C    or    dv = -f * ln(1 - maxmassflow * t / m) / maxmassflow
// dv2 = -f * (m * ln(1 - maxmassflow * t / m) + maxmassflow * t) / maxmassflow ^ 2
// C = ln(m) / maxmassflow * f

// t = m * (1 - math.e**(-v * x / f)) / x

// a = deltav
// dv2 = -f * (m * ln(1 - maxmassflow * t / m) + maxmassflow * t) / maxmassflow ^ 2