// by przemo1232
// basic navigation to orbit with a desired altitude and inclination
// auto staging relies on tagged fuel tanks: when a tank tagged "0", "1", "2" etc is empty, the script stages until rocket has thrust
// the script will not release launch clamps if there already is thrust
// higher profile parameter means shallower ascent (it has to be bigger than 0 (4 works fine for me but you can experiment))

local function main
{
  // fail conditions
  local margin is 1e4.
  if height < body:atm:height + margin
  {
    print "Incorrect height value".
    return.
  }
  if abs(inclination) < ceiling(abs(latitude), 1) or abs(inclination) > 180 - ceiling(abs(latitude), 1)
  {
    print "Incorrect inclination value, minimal is" + ceiling(abs(latitude), 1).
    return.
  }
  // initialization
  sas off.
  local azimuth is 90.
  local pitch is 90.
  local profile is 4.
  local TargetPitch is 90.
  local upwards is true.
  local lasttime is missionTime + 10.
  local lastlatitude is latitude.
  local thrt is 0.
  local twr is 0.
  local flight is list(azimuth, pitch, profile, upwards, lasttime, lastlatitude, thrt, margin, twr, StartTurn).
  if inclination < 0
    set flight[3] to false.
  local phase is 0.
  local finished is false.
  local CurrentStage is 0.
  local UpSpeed is 0.
  local CircPID is list(Upspeed, 0, 1, 0, 1, 0, 5, 0, 0, false). // Upspeed, PID values and multipliers, last P value, last time, trigger
  local pitchPID is list(TargetPitch, 0, 5, 0, 0.25, 0, 2, 0, 0, 0). // TargetPitch, PID values and multipliers, last P value, last time, last I value
  local gravity is 0.
  local acceleration is 0.
  local curacc is 0.
  lock throttle to flight[6].
  lock steering to heading(flight[0], flight[1]).
  // finish initialization, begin main loop
  until finished
  {
    // updates
    if flight[6] < 1
      set curacc to acceleration * flight[6].
    else
      set curacc to acceleration.
    set gravity to body:mu / (body:radius + altitude) ^ 2.
    set acceleration to ship:availablethrust / ship:mass.
    set flight[8] to acceleration / gravity.
    if missionTime > 0
      set CurrentStage to Staging(CurrentStage).
    // readouts
    if CurrentStage >= 0
      print "Current stage: " + CurrentStage at(0, terminal:height - 1).
    if flight[6] < 1
      print "Throttle: " + round(flight[6], 2) + "   " at(0, 0).
    else
      print "Throttle: 1   " at(0, 0).
    print "Acceleration: " + round(curacc, 2) + " m/s^2     " at(0, 1).
    print "Pitch: " + round(flight[1], 1) + "   " at(0, 3).
    print "Heading: " + round(flight[0], 1) + "   " at(0, 4).
    print "Apoapsis: " + round(apoapsis, 0) + " m  " at(0, 6).
    print "Periapsis: " + round(periapsis, 0) + " m  " at(0, 7).
    // end readouts
    if phase > 0
    {
      Direction(flight, inclination).
    }
    if phase = 0
    {
      set phase to Countdown(flight).
    }
    if phase = 1
    {
      set phase to AtmosphericFlight(flight, pitchPID).
    }
    if phase = 1.5
    {
      if RCSToggle
        rcs on.
      set phase to NonAtmosphericAscent(flight).
    }
    if phase = 2
    {
      if RCSToggle
        rcs on.
      set phase to PostAtmosphericFlight(flight, body:atm:height + margin, phase, pitchPID).
    }
    if phase = 3
    {
      set phase to ApRaise(flight, height).
    }
    if phase = 4
    {
      set phase to Circularization(flight, height, acceleration, CircPID).
    }
    if phase = -1
    {
      set flight[6] to 0.
      set finished to true.
      clearscreen.
      print "Orbit achieved, endling script.".
      print "Periapsis: " + round(periapsis, 0).
      print "Apoapsis: " + round(apoapsis, 0).
      rcs off.
    }
    wait 0.
  }
}

local function Staging // auto staging based on numbered fuel tanks
{
  parameter x.
  if x >= 0 and ship:partsdubbed(x:tostring):length > 0
  {
    local ready is stage:ready.
    for y in ship:partsdubbed(x:tostring)[0]:resources
      if y:amount < 0.001 and y:name <> "ElectricCharge" and ready
      {
        stage.
        set ready to false.
        set x to x + 1.
      }
    if ready and ship:availablethrust = 0 // extra staging if needed
      stage.
  }
  else
  {
    print "No more predefined stages" at(0, terminal:height - 1).
    set x to -1.
  }
  return x.
}

local function Countdown
{
  parameter flight.
  clearscreen.
  print "Counting down".
  set x to 5.
  until x <= 0
  {
    print x.
    set x to x - 1.
    wait 1.
  }
  clearscreen.
  set flight[6] to 1.
  until ship:availablethrust > 0
  {
    stage.
    wait until stage:ready.
  }
  if body:atm:exists
    return 1.
  return 1.5.
}

local function AtmosphericFlight // steering while in atmosphere
{ // flight[1] is pitch, flight[2] is profile
  parameter flight, pitchPID.
  local temp is altitude.
  local CurrentTime is missionTime.
  local output is 90.
  local vector is arcSin(verticalSpeed / ship:velocity:surface:mag).
  set pitchPID[0] to 90 - arcTan(flight[2] * temp / sqrt((body:atm:height + flight[7]) ^ 2 - temp ^ 2)).
  set pitchPID[1] to pitchPID[0] - vector.
  if ship:bounds:bottomaltradar > flight[9]
  {
    if gear
      toggle gear.
    if pitchPID[8] > 0 and CurrentTime > pitchPID[8] + 0.02
    {
      set pitchPID[3] to pitchPID[3] + (pitchPID[1] + pitchPID[7]) / 2 * (CurrentTime - pitchPID[8]).
      if abs(pitchPID[3]) < abs(pitchPID[9])
        set pitchPID[3] to pitchPID[3] * (1 - 0.05 * (CurrentTime - pitchPID[8])).
      set pitchPID[5] to (pitchPID[1] - pitchPID[7]) / (CurrentTime - pitchPID[8]).
      set pitchPID[8] to CurrentTime.
      set pitchPID[9] to pitchPID[3].
    }
    else if pitchPID[8] = 0
      set pitchPID[8] to CurrentTime.
    set output to pitchPID[0] + pitchPID[1] * pitchPID[2] + pitchPID[3] * pitchPID[4] + pitchPID[5] * pitchPID[6].
    if output < 0
      set flight[1] to 0.
    else if output > 90
      set flight[1] to 90.
    else if output > vector + 15
      set flight[1] to vector + 15.
    else if output < vector - 10
      set flight[1] to vector - 10.
    else
      set flight[1] to output.
  }
  if body:atm:altitudepressure(altitude) > 0.0005 and flight[8] > 0
  {
    if altitude > body:atm:height / 10
    {
      if 1 + (output - pitchPID[0]) * 0.1 > 1 / flight[8] * 2
        set flight[6] to 1 / flight[8] * 2.
      else if 1 + (output - pitchPID[0]) * 0.1 < 1 / flight[8]
        set flight[6] to 1 / flight[8].
      else
        set flight[6] to 1 + (output - pitchPID[0]) * 0.1.
    }
    else 
      set flight[6] to 1 / flight[8] * 2.
  }
  else if body:atm:altitudepressure(altitude) < 0.0005 and vector > pitchPID[0]
    return 2.
  set pitchPID[7] to pitchPID[1].
  if apoapsis < body:atm:height + flight[7] and altitude < body:atm:height
    return 1.
  else
    return 2.
}

local function NonAtmosphericAscent
{
  parameter flight.
  local radius is body:radius + altitude.
  if flight[9] < 100
    set flight[9] to 100.
  if ship:bounds:bottomaltradar > flight[9] and flight[8] > 0
  {
    if gear
      toggle gear.
    set flight[6] to 1 / flight[8] * 10.
    if flight[8] > 5
      set flight[1] to arcSin((1.5 - (vxcl(up:vector, velocity:orbit):sqrmagnitude / radius) / (body:mu / radius ^ 2)) / 5).
    else
      set flight[1] to arcSin(1.5 / flight[8]).
  }
  else
    set flight[6] to 1 / flight[8] * 2.
  if apoapsis > flight[7]
    return 3.
  return 1.5.
}

local function Direction // azimuth control
{
  parameter flight, inclination.
  local scaling is 10.
  local temp is orbit:inclination.
  if abs(inclination) - 0.1 > temp
  {
    if abs(inclination) > temp // compensation for initial speed
      set compensation to scaling * sin(abs(inclination) - temp) ^ 0.2.
    else
      set compensation to -scaling * sin(temp - abs(inclination)) ^ 0.2.
  }
  else
    set compensation to 10 * (abs(inclination) - temp).
  set temp to latitude.
  if abs(temp) <= abs(inclination) // what heading i should have
  {
    if flight[3] = true
      set flight[0] to arcsin(cos(inclination) / cos(temp)) - compensation.
    else
      set flight[0] to -arcsin(cos(inclination) / cos(temp)) + 180 + compensation.
    if flight[0] < 0
      set flight[0] to flight[0] + 360.
  }
  if missionTime > flight[4] + 1 // whether i'm going north or south
  {
    if flight[5] > latitude or latitude > abs(inclination)
      set flight[3] to false.
    if flight[5] < latitude or latitude < -abs(inclination)
      set flight[3] to true.
    set flight[5] to latitude.
    set flight[4] to missionTime.
  }
}

local function PostAtmosphericFlight
{
  parameter flight, TargetHeight, phase, pitchPID.
  set pitchPID[0] to 90 - arcTan(flight[2] * temp / sqrt((body:atm:height + flight[7]) ^ 2 - temp ^ 2)).
  local vector is arcSin(verticalSpeed / ship:velocity:surface:mag).
  set flight[1] to 0.
  if apoapsis >= 0.9 * TargetHeight
    set flight[6] to 1 - (5 * apoapsis / TargetHeight - 4.5).
  else
    set flight[6] to 1.
  if apoapsis >= TargetHeight
  {
    set flight[6] to 0.
    if altitude < body:atm:height
      return 3.
    else
    {
      clearscreen.
      return 4.
    }
  }
  if phase = 2 and vector < pitchPID[0]
    return 1.
  return phase.
}

local function ApRaise
{
  parameter flight, height.
  if altitude >= body:atm:height
  {
    if flight[6] = 0
      clearscreen.
    return PostAtmosphericFlight(flight, height, 3).
  }
  if apoapsis <= body:atm:height + (flight[7] / 2)
    return PostAtmosphericFlight(flight, body:atm:height + flight[7], 2).
  print "Coasting until above the atmosphere" at(0, 33).
  return 3.
}

local function Circularization // finishing the orbit
{ // Upspeed, PID values and multipliers, last P value, last time, trigger
  parameter flight, height, acceleration, circPID.
  local CurrentTime is missionTime.
  local CurrentSpeed is sqrt(body:mu * (2 / (body:radius + apoapsis) - 1 / orbit:semimajoraxis)).
  local TargetSpeed is sqrt(body:mu / (body:radius + apoapsis)).
  local BurnTime is (TargetSpeed - CurrentSpeed) / acceleration.
  if acceleration > 0 and BurnTime >= eta:apoapsis * 2 and circPID[9] = false
  {
    set circPID[9] to true.
    clearscreen.
  }
  else if acceleration > 0 and BurnTime <= eta:apoapsis * 1.5 and verticalSpeed > 0.1 and periapsis < 0.99 * height
  {
    set circPID[9] to false.
    set flight[6] to 0.
  }
  if circPID[9] = false
  {
    set flight[1] to 0.
    set circPID[1] to 0.
    set circPID[5] to 0.
    print "Waiting for burn: " + round(eta:apoapsis - BurnTime / 2, 0) + " s  " at(0, 33).
  }
  else if flight[8] > 0
  {
    if (periapsis + body:radius) > 0.95 * (height + body:radius) and flight[8] > 0
      set flight[6] to 1 / flight[8] / 2.
    else
      set flight[6] to 1 / flight[8] * 10.
    local VerticalAcc is vxcl(up:vector, velocity:orbit):sqrmagnitude / (body:radius + altitude) - body:mu / (body:radius + altitude) ^ 2.
    set circPID[1] to arcSin(VerticalAcc / acceleration).
    if verticalSpeed > -2
      set circPID[5] to -verticalSpeed.
    else
      set circPID[5] to 2.
    local output is circPID[1] * circPID[2] + circPID[5] * circPID[6].
    if output < 0
      set flight[1] to 0.
    else if output > 45
      set flight[1] to 45.
    else
      set flight[1] to output.
  }
  if periapsis > 0.99 * height and (eta:apoapsis < 3 / 4 * orbit:period and eta:apoapsis > orbit:period / 4)
    return -1.
  return 4.
}

parameter height is 0, inclination is ceiling(abs(latitude), 1), StartTurn is 100, RCSToggle is false.
set terminal:height to 36.
set terminal:width to 50.
if not (status = "landed" or status = "prelaunch")
  print "Vessel is not landed".
else if height = 0
{
  print "Use this script with parameters:".
  print "Altitude [m]".
  print "Optional parameters:".
  print "Inclination [degrees](current latitude)".
  print "Turn start altitude [m](100)".
  print "Toggle rcs above atmosphere(false)".
  print "Smallest inclination possible: " + ceiling(abs(latitude), 1).
}
else
  main().
