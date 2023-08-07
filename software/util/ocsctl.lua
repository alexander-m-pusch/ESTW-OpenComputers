local args = {...}

print("OCS-Kontrollprogramm")
print("BENUTZUNG NUR DURCH FACHKRÄFTE LST ODER NACH DEREN AUFFORDERUNG!")
print("Copyright (C) 2022, Alexander 'ampericus' Pusch")
print("Lizensiert unter der GNU GPLv3")

local thread = require("thread")
local event = require("event")
local shell = require("shell")

local function pusher()
  event.push("kommunikation", "cmd", "queue", args[2])
end

if args[1] == "queue" then
  print("OCS-Paket " .. args[2] .. " wird in die Warteschlange aufgenommen.")
  local thr = thread.create(pusher)
  thr:detach()
  print("Versendet, starte dmesg")
  shell.execute("dmesg")
elseif args[1] == "forcereboot" then
  print("Die angeschlossenen Computer werden neu gestartet!")
  event.push("kommunikation", "cmd", "forcereboot")
  print("Stellwerk neu gestartet!")
elseif args[1] == "wakeup" then
  print("Starte Stellwerk")
  local component = require("component")
  component.modem.open(1)
  component.modem.broadcast(1, component.modem.address)
  component.modem.close(1)
  print("Wake-on-LAN-Message versendet, Stellwerk startet!")
elseif args[1] == "status" then
  event.push("kommunikation", "cmd", "status")
  print("Strg-C zum Beenden")

  while true do
    local ev, element, status = event.pullMultiple("interrupted", "kommunikation")
    if ev == "interrupted" then return end
    if ev == "kommunikation" then
      
    end
  end
else
  print("ocsctl queue <Datei mit OCS-Paket>: versendet ein OCS-Paket.")
  print("ocsctl forcereboot: startet alle Clients neu.")
  print("ocsctl wakeup: startet alle angeschlossenen Clients (falls sie nicht bereits angeschaltet sind).")
  print("ocsctl status: gibt den status der verbundenen Geräte an")
end
