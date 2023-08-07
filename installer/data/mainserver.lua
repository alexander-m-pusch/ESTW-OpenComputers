local angemeldete_rechner = {}

local function name_von_adresse(adresse)
  for name, adr in pairs(angemeldete_rechner) do
    if adr == adresse then return name end
  end
end

function hintergrundprozess(modem)
  local event = require("event")
  while true do
    local _, _, from, port, _, nachricht, rclient = event.pull("modem_message")
    if not rclient then rclient = from end
    if port == 8080 then --um nicht-Fileserver-Befehle abzusägen
      local tbl = serialization.unserialize(nachricht)
      if tbl["typ"] == "anmeldung_fs" then
        modem.send(from, 8080, tftp, from, rclient)
        angemeldete_rechner[tbl["inhalt"]["name"]] = from
        event.push("handshake_netboot", from)
      end
    end
  end
end

local function empfangen(psender, pport, timeout)
  local computer = require("computer")

  local anfangszeit = computer.uptime()
  repeat
    local elapsed = computer.uptime() - anfangszeit
    local _, _, sender, port, _, nachricht = event.pull(timeout - elapsed, "modem_message")
    
    if (psender == sender) and (pport == port) then
      return sender, port, nachricht
    end
  until elapsed > timeout

  return nil, "Timeout bei der Anfrage."
end

local sockets = {}
local config = {}

local function download(modem, client, port, dateiname, rclient) --download vom server
  if not rclient then rclient = client end
  local event = require("event")

  event.push("ftp", "download_request", client, port, dateiname)

  local antwort = {
    ["typ"] = "",
    ["inhalt"] = 0,
  }

  if not fs.exists(dateiname) then
    antwort.inhalt = "Die Datei existiert nicht"
    antwort.typ = "abgelehnt"
    modem.send(client, port, serialization.serialize(antwort), rclient)
    event.push("ftp", "download_refused", client, port, dateiname, antwort.inhalt)
    return
  end
  
  local dlfh = io.open(dateiname, "rb")
  dlfh:seek("set", 0)
  local dlf = dlfh:read("*a")
  dlfh:seek("set", 0)

  antwort["typ"] = "bereit"
  antwort["inhalt"] = string.len(dlf)

  modem.send(client, port, serialization.serialize(antwort), rclient)

  local sender, port, nachricht = empfangen(client, port, 10)

  event.push("ftp", "download_begin", client, port, dateiname, string.len(dlf))

  if nachricht == "anfangen" then
    local gelesen = 0
    repeat
      local zulesen = math.min(config["blocksize"], string.len(dlf) - gelesen)
      modem.send(client, port, dlfh:read(config["blocksize"]), rclient)
      gelesen = gelesen + zulesen
    until gelesen >= string.len(dlf)
  end

  dlfh:close()

  event.push("ftp", "download_complete", client, port, dateiname, string.len(dlf))

  return
end

local function upload(modem, client, port, dateiname, dateigroesse, rclient) --upload zum server
  if not rclient then rclient = client end
  local event = require("event")

  event.push("ftp", "upload_request", client, port, dateiname, dateigroesse)

  local antwort = {
    ["typ"] = "bereit",
    ["inhalt"] = "",
  }

  if fs.exists(dateiname) then
    antwort.inhalt = "Datei existiert"
    antwort.typ = "abgelehnt"
    modem.send(client, port, serialization.serialize(antwort), rclient)
    event.push("ftp", "upload_refuse", client, port, dateiname, dateigroesse, antwort.inhalt)
    return
  end

  --bereit zum herunterladen

  modem.send(client, port, serialization.serialize(antwort), rclient)
  
  event.push("ftp", "upload_begin", client, port, dateiname, dateigroesse)

  local ulfh = io.open(dateiname, "wb")

  local bytes = 0
  repeat
    local sender, pport, nachricht = empfangen(client, port, 10)
    if not sender then
      ulfh:close()
      event.push("ftp", "upload_fail", client, port, dateiname, dateigroesse, pport)
      return nil
    end
    ulfh:write(nachricht)
    bytes = bytes + string.len(nachricht)
  until bytes >= dateigroesse
  ulfh:close()

  event.push("ftp", "upload_complete", client, port, dateiname, dateigroesse)

  return
end

local function remove(modem, client, port, name, rclient)
  if not rclient then rclient = client end
  local fs = require("filesystem")
  local serialization = require("serialization")
  local event = require("event")
  
  event.push("ftp", "remove_request", client, port, name)

  local success, err = fs.remove(name)

  local antwort = {
    ["typ"] = success,
    ["inhalt"] = err,
  }

  modem.send(client, port, serialization.serialize(antwort), rclient)
  if success then
    event.push("ftp", "remove_complete", client, port, name)
  else
    event.push("ftp", "remove_fail", client, port, name, err)
  end
end

local function move(modem, client, port, von, nach, rclient)
  if not rclient then rclient = client end
  local shell = require("shell")
  local fs = require("filesystem")
  local serialization = require("serialization")
  local event = require("event")
  
  event.push("ftp", "move_request", client, port, von, nach)

  shell.setPath(shell.getPath() .. ":/software/util")

  local success, err = fs.rename(von, nach)
  
  local antwort = {
    ["typ"] = success,
    ["inhalt"] = err,
  }

  modem.send(client, port, serialization.serialize(antwort), rclient)

  if success then
    event.push("ftp", "move_complete", client, port, von, nach)
  else
    event.push("ftp", "move_fail", client, port, von, nach, err)
  end
end

local function mkdir(modem, client, port, name, rclient)
  if not rclient then rclient = client end
  local fs = require("filesystem")
  local serialization = require("serialization")
  local event = require("event")

  event.push("ftp", "mkdir_request", client, port, name)

  local success, err = fs.makeDirectory(name)

  local antwort = {
    ["typ"] = success,
    ["inhalt"] = err,
  }

  modem.send(client, port, serialization.serialize(antwort), rclient)

  if success then
    event.push("ftp", "mkdir_complete", client, port, name)
  else
    event.push("ftp", "mkdir_fail", client, port, name, err)
  end
end

function ftpsocket(clientadresse, port, modem, blocksize, rclient)
  if not rclient then rclient = client end
  local event = require("event")
  local antwort = {
    ["port"] = port,
    ["blocksize"] = blocksize,
  }

  event.push("ftp", "socket_opened", clientadresse, port, blocksize, rclient)

  modem.open(port)
  modem.send(clientadresse, 21, serialization.serialize(antwort), rclient, port)

  while true do
    local _, _, from, pport, _, nachricht, prclient = event.pull("modem_message")
    if (port == pport) and (from == clientadresse) then
      local status, befehl = pcall(serialization.unserialize, nachricht)
      if status and befehl then
        if befehl["typ"] == "schliessen" then
          modem.close(port)
          sockets[clientadresse] = nil
          event.push("ftp", "socket_closed", clientadresse, port, blocksize)
          return 0
        elseif befehl["typ"] == "download" then
          download(modem, clientadresse, port, befehl["inhalt"], rclient)
        elseif befehl["typ"] == "upload" then
          upload(modem, clientadresse, port, befehl["inhalt"], befehl["groesse"], rclient)
        elseif befehl["typ"] == "remove" then
          remove(modem, clientadresse, port, befehl["inhalt"], rclient)
        elseif befehl["typ"] == "move" then
          move(modem, clientadresse, port, befehl["von"], befehl["nach"], rclient)
        elseif befehl["typ"] == "mkdir" then
          mkdir(modem, clientadresse, port, befehl["inhalt"], rclient)
        end
      end
    end
  end

  return -1
end

function ftpserver(modem)
  local thread = require("thread")
  local event = require("event")

  local ftpcfh = io.open("/etc/ftpserver.cfg", "r")
  ftpcfh:seek("set", 0)
  local cr = ftpcfh:read("*a")
  ftpcfh:close()

  modem.open(3333)

  status, config = pcall(serialization.unserialize, cr)
  
  if not status then
    return false
  end

  while true do
    local ev, bef, from, port, _, nachricht, rclient, rport = event.pullMultiple("modem_message", "ftp")
    if ev == "modem_message" then
      if port == 21 then --um nicht-FTP-Befehle auszusortieren
        if not rclient then rclient = from end
        if nachricht == "ftpreq" then
          local port = math.random(1024, 65535)
          if sockets[from] then
            sockets[from]:kill() --um geistthreads zu löschen
            event.push("ftp", "socket_kill", from, port, config["blocksize"], rclient)
          end
          sockets[from] = thread.create(ftpsocket, from, port, modem, tonumber(config["blocksize"]), rclient)
        end
      end
    elseif ev == "ftp" then
      if bef == "cmd" then
        --TODO vielleicht später tbh
      end
    end
  end
end

local eventbusse = {
  ["lichtsignal"] = {},
  ["weiche"] = {},
  ["gleisfreimeldung"] = {},
  ["blockanforderung"] = {},
  ["blockrueckmeldung"] = {},
  ["eingabe"] = {},
  ["ausgabe"] = {},
  ["anforderung"] = {},
}

local kommunikationssockets = {}
local kommunikationslookup = {}

local function kommunikationssocket(from, port, modem, rclient)
  local event = require("event")
  local serialization = require("serialization")

  while true do
    local _, _, pfrom, pport, _, nachricht = event.pull("modem_message")

    if (pport == port) and (pfrom == from) then
      local status, paket = pcall(serialization.unserialize, nachricht)

      if status and paket then
        if paket["typ"] == "close" then
          event.push("kommunikation", "socket_close", from, port, rclient)
          modem.close(port)
          kommunkationssockets[from .. ":" .. port] = nil
          return 0
        elseif paket["typ"] == "queue" then
          event.push("kommunikation", "event", paket["inhalt"]["typ"], paket["inhalt"]["inhalt"]["nummer"])
          paket["typ"] = "event"
          paket["sender_phys"] = from
          paket["sender_port"] = port
          for name, clienttbl in pairs(eventbusse[paket["inhalt"]["typ"]]) do
            paket["empfaenger"] = name
            paket["sender_rclient"] = rclient
            modem.send(clienttbl["adresse"], clienttbl["port"], serialization.serialize(paket), clienttbl["rclient"])
          end
        elseif paket["typ"] == "ack" then
          paket["typ"] = "ack"
          event.push("kommunikation", "event", paket["typ"], paket["empfaenger"])
          if not (paket["empfaenger"] == "server") then
            modem.send(paket["empfaenger_phys"], paket["empfaenger_port"], serialization.serialize(paket), paket["empfaenger_rclient"])
          end
        end
      end
    end
  end

  return -1
end

function kommunikationsserver(modem)
  local event = require("event")
  local thread = require("thread")
  local serialization = require("serialization")
  
  while true do
    local ev, bef, from, port, _, nachricht, rclient = event.pullMultiple("modem_message", "kommunikation")
    if ev == "modem_message" then
      if port == 3333 then
        if not rclient then rclient = from end
        local status, paket = pcall(serialization.unserialize, nachricht)
        if status and paket then
          if paket["typ"] == "join" then
            if kommunikationssockets[from .. ":" .. port] then
              kommunikationssockets[from .. ":" .. port]:kill()
              kommunikationssockets[from .. ":" .. port] = nil
              for _, bus in pairs(eventbusse) do
                for index, element in pairs(bus) do
                  if (element["adresse"] == from) and (element["rclient"] == rclient) and (element["port"] == port) then
                    bus[index] = nil
                  end
                end
              end
              event.push("kommunikation", "socket_kill", from, erfolg, rclient)
            end

            local erfolg = true
            local busse = paket["inhalt"]["zahl"]
            local fehlend = ""
            local zaehler = 1 --Lua-Arrays fangen aus irgendwelchen Gründen bei 1 an
            local inhalt = paket["inhalt"]

            local pport = math.random(1024, 65536)

            repeat
              if eventbusse[inhalt[zaehler]] then
                eventbusse[inhalt[zaehler]][paket["sender"]] =  { ["adresse"] = from, ["rclient"] = rclient, ["port"] = pport, }
              else
                erfolg = false
                fehlend = inhalt[zaehler]
              end
              zaehler = zaehler + 1
            until zaehler >= busse
  
            local antwort = {
              ["typ"] = "acc",
              ["inhalt"] = {
                ["status"] = erfolg,
              },
            }

            if not erfolg then
              antwort["inhalt"]["err"] = "Angeforderter Eventbus existiert nicht: " .. fehlend
            end

            antwort["inhalt"]["status"] = pport

            modem.send(from, 3333, serialization.serialize(antwort), rclient, pport)

            event.push("kommunikation", "socket_open", from, pport)

            antwort["inhalt"]["status"] = pport

            modem.open(pport)

            kommunikationssockets[from .. ":" .. pport] = thread.create(kommunikationssocket, from, pport, modem, rclient)
          end
        end
      end
    elseif ev == "kommunikation" then
      if bef == "cmd" then
        if from == "forcereboot" then
          modem.broadcast(6800, "forcereboot")
        elseif from == "queue" then
          local status, fh = pcall(io.open, port, "r")
          if status and fh then
            fh:seek("set", 0)
            local status2, teltelegramm = pcall(serialization.unserialize, fh:read("*a"))
            fh:close()

            if status2 and teltelegramm then
              event.push("kommunikation", "info", "queue", teltelegramm["inhalt"]["typ"])
              for _, client in pairs(eventbusse[teltelegramm["inhalt"]["typ"]]) do
                teltelegramm["typ"] = "event"
                teltelegramm["empfaenger"] = client["adresse"]
                teltelegramm["sender"] = "server"
                teltelegramm["sender_phys"] = modem.address
                teltelegramm["sender_rclient"] = modem.address
                modem.send(client["adresse"], client["port"], serialization.serialize(teltelegramm), client["rclient"])
              end
            else
              event.push("kommunikation", "info", "Ungültiges oder fehlerhaftes Paket.")
            end
          end
        end
      end
    end
  end
end

function start()
  term = require("term")
  component = require("component")
  fs = require("filesystem")
  thread = require("thread")
  event = require("event")
  serialization = require("serialization")

  term.clear()
  print("File- und Kommunikationsserver startet.")
  print("Öffne Modem auf 8080")

  local modem = component.getPrimary("modem")
  modem.open(8080)
  modem.open(6800)
  modem.open(21)
  os.sleep(1)
  print("Starte Filesystem-Management..")
  
  for pfad in fs.list("/mnt") do
    if fs.exists(fs.concat("/mnt", pfad, "mp.cfg")) then
      local file = io.open(fs.concat("/mnt", pfad, "mp.cfg"), "r")
      file:seek("set", 0)
      local mountpunkt = file:read("*a")
      file:close()
      print("Moute " .. mountpunkt .. " auf /" ..mountpunkt.."/")
      fs.mount(fs.get(fs.concat("/mnt", pfad)), "/"..mountpunkt.."/")
    end
  end

  os.sleep(2)
  print("Filesystem-Management geladen.")
  print("Lade tinyFTP...")

  tftpfh, err = io.open("/usr/lib/tinyftp.lua", "r")

  if not tftpfh then
    print("TinyFTP kann nicht geladen werden: " .. err)
    print("Kritischer Fehler!")
    os.sleep(5)
  end

  tftpfh:seek("set", 0)
  tftp = tftpfh:read("*a")
  tftpfh:close()

  print("TinyFTP-String geladen!")

  os.sleep(1)

  print("Lade TinyFTP-Executable..")

  local status, tinyftp = pcall(require, "tinyftp")
  if not status then
    print("tinyFTP kann nicht geladen werden!")
    print("Fehler: " .. tinyftp)
    print("Kritischer Fehler!")
    os.sleep(5)
  end

  print("Starte Welcoming-Daemon..")

  thr = thread.create(hintergrundprozess, modem)

  print("Starte FTP-Server-Daemon..")

  ftps = thread.create(ftpserver, modem)

  print("Starte Kommunikationsserver-Daemon..")

  komm = thread.create(kommunikationsserver, modem)

  print("Starte sämtliche Clients neu..")

  modem = modem.broadcast(6800, "forcereboot")

  thr:detach()
  ftps:detach()
  komm:detach()

  print("Hintergrundprozesse gestartet!")
  print("Füge /software/util/ zu PATH hinzu")

  local shell = require("shell")

  shell.setPath(shell.getPath() .. ":/software/util/")

  print("Pfad gesetzt!")
  os.sleep(2)
end

function stop()
  thr:kill()
  ftps:kill()
  print("Daemons abgewürgt!")
  os.sleep(5)
end
