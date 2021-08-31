local x is 0.
until x > 4
{
  print "Establishing connection to KSC...".
  if homeconnection:isconnected
    break.
  wait 1.
  set x to x + 1.
}
local oldbootname is core:part:getmodule("kOSProcessor"):bootfilename.
local bootname is "".
set x to 6.
until x >= oldbootname:length
{
  set bootname to bootname + oldbootname[x].
  set x to x + 1.
}
if x = 5
  print "Connection failed".
else
{
  print "Connected".
  local y is 0.
  local newboot is "".
  local files is core:part:getmodule("kOSProcessor"):volume:files.
  until y >= files:length
  {
    if files:values[y]:size = 0
      set newboot to files:values[y]:name.
    set y to y + 1.
  }
  if newboot <> bootname and newboot <> ""
  {
    if exists("0:/" + newboot)
    {
      set core:part:getmodule("kOSProcessor"):bootfilename to "/boot/" + newboot.
      copypath("boot/" + bootname, "boot/" + newboot).
      deletepath("boot/" + bootname).
      deletepath(bootname).
      copypath("0:/" + newboot, newboot).
      print "Updating boot file".
      wait 1.
      reboot.
    }
    else
    {
      print "No file associated with this name".
      deletepath(newboot).
    }
  }
}
runpath(bootname).