local serialization = require("serialization")
local fs = require("filesystem")
local sides = require("sides")

print("Weichenplaneditor der ESTW-Software")
print("Copyright (C) 2022, Alexander 'ampericus' Pusch")
print("Lizensiert unter der GNU GPLv3")

print("Bitte Name des Weichenrechners angeben: ")
local name = io.read()

local tabelle = {}

if fs.exists("/konfiguration/wr/" .. name .. "/rio.cfg") then
  local handle = io.open("/konfiguration/wr/" .. name .. "/rio.cfg", "r")
  handle:seek("set", 0)
  local raw = handle:read("*a")
  handle:close()

  local status, partab = pcall(serialization.unserialize, raw)

  if not status then
    error("Tabelle ist unlesbar. Bitte händisch korrigieren.")
  end

  tabelle = partab
end

local function seite(ps)
  if ps == "norden" then
    return sides.north
  elseif ps == "westen" then
    return sides.west
  elseif ps == "süden" then
    return sides.south
  else
    return sides.east
  end
end

local function weichenlage_hinzufuegen(weichentbl, nummer)
  print("Weichengerät bitte:")
  local dev = io.read()
  print("Weichenadresse bitte:")
  local adresse = io.read()
  print("Weichenseite bitte:")
  local ps = io.read()
  print("Weichengrundzustand bitte:")
  local grundzustand = io.read()
  
  weichentbl[nummer] = {
    ["dev"] = dev,
    ["adresse"] = adresse,
    ["seite"] = seite(ps),
    ["grundzustand"] = grundzustand,
  }
end

while true do
  print("Weichenbefehl bitte: ")
  local befehl = io.read()

  if befehl == "auswahl" then
    print("Weichennummer bitte:")
    local nummer = io.read()

    if not tabelle[befehl] then
      tabelle[nummer] = {}
      tabelle[nummer]["antriebe"] = {}
    end
    print("Weiche ausgewählt!")
    
  weichenlage_hinzufuegen(tabelle, nummer)
  elseif befehl == "loeschen" then
    print("Weichennummer bitte:")
    local wnnr = io.read()
    tabelle[wnnr] = nil
    print("Weiche gelöscht!")
  elseif befehl == "liste" then
    for signal, plan in pairs(tabelle) do
      print(signal)
    end
  elseif befehl == "beenden" then
    break
  elseif befehl == "speichern" then
    local fh = io.open("/konfiguration/wr/" .. name .. "/rio.cfg", "w")
    fh:seek("set", 0)
    fh:write(serialization.serialize(tabelle))
    fh:close()
    print("Gespeichert!")
  else
    print("'auswahl' für eine Weiche auszuwählen/ein neues anzulegen.")
    print("'liste' für eine Weichenliste.")
    print("'speichern' um die Weichenliste zu speichern")
    print("'loeschen' um eine Weiche zu löschen")
    print("'beenden' um zu beenden (ohne speichern!)")
  end
end
