local term = require("term")
term.clear()

print("Tileseteditor der ESTW-Software, geschrieben von Alexander 'ampericus' Pusch")
print("(C) 2022, verfügbar unter der GNU GPLv3")

local tileset = {}

local function newEmptyTile(name)
  tileset[name] = {}

  for y = 1, 5 do
    tileset[name][y] = {}
    for x = 1, 5 do
      tileset[name][y][x] = {
        ["bgcol"] = 0x000000,
        ["fgcol"] = 0xFFFFFF,
        ["char"] = " ",
      }
    end
  end
end

local function fixBrokenTiles()
  for _, val in pairs(tileset) do
    for y = 1, 5 do
      for x = 1, 5 do
        if val[y][x]["char"] == "" then
          val[y][x]["char"] = " "
        end
      end
    end
  end
end

local fs = require("filesystem")
local tsraw = nil

if fs.exists("/software/lib/libdraw/assets/tileset.tst") then
  local fh = io.open("/software/lib/libdraw/assets/tileset.tst", "r")
  fh:seek("set", 0)
  tsraw = fh:read("*a")
  fh:close()
end

local component = require("component")
local serialization = require("serialization")
local event = require("event")
local keyboard = require("keyboard")

if tsraw then
  tileset = serialization.unserialize(tsraw)
end

local currname = nil

print("Tile auswählen:")
local tilename = io.read()
if not tileset[tilename] then
  newEmptyTile(tilename)
end
currname = tilename

print("Bedienung:")
print("Pfeiltasten, um sich im Tile zu bewegen")
print("STRG-H um die Hintergrundfarbe des Pixels zu verändern")
print("STRG-V um die Vordergrundfarbe des Pixels zu verändern")
print("STRG-B um den Char des Pixels zu verändern")
print("STRG-F um das Tileset zu speichern")
print("STRG-E um den Editor (OHNE ZU SPEICHERN) zu beenden")
print("STRG-N um eine neue Tile anzulegen oder eine bestehende Tile auszuwählen")
print("STRG-K um eine bestehende Tile zu kopieren und unter neuem Namen anzulegen")

local function statuszeile(text)
  term.setCursor(1, 30)
  term.clearLine()
  local oldbg = component.gpu.getBackground()
  local oldfg = component.gpu.getForeground()
  component.gpu.setBackground(0x000000)
  component.gpu.setForeground(0xFFFFFF)
  print(text)

  component.gpu.setBackground(oldbg)
  component.gpu.setForeground(oldfg)
end

local function lesezeile()
  term.setCursor(1, 31)
  term.clearLine()
  return io.read()
end

local function tileRendern()
  local startx = 10
  local starty = 20

  for y = 1, 5 do
    for x = 1, 5 do
      component.gpu.setBackground(tileset[currname][y][x]["bgcol"])
      component.gpu.setForeground(tileset[currname][y][x]["fgcol"])
      component.gpu.set(x + startx, y + starty, tileset[currname][y][x]["char"])
    end
  end

  component.gpu.setBackground(0x000000)
  component.gpu.setForeground(0xFFFFFF)
end

local pixX = 1
local pixY = 1

local function speichern()
  statuszeile("Repariere beschädigte Tiles..")
  fixBrokenTiles()
  statuszeile("Fertig.")
  statuszeile("Speichere Tileset...")
  local fh = io.open("/software/lib/libdraw/assets/tileset.tst", "w")
  fh:write(serialization.serialize(tileset))
  fh:close()
  statuszeile("Gespeichert!")
end

local function pixelHintergrund()
  statuszeile("Hintergrundfarbe in RGB-Hex bitte:")
  tileset[currname][pixY][pixX]["bgcol"] = tonumber(lesezeile())
end

local function pixelVordergrund()
  statuszeile("Vordergrundfarbe in RGB-Hex bitte:")
  tileset[currname][pixY][pixX]["fgcol"] = tonumber(lesezeile())
end

local function pixelCharacter()
  statuszeile("Pixelcharacter bitte:")
  tileset[currname][pixY][pixX]["char"] = lesezeile()
end

local function tileAuswaehlen()
  statuszeile("Name bitte:")
  local name = lesezeile()
  if not tileset[name] then
    newEmptyTile(name)
  end

  currname = name
  statuszeile(name .. " ausgewählt.")
end

local function tileKopieren()
  statuszeile("Name Kopiervorlage bitte:")
  local vorlage = lesezeile()
  statuszeile("Name neues Element bitte:")
  local name = lesezeile()

  newEmptyTile(name)

  for y = 1, 5 do
    for x = 1, 5 do
      tileset[name][y][x]["bgcol"] = tileset[vorlage][y][x]["bgcol"]
      tileset[name][y][x]["fgcol"] = tileset[vorlage][y][x]["fgcol"]
      tileset[name][y][x]["char"] = tileset[vorlage][y][x]["char"]
    end
  end

  currname = name
  statuszeile(name .. " kopiert.")
end

local function leithilfeZeichnen()
  term.setCursor(10 + pixX, 20)
  term.clearLine()
  term.setCursor(10 + pixX, 20)
  print("|")
  term.setCursor(9, 21)
  term.clearLine()
  term.setCursor(9, 22)
  term.clearLine()
  term.setCursor(9, 23)
  term.clearLine()
  term.setCursor(9, 24)
  term.clearLine()
  term.setCursor(9, 25)
  term.clearLine()
  term.setCursor(9, 20 + pixY)
  print("-")
end

local function pixelVerschieben(dx, dy)
  pixX = pixX + dx
  pixY = pixY + dy

  if pixX >= 5 then
    pixX = 5
  end
  if pixX <= 0 then
    pixX = 1
  end
  if pixY >= 5 then
    pixY = 5
  end
  if pixY <= 0 then
    pixY = 1
  end

  term.setCursor(10 + pixX, 20 + pixY)

  leithilfeZeichnen()
end

pixelVerschieben(0, 0)
tileRendern()

while true do
  local ev, timid = event.pullMultiple("key_down", "timer") --das reicht uns schon

  if ev == "key_down" then
    if keyboard.isControlDown() then
      if keyboard.isKeyDown(keyboard.keys.h) then
      pixelHintergrund()
        pixelVerschieben(0, 0)
      elseif keyboard.isKeyDown(keyboard.keys.v) then
        pixelVordergrund()
        pixelVerschieben(0, 0)
      elseif keyboard.isKeyDown(keyboard.keys.b) then
        pixelCharacter()
        pixelVerschieben(0, 0)
      elseif keyboard.isKeyDown(keyboard.keys.f) then
        speichern()
        pixelVerschieben(0, 0)
      elseif keyboard.isKeyDown(keyboard.keys.e) then
        break
      elseif keyboard.isKeyDown(keyboard.keys.n) then
        tileAuswaehlen()
      elseif keyboard.isKeyDown(keyboard.keys.k) then
        tileKopieren()
      end
    else
      if keyboard.isKeyDown(keyboard.keys.up) then
        pixelVerschieben(0, -1)
      elseif keyboard.isKeyDown(keyboard.keys.down) then
        pixelVerschieben(0, 1)
      elseif keyboard.isKeyDown(keyboard.keys.left) then
        pixelVerschieben(-1, 0)
      elseif keyboard.isKeyDown(keyboard.keys.right) then
        pixelVerschieben(1, 0)
      end
    end

    tileRendern()
  else
    
  end
end
