// by przemo1232
// basic navigation to orbit with a desired altitude and inclination
// auto staging relies on tagged fuel tanks: when a tank tagged "0", "1", "2" etc is empty, the script stages until rocket has thrust
// the script will not release launch clamps if there already is thrust
// higher profile parameter means shallower ascent (it has to be bigger than 0 (4 works fine for me but you can experiment))

local function pidgenerator
{
  parameter reference, value, type is 0.
  local pid is lexicon(reference, value, "p", 0, "kp", 1, "i", 0, "ki", 1, "d", 0, "kd", 1, "lastp", 0, "lasttime", 0).
  if type = 1
    pid:add("trigger", false).
  if type = 2
    pid:add("lasti", 0).
  return pid.
}

local function main
{
  set terminal:height to 36.
  set terminal:width to 50.
  if not (status = "landed" or status = "prelaunch")
  {
    print "Vessel is not landed".
    return.
  }
  local height is 0.
  local inclination is 0.
  local RCSToggle is false.
  local StartTurn is 0.
  local profile is 0.
  local margin is 1e4.
  // parameters
  clearguis().
  local check is false.
  local maingui is gui(-300, 300).
  local options is maingui:addvlayout().
  local advOptions is maingui:addvlayout().
  // options
  options:addlabel("Orbit height").
  local inputHeight is options:addtextfield((body:atm:height + 1e4):tostring).
  options:addlabel("Orbit inclination").
  local inputInclination is options:addtextfield(ceiling(abs(latitude), 1):tostring).
  local inputRCSToggle is options:addcheckbox("Toggle RCS above atmosphere?", false).
  local advanced is options:addbutton("Advanced").
  options:addspacing(30).
  // advOptions
  advOptions:addlabel("Ascent guidance start alitude").
  local inputStartTurn is advOptions:addtextfield("100").
  advOptions:addlabel("Ascent profile multiplier").
  local inputProfile is advOptions:addtextfield("4").
  local back is advOptions:addbutton("Back").
  advOptions:addspacing(30).
  local ready is maingui:addbutton("Ready"). 
  set advOptions:visible to false.
  maingui:show().
  until check
  {
    until ready:takepress
    {
      if advanced:takepress
      {
        options:hide().
        advOptions:show().
      }
      if back:takepress
      {
        advOptions:hide().
        options:show().
      }
    }
    set check to true.
    set height to inputHeight:text:tonumber(-1).
    set inclination to inputInclination:text:tonumber(200).
    set RCSToggle to inputRCSToggle:pressed.
    set StartTurn to inputStartTurn:text:tonumber(-1).
    set profile to inputProfile:text:tonumber(-1).
    //fail conditions
    if height < body:atm:height + margin
    {
      set check to false.
      hudtext("Incorrect height, must be at least " + (body:atm:height + margin), 10, 2, 24, red, false).
    }
    if abs(inclination) < ceiling(abs(latitude), 1) or abs(inclination) > 180 - ceiling(abs(latitude), 1)
    {
      set check to false.
      hudtext("Incorrect inclination, must be at least " + ceiling(abs(latitude), 1), 10, 2, 24, red, false).
    }
    if StartTurn < 0
    {
      set check to false.
      hudtext("Incorrect Ascent guidance start alitude, must be positive", 10, 2, 24, red, false).
    }
    if profile <= 0
    {
      set check to false.
      hudtext("Incorrect profile, must be greater than 0", 10, 2, 24, red, false).
    }
  }
  maingui:hide().
  // initialization
  local flight is lexicon("azimuth", 90, "pitch", 90, "profile", profile, "upwards", true, "LastTime",
  missionTime + 10, "LastLatitude", latitude, "throttle", 0, "margin", margin, "twr", 0, "StartTurn", StartTurn).
  if inclination < 0
    set flight:upwards to false.
  local phase is 0.
  local finished is false.
  local CurrentStage is 0.
  local CircPID is pidgenerator("UpSpeed", 0, 1).
  set CircPID:kd to 5.
  local PitchPID is pidgenerator("TargetPitch", 90, 2).
  set PitchPID:kp to 5.
  set PitchPID:ki to 0.25.
  set PitchPID:kd to 2.
  local gravity is 0.
  local acceleration is 0.
  local curacc is 0.
  lock throttle to flight:throttle.
  lock steering to heading(flight:azimuth, flight:pitch).
  // finish initialization, begin main loop
  until finished
  {
    // updates
    sas off.
    set curacc to acceleration * min(flight:throttle, 1).
    set gravity to body:mu / (body:radius + altitude) ^ 2.
    set acceleration to ship:availablethrust / ship:mass.
    set flight:twr to acceleration / gravity.
    if missionTime > 0
      set CurrentStage to Staging(CurrentStage).
    // readouts
    if CurrentStage >= 0
      print "Current stage: " + CurrentStage at(0, terminal:height - 1).
    print "Throttle: " + min(round(flight:throttle, 2), 1) + "    " at(0, 0).
    print "Acceleration: " + round(curacc, 2) + " m/s^2      " at(0, 1).
    print "Pitch: " + round(flight:pitch, 2) + "    " at(0, 3).
    print "Heading: " + round(flight:azimuth, 2) + "    " at(0, 4).
    print "Apoapsis: " + round(apoapsis, 0) + " m   " at(0, 6).
    print "Periapsis: " + round(periapsis, 0) + " m   " at(0, 7).
    print "Inclination: " + round(orbit:inclination, 2) + "    " at(0, 8).
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
    if phase = 4
    {
      if RCSToggle
        rcs on.
      set phase to Circularization(flight, height, acceleration, CircPID).
    }
    if phase = -1
    {
      set flight:throttle to 0.
      set finished to true.
      clearscreen.
      print "Orbit achieved, endling script.".
      print "Periapsis: " + round(periapsis, 0) + " m".
      print "Apoapsis: " + round(apoapsis, 0) + " m".
      rcs off.
    }
    wait 0.
  }
}

local function Staging // auto staging based on numbered fuel tanks
{
  parameter x.
  local ready is stage:ready.
  if x >= 0 and ship:partsdubbed(x:tostring):length > 0
  {
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
  set flight:throttle to 1.
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
{
  parameter flight, pitchPID.
  local temp is altitude.
  local CurrentTime is missionTime.
  local output is 90.
  local vector is 90 - vang(up:vector, ship:velocity:surface).
  set pitchPID:TargetPitch to 90 - arcTan(flight:profile * temp / sqrt((body:atm:height + flight:margin) ^ 2 - temp ^ 2)).
  set pitchPID:p to pitchPID:TargetPitch - vector.
  if ship:bounds:bottomaltradar > flight:StartTurn // pitch control
  {
    if gear
      toggle gear.
    if pitchPID:LastTime > 0 and CurrentTime > pitchPID:LastTime + 0.02
    {
      set pitchPID:i to pitchPID:i + (pitchPID:p + pitchPID:lastp) / 2 * (CurrentTime - pitchPID:LastTime).
      if abs(pitchPID:i) < abs(pitchPID:lasti)
        set pitchPID:i to pitchPID:i * (1 - 0.05 * (CurrentTime - pitchPID:LastTime)).
      set pitchPID:d to (pitchPID:p - pitchPID:lastp) / (CurrentTime - pitchPID:LastTime).
      set pitchPID:LastTime to CurrentTime.
      set pitchPID:lasti to pitchPID:i.
    }
    else if pitchPID:LastTime = 0
    {
      set pitchPID:LastTime to CurrentTime.
    }
    set output to pitchPID:TargetPitch + pitchPID:p * pitchPID:kp + pitchPID:i * pitchPID:ki + pitchPID:d * pitchPID:kd.
    set flight:pitch to max(0, min(90, max(vector - 10, min(vector + 15, output)))).
  }
  if body:atm:altitudepressure(altitude) > 0.001 and flight:twr > 0 // throttle control
  {
    if altitude > body:atm:height / 20
    {
      local thrt is 1 + (output - pitchPID:TargetPitch) * 0.1.
      set flight:throttle to min(2 / flight:twr, max(1 / flight:twr, thrt)).
    }
    else
      set flight:throttle to 2 / flight:twr.
  }
  else
    set flight:throttle to 1.
  set pitchPID:lastp to pitchPID:p.
  if apoapsis < body:atm:height + flight:margin
    return 1.
  else
    return 4.
}

local function NonAtmosphericAscent // WIP
{
  parameter flight.
  local radius is body:radius + altitude.
  if flight:StartTurn < 100
    set flight:StartTurn to 100.
  if ship:bounds:bottomaltradar > flight:StartTurn and flight:twr > 0
  {
    if gear
      toggle gear.
    set flight:throttle to 1 / flight:twr * 10.
    if flight:twr > 5
      set flight:pitch to arcSin((1.5 - (vxcl(up:vector, velocity:orbit):sqrmagnitude / radius) / (body:mu / radius ^ 2)) / 5).
    else
      set flight:pitch to arcSin(1.5 / flight:twr).
  }
  else
    set flight:throttle to 1 / flight:twr * 2.
  if apoapsis > flight:margin
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
    if flight:upwards = true
      set flight:azimuth to arcsin(cos(inclination) / cos(temp)) - compensation.
    else
      set flight:azimuth to -arcsin(cos(inclination) / cos(temp)) + 180 + compensation.
    if flight:azimuth < 0
      set flight:azimuth to flight:azimuth + 360.
  }
  if missionTime > flight:LastTime + 1 // whether i'm going north or south
  {
    if flight:LastLatitude > latitude or latitude > abs(inclination)
      set flight:upwards to false.
    if flight:LastLatitude < latitude or latitude < -abs(inclination)
      set flight:upwards to true.
    set flight:LastLatitude to latitude.
    set flight:LastTime to missionTime.
  }
}

local function Circularization // finishing the orbit
{
  parameter flight, height, acceleration, circPID.
  local raise is (apoapsis < height). // raising the ap
  local CurrentSpeed is sqrt(body:mu * (2 / (body:radius + apoapsis) - 1 / orbit:semimajoraxis)).
  local TargetSpeed is sqrt(body:mu / (body:radius + apoapsis)).
  local BurnTime is 0.
  if acceleration > 0
    set BurnTime to (TargetSpeed - CurrentSpeed) / acceleration.
  if acceleration > 0 and BurnTime >= eta:apoapsis * 2 and not(circPID:trigger) // turning the engine on and off
  {
    set circPID:trigger to true.
    clearscreen.
  }
  else if acceleration > 0 and BurnTime <= eta:apoapsis and periapsis < 0.99 * height and verticalSpeed > 0.1 
  {
    set circPID:trigger to false.
    if raise
    {
      if apoapsis > 0.97 * height and flight:twr > 0
        set flight:throttle to 1 / flight:twr.
      else
        set flight:throttle to 1.
    }
    else
      set flight:throttle to 0.
  }
  if not(circPID:trigger or raise)
  {
    set flight:pitch to 0.
    set circPID:p to 0.
    set circPID:d to 0.
    print "Waiting for burn: " + round(eta:apoapsis - BurnTime / 2, 0) + " s  " at(0, 33).
  }
  else if flight:twr > 0 // throttle and attitude control
  {
    if (periapsis + body:radius) > 0.95 * (height + body:radius)
      set flight:throttle to min(1 / flight:twr / 2, 1).
    else if not(raise) and eta:apoapsis < 0.5 * orbit:period
      set flight:throttle to min(burntime / eta:apoapsis / 2, 1).
    else
      set flight:throttle to 1.
    local VerticalAcc is vxcl(up:vector, velocity:orbit):sqrmagnitude / (body:radius + altitude) - body:mu / (body:radius + altitude) ^ 2.
    if -VerticalAcc / (acceleration * flight:throttle) < 1
      set circPID:p to arcSin(-VerticalAcc / (acceleration * flight:throttle)).
    else
      set circPID:p to 90.
    set circPID:d to min(-verticalSpeed, 2).
    local output is circPID:p * circPID:kp + circPID:d * circPID:kd.
    if verticalSpeed < 0
      set flight:pitch to min(45, max(0, output)).
    else
      set flight:pitch to 0.
  }
  if periapsis > 0.99 * height and (eta:apoapsis < 3 / 4 * orbit:period and eta:apoapsis > orbit:period / 4)
    return -1.
  return 4.
}

main().