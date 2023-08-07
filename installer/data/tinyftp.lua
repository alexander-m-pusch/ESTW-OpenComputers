local tinyftp = {}

local function empfangen(psender, pport, timeout)
  local computer = require("computer")
  local event = require("event")

  local bef = computer.uptime()

  repeat
    local elapsed = computer.uptime() - bef
    local _, _, sender, port, _, nachricht = event.pull(timeout - elapsed, "modem_message")
    if (psender == sender) and (pport == port) then
      return sender, port, nachricht
    end

  until elapsed > timeout
  return nil, "Timeout bei der Anfrage"
end

function tinyftp:connect(pmodem, ziel)
  local event = require("event")
  local serialization = require("serialization")
  local component = require("component")

  local modem = component.proxy(pmodem)

  local obj = {
    ["modem"] = pmodem,
    ["ziel"] = ziel,
  }
  setmetatable(obj, self)
  self.__index = self
  
  modem.open(21)

  modem.send(ziel, 21, "ftpreq")
 
  local sender, port, nachricht = empfangen(ziel, 21, 10)

  modem.close(21)
  if not sender then
    return nil, port
  end

  local status, tbl = pcall(serialization.unserialize, nachricht)
  if not status then
    return nil, "Ungültige Antwort vom FTP-Server"
  end

  obj["port"] = tbl["port"]
  obj["blocksize"] = tbl["blocksize"]

  modem.open(tonumber(tbl["port"]))

  return obj
end

function tinyftp:download(name_lokal, name_remote)
  local component = require("component")
  local serialization = require("serialization")
  local fs = require("filesystem")

  local req = {
    ["typ"] = "download",
    ["inhalt"] = name_remote,
  }

  local modem = component.proxy(self.modem)
  modem.send(self.ziel, self.port, serialization.serialize(req))

  local sender, port, nachricht = empfangen(self.ziel, self.port, 5)

  local status, antwort = pcall(serialization.unserialize, nachricht)
  if not status then
    return nil, "Ungültige Antwort vom FTP-Server"
  end

  if not (antwort["typ"] == "bereit") then
    return nil, "Server kann Datei nicht liefern: " .. antwort["inhalt"]
  end

  local dateigroesse = tonumber(antwort["inhalt"])

  --bereit zum empfangen

  modem.send(self.ziel, self.port, "anfangen")
  
  local bytes = 0
  
  if fs.exists(name_lokal) then
    fs.remove(name_lokal) --ohne rücksicht auf eigene verluste
  end

  local dlfh, err = io.open(name_lokal, "wb")

  if not dlfh then
    return nil, "Kann DL-Datei nicht öffnen: " .. err
  end

  repeat
    local sender, port, nachricht = empfangen(self.ziel, self.port, 10)
    if not sender then
      dlfh:close()
      return nil, "Timeout"
    end

    dlfh:write(nachricht)

    bytes = bytes + string.len(nachricht)
  until bytes >= dateigroesse

  dlfh:close()
  return true
end

function tinyftp:upload(name_lokal, name_remote)
  local component = require("component")
  local serialization = require("serialization")

  local req = {
    ["typ"] = "upload",
    ["inhalt"] = name_remote,
    ["groesse"] = "",
  }

  local ulfh = io.open(name_lokal, "rb")
  ulfh:seek("set", 0)
  local inhalt = ulfh:read("*a")
  
  req.groesse = string.len(inhalt)

  local modem = component.proxy(self.modem)
  modem.send(self.ziel, self.port, serialization.serialize(req))

  local sender, port, nachricht = empfangen(self.ziel, self.port, 10)

  local status, antwort = pcall(serialization.unserialize, nachricht)
  if not status then
    return nil, "Ungültige Antwort vom FTP-Server"
  end

  if not (antwort["typ"] == "bereit") then
    return nil, "Server ist nicht bereit: " .. (antwort["inhalt"] or "Der Server hat den Upload verweigert.")
  end

  --bereit zum senden

  ulfh:seek("set", 0)
  
  local gelesen = 0
  repeat
    local zulesen = math.min(self.blocksize, req.groesse - gelesen)
    modem.send(self.ziel, self.port, ulfh:read(zulesen))
    gelesen = gelesen + zulesen
  until gelesen >= req.groesse

  ulfh:close()
  return true
end

function tinyftp:remove(name)
  local component = require("component")
  local serialization = require("serialization")
  
  local req = {
    ["typ"] = "remove",
    ["inhalt"] = name,
  }
  
  local modem = component.proxy(self.modem)

  modem.send(self.ziel, self.port, serialization.serialize(req))

  local sender, port, nachricht = empfangen(self.ziel, self.port, 5)
  local status, antwort = pcall(serialization.unserialize, nachricht)
  if not status then
    return nil, "Ungültige Antwort vom Server"
  end
  return antwort["typ"], antwort["inhalt"]
end

function tinyftp:move(von, nach)
  local component = require("component")
  local serialization = require("serialization")
  
  local req = {
    ["typ"] = "move",
    ["von"] = von,
    ["nach"] = nach,
  }

  local modem = component.proxy(self.modem)

  modem.send(self.ziel, self.port, serialization.serialize(req))

  local sender, port, nachricht = empfangen(self.ziel, self.port, 5)
  local status, antwort = pcall(serialization.unserialize, nachricht)
  if not status then
    return nil, "Ungültige Antwort vom Server"
  end
  return antwort["typ"], antwort["inhalt"]
end

function tinyftp:mkdir(name)
  local component = require("component")
  local serialization = require("serialization")

  local req = {
    ["typ"] = "mkdir",
    ["inhalt"] = name,
   }

  local modem = component.proxy(self.modem)

  modem.send(self.ziel, self.port, serialization.serialize(req))

  local sender, port, nachricht = empfangen(self.ziel, self.port, 5)
  local status, antwort = pcall(serialization.unserialize, nachricht)
  if not status then
    return nil, "Ungültige Antwort vom Server"
  end
  return antwort["typ"], antwort["inhalt"]
end

function tinyftp:close()
  local component = require("component")
  local serialization = require("serialization")

  local req = {
    ["typ"] = "schliessen",
  }

  local modem = component.proxy(self.modem)
  modem.send(self.ziel, self.port, serialization.serialize(req))

  modem.close(self.port)
end

return tinyftp
