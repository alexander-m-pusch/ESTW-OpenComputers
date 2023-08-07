print("OCS-Installersoftware")
print("(C) 2022/23 Alexander 'ampericus' Pusch, verfügbar unter der GNU GPLv3")

local fs = require("filesystem")
local shell = require("shell")
local computer = require("computer")

print("Software-RAID-Kürzel bitte: ")
local softkuerzel = io.read()
print("Konfiguration-RAID-Kürzel bitte: ")
local konfkuerzel = io.read()

if not fs.exists("/mnt/" .. softkuerzel) then error("Software-RAID-Kürzel ungültig.") end
if not fs.exists("/mnt/" .. konfkuerzel) then error("Konfiguration-RAID-Kürzel ungültig.") end

local sffh = io.open("/mnt/" .. softkuerzel .. "/mp.cfg", "w")
sffh:write("software\n")
sffh:close()
local kffh = io.open("/mnt/" .. konfkuerzel .. "/mp.cfg", "w")
kffh:write("konfiguration")
kffh:close()

print("Mounte /software/ und /konfiguration/..")

fs.mount(softkuerzel, "/software/")
fs.mount(konfkuerzel, "/konfiguration/")

print("Installiere Stellwerksoftware...")
fs.copy(shell.getWorkingDirectory() .. "/data/software.tar", "/software/tmp.tar")
local curr = shell.getWorkingDirectory()
shell.setWorkingDirectory("/software/")
os.execute(curr .. "/tar.lua -xvf " .. "/software/tmp.tar")
shell.getWorkingDirectory(curr)
fs.remove("/software/tmp.tar")

print("Installiere Serversoftware...")
fs.makeDirectory("/usr/lib/")
print("...tinyftp")
fs.copy(shell.getWorkingDirectory() .. "/data/tinyftp.lua", "/usr/lib/tinyftp.lua")
print("...mainserver")
fs.copy(shell.getWorkingDirectory() .. "/data/mainserver.lua", "/etc/rc.d/mainserver.lua")

print("Schreibe Standardkonfiguration für Server...")

local standconf = {
  ["blocksize"] = 4096,
}

local serialization = require("serialization")

local scfh = io.open("/etc/ftpserver.cfg", "w")
scfh:write(serialization.serialize(standconf))
scfh:close()

local rc = require("rc")

print("Aktiviere Standardserver..")

os.execute("rc mainserver enable")

print("Fertig!")
print("Starte System neu..")
os.sleep(5)
computer.shutdown(true)
