local term = require("term")
local fs = require("filesystem")
local serialization = require("serialization")
local component = require("component")

term.clear()
print("Netboot Konfigurator")
print("(C) 2022 Alexander 'ampericus' Maximilian Pusch")
print("Verfügbar unter GNU GPLv3")

os.sleep(1)

print("Rechnername:")
local name = io.read()
print("Rechnertyp: ")
local typ = io.read()
print("Zentralrechneradresse:")
local adresse = io.read()
print("Lokale Netzwerkkarte (leer lassen für primäre Netzwerkkarte):")
local lokal = io.read()

if lokal == "" then
  print("Ermittle Standardadresse..")
  os.sleep(0.5)
  for addr, ct in component.list() do
    if ct == "modem" then
      lokal = addr
    end
  end
  if lokal == "" then
    error("Kein Netzwerkmodem im Rechner installiert. Dies ist ein schwerwiegender Fehler.")
  end
  print("Adresse:")
  print(lokal)
  os.sleep(1)
end

print("Konfigurationsdatei wird nach /etc/netboot.cfg geschrieben.")

local tab = {
  ["name"] = name,
  ["adresse"] = adresse,
  ["typ"] = typ,
  ["lokal"] = lokal,
}

if fs.exists("/etc/netboot.cfg") then
  fs.remove("/etc/netboot.cfg")
end

local file, err = io.open("/etc/netboot.cfg", "w")
if not file then
  error("Datei nicht schreibbar: " .. err)
end

file:seek("set", 0)
file:write(serialization.serialize(tab, false))
file:close()

print("Setze Wake-On-Lan-Kennung...")
local modem = component.proxy(tab["lokal"])
modem.setWakeMessage(tab["adresse"])
print("Wake-Message gesetzt!")
