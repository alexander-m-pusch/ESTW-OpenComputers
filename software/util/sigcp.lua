print("Quellsignalrechner bitte:")
local serialization = require("serialization")

local sigrq = io.read()

local srraw = io.open("/konfiguration/sr/" .. sigrq .. "/rio.cfg", "r")
srraw:seek("set", 0)
local sr = serialization.unserialize(srraw:read("*a"))
srraw:close()

print("Zielsignalrechner bitte: ")
local sigz = io.read()

local szraw = io.open("/konfiguration/sr/" .. sigz .. "/rio.cfg", "r")
szraw:seek("set", 0)
local szr = serialization.unserialize(szraw:read("*a"))
szraw:close()

while true do
  print("Zu verschiebendes Signal oder \"beenden\"")
  local sign = io.read()

  if sign == "beenden" then break end

  szr[sign] = sr[sign]
  sr[sign] = nil

  print("Signal " .. sign .. " verschoben!")
end

local ssraw = io.open("/konfiguration/sr/" .. sigz .. "/rio.cfg", "w")
ssraw:seek("set", 0)
ssraw:write(serialization.serialize(szr))
ssraw:close()
