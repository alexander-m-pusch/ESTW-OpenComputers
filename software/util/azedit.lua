print("Anzeigerechnereditor der ESTW-Software")
print("(C) 2022/23 Alexander 'ampericus' Pusch")
print("Verfügbar unter der GNU GPLv3")

local fs = require("filesystem")
local ser = require("serialization")

print("Anzeigrechner bitte:")
local rechner = io.read()

if not fs.exists("/konfiguration/azr/" .. rechner .. "/") then
  fs.makeDirectory("/konfiguration/azr/" .. rechner .. "/")
end

local tbl = {}

if fs.exists("/konfiguration/azr/" .. rechner .. "/screens.cfg") then
  local fh = io.open("/konfiguration/azr/" .. rechner .. "/screens.cfg", "r")
  local tbraw = fh:read("*a")
  fh:close()

  tbl = ser.unserialize(tbraw)
end

while true do
  print("Befehl bitte:")
  local bef = io.read()
  
  if bef == "anlegen" then
    print("Anzeigeschirmname:")
    local name = io.read()
    print("GPU-Adresse:")
    local gpu = io.read()
    print("Schirmadresse:")
    local bilds = io.read()
    print("Anzuzeigende Datei:")
    local filename = io.read()

    tbl[name] = {
      ["gpu"] = gpu,
      ["screen"] = bilds,
      ["filename"] = filename,
    }
  elseif bef == "speichern" then
    local fh = io.open("/konfiguration/azr/" .. rechner .. "/screens.cfg", "w")
    fh:write(ser.serialize(tbl))
    fh:close()

    print("Gespeichert!")
  elseif bef == "beenden" then
    break
  else
    print("Befehle:")
    print("anlegen - legt einen Anzeigebildschirm an")
    print("speichern - speichert den Plan")
    print("beenden - beendet das Programm")
  end
end
