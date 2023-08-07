local blockrechner = {}

local rio = {}

local eingabe = {}

function empfaenger(nummer, funktion)
  local event = require("event")

  local serialization = require("serialization")

  if not rio[nummer] then
    event.push("block", nummer, "Nicht unser Block")
    return false -- nicht unsere Baustelle
  end

  local component = require("component")

  local redstone = component.proxy(rio[nummer]["dev"])

  redstone.setBundledOutput(tonumber(rio[nummer]["seite"]), { [tonumber(rio[nummer]["adresse"])] = 255 } )

  local thread = require("thread")

  event.push("block", nummer, "Vorblock", rio[nummer]["adresse"])

  return true, true, "Erfolg"
end

function redstone()
  local event = require("event")
  local component = require("component")

  while true do
    local _, dev, seite, alterWert, neuerWert, adresse = event.pull("redstone_changed")

    if neuerWert > alterWert then
      for block, btl in pairs(rio) do
        if btl["dev"] == dev then
          if btl["seite"] == seite then
            if btl["rueckbadresse"] == adresse then
              event.push("block", block, "Rückblock")
              local redstone = component.proxy(rio[block]["dev"])
              redstone.setBundledOutput(tonumber(rio[block]["seite"]), { [tonumber(rio[block]["adresse"])] = 0} )
              eingabe:send("blockfrei", block, "frei")
            end
          end
        end
      end
    end
  end
end

function blockrechner.start(tinyftp, ziel, modem, name)
  local term = require("term")
  local computer = require("computer")
  local fs = require("filesystem")
  local serialization = require("serialization")
  local component = require("component")
  local thread = require("thread")

  print("startet...")

  os.sleep(5)

  if not fs.exists("/estw/") then fs.mkdir("/estw/") end

  term.clear()
  print("Blockrechner startet!")
  os.sleep(0.5)
  print("Fordere OCS-Basislibrary an..")

  local erfolg, err = tinyftp:download("/estw/lib/libocs/base.lua", "/software/lib/libocs/base.lua")
  if not erfolg then
    error("LibOCS-Download: " .. err)
  end

  if not fs.exists("/estw/lib/") then fs.makeDirectory("/estw/lib/") end

  local libocs = require("/estw/lib/libocs.base")

  local module = {
    [1] = "block",
  }
  
  local ocsverbindung, err = libocs:connect(name, modem, ziel, module)

  if not ocsverbindung then
    error("OCS-Verbindung: " .. err)
  end

  print("Erfolgreich mit OCS verbunden!")
  print("Fordere OCS-BK-Schnittstelle an...")
  os.sleep(0.5)

  if not fs.exists("/estw/lib/libocs/") then fs.makeDirectory("/estw/lib/libocs/") end

  local erfolg, err = tinyftp:download("/estw/lib/libocs/bk.lua", "/software/lib/libocs/bk.lua")
  if not erfolg then
    error("OCS-LS-Download: " .. err)
  end

  local libocs_ls = require("/estw/lib/libocs.bk")

  local ocs_ls = libocs_ls:init(ocsverbindung)
  ocs_ls:subscribe(empfaenger)

  print("OCS-BK-Schnittstelle geladen!")

  print("Fordere OCS-EG an..")
  local erfolg, err = tinyftp:download("/estw/lib/libocs/eg.lua", "/software/lib/libocs/eg.lua")
  os.sleep(0.5)
  if not erfolg then
    error("OCS-EG-Download: " .. err)
  end

  print("OCS-EG-Schnittstelle geladen, fordere Konfiguration an..")

  local libocs_eg = require("/estw/lib/libocs.eg")

  eingabe = libocs_eg:init(ocsverbindung)

  if not fs.exists("/estw/etc/") then fs.makeDirectory("/estw/etc/") end

  local erfolg, err = tinyftp:download("/estw/etc/rio.cfg", "/konfiguration/bkr/" .. name ..  "/rio.cfg")
  if not erfolg then
    error("Konfigurationsdownload: " .. err)
  end

  print("Lese Konfiguration ein...")

  local konfh = io.open("/estw/etc/rio.cfg", "r")
  konfh:seek("set", 0)
  local konfraw = konfh:read("*a")
  konfh:close()

  local status, orio = pcall(serialization.unserialize, konfraw)

  if not status then
    error("Signalplan unlesbar.")
  end

  rio = orio

  print("Konfiguration eingelesen, starte Redstoneausgabegeräte...")

  local fehlerhaft = {}

  print("Konfiguration eingelesen!")

  ocsverbindung:subscribe(ocs_ls)
  ocsverbindung:listener_thread()

  thread.create(redstone)

  print("Blockrechner gestartet!")
  print("[BKR DARF NUR DURCH FACHKRAFT LST BEDIENT WERDEN]")

  local event = require("event")
  while true do
    local ev, arg1, arg2, arg3, arg4, arg5, arg6 = event.pull("block")
    if not arg1 then arg1 = "" end
    if not arg2 then arg2 = "" end
    if not arg3 then arg3 = "" end
    if not arg4 then arg4 = "" end
    if not arg5 then arg5 = "" end
    if not arg6 then arg6 = "" end
    print(tostring(arg1) .. " " .. tostring(arg2) .. " " .. tostring(arg3) .. " " .. tostring(arg4) .. " " .. tostring(arg5) .. " " .. tostring(arg6))
  end
end

return blockrechner
