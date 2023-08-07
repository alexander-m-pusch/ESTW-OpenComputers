local handle, err = 0

function start()
  local computer = require("computer")
  local term = require("term")
  local component = require("component")
  local serialization = require("serialization")
  local event = require("event")
  local fs = require("filesystem")

  term.clear()
  print("Netboot startet")
  
  local file, err = io.open("/etc/netboot.cfg", "r")
  if not file then
    print("Konfigurationsdatei unlesbar!")
    print("Fehlercode: " .. err)
    print("Fallback zur Shell!")
    os.sleep(5)
    return
  end
  
  file:seek("set", 0)
  local cont = file:read("*a")
  file:close()

  print("Datei geladen, einlesen..")
  local tab = serialization.unserialize(cont)
  if not tab then
    print("Konfigurationsdatei beschädigt!")
    print("Fallback zur Shell!")
    os.sleep(5)
    return
  end

  print("Datei gelesen!")
  print("Rechnername: ")
  print(tab["name"])
  print("Rechnertyp: ")
  print(tab["typ"])
  print("Zentralrechneradresse:")
  print(tab["adresse"])
  print("Netzwerkkartenadresse:")
  print(tab["lokal"])

  print("Mounte Arbeitsverzeichnis...")

  for pfad in fs.list("/mnt") do
    if fs.exists(fs.concat("/mnt", pfad, "mp.cfg")) then
      local file = io.open(fs.concat("/mnt", pfad, "mp.cfg"), "r")
      file:seek("set", 0)
      local mountpunkt = file:read("*a")
      file:close()
      print("Mounte " .. mountpunkt .. " auf /" ..mountpunkt.. "/")
      fs.mount(fs.get(fs.concat("/mnt", pfad)), "/" .. mountpunkt .. "/")
    end
  end

  os.sleep(1)
  print("Initialisiere Modem...")
  local modem = component.proxy(tab["lokal"])
  modem.open(8080)
  
  print("Modem initialisiert.")

  print("Melde am Zentralrechner an..")
  
  local paket = {
    ["typ"] = "anmeldung_fs",
    ["inhalt"] = tab,
  }

  local tinyftp = ""

  while true do
    modem.send(tab["adresse"], 8080, serialization.serialize(paket))
    local _, _, from, port, _, message = event.pull(5, "modem_message")
    if from == tab["adresse"] then
      print("Nachricht erhalten!")
      print("Kommunikation steht.")
      print("FTP-Bibliothek heruntergeladen!")
      tinyftp = message
      os.sleep(1)
      break
    end
    print("Timeout bei der Anfrage, sende erneut..")
  end
  
  print("Speichere tinyFTP in /usr/lib/tinyftp.lua...")
  
  if not fs.exists("/usr/lib") then
    fs.makeDirectory("/usr/lib")
  end

  local tftp, err = io.open("/usr/lib/tinyftp.lua", "w")
  if not tftp then
    print("Datei kann nicht geschrieben werden!")
    print("Fehler: " .. err)
    os.sleep(10)
  end

  tftp:write(tinyftp)
  tftp:close()
  os.sleep(1)
  print("tinyFTP gespeichert, lade Bibliothek..")
  local status, tinyftp = pcall(require, "tinyftp")

  if not status then
    print("TinyFTP kann nicht geladen werden!")
    print("Fehler: " .. tinyftp)
    print("Neustart in 10 Sekunden!")
    os.sleep(10)
    computer.shutdown(true)
  end

  os.sleep(2)

  print("Verbinde mit FTP-Server..")

  handle, err = tinyftp:connect(tab["lokal"], tab["adresse"])

  if not handle then
    print("Kann Verbindung nicht aufbauen!")
    print(err)
    os.sleep(10)
    computer.shutdown(true)
  end

  print("Verbindung hergestellt, lade executables herunter")
  os.sleep(1)
  local erfolg, fehler = handle:download("/estw/" .. tab["typ"] .. ".lua", "/software/" .. tab["typ"] .. "/main.lua")
  if not erfolg then
    print("Download der Executable fehlgeschlagen!")
    print(fehler)
    os.sleep(10)
    computer.shutdown(true)
  end

  print("Datei erfolgreich heruntergeladen!")
  print("Starte executable...")
  os.sleep(1)
  local status, executable = pcall(require, "/estw/" .. tab["typ"])
  if not status then
    print("Die executable konnte nicht gestartet werden!")
    print("Fehler: " .. executable)
    print("Schreibe Fehler in /estw/log/crash.txt...")
    local crash = io.open("/estw/log/crash.txt", "w")
    crash:seek("set", 0)
    crash:write(executable)
    crash:close()
    print("Beende!")
    os.sleep(10)
    computer.shutdown(true)
  end
  local status, err = pcall(executable.start, handle, tab["adresse"], modem, tab["name"])
  if not status then
    print("Der Rechner ist abgestürzt!")
    print("Fehler: " .. err)
    print("Schreibe Fehler in /estw/log/crash.txt...")
    local crash = io.open("/estw/log/crash.txt", "w")
    crash:seek("set", 0)
    crash:write(err)
    crash:close()
    print("Beende!")
    os.sleep(10)
    computer.shutdown(true)
  end
end

function stop()
  handle:close()
end
