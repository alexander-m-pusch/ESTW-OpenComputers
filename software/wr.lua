local wr = {}

local weichen = {}

local rio = {}

local function empfaenger(nummer, lage)
  local component = require("component")
  if not rio[nummer] then
    return true, false
  end

  local redstone = component.proxy(rio[nummer]["dev"])

  local redstonestaerke = 255

  if rio[nummer]["grundzustand"] == lage then
    redstonestaerke = 0
  end

  redstone.setBundledOutput(rio[nummer]["seite"], { [tonumber(rio[nummer]["adresse"])] = redstonestaerke, })

  print("Empfangen: " .. nummer .. " " .. lage .. " an " .. rio[nummer]["seite"] .. " " .. rio[nummer]["adresse"])

  return true, true
end

function wr.start(tinyftp, ziel, modem, name)
  local term = require("term")
  local fs = require("filesystem")
  local serialization = require("serialization")
  term.clear()

  if not fs.exists("/estw/lib/libocs") then
    fs.makeDirectory("/estw/lib/libocs")
  end

  print("Weichenrechner startet!")
  print("Fordere OCS-Basislibrary an...")
  
  local erfolg, err = tinyftp:download("/estw/lib/libocs/base.lua", "/software/lib/libocs/base.lua")

  if not erfolg then
    error("LibOCS: " .. err)
  end

  local libocs = require("/estw/lib/libocs.base")

  print("LibOCS heruntergeladen!")
  print("Lade OCS-W herunter")

  local erfolg, err = tinyftp:download("/estw/lib/libocs/w.lua", "/software/lib/libocs/w.lua")

  if not erfolg then
    error("OCS-W: " .. err)
  end

  local libw = require("/estw/lib/libocs.w")

  print("OCS-W erfolgreich heruntergeladen!")

  local module = {
    [1] = "weiche"
  }

  local ocsverbindung, err = libocs:connect(name, modem, ziel, module)
  
  local ocs_w = libw:init(ocsverbindung)
  ocs_w:subscribe(empfaenger)

  print("OCS-Bibliothek erfolgreich initialisiert!")
  os.sleep(0.5)

  print("Lade Konfiguration herunter...")
  
  local status, err = tinyftp:download("/estw/etc/rio.cfg", "/konfiguration/wr/" .. name .. "/rio.cfg")

  if not status then
    error("rio-Download: " ..err)
  end

  local rih = io.open("/estw/etc/rio.cfg", "r")
  rih:seek("set", 0)
  local rihs = rih:read("*a")
  rih:close()

  local status, orio = pcall(serialization.unserialize, rihs)

  if not status then
    error("rio.cfg ist nicht einlesbar!")
  end

  rio = orio
  
  ocsverbindung:subscribe(ocs_w)
  ocsverbindung:listener_thread()

  print("Fordere Weichenlagen an..")

  for weiche, _ in pairs(rio) do
    local status = ocsverbindung:request(weiche)
    if not status then
      print("Weiche " .. weiche .. " kann nicht angefordert werden, setze auf Grundzustand!")
    end
  end

  print("Weichenrechner gestartet!")

  print("[DARF NUR DURCH FACHKRAFT LST BEDIENT WERDEN]")

  while true do
    os.sleep(10)
  end
end

return wr
