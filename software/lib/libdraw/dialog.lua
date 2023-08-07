local dialog = {}

function dialog:new(gpuaddr, screenaddr)
  local component = require("component")
  local o = {
    ["gpu"] = component.proxy(gpuaddr),
    ["screen"] = screenaddr,
  }

  setmetatable(o, self)
  self.__index = self
  return o
end

function dialog:setText(text)
  self["text"] = text
end

function dialog:setCursorAppropriately(text, y)
  local term = require("term")
  local sizeX, sizeY = self["gpu"].getResolution()

  term.setCursor(math.floor((sizeX - string.len(text)) / 2), y)
end

local geschriebenes = ""

function dialog:ioreadverschnitt(template, topY, sizeX)
  geschriebenes = ""
  local event = require("event")
  local keyboard = require("keyboard")
  local term = require("term")
  local unicode = require("unicode")
  while true do
    local ev, _, char, key = event.pull("key_down")
    if key == keyboard.keys.back then
      geschriebenes = unicode.sub(geschriebenes, 0, -2)
    elseif key == keyboard.keys.enter then
      return geschriebenes
    elseif (key == keyboard.keys.lshift) or (key == keyboard.keys.rshift) then
      --ignore
    else
      geschriebenes = geschriebenes .. unicode.char(char)
    end
    self:setCursorAppropriately(template, topY+ 2)
    term.write(template)
    term.setCursor(math.floor(sizeX / 4) + 1, topY + 2)
    term.write(geschriebenes)
  end
end

function dialog:open()
  self["gpu"].bind(self["screen"])

  local term = require("term")
  
  local sizeX, sizeY = self["gpu"].getResolution()

  local topY = math.floor(sizeY / 2) - 2

  self["gpu"].setBackground(0x696969)
  self["gpu"].setForeground(0xFFFFFF)
  
  self:setCursorAppropriately(self["text"], topY)
  term.write(self["text"])
  self:setCursorAppropriately("", topY)
  local template = ""
  for i = 1, sizeX / 2 do
    template = template .. " "
  end
  self:setCursorAppropriately(template, topY + 1)
  term.write(template)
  self:setCursorAppropriately(template, topY + 2)
  term.write(template)
  self:setCursorAppropriately(template, topY + 3)
  term.write(template)
  term.setCursor(math.floor(sizeX / 4) + 1, topY + 2)
  return self:ioreadverschnitt(template, topY, sizeX), math.floor(sizeX / 4), math.floor(sizeY / 2) - 2, 3 * math.floor(sizeX / 4), math.floor(sizeY / 2) + 5
end

return dialog
