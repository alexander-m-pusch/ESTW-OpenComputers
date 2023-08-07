local libocs = {}

local function empfangen(psender, pport, timeout, uuid, bus) --blockiert
  local event = require("event")
  local computer = require("computer")
  local serialization = require("serialization")

  local bef = computer.uptime()

  repeat
    local elapsed = computer.uptime() - bef
    local _, loc, from, port, _, nachricht = event.pull(timeout - elapsed, "modem_message")

    if (psender == from) and (pport == port) and not (psender == loc) then
      if not uuid then
        return from, port, nachricht
      else
        local status, msg = pcall(serialization.unserialize, nachricht)
        if status then
          if msg["num"] == uuid then
            return from, port, nachricht
          end
        end
      end
    end
  until elapsed > timeout

  return nil, "Timeout bei er Anfrage"
end

function libocs:connect(name, pmodem, ziel, module, fsr)
  local o = {
    ["modem"] = pmodem,
    ["name"] = name,
    ["ziel"] = ziel,
    ["fsr"] = fsr,
  }

  pmodem.open(3333)
  pmodem.open(6800)

  setmetatable(o, libocs)
  self.__index = self

  local serialization = require("serialization")

  local paket = {
    ["typ"] = "join",
    ["num"] = require("uuid").next(),
    ["sender"] = name,
    ["inhalt"] = {
      ["zahl"] = #module,
    },
  }

  for k, v in pairs(module) do
    paket["inhalt"][k] = v
  end

  pmodem.send(ziel, 3333, serialization.serialize(paket))

  local sender, port, nachricht = empfangen(ziel, 3333, 10)

  if not sender then
    return nil, port
  end

  local status, antwort = pcall(serialization.unserialize, nachricht)

  if not status then
    return nil, "Antwort ist ungültig"
  end

  if not antwort["inhalt"]["status"] then
    return nil, antwort["inhalt"]["err"]
  end

  o["port"] = antwort["inhalt"]["status"]

  pmodem.open(o["port"])

  return o
end

local subscribers = {}

function libocs:send(inhalt, wait)
  local uuid = require("uuid")
  local serialization = require("serialization")

  local telegramm = {
    ["typ"] = "queue",
    ["sender"] = self.name,
    ["num"] = uuid.next(),
    ["inhalt"] = inhalt,
  }

  self.modem.send(self.ziel, self.port, serialization.serialize(telegramm))

  if (not self["fsr"]) and (not wait) then
    local sender, port, nachricht = empfangen(self.ziel, self.port, 10, telegramm["num"], inhalt["typ"])

    status, msg = pcall(serialization.unserialize, nachricht)
  
    if status then
      return msg["inhalt"]["erhalt"], msg["inhalt"]["erfolg"], msg["inhalt"]["kommentar"]
    end
  end
end

function libocs:request(nummer)
  local telegramm = {
    ["typ"] = "anforderung",
    ["inhalt"] = {
      ["nummer"] = nummer,
    },
  }

  return self:send(telegramm)
end

function libocs:subscribe(subscriber)
  if not subscribers[subscriber.bus] then
    subscribers[subscriber.bus] = {}
  end
  table.insert(subscribers[subscriber.bus], subscriber)
end

local function listener_internal(modem, ziel, pport, name)
  local event = require("event")
  local serialization = require("serialization")
  local computer = require("computer")

  while true do
    local _, _, from, port, _, msgraw = event.pull("modem_message")
    if port == 6800 then
      computer.beep(1000)
      if msgraw == "forcereboot" then
        print("Der Server forciert einen Neustart.")
        local computer = require("computer")

        computer.beep(2000)
        computer.shutdown(true)
      end
    elseif (from == ziel) and (port == pport) then
      local status, nachricht = pcall(serialization.unserialize, msgraw)
      if status then
        if nachricht["typ"] == "event" then
          local erfolg = true
          local abteilung = false

          if subscribers[nachricht["inhalt"]["typ"]] then
            for _, subscriber in pairs(subscribers[nachricht["inhalt"]["typ"]]) do
              local abt, erfolgr, kommentar = subscriber:callback(nachricht["inhalt"]["inhalt"])
              if abt then
                abteilung = true
              end
              erfolg = erfolg and erfolgr
            end

            local antworttelegramm = {
              ["typ"] = "ack",
              ["sender"] = name,
              ["empfaenger"] = nachricht["sender"],
              ["empfaenger_port"] = nachricht["sender_port"],
              ["empfaenger_phys"] = nachricht["sender_phys"],
              ["empfaenger_rclient"] = nachricht["sender_rclient"],
              ["num"] = nachricht["num"],
              ["inhalt"] = {
                ["erhalt"] = "true",
                ["erfolg"] = erfolg,
                ["kommentar"] = kommentar,
              },
            }

            if abteilung then
              modem.send(ziel, port, serialization.serialize(antworttelegramm))
            end
          end
        end
      end
    end
  end
end

function libocs:listener_thread()
  local thread = require("thread")
  thread.create(listener_internal, self.modem, self.ziel, self.port, self.name)
end

function libocs:close()
  local serialization = require("serialization")

  local telegramm = {
    ["typ"] = "close",
    ["inhalt"] = {},
  }

  self.modem.send(self.ziel, self.port, serialization.serialize(telegramm))
  self.modem.close(self.port)
end

return libocs
