// by przemo1232
// this is just a prototype
// staging relies on tagging fuel tanks that are supposed to be empty on stage "0", "1", "2" etc
// this script does not handle igniting any engines before releasing launch clamps
// higher profile parameter means shallower ascent (it has to be bigger than 0), higher values work better with higher TWRs

// REWRITE THE CIRCULARIZATION FUNCTION AND ADD NON ATMOSPHERIC PROFILES

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
  if profile <= 0
  {
    print "Incorrect profile".
    return.
  }
  // initialization
  sas off.
  local azimuth is 90.
  local pitch is 90.
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
  local CircPID is list(height, 0, 0.001, 0, 0.001, 0, 0.001, 0, 0). // TargetHeight, PID values and multipliers, last P value, last time
  local pitchPID is list(TargetPitch, 0, 5, 0, 0.2, 0, 5, 0, 0, 0). // TargetPitch, PID values and multipliers, last P value, last time, last I value
  local CurrentSpeed is 0.
  local TargetSpeed is 0.
  local trigger is false.
  local gravity is 0.
  local acceleration is 0.
  lock throttle to flight[6].
  lock steering to heading(flight[0], flight[1]).
  // finish initialization, begin main loop
  until finished
  {
    // updates
    set gravity to body:mu / (body:radius + altitude) ^ 2.
    set acceleration to ship:availablethrust / ship:mass.
    set flight[8] to acceleration / gravity.
    if CurrentStage >= 0
      print "Current stage: " + CurrentStage at(0, 0).
    if missionTime > 0
      set CurrentStage to Staging(CurrentStage).
    print "Acceleration: " + acceleration * flight[6] at(0, 3).
    // end updates
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
    if phase = 2
    {
      set phase to PostAtmosphericFlight(flight, body:atm:height + margin, phase).
    }
    if phase = 3
    {
      set phase to ApRaise(flight, height).
    }
    if phase = 4
    {
      set CurrentSpeed to sqrt(body:mu * (2 / (body:radius + apoapsis) - 1 / orbit:semimajoraxis)).
      set TargetSpeed to sqrt(body:mu / (body:radius + apoapsis)).
      print "Current speed: " + CurrentSpeed at(0, 1).
      print "Target speed: " + TargetSpeed at(0, 2).
      print "Pitch: " + flight[1] at(0, 4).
      print "Time to Ap: " + eta:apoapsis at(0, 5).
      local temp is acceleration.
      if temp > 0
        print "Time to burn: " + (eta:apoapsis - ((TargetSpeed - CurrentSpeed) / temp) / 2) at(0, 6).
      if acceleration > 0
        if (TargetSpeed - CurrentSpeed) / acceleration >= eta:apoapsis * 2
          set trigger to true.
      if trigger
      {
        print "Throttle: " + flight[6] at(0, 7).
        set phase to Circularization(flight, circPID).
      }
    }
    if phase = -1
    {
      set flight[6] to 0.
      set finished to true.
    }
    print "Phase: " + phase at(0, terminal:height - 1).
    wait 0.
  }
  print "Current apoapsis: " + apoapsis at(0, 11).
  print "Current periapsis: " + periapsis at(0, 12).
  print "Orbit achieved, ending script" at(0, 13).
}

local function Staging // auto staging based on numbered fuel tanks
{
  parameter x.
  if x >= 0
  {
    if ship:partsdubbed(x:tostring):length > 0
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
      print "No more predefined stages" at(0, terminal:height - 3).
      set x to -1.
    }
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
  return 1.
}

local function AtmosphericFlight // steering while in atmosphere
{ // flight[1] is pitch, flight[2] is profile
  parameter flight, pitchPID.
  local temp is altitude.
  local CurrentTime is missionTime.
  local output is 90.
  set pitchPID[0] to 90 - arcTan(flight[2] * temp / sqrt((body:atm:height + flight[7]) ^ 2 - temp ^ 2)).
  set pitchPID[1] to pitchPID[0] - arcSin(verticalSpeed / ship:velocity:surface:mag).
  print "Target: " + pitchPID[0] at(0, 12).
  if ship:bounds:bottomaltradar > flight[9]
  {
    print "Vector: " + arcSin(verticalSpeed / ship:velocity:surface:mag) at(0, 13).
    if pitchPID[8] > 0 and CurrentTime > pitchPID[8] + 0.02
    {
      set pitchPID[3] to pitchPID[3] + (pitchPID[1] + pitchPID[7]) / 2 * (CurrentTime - pitchPID[8]).
      if abs(pitchPID[3]) < abs(pitchPID[9])
        set pitchPID[3] to pitchPID[3] * (1 - 0.2 * (CurrentTime - pitchPID[8])).
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
    else
      set flight[1] to output.
  }
  if ship:velocity:surface:mag > 100 and body:atm:altitudepressure(altitude) > 0.0005
  {
    if flight[8] > 0
    {
      if 1 + (output - pitchPID[0]) * 0.1 > 1 / flight[8] * 2
        set flight[6] to 1 / flight[8] * 2.
      else if 1 + (output - pitchPID[0]) * 0.1 < 1 / flight[8]
        set flight[6] to 1 / flight[8].
      else
        set flight[6] to 1 + (output - pitchPID[0]) * 0.1.
    }
  }
  else
  {
    if flight[8] > 0
      set flight[6] to 1 / flight[8] * 2.
    if body:atm:altitudepressure(altitude) < 0.0005
      return 2.
  }
  set pitchPID[7] to pitchPID[1].
  print "Pitch: " + flight[1] at(0, 4).
  print "Proportional: " + (pitchPID[1] * pitchPID[2]) at(0, 8).
  print "Integral: " + (pitchPID[3] * pitchPID[4]) at(0, 9).
  print "Derivative: " + (pitchPID[5] * pitchPID[6]) at(0, 10).
  if apoapsis < body:atm:height + flight[7] and altitude < body:atm:height
    return 1.
  else
    return 2.
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
    if flight[5] > latitude
      set flight[3] to false.
    if flight[5] < latitude
      set flight[3] to true.
    set flight[5] to latitude.
    set flight[4] to missionTime.
  }
}

local function PostAtmosphericFlight
{
  parameter flight, height, phase.
  set flight[1] to 0.
  if apoapsis >= 0.9 * height
    set flight[6] to 1 - ((apoapsis - 0.9 * height) / (0.1 * height)) * 0.5.
  else
    set flight[6] to 1.
  if apoapsis >= height
  {
    set flight[6] to 0.
    if altitude < body:atm:height
      return 3.
    else
      return 4.
  }
  return phase.
}

local function ApRaise
{
  parameter flight, height.
  if altitude >= body:atm:height
    return PostAtmosphericFlight(flight, height, 3).
  if apoapsis <= body:atm:height + (flight[7] / 2)
    return PostAtmosphericFlight(flight, body:atm:height + flight[7], 2).
  return 3.
}

local function Circularization // finishing the orbit
{
  parameter flight, circPID.
  local CurrentTime is missionTime.
  set circPID[1] to circPID[0] - apoapsis.
  if circPID[8] > 0
  {
    set circPID[3] to circPID[3] + (circPID[1] + circPID[7]) / 2 * (CurrentTime - circPID[8]).
    set circPID[5] to (circPID[1] - circPID[7]) / (CurrentTime - circPID[8]).
  }
  local output is circPID[1] * circPID[2] + circPID[3] * circPID[4] + circPID[5] * circPID[6].
  if abs(output) <= 90 
    set flight[1] to output.
  else if output > 0
    set flight[1] to 90.
  else
    set flight[1] to -90.
  set circPID[7] to circPID[1].
  set circPID[8] to CurrentTime.
  set flight[6] to 0.5 + (circPID[0] - periapsis) / circPID[0].
  print "Proportional: " + (circPID[1] * circPID[2]) at(0, 8).
  print "Integral: " + (circPID[3] * circPID[4]) at(0, 9).
  print "Derivative: " + (circPID[5] * circPID[6]) at(0, 10).
  if periapsis > 0.99 * apoapsis or (periapsis > body:atm:height and apoapsis > 2 * circPID[0])
    return -1.
  return 4.
}
parameter height is 0, inclination is 200, StartTurn is 0, profile is 4.
if inclination = 200
{
  print "Use this script with parameters: altitude [m], inclination [degrees]".
  print "Optional parameters: StartTurn [m](0), profile(4, atmosphere only)".
  print "Smallest inclination possible: " + ceiling(abs(latitude), 1).
}
else
  main().
