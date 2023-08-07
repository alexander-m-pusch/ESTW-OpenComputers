local anzeigerechner = {}

local function erzeugeMenuesUndDialoge(dialog, menu, gpu, screen)
  local mud = {
    ["dateimenu"] = menu:new(gpu, screen),
    ["signalmenu"] = menu:new(gpu, screen),
    ["fsmenu"] = menu:new(gpu, screen),
    ["weichenmenu"] = menu:new(gpu, screen),
    ["weichendialog"] = dialog:new(gpu, screen),
    ["begrdialog"] = dialog:new(gpu, screen),
  }

  mud["dateimenu"]:addEntry("neustart", "Stellwerk neu starten")
  mud["dateimenu"]:addEntry("anfordern", "Gleisbild neu anfordern")
  
  mud["signalmenu"]:addEntry("ersgt", "Ersatzsignal anschalten")
  mud["signalmenu"]:addEntry("vorsgt", "Vorsichtsignal anschalten")
  mud["signalmenu"]:addEntry("zs8", "Gegengleisfahrt-Ersatzsignal anschalten")
  mud["signalmenu"]:addEntry("fsha", "Fahrstraßenhilfsauflösung")
  mud["signalmenu"]:addEntry("sht", "Signal auf Halt werfen")
  mud["signalmenu"]:addEntry("hilfsentriegeln", "Signal hilfsentriegeln")
  
  mud["fsmenu"]:addEntry("rfs", "Rangierfahrstraße hierhin")
  mud["fsmenu"]:addEntry("zfs", "Zugfahrstraße hierhin")

  mud["weichenmenu"]:addEntry("wsp", "Weiche sperren")
  mud["weichenmenu"]:addEntry("wesp", "Weiche entspreen")
  mud["weichenmenu"]:addEntry("wum", "Weiche umlegen")
  mud["weichenmenu"]:addEntry("hilfsentriegeln", "Weiche hilfsentriegeln")

  mud["weichendialog"]:setText("Neue Weichenlage (links/rechts)")

  mud["begrdialog"]:setText("Begründung für Hilfshandlung bitte:")

  return mud
end

local statuszeile = ""

local function zeichneMenueBand(gpu, screen)
  local term = require("term")
  gpu.bind(screen)
  term.bind(gpu)
  term.setCursor(1,1)
  term.write("Datei | " .. tostring(statuszeile))
end

elemente = {}
eg = {}

gleise = {}

function updhandler(nummer)
  local event = require("event")
  local computer = require("computer")

  computer.beep(1500)

  local thread = require("thread")
  thread.create(upd_internal, nummer)
end

function upd_internal(nummer)
  local erhalt, erfolg, kommentar = eg:send("info", nummer, "")
  
  elemente[nummer]["zustand"] = {
    ["verriegelt"] = kommentar["verriegelt"],
  }

  if elemente[nummer]["typ"] == "signal" then
    elemente[nummer]["zustand"]["v_hp"] = kommentar["v_hp"]
    elemente[nummer]["zustand"]["v_vr"] = kommentar["v_vr"]
    elemente[nummer]["zustand"]["f_vr"] = kommentar["f_vr"]
  elseif elemente[nummer]["typ"] == "weiche" then
    elemente[nummer]["zustand"]["lage"] = kommentar["lage"]
  end

  local event = require("event")
  event.push("anzeige", nummer)
end

--[[function anforderung_daemon(eg, elemente)
  local ser = require("serialization")
  local event = require("event")

  local computer = require("computer")

  while true do
    for element, tbl in pairs(elemente) do
      local erhalt, erfolg, kommentar = eg:send("info", element, "")
      local zustand_alt = elemente[element]["zustand"]
      if (erfolg and kommentar) then
        elemente[element]["zustand"] = kommentar

        local gleich = true
        if zustand_alt then
          for k, v in pairs(zustand_alt) do
            gleich = gleich and (elemente[element]["zustand"][k] == v)
          end
        else
          gleich = false
        end

        if not gleich then
          event.push("anzeige", element)
        end
      end
    end
    os.sleep(2)
  end
end ]]--

local function kachel_update(element, tile, rendern)
  if element["typ"] == "signal" then
    local tilename = "signal_" .. element["zusatz"] .."_von_" .. element["richtung"]

    if (element["zusatz"] == "hp") or (element["zusatz"] == "ms") or (element["zusatz"] == "ls") then
      if element["zustand"]["v_hp"] == 0 then
        tilename = tilename .. "_halt"
      elseif type(element["zustand"]["v_hp"]) == "number" then
        tilename = tilename .. "_fahrt"
      elseif element["zustand"]["v_hp"] == "s" then
        tilename = tilename .. "_rangierfahrt"
      elseif (element["zustand"]["v_hp"] == "v") or (element["zustand"]["v_hp"] == "e") or (element["zustand"]["v_hp"] == "g") then
        tilename = tilename .. "_vorsicht"
      end
      if (element["zusatz"] == "ms") and (not (element["zustand"]["v_hp"] == 0)) and (type(element["zustand"]["v_hp"]) == "number") then
        if element["zustand"]["f_vr"] then
          tilename = tilename .. "_fahrt_erwarten"
        else
          tilename = tilename .. "_halt_erwarten"
        end
      end
    else
      if not element["zustand"]["f_vr"] then
        tilename = tilename .. "_halt_erwarten"
      else
        tilename = tilename .. "_fahrt_erwarten"
      end
    end

    if element["zustand"]["verriegelt"] > 0 then
      tilename = tilename .. "_fahrstrasse"
    end

    tile:place(tilename, element["x"], element["y"])
    tile:redrawTile(element["x"], element["y"])
    if rendern then tile:render() end

    local computer = require("computer")
    computer.beep(500)
  elseif element["typ"] == "weiche" then
    local tilename = "weiche_" .. element["zusatz"] .. "_von_" .. element["richtung"] .. "_" .. element["zustand"]["lage"] .. "lage"

    if element["zustand"]["verriegelt"] > 0 then
      tilename = tilename .. "_fahrstrasse"
    end

    tile:place(tilename, element["x"], element["y"])
    tile:redrawTile(element["x"], element["y"])
    if rendern then tile:render() end
  elseif element["typ"] == "streckenblock" then
    if element["zustand"]["verriegelt"] > 0 then
      tilename = tilename .. "_fahrstrasse"
    
      tile:place(tilename, element["x"], element["y"])
      tile:redrawTile(element["x"], element["y"])
    end
    --TODO
  end

  for nachbar, liste in pairs(element["nachbarn"]) do
    if elemente[nachbar] then
      if elemente[nachbar]["zustand"] then
        if (element["zustand"]["verriegelt"] > 0) or (element["zustand"]["zielsignal"]) then
          for _, val in pairs(liste) do
            if gleise[val["x"]] then
              if gleise[val["x"]][val["y"]] then
                typ = gleise[val["x"]][val["y"]]["typ"]
                typ = typ .. "_fahrstrasse"

                tile:place(typ, val["x"], val["y"])
                tile:redrawTile(val["x"], val["y"])
              end
            end
          end
        else
          for _, val in pairs(liste) do
            if gleise[val["x"]] then
              if gleise[val["x"]][val["y"]] then
                local typ = gleise[val["x"]][val["y"]]["typ"]

                tile:place(typ, val["x"], val["y"])
                tile:redrawTile(val["x"], val["y"])
              end
            end
          end
        end
      else
        for _, val in pairs(liste) do
          if gleise[val["x"]] then
            if gleise[val["x"]][val["y"]] then
              local typ = gleise[val["x"]][val["y"]]["typ"]
  
              tile:place(typ, val["x"], val["y"])
              tile:redrawTile(val["x"], val["y"])
            end
          end
        end
      end
    end
  end
end

function anzeigerechner.start(tinyftp, ziel, modem, name)
  local term = require("term")
  local fs = require("filesystem")

  term.clear()
  
  print("Anzeigerechner startet!")
  print("Fordere OCS-Bibliotheken an..")

  local status, err = tinyftp:download("/estw/lib/libocs/base.lua", "/software/lib/libocs/base.lua")

  if not status then
    error("OCS-Basis kann nicht angefordert werden: " .. err)
  end

  local status, err = tinyftp:download("/estw/lib/libocs/eg.lua", "/software/lib/libocs/eg.lua")

  if not status then
    error("OCS-Eingabe kann nicht angefordert werden: " .. err)
  end

  local status, err = tinyftp:download("/estw/lib/libocs/upd.lua", "/software/lib/libocs/upd.lua")
  
  if not status then
    error("OCS-Update kann nicht angefordert werden: " .. err)
  end

  local libocs = require("/estw/lib/libocs/base")  
  local libeg = require("/estw/lib/libocs/eg")
  local libupd = require("/estw/lib/libocs/upd")

  local module = {
    [1] = "ausgabe",
  }

  local ocsverbindung, err = libocs:connect(name, modem, ziel, module)

  if not ocsverbindung then
    error("Verbindung kann nicht hergestellt werden: " .. err)
  end

  eg, err = libeg:init(ocsverbindung)

  if not eg then
    error("Eingabe kann nicht gestartet werden: " .. err)
  end

  local upd, err = libupd:init(ocsverbindung)

  if not upd then
    error("Update kann nicht gestartet werden: " .. err)
  end

  upd:subscribe(updhandler)

  ocsverbindung:subscribe(upd)

  print("Mit OCS Verbunden!")

  print("Fordere libdraw an...")

  local status, err = tinyftp:download("/estw/lib/libdraw/dialog.lua", "/software/lib/libdraw/dialog.lua")
  
  if not status then
    error("Kann dialog-API nicht anfordern: " .. err)
  end

  local status, err = tinyftp:download("/estw/lib/libdraw/menu.lua", "/software/lib/libdraw/menu.lua")

  if not status then
    error("Kann menu-API nicht anfordern: " .. err)
  end

  local status, err = tinyftp:download("/estw/lib/libdraw/tile.lua", "/software/lib/libdraw/tile.lua")

  if not status then
    error("Kann tile-API nicht anfordern: " .. err)
  end

  print("libdraw angefordert!")

  local dialog = require("/estw/lib/libdraw/dialog")
  local menu = require("/estw/lib/libdraw/menu")
  local tile = require("/estw/lib/libdraw/tile")

  print("Lade Tileset herunter (dies kann einen Moment dauern)")

  local status, err = tinyftp:download("/estw/lib/libdraw/assets/tileset.tst", "/software/lib/libdraw/assets/tileset.tst")

  if not status then
    error("Tileset konnte nicht heruntergeladen werden: " .. err)
  end

  print("Tileset heruntergeladen!")

  print("Lade Konfiguration herunter...")

  local status, err = tinyftp:download("/estw/etc/screens.cfg", "/konfiguration/azr/" .. name .. "/screens.cfg")

  if not status then
    error("Konnte Konfiguration nicht herunterladen: " .. err)
  end

  local ser = require("serialization")

  local fh = io.open("/estw/etc/screens.cfg", "r")
  local kraw = fh:read("*a")
  fh:close()
  local screens = ser.unserialize(kraw)

  print("Konfiguration eingelesen!")

  local fh = io.open("/estw/lib/libdraw/assets/tileset.tst", "r")
  local traw = fh:read("*a")
  fh:close()
  local tileset = ser.unserialize(traw)

  print("Tileset eingelesen!")

  print("Lade Pläne herunter...")

  local outputger = {}

  local component = require("component")

  for screen, tbl in pairs(screens) do
    print("Erzeuge Bildschirm " .. screen)
    local status, err = tinyftp:download("/estw/etc/" .. tbl["filename"], "/konfiguration/azr/" .. name .. "/" .. tbl["filename"])

    if not status then
      error("Konnte " .. screen .. " nicht anfordern!")
    end

    outputger[component.get(tbl["screen"])] = {
      ["gpu"] = component.proxy(component.get(tbl["gpu"])),
      ["screen"] = tbl["screen"],
      ["tile"] = tile:new(component.get(tbl["gpu"]), component.get(tbl["screen"]), 1, tileset),
      ["mud"] = erzeugeMenuesUndDialoge(dialog, menu, component.get(tbl["gpu"]), component.get(tbl["screen"])),
    }

    outputger[component.get(tbl["screen"])]["gpu"].bind(component.get(tbl["screen"]))

    print("Lese Bildschirmdatei ein..")
    
    local fh = io.open("/estw/etc/" .. tbl["filename"], "r")
    local bsr = fh:read("*a")
    fh:close()
    outputger[component.get(tbl["screen"])]["bsd"] = ser.unserialize(bsr)
    
    for y, row in pairs(outputger[component.get(tbl["screen"])]["bsd"]) do
      for x, tiletbl in pairs(row) do
        outputger[component.get(tbl["screen"])]["tile"]:place(tiletbl["typ"], x, y)
        
        if (not (tiletbl["typ"] == "null")) then
          if (string.sub(tiletbl["typ"], 1, 5) == "gleis") then
            if (not gleise[x]) then
              gleise[x] = {}
            end
            gleise[x][y] = tiletbl
          end
        end

        if (not (tiletbl["typ"] == "null")) and (not (string.sub(tiletbl["typ"], 1, 5) == "gleis")) then
          print("Fordere Element " .. tiletbl["daten"]["nummer"] .. " an..")

          erhalt, erfolg, kommentar = eg:send("info", tiletbl["daten"]["nummer"], "")
          
          elemente[tiletbl["daten"]["nummer"]] = {
            ["typ"] = tiletbl["daten"]["typ"],
            ["screen"] = component.get(tbl["screen"]),
            ["richtung"] = tiletbl["daten"]["beginn"],
            ["nachbarn"] = tiletbl["nachbarn"],
            ["zusatz"] = string.lower(tiletbl["daten"]["funktion"] or tiletbl["daten"]["weichentyp"] or ""),
            ["x"] = x,
            ["y"] = y,
          }

          if erfolg then
            elemente[tiletbl["daten"]["nummer"]]["zustand"] = kommentar
            print("Element " .. tiletbl["daten"]["nummer"] .. " erfolgreich angefordert.")
            kachel_update(elemente[tiletbl["daten"]["nummer"]], outputger[component.get(tbl["screen"])]["tile"], false)
          end
        end
      end
    end
    print("Bildschirmdatei eingelesen!")

  end
  
  ocsverbindung:listener_thread()

  print("Anzeigerechner gestartet!")
  os.sleep(2)

  local term = require("term")

  local thread = require("thread")

  --local daemon = thread.create(anforderung_daemon, eg, elemente)
  --daemon:detach()

  print("Anforderungs-Daemon gestartet!")

  for sc, tbl in pairs(outputger) do
    tbl["gpu"].bind(tbl["screen"])
    term.bind(tbl["gpu"])
    term.clear()
    tbl["tile"]:render()
  end

  local event = require("event")

  local component = require("component")

  local menuAuf = false

  local click1 = nil
  local tle = nil

  --local statuszeile = " Datei | "

  while true do
    local ev, evdev, x, y, taste = event.pullMultiple("touch", "anzeige")


    if ev == "anzeige" then
      local element = elemente[evdev]
      kachel_update(element, outputger[element["screen"]]["tile"], true)
    elseif ev == "touch" then
      local mud = outputger[component.get(evdev)]["mud"]
      zeichneMenueBand(outputger[component.get(evdev)]["gpu"], component.get(evdev))
      if menuAuf then
        if menuAuf == "weiche" then
          local option, x1, y1, x2, y2 = mud["weichenmenu"]:click(x, y)

          if option == "wsp" then
            erreicht, erfolg, kommentar = eg:send("wsp", tle["daten"]["nummer"], "")
          elseif option == "wesp" then
            erreicht, erfolg, kommentar = eg:send("wesp", tle["daten"]["nummer"], "")
          elseif option == "wum" then
            local lage, dx1, dy1, dx2, dy2 = mud["weichendialog"]:open()

            erreicht, erfolg, kommentar = eg:send("wum", tle["daten"]["nummer"], lage)

            outputger[component.get(evdev)]["tile"]:redrawArea(dx1, dy1, dx2, dy2)
          elseif option == "hilfsentriegeln" then
            local begr, dx1, dy1, dx2, dy2 = mud["begrdialog"]:open()

            erreicht, erfolg, kommentar = eg:send("hilfsentriegeln", tle["daten"]["nummer"], begr)

            outputger[component.get(evdev)]["tile"]:redrawAreax(dx1, dy1, dx2, dy2)
          end

          outputger[component.get(evdev)]["tile"]:redrawArea(x1, y1, x2, y2)
        elseif menuAuf == "signal" then
          local option, x1, y1, x2, y2 = mud["signalmenu"]:click(x, y)

          if option == "ersgt" then
            local begr, dx1, dy1, dx2, dy2 = mud["begrdialog"]:open()

            erreicht, erfolg, kommentar = eg:send("ersgt", tle["daten"]["nummer"], begr)

            outputger[component.get(evdev)]["tile"]:redrawArea(dx1, dy1, dx2, dy2)
          elseif option == "vorsgt" then
            local begr, dx1, dy1, dx2, dy2 = mud["begrdialog"]:open()

            erreicht, erfolg, kommentar = eg:send("vorsgt", tle["daten"]["nummer"], begr)

            outputger[component.get(evdev)]["tile"]:redrawArea(dx1, dy1, dx2, dy2)
          elseif option == "zs8" then
            local begr, dx1, dy1, dx2, dy2 = mud["begrdialog"]:open()

            erreicht, erfolg, kommentar = eg:send("zs8", tle["daten"]["nummer"], begr)

            outputger[component.get(evdev)]["tile"]:redrawArea(dx1, dy1, dx2, dy2)
          elseif option == "fsha" then
            local begr, dx1, dy1, dx2, dy2 = mud["begrdialog"]:open()

            erreicht, erfolg, kommentar = eg:send("fsha", tle["daten"]["nummer"], begr)

            outputger[component.get(evdev)]["tile"]:redrawArea(dx1, dy1, dx2, dy2)
          elseif option == "sht" then
            local begr, dx1, dy1, dx2, dy2 = mud["begrdialog"]:open()

            erreicht, erfolg, kommentar = eg:send("sht", tle["daten"]["nummer"], begr)

            outputger[component.get(evdev)]["tile"]:redrawArea(dx1, dy1, dx2, dy2)
          elseif option == "hilfsentriegeln" then
            local begr, dx1, dy1, dx2, dy2 = mud["begrdialog"]:open()

            erreicht, erfolg, kommentar = eg:send("hilfsentriegeln", tle["daten"]["nummer"], begr)

            outputger[component.get(evdev)]["tile"]:redrawArea(dx1, dy1, dx2, dy2)
          end

          if not kommentar then kommentar = "<keine detaillierte Antwort vom Server>" end

          statuszeile = kommentar

          local term = require("term")
          term.setCursor(1, 1)
          print(statuszeile)

          outputger[component.get(evdev)]["tile"]:redrawArea(x1, y1, x2, y2)
        elseif menuAuf == "fahrstr" then
          local option, x1, y1, x2, y2 = mud["fsmenu"]:click(x, y)

          if option == "rfs" then
            eg:send("rfs", click1["daten"]["nummer"], tle["daten"]["nummer"])
          elseif option == "zfs" then
            eg:send("zfs", click1["daten"]["nummer"], tle["daten"]["nummer"])
          end

          outputger[component.get(evdev)]["tile"]:redrawArea(x1, y1, x2, y2)
        end
        menuAuf = nil
        click1 = nil
        tle = nil
      else
        local tbl = outputger[component.get(evdev)]["bsd"]
        local selX, selY = outputger[component.get(evdev)]["tile"]:toTileCoords(x, y)
        tle = tbl[selY][selX]

        if not click1 then
          if taste == 0 then
            click1 = tle
          else
            if tle["daten"]["typ"] == "weiche" then
              mud["weichenmenu"]:open(x, y)
              menuAuf = "weiche"
            elseif tle["daten"]["typ"] == "signal" then
              mud["signalmenu"]:open(x, y)
              menuAuf = "signal"
            elseif tle["daten"]["typ"] == "block" then
              mud["signalmenu"]:open(x, y) --workaround
              menuAuf = "signal"
            end
          end
        else
          mud["fsmenu"]:open(x, y)
          menuAuf = "fahrstr"
        end
      end
    end
  end
end

return anzeigerechner
