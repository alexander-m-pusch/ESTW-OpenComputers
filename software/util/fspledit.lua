local serialization = require("serialization")
local fs = require("filesystem")

print("Spurplaneditor der ESTW-Software")
print("Copyright (C) 2022, Alexander 'ampericus' Pusch")
print("Lizensiert unter der GNU GPLv3")

print("Bitte Name des Fahrstraßenrechners angeben: ")
local name = io.read()

local tabelle = {}

if fs.exists("/konfiguration/fsr/" .. name .. "/fsp.cfg") then
  local handle = io.open("/konfiguration/fsr/" .. name .. "/fsp.cfg", "r")
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
  print("Spurplanbefehl bitte: ")
  local befehl = io.read()

  if befehl == "auswahl" then
    local element = {}
    print("Elementtyp bitte, verfügbar:")
    print("(1) Signal")
    print("(2) Weiche")
    print("(3) Umfahrgruppe")
    print("(4) Gleisfreimeldekontakt")
    print("(5) Block [TODO!]")

    local modus = tonumber(io.read())

    print("Elementnummer bitte:")
    local num = io.read()

    if modus == 1 then
      element["typ"] = "signal"
      print("Signalsystem bitte: ")
      local system = io.read()
      element["system"] = system
      print("Signalfunktion bitte: ")
      local funktion = io.read()
      element["funktion"] = funktion
      print("Signalstartgeschwindigkeit bitte: ")
      local startv = tonumber(io.read())
      element["startv"] = startv
      print("Zeigt Signal im Grundzustand Kennlicht? (j/n): ")
      local grz = io.read()

      if grz == "j" then
        element["grz"] = true
      else
        element["grz"] = false
      end

      print("Element am Anfang: ")
      local elementanf = io.read()
      print("Element am Ende: ")
      local elementende = io.read()
      
      element["nachbarn"] = {
        ["anfang"] = elementanf,
        ["ende"] = elementende,
      }

      tabelle[num] = element
    elseif modus == 2 then
      local zahler = 1
      tabelle[num] = {
        ["typ"] = "weiche",
        ["lagen"] = {
          
        },
      }
      while true do
        print("Weichenlage hinzufügen")
        print("von:")
        local von = io.read()
        print("nach:")
        local nach = io.read()
        print("vmax:")
        local vmax = tonumber(io.read())
        print("Flankenschutztransport: (j/n)")
        local fsr = io.read()
        if fsr == "j" then
          fsr = true
        else
          fsr = false
        end

        tabelle[num]["lagen"][zaehler] = {
          ["von"] = von,
          ["nach"] = nach,
          ["vmax"] = vmax,
          ["flankenschutztransport"] = fsr,
        }

        tabelle[num]["lagen"][zaehler + 1] = {
          ["von"] = nach,
          ["nach"] = von,
          ["vmax"] = vmax,
          ["flankenschutztransport"] = fsr,
        }
        
        print("Weitere Lage hinzufügen? (j/n)")

        local ack = io.read()

        if not (ack == "j") then
          break
        end

        zaehler = zaehler + 2
      end
    elseif modus == 3 then
      print("Element am Anfang: ")
      local anf = io.read()
      print("Element am Ende: ")
      local ende = io.read()

      tabelle[num] = {
        ["typ"] = "umfahgruppe",
        ["nachbarn"] = {
          ["anfang"] = anf,
          ["ende"] = ende,
        },
        ["durchlaessig"] = {},
      }

      while true do
        print("Umfahrgruppe durchlässig für: ")
        print("von: ")
        local von = io.read()
        print("nach: ")
        local nach = io.read()

        tabelle["durchlaessig"][von] = nach

        print("Weitere durchlässige Kombination eintragen? (j/n)")
        local weiteres = io.read()

        if not (weiteres == "j") then
          break
        end
      end
    elseif modus == 4 then
      print("Element am Anfang: ")
      local anf = io.read()
      print("Element am Ende: ")
      local ende = io.read()

      tabelle[num] = {
        ["nachbarn"] = {
          ["anfang"] = anf,
          ["ende"] = ende,
        },
        ["typ"] = "gleisfreimeldung",
      }
    elseif modus == 5 then

    end
  elseif befehl == "liste" then
    for signal, plan in pairs(tabelle) do
      print(signal)
    end
  elseif befehl == "loeschen" then
    print("Element bitte:")
    local element = io.read()

    tabelle[element] = nil

    print("Element gelöscht!")
  elseif befehl == "beenden" then
    break
  elseif befehl == "speichern" then
    local fh = io.open("/konfiguration/fsr/" .. name .. "/fsp.cfg", "w")
    fh:seek("set", 0)
    fh:write(serialization.serialize(tabelle))
    fh:close()
    print("Gespeichert!")
  else
    print("'auswahl' für ein Spurplanelement anzulegen.")
    print("'liste' für eine Spurplanelementliste.")
    print("'speichern' um den Spurplan zu speichern")
    print("'loeschen' um ein Spurplanelement zu löschen")
    print("'beenden' um zu beenden (ohne speichern!)")
  end
end
