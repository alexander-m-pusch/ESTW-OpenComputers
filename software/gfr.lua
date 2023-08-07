local gleisfreimelderechner = {}

local rio = {}

local function input(ogf)
  local event = require("event")
  local thread = require("thread")

  while true do
    local _, dev, seite, alterWert, neuerWert, adresse = event.pull("redstone_changed")

    local freigefahren = true

    if alterWert < neuerWert then
      freigefahren = false
    end

    thread.create(ogf.send, ogf, rio[dev][seite][adresse], freigefahren)
  end
end

function gleisfreimelderechner.start(tinyftp, ziel, modem, name)
  local term = require("term")
  local serialization = require("serialization")
  local thread = require("thread")
  term.clear()

  print("Gleisfreimelderechner startet!")

  local status, err = tinyftp:download("/estw/lib/libocs/base.lua", "/software/lib/libocs/base.lua")

  if not status then
    error("LibOCS-Download: " .. err)
  end

  local libocs = require("/estw/lib/libocs.base")

  local status, err = tinyftp:download("/estw/lib/libocs/gfr.lua", "/software/lib/libocs/gfr.lua")

  if not status then
    error("OCS-GF-Download: " .. err)
  end

  local libgfr = require("/estw/lib/libocs.gfr")

  local module = {
    [1] = "gleisfreimeldung",
  }

  local ocsverbindung, err = libocs:connect(name, modem, ziel, module)

  local ocs_gf = libgfr:init(ocsverbindung)

  os.sleep(0.5)
  print("OCS Verbunden!")

  print("Fordere rio.cfg an..")

  local status, err = tinyftp:download("/estw/etc/rio.cfg", "/konfiguration/gfr/" .. name .. "/rio.cfg")

  if not status then
    error("rio.cfg kann nicht angefordert werden!")
  end

  local fh = io.open("/estw/etc/rio.cfg", "r")
  fh:seek("set", 0)
  local rraw = fh:read("*a")
  fh:close()

  local status, orio = pcall(serialization.unserialize, rraw)

  if not status then
    error("rio.cfg ist unlesbar!")
  end

  rio = orio

  thread.create(input, ocs_gf)

  print("Gleisfreimelderechner gestartet!")
  print("[DARF NUR DURCH FACHRKRAFT LST BEDIENT WERDEN]")

  while true do
    os.sleep(10)
  end  

end

return gleisfreimelderechner
