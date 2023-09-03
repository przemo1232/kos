global function safeWarp // warp with a margin to correct heading (absolute time)
{
  parameter parameters. // lexicon("check", 0, "time", 0, "checkAligned", true)
  local warpTime is parameters:time - time:seconds.
  if warpTime > 181 // warp to 3 minutes early
  {
    if kuniverse:timewarp:rate = 1 and parameters:check >= 0
    {
      if abs(steeringManager:angleerror) < 0.5 or not(parameters:checkAligned)
        set parameters:check to parameters:check + 1.
      else
        set parameters:check to 0.
    }
    if parameters:check = 5
    {
      warpto(parameters:time - 180).
      set parameters:check to -1.
    }
  }
  else if warpTime > 16 and warpTime < 175 // correct heading and warp to 10 seconds early
  {
    if parameters:check > 0 and parameters:check < 5
      set parameters:check to 0.
    if kuniverse:timewarp:rate = 1 and parameters:check <= 0
    {
      if abs(steeringManager:angleerror) < 0.5 or not(parameters:checkAligned)
        set parameters:check to parameters:check - 1.
      else
        set parameters:check to 0.
    }
    if parameters:check = -5
    {
      warpto(parameters:time - 10).
      set parameters:check to 5.
    }
  }
  // else // resetting parameters
  // {
  //   set parameters:time to 0.
  //   set parameters:check to 0.
  //   set parameters:checkAligned to true.
  // }
}