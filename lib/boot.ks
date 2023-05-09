local function main
{
  wait until ship:unpacked.
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
  local y is 6.
  until y >= oldbootname:length
  {
    set bootname to bootname + oldbootname[y].
    set y to y + 1.
  }
  if x = 5
  {
    print "Connection failed".
    return bootname.
  }
  else
  {
    print "Connected".
    set y to 0.
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
        print "Updating boot file".
        copypath("0:/" + newboot, newboot).
        set core:part:getmodule("kOSProcessor"):bootfilename to "/boot/" + newboot.
        copypath("boot/" + bootname, "boot/" + newboot).
        deletepath("boot/" + bootname).
        deletepath(bootname).
        wait 1.
        reboot.
      }
      else
      {
        print "No file associated with this name".
        deletepath(newboot).
      }
    }
    else
      copypath("0:/" + bootname, bootname).
  }
  return bootname.
}
runpath(main()).