local serialization = require("serialization")
local fs = require("filesystem")

print("Signalplaneditor der ESTW-Software")
print("Copyright (C) 2022, Alexander 'ampericus' Pusch")
print("Lizensiert unter der GNU GPLv3")

print("Bitte Name des Signalrechners angeben: ")
local name = io.read()

local tabelle = {}

if fs.exists("/konfiguration/sr/" .. name .. "/rio.cfg") then
  local handle = io.open("/konfiguration/sr/" .. name .. "/rio.cfg", "r")
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
  print("Signalbefehl bitte: ")
  local befehl = io.read()

  if befehl == "auswahl" then
    print("Signalnummer bitte:")
    local signr = io.read()
    
    if not tabelle[signr] then
      tabelle[signr] = {}
      tabelle[signr]["begriffe"] = {}
    end
    print("Signal ausgewählt!")

    while true do
      print("Signalbefehl bitte:")
      befehl = io.read()

      if befehl == "begriff" then
        local sides = require("sides")

        print("Begriffname: ")
        local name = io.read()
        print("Begriffsgerät: ")
        local dev = io.read()
        print("Begriffsadresse: ")
        local adresse = io.read()
        print("Begriffsseite ((n)orden/(w)esten/(s)üden/(o)sten):")
        local seite = io.read()
        local pseite = sides.east
        
        if seite == "n" then
          pseite = sides.north
        elseif seite == "w" then
          pseite = sides.west
        elseif seite == "s" then
          pseite = sides.south
        else
          pseite = sides.east
        end

        tabelle[signr]["begriffe"][name] = {}
        tabelle[signr]["begriffe"][name]["dev"] = dev
        tabelle[signr]["begriffe"][name]["adresse"] = adresse
        tabelle[signr]["begriffe"][name]["seite"] = pseite

        print("Angelegt!")
      elseif befehl == "meta" then
        if not (type(tabelle[signr]["meta"]) == "table") then
          tabelle[signr]["meta"] = {}
        end
        print("Ist Zs3 mit Hp verbacken? (j/n)")
        local hpalt = io.read()
        if hpalt == "j" then
          tabelle[signr]["meta"]["hv_alt_hp"] = true
        end
        print("Ist Zs3v mit Vr verbacken? (j/n)")
        local vralt = io.read()
        if vralt == "j" then
          tabelle[signr]["meta"]["hv_alt_vr"] = true
        end
      elseif befehl == "umbenennen" then
        print("Quellbegriff: ")
        local quelle = io.read()
        print("Zielbegriff: ")
        local ziel = io.read()
        tabelle[signr]["begriffe"][ziel] = tabelle[signr]["begriffe"][quelle]
        tabelle[signr]["begriffe"][quelle] = nil
        print("Umbenannt.")
      elseif befehl == "loeschen" then
        print("Begriffname: ")
        local name = io.read()
        tabelle[signr]["begriffe"][name] = nil

        print("Gelöscht!")
      elseif befehl == "beenden" then
        break
      elseif befehl == "liste" then
        for begriff, _ in pairs(tabelle[signr]["begriffe"]) do
          print(begriff)
        end
      else
        print("'begriff' um einen Begriff auszuwählen/einen neuen anzulegen")
        print("'loeschen' um einen Begriff zu löschen.")
        print("'liste' um alle Begriffe anzuzeigen.")
        print("'beenden' um die Ansicht zu beenden.")
      end
    end
  elseif befehl == "liste" then
    for signal, plan in pairs(tabelle) do
      print(signal)
    end
  elseif befehl == "pruefen" then
    for signal, sigtab in pairs(tabelle) do
      print("Prüfe " .. signal)
      for begriff, begrtab in pairs(sigtab["begriffe"]) do
        if not begrtab["dev"] then
          print("Gerät fehlt für " .. begriff)
        end
        if not begrtab["adresse"] then
          print("Adresse fehlt für " .. adresse)
          if begrtab["adresse"] > 15 then
            print("Ungültige Adresse " .. begrtab["adresse"] .. " für " .. begriff)
          end
        end
      end
    end
  elseif befehl == "adressen" then
    print("Gerät bitte:")
    local der_geraet = io.read()

    for signal, sigtab in pairs(tabelle) do
      for begriff, begrtab in pairs(sigtab["begriffe"]) do
        if begrtab["dev"] == der_geraet then
          print(begriff .. " an " .. signal .. " : " .. begrtab["adresse"])
        end
      end
    end
  elseif befehl == "loeschen" then
    print("Signalnummer bitte:")
    local sig = io.read()
    tabelle[sig] = nil
    print("Gelöscht.")
  elseif befehl == "beenden" then
    break
  elseif befehl == "speichern" then
    if not fs.exists("/konfiguration/sr/" .. name) then
      fs.makeDirectory("/konfiguration/sr/" .. name)
    end
    local fh = io.open("/konfiguration/sr/" .. name .. "/rio.cfg", "w")
    fh:seek("set", 0)
    fh:write(serialization.serialize(tabelle))
    fh:close()
    print("Gespeichert!")
  else
    print("'auswahl' für ein Signal auszuwählen/ein neues anzulegen.")
    print("'liste' für eine Signalliste.")
    print("'pruefen' um die Signalliste auf Korrektheit zu prüfen.")
    print("'speichern' um die Signalliste zu speichern")
    print("'loeschen' um ein Signal zu löschen")
    print("'adressen' um die Adressen an einem Gerät auszulesen")
    print("'beenden' um zu beenden (ohne speichern!)")
  end
end
