print("Signalrechner bitte:")
local serialization = require("serialization")

local sigr = io.read()

local srraw = io.open("/konfiguration/sr/" .. sigr .. "/rio.cfg", "r")
srraw:seek("set", 0)
local sr = serialization.unserialize(srraw:read("*a"))
srraw:close()

print("Ersetzendes Gerät: ")
local ers = io.read()

print("Damit ersetzen: ")
local rep = io.read()

for signal, sigtab in pairs(sr) do
  for begriff, begrtab in pairs(sigtab["begriffe"]) do
    if begrtab["dev"] == ers then
      print("Ersetzt in " .. signal .. ": " .. begriff)
      begrtab["dev"] = rep
    end
  end
end

local ssraw = io.open("/konfiguration/sr/" .. sigr .. "/rio.cfg", "w")
ssraw:seek("set", 0)
ssraw:write(serialization.serialize(sr))
ssraw:close()
