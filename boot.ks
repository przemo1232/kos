local x is 0.
until x > 4
{
  print "Establishing connection to KSC...".
  if homeconnection:isconnected
    break.
  wait 1.
  set x to x + 1.
}
if x = 5
  print "Connection failed.".
else
{
  set x to 6.
  global newboot is "".
  set bootname to core:part:getmodule("kOSProcessor"):bootfilename.
  until x >= bootname:length
  {
    set newboot to newboot + bootname[x].
    set x to x + 1.
  }
  on newboot
  {
    set core:part:getmodule("kOSProcessor"):bootfilename to "/boot/" + newboot.
    copypath("boot/" + bootname, "boot/" + newboot).
    deletepath("boot/" + bootname).
    set bootname to newboot.
    return true.
  }
  copypath("0:/" + newboot, newboot).
  print "Connected and updated boot file.".
}
runpath(newboot).