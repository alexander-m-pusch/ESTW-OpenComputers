local serialization = require("serialization")
local fs = require("filesystem")
local sides = require("sides")

print("Blockplaneditor der ESTW-Software")
print("Copyright (C) 2023, Alexander 'ampericus' Pusch")
print("Lizensiert unter der GNU GPLv3")

print("Bitte Name des Blockrechners angeben: ")
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

while true do
  print("Blockbefehl bitte: ")
  local befehl = io.read()

  if befehl == "kontakt" then
  elseif befehl == "beenden" then
    break
  elseif befehl == "speichern" then
    local fh = io.open("/konfiguration/bkr/" .. name .. "/rio.cfg", "w")
    fh:seek("set", 0)
    fh:write(serialization.serialize(tabelle))
    fh:close()
    print("Gespeichert!")
  elseif befehl == "block" then
    print("Blocknummer: ")
    local nummer = io.read()
    print("Blockgerät bitte: ")
    local dev = io.read()
    print("Vorblockadresse bitte: ")
    local adresse = io.read()
    print("Rückblockadresse bitte: ")
    local rueckbadresse = io.read()
    print("Seite bitte (n/o/s/w):")
    local seiteRaw = io.read()
    local seite = 0

    if seiteRaw == "n" then
      seite = sides.north
    elseif seiteRaw == "o" then
      seite = sides.east
    elseif seiteRaw == "s" then
      seite = sides.south
    elseif seiteRaw == "w" then
      seite = sides.west
    end

    tabelle[nummer] = {
      ["dev"] = dev,
      ["adresse"] = tonumber(adresse),
      ["rueckbadresse"] = tonumber(rueckbadresse),
      ["seite"] = seite,
    }
  else
    print("'block' um einen Streckenblock hinzuzufügen")
  end
end
