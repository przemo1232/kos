function ListActiveEngines
{
  local result is list().
  LIST ENGINES IN engLst.
  FOR eng IN engLst
  {
    IF eng:IGNITION
    {
      result:ADD(eng).
    }
  }
  RETURN result.
}

function EnginesConsumption
{
  parameter engLst is ListActiveEngines().
  local result is 0.
  FOR eng IN engLst
  {
    set result to result + eng:MAXMASSFLOW.
  }
  RETURN result.
}

set fuelflow to EnginesConsumption(ListActiveEngines()).
clearscreen.
until false
{
  set startmass to ship:mass.
  set gravity to body:mu / (body:radius + altitude) ^ 2.
  set srfgravity to body:mu / body:radius ^ 2.
  set finalv to sqrt(2 * (body:mu / (body:radius + altitude - ship:bounds:bottomaltradar) - body:mu / (body:radius + altitude)) + ship:verticalspeed ^ 2).
  set burntime to startmass * (1 - 1 / constant:e ^ (finalv * fuelflow / ship:availablethrust)) / fuelflow.
  set suicideburn to (finalv + burntime * srfgravity) * burntime / 2. // this whole thing has some sort of error but let's just say it gives a safety margin instead
  if suicideburn >= ship:bounds:bottomaltradar
  {
    lock throttle to 1.
    set burntimefin to missionTime.
  }
  if ship:verticalSpeed >= 0 and throttle = 1
  {
    lock throttle to 0.
    print "final burn time: " + (missionTime - burntimefin) at(0, 9).
  }
  else
  {
    print "suicide burn altitude: " + (suicideburn + altitude - ship:bounds:bottomaltradar) at(0, 0).
    print "suicide burn time: " + burntime at(0, 4).
    print "finalv: " + finalv at(0, 5).
    print "suicide burn deltav: " + (finalv + burntime * gravity) at(0, 6).
  }
}