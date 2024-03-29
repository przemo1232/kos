// by przemo1232
// navigation to orbit with auto staging
// higher profile parameter means shallower ascent (it has to be bigger than 0)
// dependencies: /lib/staging.ks

@lazyGlobal off.

local function pidgenerator
{
  parameter reference, value, type is 0.
  local pid is lexicon(reference, value, "p", 0, "kp", 1, "i", 0, "ki", 1, "d", 0, "kd", 1, "lastp", 0, "lasttime", 0).
  if type = 2
  {
    pid:add("lasti", 0).
    pid:add("kp2", 1).
  }
  return pid.
}

local function main
{
  if not(exists("/lib/staging.ks"))
    copypath("0:/lib/staging.ks", "/lib/staging.ks").
  runOncePath("/lib/staging.ks").
  if not(exists("/lib/warp.ks"))
    copypath("0:/lib/warp.ks", "/lib/warp.ks").
  runOncePath("/lib/warp.ks").
  set terminal:height to 36.
  set terminal:width to 50.
  if not (status = "landed" or status = "prelaunch")
  {
    print "Vessel is not landed".
    return.
  }
  local height is 0.
  local targetAp is 0.
  local ArgofPe is 0.
  local inclination is 0.
  local LongofAN is 0.
  local RCSToggle is false.
  local FairingSep is 0.
  local autoWarp is true.
  local thrustLimit is 0.
  local StartTurn is 0.
  local profile is 0.
  local margin is 1e4.
  // maingui
  clearguis().
  local check is false.
  local maingui is gui(-300, 300).
  set maingui:style:width to 300.
  // compartments
  local compartments is maingui:addhlayout().
  local readoutscontainer is compartments:addvlayout().
  local readouts is readoutscontainer:addhlayout().
  local options is compartments:addvlayout().
  local tools is compartments:addvlayout().
  local dev is compartments:addvlayout().
  // readouts
  readouts:hide().
  local leftread1 is readouts:addvlayout().
  set leftread1:style:width to 100.
  local leftread2 is readouts:addvlayout().
  set leftread2:style:width to 90.
  readouts:addspacing(40).
  local rightread1 is readouts:addvlayout().
  set rightread1:style:width to 80.
  local rightread2 is readouts:addvlayout().
  set rightread2:style:width to 90.
  local waiting is readoutscontainer:addlabel("").
  // leftread
  leftread1:addlabel("Current Stage").
  local stageread is leftread2:addtextfield("0").
  leftread1:addlabel("Throttle").
  local throttleread is leftread2:addtextfield("0").
  leftread1:addlabel("Acceleration").
  local accelerationread is leftread2:addtextfield("0").
  leftread1:addlabel("Pitch").
  local pitchread is leftread2:addtextfield("0").
  leftread1:addlabel("Heading").
  local headingread is leftread2:addtextfield("0").
  for x in leftread2:widgets
    set x:style:align to "right".
  // rightread
  rightread1:addlabel("Apoapsis").
  local apoapsisread is rightread2:addtextfield("0").
  rightread1:addlabel("Periapsis").
  local periapsisread is rightread2:addtextfield("0").
  rightread1:addlabel("Inclination").
  local inclinationread is rightread2:addtextfield("0").
  rightread1:addlabel("Ln. of AN").
  local LnofANread is rightread2:addtextfield("0").
  rightread1:addlabel("Arg of Pe").
  local ArgofPeread is rightread2:addtextfield("0").
  for x in rightread2:widgets
    set x:style:align to "right".
  // options
  local tabs is options:addhlayout().
  local simplebutton is tabs:addbutton("Simple").
  local advancedbutton is tabs:addbutton("Advanced").
  set simplebutton:pressed to true.
  local simple is options:addvlayout().
  local advanced is options:addvlayout().
  options:addlabel("Thrust limit on ascent (nothing means no limit)").
  local inputThrustLimit is options:addtextfield("").
  options:addlabel("Ascent guidance start altitude").
  local inputStartTurn is options:addtextfield("0").
  local inputRCSToggle is options:addcheckbox("Toggle RCS above atmosphere?", false).
  local inputWarp is options:addcheckbox("Auto warp?", true).
  local inputFairingSep is options:addcheckbox("Activate action 10 above atmosphere?", true).
  options:addspacing(30).
  local ready is options:addbutton("Ready"). 
  // dev
  dev:hide().
  set dev:style:width to 200.
  dev:addlabel("Ascent profile multiplier").
  local inputProfile is dev:addtextfield("5").
  dev:addlabel("<color=orange><b>Changing those parameters can cause the script to malfunction</b></color>").
  dev:addlabel("P").
  local inputP is dev:addtextfield("5").
  dev:addlabel("I").
  local inputI is dev:addtextfield("0.5").
  dev:addlabel("D").
  local inputD is dev:addtextfield("2").
  dev:addlabel("throttle limit").
  local inputThrottleLimit is dev:addtextfield("0.05").
  // simple
  simple:addlabel("Height").
  local inputHeight is simple:addtextfield((body:atm:height + 1e4):tostring).
  simple:addlabel("Inclination").
  local inputInclination is simple:addtextfield(ceiling(abs(latitude), 1):tostring).
  // advanced
  advanced:addlabel("Periapsis").
  local inputPeriapsis is advanced:addtextfield((body:atm:height + 1e4):tostring).
  advanced:addlabel("Apoapsis").
  local inputApoapsis is advanced:addtextfield((body:atm:height + 1e4):tostring).
  advanced:addlabel("Argument of periapsis").
  local inputArgofPe is advanced:addtextfield("0").
  advanced:addlabel("Inclination").
  local inputInclinationAdv is advanced:addtextfield(ceiling(abs(latitude), 1):tostring).
  advanced:addlabel("Longitude of ascending node," + char(10) + "leave empty to launch now").
  local inputLongofAN is advanced:addtextfield("").
  advanced:hide().
  // tools
  set tools:style:width to 30.
  local minimize is tools:addbutton("_").
  set minimize:style:width to 0.
  minimize:hide().
  local devbutton is tools:addbutton(">").
  set devbutton:style:width to 0.
  maingui:show().
  // user input
  until check
  {
    local adv is 0.
    until ready:takepress
    {
      if simplebutton:pressed and advanced:visible
      {
        advancedbutton:takepress.
        advanced:hide().
        simple:show().
      }
      if advancedbutton:pressed and simple:visible
      {
        simplebutton:takepress.
        simple:hide().
        advanced:show().
      }
      if devbutton:takepress
      {
        if dev:visible
        {
          set maingui:style:width to 300.
          dev:hide().
          set devbutton:text to ">".
        }
        else
        {
          set maingui:style:width to 500.
          dev:show().
          set devbutton:text to "<".
        }
      }
    }
    set check to true.
    if simple:visible
    {
      set height to inputHeight:text:tonumber(-1).
      set targetAp to height.
    }
    else
      set height to inputPeriapsis:text:tonumber(-1).
    set targetAp to inputApoapsis:text:tonumber(-1).
    set ArgofPe to inputArgofPe:text:tonumber(-1).
    if simple:visible
      set inclination to inputInclination:text:tonumber(200).
    else
      set inclination to inputInclinationAdv:text:tonumber(200).
    set LongofAN to (choose 666 if inputLongofAN:text = "" else inputLongofAN:text:tonumber(-1)).
    set RCSToggle to inputRCSToggle:pressed.
    if inputFairingSep:pressed
      set FairingSep to 3.
    set autoWarp to inputWarp:pressed.
    set thrustLimit to (choose 9000 if inputThrustLimit:text = "" else inputThrustLimit:text:tonumber(-1)).
    set StartTurn to inputStartTurn:text:tonumber(-1).
    set profile to inputProfile:text:tonumber(-1).
    //fail conditions
    if height < body:atm:height
    {
      set check to false.
      hudtext("Incorrect height, must be at least " + (body:atm:height), 10, 2, 24, red, false).
    }
    if inclination < ceiling(abs(latitude), 1) or inclination > 180 - ceiling(abs(latitude), 1)
    {
      set check to false.
      hudtext("Incorrect inclination, must be between " + ceiling(abs(latitude), 1) + " and " + (180 - ceiling(abs(latitude), 1)), 10, 2, 24, red, false).
    }
    if thrustLimit <= 1
    {
      set check to false.
      hudtext("Incorrect thrust limit, must be greater than 1", 10, 2, 24, red, false).
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
    if advanced:visible
    {
      if targetAp < height
      {
        set check to false.
        hudtext("Incorrect apoapsis, must be no lower than periapsis", 10, 2, 24, red, false).
      }
      if ArgofPe < 0 or ArgofPe >= 360
      {
        set check to false.
        hudtext("Incorrect argument of periapsis, must be between 0 and 360", 10, 2, 24, red, false).
      }
      if (LongofAN < 0 or LongofAN >= 360) and longOfAN <> 666
      {
        set check to false.
        hudtext("Incorrect longitude of ascending node, must be between 0 and 360", 10, 2, 24, red, false).
      }
    }
  }
  readouts:show().
  options:hide().
  dev:hide().
  devbutton:hide().
  minimize:show().
  set maingui:style:width to 444.
  set maingui:style:height to 180.
  // initialization
  local setupTime is time:seconds.
  hudtext("setting up, please wait", 1, 2, 20, yellow, false).
  local flight is lexicon("azimuth", -ship:bearing, "pitch", 90, "profile", profile, "upwards", true, "LastLatitude", latitude,
  "throttle", 0, "margin", margin, "twr", 0, "StartTurn", StartTurn, "yeet", heading(-ship:bearing, 90), "autoWarp", autoWarp,
  "trigger", true, "lastAcceleration", 0, "timeToManeuver", 0, "thrustloss", false, "counter", missionTime,
  "thrustLimit", thrustLimit, "startHeight", altitude, "throttleLimit", inputThrottleLimit:text:tonumber, "startTime", missionTime).
  local targetOrbit is lexicon("periapsis", height, "apoapsis", targetAp, "inclination", inclination,
  "longofAN", LongofAN, "argofPe", ArgofPe, "semiMajorAxis", (height + targetAp + 2 * body:radius) / 2,
  "CurrentSpeed", 0, "TargetSpeed", 0, "OrbitType", 0, "targetSpeed", 0).
  local warpParameters is lexicon("check", 0, "time", 0, "checkAligned", true).
  if advanced:visible
    set targetOrbit:OrbitType to 1.
  local phase is 0.
  local finished is false.
  local CircPID is pidgenerator("UpSpeed", 0).
  local PitchPID is pidgenerator("TargetPitch", 90, 2).
  set PitchPID:kp to inputP:text:tonumber.
  set PitchPID:ki to inputI:text:tonumber.
  set PitchPID:kd to inputD:text:tonumber.
  set PitchPID:kp2 to PitchPID:kp / 5.
  local gravity is 0.
  local acceleration is 0.
  local curacc is 0.
  local delay is 0.
  lock throttle to flight:throttle.
  lock steering to flight:yeet.
  local shouldStage is false.
  local stagingList is stagingSetup().
  hudtext("setup done in " + round((time:seconds - setuptime), 2):tostring + " s", 1, 2, 20, yellow, true).
  wait 1.
  // finish initialization, begin main loop
  until finished
  {
    // gui
    if minimize:takepress
    {
      if minimize:text = "_"
      {
        set minimize:text to "[]".
        readoutscontainer:hide().
        set maingui:style:width to 44.
        set maingui:style:height to 50.
        set maingui:x to maingui:x + 400.
      }
      else
      {
        set minimize:text to "_".
        readoutscontainer:show().
        set maingui:style:width to 444.
        set maingui:style:height to 180.
        set maingui:x to maingui:x - 400.
      }
    }
    // updates
    sas off.
    set gravity to body:mu / (body:radius + altitude) ^ 2.
    set flight:lastAcceleration to acceleration.
    set acceleration to ship:availablethrust / ship:mass.
    set curacc to acceleration * min(flight:throttle, 1).
    set flight:twr to acceleration / gravity.
    // readouts
    set stageread:text to ship:stagenum:tostring.
    set throttleread:text to max(min(round(flight:throttle, 2), 1), 0):tostring.
    set accelerationread:text to round(curacc, 2):tostring + " m/s²".
    set pitchread:text to round(flight:pitch, 2):tostring.
    set headingread:text to round(flight:azimuth, 2):tostring.
    set apoapsisread:text to round((apoapsis / 1000), 1):tostring + " km".
    set periapsisread:text to round((periapsis / 1000), 1):tostring + " km".
    set inclinationread:text to round(orbit:inclination, 2):tostring.
    set LnofANread:text to round(orbit:longitudeofascendingnode, 1):tostring.
    set ArgofPeread:text to round(orbit:argumentofperiapsis, 1):tostring.
    // end readouts
    if phase > 0
    {
      set shouldStage to autoStaging(stagingList).
      if shouldStage
      {
        set flight:throttle to 0.
        stage.
      }
      if FairingSep > 0 and altitude > body:atm:height
      {
        toggle ag10.
        set FairingSep to FairingSep - 1.
      }
    }
    if phase > 0 and ship:bounds:bottomaltradar > flight:StartTurn
    {
      Direction(flight, inclination, phase).
    }
    if phase < 4
    {
      set flight:yeet to heading(flight:azimuth, flight:pitch).
    }
    if phase = 0
    {
      set phase to Countdown(flight, targetOrbit, waiting, warpParameters).
      if phase >= 1
      {
        set flight:counter to missionTime.
        set flight:timeToManeuver to 0.
      }
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
    if phase >= 4
    {
      if RCSToggle and abs(steeringManager:angleerror) > 0.5 and curacc = 0
        rcs on.
      else
        rcs off.
    }
    if phase = 4
    {
      set phase to Circularization(flight, targetOrbit, acceleration, CircPID, waiting, warpParameters).
      if phase = 5
      {
        set flight:trigger to false.
        set delay to missionTime.
        if targetOrbit:OrbitType = 0
          set phase to -1.
      }
    }
    if phase = 5 and missionTime > delay + 1
    {
      set phase to OrbitFinish(flight, targetOrbit, waiting, acceleration, warpParameters).
    }
    if phase = -1
    {
      unlock steering.
      set flight:throttle to 0.
      set finished to true.
      hudtext("Orbit achieved, ending script.", 10, 2, 24, green, false).
      wait 0.1.
      set periapsisread:text to round(periapsis / 1000, 1):tostring + " km".
      set apoapsisread:text to round(apoapsis / 1000, 1):tostring + " km".
      rcs off.
      wait 10.
      maingui:dispose().
    }
    wait 0.
  }
}

local function Countdown
{
  parameter flight, targetOrbit, waiting, warpParameters.
  if flight:timeToManeuver = 0 and targetOrbit:OrbitType = 1 and targetOrbit:longOfAN <> 666
    set flight:timeToManeuver to StartAngle(targetOrbit, flight).
  if time:seconds > flight:timeToManeuver - 6
  {
    local x is 5.
    set waiting:text to "".
    until x <= 0
    {
      hudtext("T-" + x, 1, 2, 36, yellow, false).
      set x to x - 1.
      wait 1.
    }
    set flight:throttle to 1.
    if body:atm:exists
      return 1.
    return 1.5.
  }
  else
  {
    set waiting:text to "Waiting for correct alignment: " + round((flight:timeToManeuver - time:seconds), 0):tostring + " s".
    if flight:autoWarp
    {
      if warpParameters:time = 0
        set warpParameters:time to flight:timeToManeuver.
      set warpParameters:checkAligned to false.
      safewarp(warpParameters).
    }
  }
}

local function AtmosphericFlight // steering while in atmosphere
{
  parameter flight, pitchPID.
  local temp is altitude - flight:startHeight.
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
      set pitchPID:LastTime to CurrentTime.
    set output to pitchPID:TargetPitch + pitchPID:p * (choose pitchPID:kp if pitchPID:targetPitch < 85 else pitchPID:kp2) + pitchPID:i * pitchPID:ki + pitchPID:d * pitchPID:kd.
    if ship:velocity:surface:mag > 10
      set flight:pitch to max(0, min(90, max(vector - 10, min(vector + 20, output)))).
    else
      set flight:pitch to 90.
  }
  if body:atm:altitudepressure(altitude) > 0.001 and flight:twr > 0 // throttle control
  {
    if altitude > body:atm:height / 20
    {
      local thrt is 1 + (output - pitchPID:TargetPitch + 2) * flight:throttleLimit.
      set flight:throttle to min(flight:thrustLimit / flight:twr, max(1 / flight:twr, thrt)).
    }
    else
      set flight:throttle to flight:thrustLimit / flight:twr.
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
  return 1.
  // local radius is body:radius + altitude.
  // if flight:StartTurn < 100
  //   set flight:StartTurn to 100.
  // if ship:bounds:bottomaltradar > flight:StartTurn and flight:twr > 0
  // {
  //   if gear
  //     toggle gear.
  //   set flight:throttle to 1 / flight:twr * 10.
  //   if flight:twr > 5
  //     set flight:pitch to arcSin((1.5 - (vxcl(up:vector, velocity:orbit):sqrmagnitude / radius) / (body:mu / radius ^ 2)) / 5).
  //   else
  //     set flight:pitch to arcSin(1.5 / flight:twr).
  // }
  // else
  //   set flight:throttle to 1 / flight:twr * 2.
  // if apoapsis > flight:margin
  //   return 4.
  // return 1.5.
}

local function Direction // azimuth control
{
  parameter flight, inclination, phase.
  if missionTime > flight:counter + 1
  {
    local scaling is 10.
    local temp is orbit:inclination.
    local temp2 is abs(latitude).
    local maxLatitude is (choose inclination if inclination <= 90 else 180 - inclination).
    local compensation is 0.
    if inclination - 0.1 > temp
    {
      if inclination > temp // compensation for initial speed
        set compensation to scaling * sin(inclination - temp) ^ 0.2.
      else
        set compensation to -scaling * sin(temp - inclination) ^ 0.2.
    }
    else
      set compensation to 10 * (inclination - temp).
    if temp2 <= maxLatitude // what heading i should have
    {
      if flight:upwards
        set flight:azimuth to arcsin(cos(inclination) / cos(temp2)) - compensation.
      else
        set flight:azimuth to -arcsin(cos(inclination) / cos(temp2)) + 180 + compensation.
      if flight:azimuth < 0
        set flight:azimuth to flight:azimuth + 360.
      if (flight:upwards and flight:azimuth > 90 and flight:azimuth < 180) or (not(flight:upwards) and flight:azimuth < 90)
        set flight:azimuth to 90.
      if (flight:upwards and flight:azimuth > 180 and flight:azimuth < 270) or (not(flight:upwards) and flight:azimuth > 270)
        set flight:azimuth to 270.
    }
    if phase >= 2 or temp2 > 0.999 * maxLatitude
    {
      if flight:LastLatitude > latitude or latitude > maxLatitude // whether i'm going north or south
        set flight:upwards to false.
      if flight:LastLatitude < latitude or latitude < -maxLatitude
        set flight:upwards to true.
      set flight:LastLatitude to latitude.
    }
    set flight:counter to missionTime.
  }
}

local function Circularization // circularizing the orbit
{
  parameter flight, targetOrbit, acceleration, circPID, waiting, warpParameters.
  local raise is (apoapsis < targetOrbit:periapsis). // raising the ap
  local CurrentSpeed is velocityat(ship, time() + eta:apoapsis):orbit:mag.
  local sqrTargetSpeed is body:mu / (body:radius + targetOrbit:periapsis).
  local TargetSpeed is sqrt(sqrTargetSpeed).
  local speedDiff is TargetSpeed - CurrentSpeed.
  local BurnTime is 0.
  if altitude < targetOrbit:periapsis and apoapsis > targetOrbit:periapsis
    set flight:trigger to false.
  if acceleration > 0
  {
    set BurnTime to speedDiff / acceleration.
    if BurnTime >= eta:apoapsis * 2 or verticalSpeed < 0 // turning the engine on and off
      set flight:trigger to true.
    else if BurnTime <= eta:apoapsis * 1.5 and periapsis < 0.99 * targetOrbit:periapsis and verticalSpeed > 0.1
    {
      set flight:trigger to false.
      if raise
      {
        if apoapsis > 0.95 * targetOrbit:periapsis and flight:twr > 0
          set flight:throttle to 1 / flight:twr.
        else
          set flight:throttle to 1.
      }
      else
        set flight:throttle to 0.
    }
  }
  if not(flight:trigger or raise) // auto warp
  {
    set circPID:p to 0.
    set circPID:d to 0.
    if warpParameters:time = 0
      set warpParameters:time to time:seconds + eta:apoapsis - BurnTime / 2.
    local temp is round(eta:apoapsis - BurnTime / 2, 0).
    if altitude > body:atm:height
      set flight:yeet to vxcl(positionat(ship, time() + temp) - body:position, velocityat(ship, time() + temp):orbit).
    else
      set flight:yeet to srfPrograde.
    set waiting:text to "Waiting for circularization burn: " + temp:tostring + " s".
    if temp < 1
      set waiting:text to "".
    if flight:autowarp and altitude > body:atm:height
      safeWarp(warpParameters).
  }
  else if acceleration > 0 // throttle and attitude control
  {
    set waiting:text to "".
    if (periapsis + body:radius) > 0.95 * (targetOrbit:periapsis + body:radius)
      set flight:throttle to max(1 / acceleration, speedDiff / 2 / acceleration).
    else if not(raise)
      set flight:throttle to 1.
    local VerticalAcc is vxcl(up:vector, velocity:orbit):sqrmagnitude / (body:radius + altitude) - body:mu / (body:radius + altitude) ^ 2.
    if flight:throttle <> 0 and -VerticalAcc / (acceleration * flight:throttle) < 1
      set circPID:p to arcSin(-VerticalAcc / (acceleration * flight:throttle)).
    else
      set circPID:p to 90.
    set circPID:d to min(-verticalSpeed, 2).
    set circPID:kd to 1/flight:twr.
    local output is circPID:p * circPID:kp + circPID:d * circPID:kd.
      set flight:yeet to heading(flight:azimuth, min(45, max(0, output))).
  }
  if acceleration = 0
    set flight:throttle to 1.
  if periapsis > targetOrbit:periapsis
  {
    set flight:throttle to 0.
    return 5.
  }
  return 4.
}

local function OrbitFinish // raising the ap
{
  parameter flight, targetOrbit, waiting, acceleration, warpParameters.
  if flight:timeToManeuver = 0
  {
    set flight:timeToManeuver to timetoanomaly(orbit:trueanomaly, targetOrbit:ArgofPe - orbit:argumentofperiapsis) + time:seconds.
    set targetOrbit:targetSpeed to sqrt(body:mu * (2 / (body:radius + targetOrbit:periapsis) - 1 / targetOrbit:semiMajorAxis)).
  }
  local currentSpeed is sqrt(body:mu * (2 / (body:radius + targetOrbit:periapsis) - 1 / orbit:semiMajorAxis)).
  local speedDiff is targetOrbit:targetSpeed - currentSpeed.
  local BurnTime is 0.
  if acceleration > 0
    set BurnTime to speedDiff / acceleration.
  local TimetoBurn is flight:timeToManeuver - time:seconds - BurnTime / 2.
  if acceleration > 0 and TimetoBurn <= 0 and not(TimetoBurn < -1 and not(flight:trigger)) // igniting the engine and throttle control
  {
    set flight:trigger to true.
    set flight:throttle to max(1 / acceleration, speedDiff / 2 / acceleration).
  }
  if not(flight:trigger) // auto warp
  {
    local temp is round(TimetoBurn, 0).
    set flight:yeet to velocityat(ship, flight:TimetoManeuver):orbit.
    set waiting:text to "Waiting for Ap raise burn: " + temp:tostring + " s".
    if temp < 1
      set waiting:text to "".
    if warpParameters:time = 0
      set warpParameters:time to time:seconds + timeToBurn.
    if flight:autowarp
      safeWarp(warpParameters).
  }
  local argofpe is orbit:argumentofperiapsis.
  until argofpe > targetOrbit:argofPe
    set argofpe to argofpe + 360.
  if acceleration < flight:lastacceleration * 0.8
    set flight:thrustloss to true.
  if flight:thrustloss and argofpe < (180 + targetOrbit:argofPe) // going an extra orbit in case of loss of thrust
  {
    set flight:trigger to false.
    set flight:throttle to 0.
    set warpParameters:check to 0.
    set flight:timeToManeuver to 0.
    set flight:thrustloss to false.
    hudtext("Loss of thrust, waiting an orbit", 10, 2, 24, green, false).
  }
  if currentSpeed > targetOrbit:targetSpeed or apoapsis > targetOrbit:apoapsis
  {
    set flight:throttle to 0.
    return -1.
  }
  return 5.
}

local function eccentricanomaly // eccentric from true
{
  parameter trueanomaly.
  until trueanomaly > -180 and trueanomaly <= 180
    set trueanomaly to trueanomaly + (choose 360 if trueanomaly <= -180 else -360).
  local temp is orbit:eccentricity.
  local e is 0.
  if temp + cos(trueanomaly) <> 0
  {
    set e to arctan(sqrt(1-temp^2)*sin(trueanomaly)/(temp+cos(trueanomaly))).
    if temp + cos(trueanomaly) < 0
      set e to choose e+180 if trueanomaly > 0 else e-180.
  }
  else
    set e to choose 180 if trueanomaly > 0 else -180.
  return e.
}

local function meananomaly // mean from true
{
  parameter trueanomaly.
  local e is eccentricanomaly(trueanomaly).
  local m is e-orbit:eccentricity*sin(e)*constant:radtodeg.
  return m.
}

local function timetoanomaly // time between two true anomalies
{
  parameter start, finish.
  local mean1 is meananomaly(start).
  local mean2 is meananomaly(finish).
  return orbit:period*(choose mean2-mean1 if mean2 > mean1 else mean2-mean1+360)/360.
}

local function StartAngle // start longitude from spherical triagles
{
  parameter targetOrbit, flight.
  local alpha is targetOrbit:inclination.
  local angle is 0.
  if alpha <> 90
  {
    local beta is arcsin(cos(alpha) / cos(latitude)).
    local c is 0.
    if abs((cos(alpha)*cos(beta))/(sin(alpha)*sin(beta))) < 1
      set c to arccos((cos(alpha)*cos(beta))/(sin(alpha)*sin(beta))).
    local b is 90.
    local a is 90 - latitude.
    set angle to arccos((cos(c)-cos(a)*cos(b))/(sin(a)*sin(b))).
  }
  local endangle is targetOrbit:longofAN + angle - body:rotationangle - longitude.
  if (alpha > 90 and latitude >= 0) or (alpha <= 90 and latitude < 0)
    set endangle to endangle - 2 * angle.
  until endangle >= 0 and endangle < 360
    set endangle to endangle + (choose 360 if endangle < 0 else -360).
  local endangle2 is endangle - 180 + 2 * angle.
  if alpha <= 90
    set endangle2 to endangle + 180 - 2 * angle.
  until endangle2 >= 0 and endangle2 < 360
    set endangle2 to endangle2 + (choose 360 if endangle2 < 0 else -360).
  if endangle2 < endangle
    set flight:upwards to false.
  return ((choose endangle2 if endangle2 < endangle else endangle) - 1) * body:rotationperiod / 360 + time:seconds.
}

main().