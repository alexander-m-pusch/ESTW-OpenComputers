local tile = {}

local tilebuffer = {}

--posX und posY in tilespace, NICHT screenspace
local function generateNullTile(posX, posY, bgcol_true)
  local tile = {
    ["x"] = posX,
    ["y"] = posY,
    ["dirty"] = true,
    ["bgcol"] = bgcol_true,
    ["data"] = {},
  }
  for y = 1, 5 do
    tile["data"][y] = {}
    for x = 1, 5 do
      tile["data"][y][x] = {
        ["fgcol"] = 0xFFFFFF,
        ["bgcol"] = 0x000000,
        ["char"] = " ",
      }
    end
  end

  return tile
end

function tile:new(gpuaddr, screenaddr, topline, tileset)
  local component = require("component")

  local o = {
    ["gpu"] = component.proxy(gpuaddr),
    ["screen"] = screenaddr,
    ["topline"] = topline,
    ["tileset"] = tileset,
  }
  
  setmetatable(o, tile)
  self.__index = self

  local sizeX, sizeY = o["gpu"].getResolution()
  
  local bgcol = false

  local bottomY = math.floor((sizeY - o["topline"]) / 5)
  local rightX = math.floor(sizeX / 5)

  o["bottomY"] = bottomY
  o["rightX"] = rightX

  for y = 1, bottomY do
    local ygoug = false
    if y % 2 == 0 then
      ygoug = true
    end
    for x = 1, rightX do
      local index = y * rightX + x
      
      local xgoug = false
      if x % 2 == 0 then
        xgoug = true
      end

      if ygoug then
        if xgoug then
          bgcol = true
        else
          bgcol = false
        end
      else
        if xgoug then
          bgcol = false
        else
          bgcol = true
        end
      end

      tilebuffer[index] = generateNullTile(x, y, bgcol)
    end
  end

  return o
end

function tile:place(name, x, y)
  local index = y * self["rightX"] + x

  if not tilebuffer[index]["data"] then
    error("Tile existiert nicht!")
  end

  if not self["tileset"][name] then
    error("Ungültiger Kachelname: " .. name)
  end

  for y = 1, 5 do
    for x = 1, 5 do
      tilebuffer[index]["data"][y][x]["bgcol"] = self["tileset"][name][y][x]["bgcol"]
      tilebuffer[index]["data"][y][x]["fgcol"] = self["tileset"][name][y][x]["fgcol"]
      tilebuffer[index]["data"][y][x]["char"] = self["tileset"][name][y][x]["char"]
    end
  end
  tilebuffer[index]["dirty"] = true
end

function tile:redrawArea(x1, y1, x2, y2)
  if (not x1) or (not y1) or (not x2) or (not y2) then return end
  local x1tilespace = (math.floor(x1 / 5))
  local x2tilespace = (math.floor(x2 / 5) + 1)
  local y1tilespace = (math.floor((y1 - self["topline"]) / 5))
  local y2tilespace = (math.floor((y2 - self["topline"]) / 5) + 1)

  if y1tilespace <= 0 then y1tilespace = 1 end
  if y2tilespace <= 0 then y2tilespace = 1 end

  for x = x1tilespace, x2tilespace do
    for y = y1tilespace, y2tilespace do
      local index = y * self["rightX"] + x
      if tilebuffer[index] then
        tilebuffer[index]["dirty"] = true
      end
    end
  end

  self:render()
end

function tile:redrawTile(x, y)
  local index = y * self["rightX"] + x
  if tilebuffer[index] then
    tilebuffer[index]["dirty"] = true
  end
end

function tile:toTileCoords(x, y)
  return math.floor(x / 5) + 1, math.floor((y - self["topline"]) / 5) + 1
end

function tile:render()
  self["gpu"].bind(self["screen"])
  self["gpu"].setDepth(self["gpu"].maxDepth())

  --als erstes: hintergrund rendern
  --als zweites: overlay rendern

  local topY = self["topline"]

  for _, tile in pairs(tilebuffer) do
    if tile["dirty"] then
      for y = 1, 5 do
        for x = 1, 5 do
          if tile["bgcol"] and (tile["data"][y][x]["bgcol"] == 0x000000) then
            self["gpu"].setBackground(0x0f0f0f)
          else
            self["gpu"].setBackground(tile["data"][y][x]["bgcol"])
          end
          self["gpu"].setForeground(tile["data"][y][x]["fgcol"])
          
          self["gpu"].set(((tile["x"] - 1) * 5) + x, ((tile["y"] - 1) * 5) + topY + y, tile["data"][y][x]["char"])
        end
      end
      tile["dirty"] = false
    end
  end
end

return tile
