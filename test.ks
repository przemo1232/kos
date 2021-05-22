parameter height is 11, width is 11.
clearguis().
set options to gui(32 * width, 37 * height).
for x in range(height)
{
  options:addhlayout().
  for y in range(width)
  {
    options:widgets[x]:addcheckbox("", false).
    local temp is options:widgets[x]:widgets[y]:style.
    set temp:height to 0.
    set temp:width to 0.
  }
}
local start is options:addbutton("start").
options:show().
wait until start:takepress.
set start:text to "stop".
local gameStatus is list().
for x in range(height)
{
  gameStatus:add(list()).
  for y in range(width)
  {
    gameStatus[x]:add(options:widgets[x]:widgets[y]:pressed).
  }
}
until false
{
  if start:takepress
    break.
  for x in range(height)
  {
    for y in range(width)
    {
      local neighbours is 0.
      local upwards is 0.
      local sideways is 0.
      if true
      {
        if x > 0
        {
          if options:widgets[x-1]:widgets[y]:pressed = true
            set neighbours to neighbours + 1.
        }
        else set upwards to 1.
        if x < height - 1
        {
          if options:widgets[x+1]:widgets[y]:pressed = true
            set neighbours to neighbours + 1.
        }
        else set upwards to -1.
        if y > 0
        {
          if options:widgets[x]:widgets[y-1]:pressed = true
            set neighbours to neighbours + 1.
        }
        else set sideways to -1.
        if y < width - 1
        {
          if options:widgets[x]:widgets[y+1]:pressed = true
            set neighbours to neighbours + 1.
        }
        else set sideways to 1.
        if upwards >= 0
        {
          if sideways >= 0
            if options:widgets[x+1]:widgets[y-1]:pressed = true
              set neighbours to neighbours + 1.
          if sideways <= 0
            if options:widgets[x+1]:widgets[y+1]:pressed = true
              set neighbours to neighbours + 1.
        }
        if upwards <= 0
        {
          if sideways >= 0
            if options:widgets[x-1]:widgets[y-1]:pressed = true
              set neighbours to neighbours + 1.
          if sideways <= 0
            if options:widgets[x-1]:widgets[y+1]:pressed = true
              set neighbours to neighbours + 1.
        }
      }
      if neighbours > 3 or neighbours < 2
        set gameStatus[x][y] to false.
      if neighbours = 3
        set gameStatus[x][y] to true.
    }
  }
  for x in range(height)
  {
    for y in range(width)
    {
      set options:widgets[x]:widgets[y]:pressed to gameStatus[x][y].
    }
  }
}