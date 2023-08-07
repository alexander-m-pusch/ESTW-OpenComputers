local serialization = require("serialization")
local fs = require("filesystem")

print("Gleisfreimeldeplaneditor der ESTW-Software")
print("Copyright (C) 2022, Alexander 'ampericus' Pusch")
print("Lizensiert unter der GNU GPLv3")

print("Bitte Name des Gleisfreimelderechners angeben: ")
local name = io.read()

local tabelle = {}

package.path = package.path .. ";/?.lua"

if fs.exists("/konfiguration/gfr/" .. name .. "/rio.cfg") then
  local handle = io.open("/konfiguration/gfr/" .. name .. "/rio.cfg", "r")
  handle:seek("set", 0)
  local raw = handle:read("*a")
  handle:close()

  local status, partab = pcall(serialization.unserialize, raw)

  if not status then
    error("Tabelle ist unlesbar. Bitte händisch korrigieren.")
  end

  tabelle = partab
end

local function seite(pars)
  local sides = require("sides")

  if pars == "norden" then
    return sides.north
  elseif pars == "westen" then
    return sides.west
  elseif pars == "süden" then
    return sides.south
  else
    return sides.east
  end
end

while true do
  print("Gleisfreimeldebefehl bitte: ")
  local befehl = io.read()

  if befehl == "anlegen" then
    print("Gleisfreimeldekontakt bitte:")
    local gfr = io.read()
    print("Redstoneadresse bitte:")
    local dev = io.read()
    print("Redstoneseite bitte:")
    local ps = seite(io.read())
    print("Redstoneadresse bitte:")
    local adresse = tonumber(io.read())

    if not tabelle[dev] then tabelle[dev] = {} end
    if not tabelle[dev][ps] then tabelle[dev][ps] = {} end
    tabelle[dev][ps][adresse] = gfr
    print("Gleisfreimeldekontakt angelegt!")
  elseif befehl == "liste" then
    for signal, plan in pairs(tabelle) do
      print(signal)
    end
  elseif befehl == "loeschen" then
    print("Funktionslos!")
  elseif befehl == "beenden" then
    break
  elseif befehl == "speichern" then
    local fh = io.open("/konfiguration/gfr/" .. name .. "/rio.cfg", "w")
    fh:seek("set", 0)
    fh:write(serialization.serialize(tabelle))
    fh:close()
    print("Gespeichert!")
  else
    print("'anlegen' für ein Gleisfreimeldekontakt anzulegen.")
    print("'liste' für eine Gleisfreimeldekontaktliste.")
    print("'speichern' um die Signalliste zu speichern")
    print("'loeschen' um ein Signal zu löschen")
    print("'beenden' um zu beenden (ohne speichern!)")
  end
end
