print("Rechnerinstaller für Clientrechner")

local shell = require("shell")
local fs = require("filesystem")

local curp = shell.getWorkingDirectory()

print("Kopiere netboot")
fs.copy(curp .. "/data/netboot.lua", "/etc/rc.d/netboot.lua")
print("Kopiere netbootcfg")
fs.copy(curp .. "/data/netbootcfg.lua", "/home/netbootcfg.lua")

print("Erfolgreich kopiert!")

print("Lege estw-Ordner an..")
fs.makeDirectory("/estw/")

local kuerz = ""
local gef = false
repeat
  print("ESTW-Plattenkürzel bitte: ")
  kuerz = io.read()

  if not fs.exists("/mnt/" .. kuerz) then
    print("Ungültiges Kürzel!")
  else
    print("Gültiges Kürzel!")
    gef = true
  end
until gef == true

fs.mount(kuerz, "/estw/")

print("Lege Partitionsheader an..")

local mpfh = io.open("/estw/mp.cfg", "w")
mpfh:write("estw")
mpfh:close()

print("Lege wichtige Verzeichnisse an..")

fs.makeDirectory("/estw/lib/")
fs.makeDirectory("/estw/lib/libocs/")
fs.makeDirectory("/estw/lib/libdraw/")
fs.makeDirectory("/estw/etc/")
fs.makeDirectory("/estw/log/")

print("Fertig!")
print("Aktiviere netboot..")

os.execute("rc netboot enable")

print("Starte Konfigurationstool..")

os.execute("/home/netbootcfg.lua")

print("System wird jetzt neu starten!")
local computer = require("computer")
computer.shutdown(true)
