local menu = {}

function menu:new(gpuaddr, screenaddr)
  local component = require("component")

  local o = {
    ["gpu"] = component.proxy(gpuaddr),
    ["screenaddr"] = screenaddr,
    ["entries"] = {},
    ["longestEntry"] = 0,
    ["isOpen"] = false,
  }

  setmetatable(o, self)
  self.__index = self

  return o
end

function menu:addEntry(name, text)
  local unicode = require("unicode")
  if unicode.len(text) > self["longestEntry"] then
    self["longestEntry"] = unicode.len(text)
    text = text .. " "
  end

  table.insert(self["entries"], { ["name"] = name, ["text"] = text, })
end

function menu:click(posX, posY)
  if not self["isOpen"] then return end
  local found = nil
  if not ((posX < self["x"]) or (posX >= self["x"] + self["longestEntry"]) or (posY <= self["y"]) or (posY > self["y"] + #self["entries"])) then
    found = self["entries"][posY - self["y"]]["name"]
  end
  self["isOpen"] = false

  return found, self["x"], self["y"], self["x"] + self["longestEntry"], self["y"] + #self["entries"]
end

function menu:open(x, y)
  local unicode = require("unicode")
  self["isOpen"] = true
  self["x"] = x
  self["y"] = y

  self["gpu"].bind(self["screenaddr"])

  for index, eintrag in ipairs(self["entries"]) do
    self["gpu"].setBackground(0x696969)
    self["gpu"].setForeground(0xFFFFFF)
    local text = eintrag["text"]
    if unicode.len(text) < self["longestEntry"] + 1 then
      for i = 1, self["longestEntry"] - unicode.len(text) + 1 do
        text = text .. " "
      end
    end
    self["gpu"].set(x, y + index, text)
  end
end

function menu:close()
  self["isOpen"] = false
end

return menu
