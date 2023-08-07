print("Notbedienprogramm für das ESTW")
print("(C) 2022/2023 Alexander 'ampericus' Pusch")
print("Lizensiert unter der GNU GPLv3")

local fs = require("filesystem")
local serialization = require("serialization")
local event = require("event")
local computer = require("computer")

if not fs.exists("/tmp") then
  fs.makeDirectory("/tmp/")
end

local function push(befehl, arg1, arg2)
  local paket = {
    ["typ"] = "queue",
    ["sender"] = "server",
    ["num"] = 000000,
    ["inhalt"] = {
      ["typ"] = "eingabe",
      ["inhalt"] = {
        ["befehl"] = befehl,
        ["arg1"] = arg1,
        ["arg2"] = arg2,
      },
    },
  }

  local fh = io.open("/tmp/p.paket", "w")
  fh:write(serialization.serialize(paket))
  fh:close()

  event.push("kommunikation", "cmd", "queue", "/tmp/p.paket")

  local zeitbeginn = computer.uptime()
  local verstrichen = 0

  local erhalt = false
  local erfolg = false
  local kommentar = nil
  repeat
    local ev, _, _, _, _, msg = event.pull("modem_message")
    local erf, tb = pcall(serialization.unserialize, msg)
    
    if erf and tb then
      if (tb["typ"] == "ack") and (tb["empfaenger"] == "server") then
        erhalt = tb["inhalt"]["erhalt"]
        erfolg = tb["inhalt"]["erfolg"]
        kommentar = tb["inhalt"]["kommentar"]
        break
      end
    end

    verstrichen = verstrichen + (computer.uptime() - zeitbeginn)
  until verstrichen > 5

  print("Erfolg: " .. tostring(erfolg))

  if kommentar then
    if type(kommentar) == "table" then
      for k, v in pairs(kommentar) do
        print(k .. ": " .. tostring(v))
      end
    else
      print("Kommentar: " .. tostring(kommentar))
    end
  else
      print("Kommentar: <ohne>")
  end

  fs.remove("/tmp/p.paket")
end

while true do
  print("Befehl bitte:")
  local befehl = io.read()

  if befehl == "zfs" then
    print("Startsignal:")
    local startsignal = io.read()
    print("Zielsignal:")
    local zielsignal = io.read()
    push("zfs", startsignal, zielsignal)
  elseif befehl == "rfs" then
    print("Startsignal:")
    local startsignal = io.read()
    print("Zielsignal:")
    local zielsignal = io.read()
    push("rfs", startsignal, zielsignal)
  elseif befehl == "zufs" then
    print("Startsignal:")
    local startsignal = io.read()
    print("Zielsignal")
    local zielsignal = io.read()
    push("zufs", startsignal, zielsignal)
  elseif befehl == "rufs" then
    print("Startsignal:")
    local startsignal = io.read()
    print("Zielsignal:")
    local zielsignal = io.read()
    push("rufs", startsignal, zielsignal)
  elseif befehl == "ersgt" then
    print("Signal:")
    local signal = io.read()
    print("Begründung:")
    local begr = io.read()
    push("ersgt", signal, begr)
  elseif befehl == "vorsgt" then
    print("Signal:")
    local signal = io.read()
    print("Begründung:")
    local begr = io.read()
    push("vorsgt", signal, begr)
  elseif befehl == "zs8" then
    print("Signal:")
    local signal = io.read()
    print("Begründung:")
    local begr = io.read()
    push("zs8", signal, begr)
  elseif befehl == "sht" then
    print("Signal:")
    local signal = io.read()
    print("Begründung:")
    local begr = io.read()
    push("sht", signal, begr)
  elseif befehl == "fsha" then
    print("Zielsignal der Fahrstraße:")
    local signal = io.read()
    print("Begründung:")
    local begr = io.read()
    push("fsha", signal, begr)
  elseif befehl == "wum" then
    print("Weichennummer:")
    local signal = io.read()
    print("Neue Lage (links/rechts):")
    local begr = io.read()
    push("", signal, begr)
  elseif befehl == "hilfsentriegeln" then
    print("Element:")
    local signal = io.read()
    print("Begründung:")
    local begr = io.read()
    push("hilfsentriegeln", signal, begr)
  elseif befehl == "info" then
    print("Elementnummer:")
    local signal = io.read()
    push("info", signal, "")
  elseif befehl == "beenden" then
    break
  else
    print("Verfügbare Befehle: ")
    print("z(u)fs - Zug(um)fahrstraße")
    print("r(u)fs - Rangier(um)fahrstraße")
    print("ergst - Ersatzgruppentaste")
    print("vorsgt - Vorsichtgruppentaste")
    print("zs8 - Gegengleisgruppentaste")
    print("sht - Signalhalttaste")
    print("fsha - Fahrstaßenhilfsauflösung")
    print("wum - Weichenumlegetaste")
    print("hilfsentriegeln - Hilfsentriegeln von Fahrwegelementen")
    print("info - Informationen zu Fahrwegelement anfordern")
    print("beenden - Beendet die Rückfallebene")
  end
end
