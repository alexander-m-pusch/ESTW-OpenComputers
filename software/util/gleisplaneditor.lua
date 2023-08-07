print("Gruppenverbindungsplaneditor der ESTW-Software, geschrieben von Alexander 'ampericus' Pusch")
print("Gruppenverbindungsplandatei bitte:")
local datei = io.read()

local fs = require("filesystem")
local serialization = require("serialization")
local term = require("term")

local elementzaehler = 0
local dateibuffer = {}

package.path = package.path .. ";/?.lua"

if fs.exists(datei) then
  local fh = io.open(datei, "r")
  fh:seek("set", 0)
  local flr = fh:read("*a")
  fh:close()

  dateibuffer = serialization.unserialize(flr)
  print("Gruppenverbindungsplandatei eingelesen!")
else
  print("Gruppenverbindungsplandatei angelegt!")
end

print("Lade Bibliotheken!")
local tile = require("/software/lib/libdraw.tile")
local menu = require("/software/lib/libdraw.menu")
local dialog = require("/software/lib/libdraw.dialog")
print("Bibliotheken geladen!")
print("Lese Tileset ein!")

local fh = io.open("/software/lib/libdraw/assets/tileset.tst", "r")
fh:seek("set", 0)
local tsr = fh:read("*a")
fh:close()

local success, tileset = pcall(serialization.unserialize, tsr)

if not success then error(tileset) end

print("Tileset geladen!")
print("Tileeditor startet!")

os.sleep(0.5)

local term = require("term")
local component = require("component")
local event = require("event")

local gpu = component.gpu

term.clear()

local statuszeile = ""

local canvas = tile:new(component.gpu.address, component.screen.address, 1, tileset)

elementzaehler = canvas["bottomY"] * canvas["rightX"]

local function zeichneMenuBand()
  term.setCursor(1, 1)
  gpu.setBackground(0x0E0E0E)
  gpu.setForeground(0xFFFFFF)
  term.clearLine()
  term.write("Datei | Spurplan | " .. statuszeile)
  gpu.setBackground(0x000000)
end

local function speichern()
  local fh = io.open(datei, "w")
  fh:seek("set", 0)
  fh:write(serialization.serialize(dateibuffer))
  fh:close()
end

local function kachelBei(x, y)
  if not dateibuffer[y] then
    return "null", {}
  end
  if not dateibuffer[y][x] then
    return "null", {}
  end
  return dateibuffer[y][x]["typ"], dateibuffer[y][x]["daten"]
end

local function platziereKachel(x, y, kacheltyp, daten) --x und y in Tilespace, nicht screenspace
  if not dateibuffer[y] then
    dateibuffer[y] = {}
  end

  dateibuffer[y][x] = {
    ["typ"] = kacheltyp,
    ["daten"] = daten,
  }

  canvas:place(kacheltyp, x, y)
end

local function verschiebeKachel(x1, y1, x2, y2)
  local typ, daten = kachelBei(x1, y1)
  platziereKachel(x2, y2, typ, daten)
  platziereKachel(x1, y1, "null", {})
end

local function gegenueber_gleis(typp, von)
  local typ = typp
  if typ == "gleis_geradeaus" then
    if von == "links" then
      return 1, 0, "links"
    else
      return -1, 0, "rechts"
    end
  elseif typ == "gleis_von_links_nach_oben_rechts" then
    if von == "links" then
      return 1, -1, "unten_links"
    else
      return -1, 0, "rechts"
    end
  elseif typ == "gleis_von_links_nach_unten_rechts" then
    if von == "links" then
      return 1, 1, "oben_links"
    else
      return -1, 0, "rechts"
    end
  elseif typ == "gleis_von_oben_links_nach_rechts" then
    if von == "oben_links" then
      return 1, 0, "links"
    else
      return -1, -1, "unten_rechts"
    end
  elseif typ == "gleis_von_oben_links_nach_unten_rechts" then
    if von == "oben_links" then
      return 1, 1, "oben_links"
    else
      return -1, -1, "unten_rechts"
    end
  elseif typ == "gleis_von_unten_links_nach_rechts" then
    if von == "unten_links" then
      return 1, 0, "links"
    else
      return -1, 1, "oben_rechts"
    end
  elseif typ == "gleis_von_unten_links_nach_oben_rechts" then
    if von == "unten_links" then
      return 1, -1, "unten_links"
    else
      return -1, 1, "oben_rechts"
    end
  else
    if von == "links" then return -1, 0, "rechts" end
    if von == "rechts" then return 1, 0, "links" end
    if von == "unten_links" then return -1, 1, "oben_rechts" end
    if von == "unten_rechts" then return 1, 1, "oben_links" end
    if von == "oben_links" then return -1, -1, "unten_rechts" end
    if von == "oben_rechts" then return 1, -1, "unten_links" end
  end
end

local function sollGeskipptWerden(typ)
  if typ == "gleis_geradeaus" then return true
  elseif typ == "gleis_von_links_nach_unten_rechts" then return true
  elseif typ == "gleis_von_links_nach_oben_rechts" then return true
  elseif typ == "gleis_von_unten_links_nach_rechts" then return true
  elseif typ == "gleis_von_unten_links_nach_oben_rechts" then return true
  elseif typ == "gleis_von_oben_links_nach_rechts" then return true
  elseif typ == "gleis_von_oben_links_nach_unten_rechts" then return true
  elseif typ == "null" then return true
  elseif typ == "link" then return true
  else return false end
end

local vorbehalt = {}

local function gleisrekursion(x, y, von, infs, parend, num, wegDahin)
  local typ = dateibuffer[y][x]["typ"]

  if not infs then
    if typ == "null" then
      statuszeile = "WARNUNG: Element bei (" .. x .. "|" .. y .. ") ist null, kommend aus " .. von
      zeichneMenuBand()
      os.sleep(5)
      return ""
    end
    if not sollGeskipptWerden(typ) then

      local liste = {}
      table.insert(liste, {["x"] = x, ["y"] = y,})

      if vorbehalt[num] then
        if vorbehalt[num][dateibuffer[y][x]["daten"]["nummer"]] then
          return vorbehalt[num][dateibuffer[y][x]["daten"]["nummer"]], liste
        end
      end
      
      return dateibuffer[y][x]["daten"]["nummer"], liste
    end
  end 

  statuszeile = "Taste ab für Nachbar: " ..  von .. ", " .. typ .. "(" .. x .. "|" .. y .. ")"
  zeichneMenuBand()

  local dx, dy, von = gegenueber_gleis(typ, von)

  os.sleep(0.01)

  local name, liste = gleisrekursion(x + dx, y + dy, von, false, parend, num)

  statuszeile = "Ende für " .. von .. " gefunden: " .. name .. "(" .. x + dx .. "|" .. y + dy .. ")"
  zeichneMenuBand()

  table.insert(liste, {["x"] = x, ["y"] = y,})

  os.sleep(0.01)

  return name, liste
end

local function exportiere_fahrstrassenplan(zieldatei)
  local exportbuffer = {}
  local exportzaehler = 0
  for y, zeile in pairs(dateibuffer) do
    for x, element in pairs(zeile) do
      if not element["daten"]["nummer"] then element["daten"]["nummer"] = "" end
      statuszeile = tostring((exportzaehler / elementzaehler) * 100) .. "%: Exportiere " .. element["typ"] .. ": " .. element["daten"]["nummer"]
      zeichneMenuBand()
      exportzaehler = exportzaehler + 1
      os.sleep(0.01)
      if not sollGeskipptWerden(element["typ"]) then
        local element = dateibuffer[y][x]
        if element["daten"]["typ"] == "signal" then
          exportbuffer[element["daten"]["nummer"]] = {
            ["typ"] = element["daten"]["typ"],
            ["system"] = element["daten"]["system"],
            ["funktion"] = element["daten"]["funktion"],
            ["grz"] = element["daten"]["grz_kennlicht"],
            ["startv"] = element["daten"]["startv"],
            ["gleisabschluss"] = element["daten"]["gleisabschluss"],
          }
          local anfang = "links"
          local ende = "rechts"
          if element["daten"]["beginn"] == "rechts" then
            anfang = "rechts"
            ende = "links"
          end
          
          anfang_nummer, anfang_liste = gleisrekursion(x, y, anfang, true, "anfang", element["daten"]["nummer"])
          ende_nummer, ende_liste = gleisrekursion(x, y, anfang, true, "ende", element["daten"]["nummer"])

          exportbuffer[element["daten"]["nummer"]]["nachbarn"] = {
            ["anfang"] = anfang_nummer,
            ["ende"] = ende_nummer,
          }

          dateibuffer[y][x]["nachbarn"] = {
            [anfang_nummer] = anfang_liste,
            [ende_nummer] = ende_liste,
          }

          if not exportbuffer[element["daten"]["nummer"]]["nachbarn"]["ende"] then
            exportbuffer[element["daten"]["nummer"]]["gleisabschluss"] = true
          end
        elseif element["daten"]["typ"] == "weiche" then
          local grundstellung = "rechts"

          if element["daten"]["weichentyp"] == "rechtsweiche" then
            grundstellung = "links"
          end

          exportbuffer[element["daten"]["nummer"]] = {
            ["typ"] = element["daten"]["typ"],
            ["nummer"] = element["daten"]["nummer"],
            ["grundstellung"] = grundstellung,
            ["lagen"] = {
              ["links"] = {
                ["vmax"] = element["daten"]["vmax_links"],
              },
              ["rechts"] = {
                ["vmax"] = element["daten"]["vmax_rechts"],
              },
            },
          }

          local anfang = "links"
          local ende_rechts = "rechts"
          local ende_links = "oben_rechts"
          if element["daten"]["weichentyp"] == "linksweiche" then
            if element["daten"]["beginn"] == "oben_links" then
              anfang = "oben_links"
              ende_rechts = "unten_rechts"
              ende_links = "rechts"
            elseif element["daten"]["beginn"] == "unten_rechts" then
              anfang = "unten_rechts"
              ende_rechts = "oben_links"
              ende_links = "links"
            elseif element["daten"]["beginn"] == "rechts" then
              anfang = "rechts"
              ende_rechts = "links"
              ende_links = "unten_links"
            end
          elseif element["daten"]["weichentyp"] == "rechtsweiche" then
            if element["daten"]["beginn"] == "links" then
              anfang = "links"
              ende_rechts = "unten_rechts"
              ende_links = "rechts"
            elseif element["daten"]["beginn"] == "unten_links" then
              anfang = "unten_links"
              ende_rechts = "rechts"
              ende_links = "oben_rechts"
            elseif element["daten"]["beginn"] == "oben_rechts" then
              anfang = "oben_rechts"
              ende_rechts = "links"
              ende_links = "unten_links"
            elseif element["daten"]["beginn"] == "rechts" then
              anfang = "rechts"
              ende_rechts = "oben_links"
              ende_links = "links"
            end
          end

          spitze_nummer, spitze_liste = gleisrekursion(x, y, anfang, true, "spitze", element["daten"]["nummer"])
          links_nummer, links_liste = gleisrekursion(x, y, ende_links, true, "links", element["daten"]["nummer"])
          rechts_nummer, rechts_liste = gleisrekursion(x, y, ende_rechts, true, "rechts", element["daten"]["nummer"])

          exportbuffer[element["daten"]["nummer"]]["nachbarn"] = {
            ["spitze"] = spitze_nummer,
            ["links"] = links_nummer,
            ["rechts"] = rechts_nummer,
          }

          dateibuffer[y][x]["nachbarn"] = {
            [spitze_nummer] = spitze_liste,
            [links_nummer] = links_liste,
            [rechts_nummer] = rechts_liste,
        }

        elseif element["daten"]["typ"] == "kreuzung" then
          local a = "unten_links"
          local b = "oben_links"
          local c = "oben_rechts"
          local d = "unten_rechts"

          if element["daten"]["form"] == "geradeaus" then
            if element["daten"]["beginn"] == "rechts" then
              a = "links"
              c = "rechts"
            else
              b = "links"
              d = "rechts"
            end
          end

          a_nummer, a_liste = gleisrekursion(x, y, a, true, "a", element["daten"]["nummer"])
          b_nummer, b_liste = gleisrekursion(x, y, b, true, "b", element["daten"]["nummer"])
          c_nummer, c_liste = gleisrekursion(x, y, c, true, "c", element["daten"]["nummer"])
          d_nummer, d_liste = gleisrekursion(x, y, d, true, "d", element["daten"]["nummer"])

          exportbuffer[element["daten"]["nummer"]] = {
            ["typ"] = "kreuzung",
            ["nachbarn"] = {
              ["a"] = a_nummer,
              ["b"] = b_nummer,
              ["c"] = c_nummer,
              ["d"] = d_nummer,
            },
          }

          dateibuffer[y][x]["nachbarn"] = {
            [a_nummer] = a_liste,
            [b_nummer] = b_liste,
            [c_nummer] = c_liste,
            [d_nummer] = d_liste,
        }

        elseif element["daten"]["typ"] == "block" then
          
          anfang_nummer, anfang_liste = gleisrekursion(x, y, element["daten"]["beginn"], true, "anfang", element["daten"]["nummer"])

          exportbuffer[element["daten"]["nummer"]] = {
            ["typ"] = "block",
            ["gwb"] = element["daten"]["gwb"],
            ["erlaubnis"] = element["daten"]["erlaubnis"],

            ["nachbarn"] = {
              ["anfang"] = anfang_nummer,
            },
          }

          dateibuffer[y][x]["nachbarn"] = {
            [anfang_nummer] = anfang_liste,
          }

        end

        if element["daten"]["attachments"] then
          for ende, attachments in pairs(element["daten"]["attachments"]) do
            for _, attachment in pairs(attachments) do
              exportbuffer[element["daten"]["nummer"] .. "_" .. ende .. "_" .. attachment] = {
                ["typ"] = attachment,
                ["nachbarn"] = {
                  ["anfang"] = element["daten"]["nummer"],
                  ["ende"] = exportbuffer[element["daten"]["nummer"]]["nachbarn"][ende],
                },
              }

              local alternachbar = exportbuffer[element["daten"]["nummer"]]["nachbarn"][ende]
              exportbuffer[element["daten"]["nummer"]]["nachbarn"][ende] = element["daten"]["nummer"] .. "_" .. ende .. "_" .. attachment

              if exportbuffer[alternachbar] then
                for ende_remote, nachbar in pairs(exportbuffer[alternachbar]["nachbarn"]) do
                  if nachbar == element["daten"]["nummer"] then
                    exportbuffer[alternachbar]["nachbarn"][ende_remote] = element["daten"]["nummer"] .. "_" .. ende .. "_" .. attachment
                  end
                end
              else
                if not vorbehalt[alternachbar] then
                  vorbehalt[alternachbar] = {}
                end

                vorbehalt[alternachbar][element["daten"]["nummer"]][element["daten"]["nummer"]] = element["daten"]["nummer"] .. "_" .. ende .. "_" .. attachment
              end
            end
          end
        end
      end
    end
  end

  statuszeile = "Fahrstraßenplan wurde gespeichert in " .. zieldatei
  zeichneMenuBand()

  local serialization = require("serialization")

  fhexp = io.open(zieldatei, "w")
  fhexp:seek("set", 0)
  fhexp:write(serialization.serialize(exportbuffer))
  fhexp:close()

  statuszeile = "Exportiert."
  zeichneMenuBand()
end

local function attachment_hinzufuegen(nummer, ende, attachment)
  for y, ytbl in pairs(dateibuffer) do
    for x, element in pairs(ytbl) do
      if element["daten"]["nummer"] == nummer then
        if not element["daten"]["attachments"] then
          element["daten"]["attachments"] = {}
        end

        if not element["daten"]["attachments"][ende] then
          element["daten"]["attachments"][ende] = {}
        end

        table.insert(element["daten"]["attachments"][ende], attachment)

        statuszeile = "Attachment " .. attachment .. " an " .. nummer .. " hinzugefügt."
        zeichneMenuBand()
      end      
    end
  end
end

zeichneMenuBand()

for y, zeile in pairs(dateibuffer) do
  for x, kachel in pairs(zeile) do
    canvas:place(kachel["typ"], x, y)
  end
end

rightX = canvas["rightX"]
bottomY = canvas["bottomY"]

local startY = 1
while startY <= bottomY do
  local startX = 1
  while startX <= rightX do
    if not dateibuffer[startY] then
      dateibuffer[startY] = {}
    end
    if not dateibuffer[startY][startX] then
      platziereKachel(startX, startY, "null", {})
      print("Platziere Nullkachel bei: " .. startX .. ", " .. startY .. " " .. rightX .. " " .. bottomY)
    end
    startX = startX + 1
  end
  startY = startY + 1
end

term.clear()

canvas:render()
zeichneMenuBand()

local dateiMenu = menu:new(component.gpu.address, component.screen.address)
local spurplanMenu = menu:new(component.gpu.address, component.screen.address)
local tileRechtsclickMenu = menu:new(component.gpu.address, component.screen.address)
local neuesElementMenu = menu:new(component.gpu.address, component.screen.address)
local verschiebeMenu = menu:new(component.gpu.address, component.screen.address)
local gleisMenu = menu:new(component.gpu.address, component.screen.address)

local elementNameDialog = dialog:new(component.gpu.address, component.screen.address)
local elementRichtungVonDialog = dialog:new(component.gpu.address, component.screen.address)

local weichenNormalDialog = dialog:new(component.gpu.address, component.screen.address)
local weichenVmaxLinks = dialog:new(component.gpu.address, component.screen.address)
local weichenVmaxRechts = dialog:new(component.gpu.address, component.screen.address)

local signalSystemDialog = dialog:new(component.gpu.address, component.screen.address)
local signalFunktionDialog = dialog:new(component.gpu.address, component.screen.address)
local signalGrundzustandKennlichtDialog = dialog:new(component.gpu.address, component.screen.address)
local signalZielZugfahrstrasseDialog = dialog:new(component.gpu.address, component.screen.address)
local signalStartGeschwindigkeitDialog = dialog:new(component.gpu.address, component.screen.address)
local signalGleisabschlussDialog = dialog:new(component.gpu.address, component.screen.address)

local kreuzungsDialog = dialog:new(component.gpu.address, component.screen.address)

local blockDialog = dialog:new(component.gpu.address, component.screen.address)
local blockErlaubnisDialog = dialog:new(component.gpu.address, component.screen.address)

local umfahrDialog = dialog:new(component.gpu.address, component.screen.address)

local exportNameDialog = dialog:new(component.gpu.address, component.screen.address)

local anzeigerTypDialog = dialog:new(component.gpu.address, component.screen.address)

elementNameDialog:setText("Elementname bitte:")
elementRichtungVonDialog:setText("Elementanfang an: (links/rechts)")

weichenNormalDialog:setText("Weichenart bitte: (linksweiche/rechtsweiche)")
weichenVmaxLinks:setText("Weichengeschwindigkeit Linkslage geradeaus: ")
weichenVmaxRechts:setText("Weichengeschwindigkeit Rechtslage geradeaus: ")

signalSystemDialog:setText("Signalsystem bitte: (Ks/HV)")
signalFunktionDialog:setText("Signalfunktion bitte: (Hp/Vr/Ls/Ms)")
signalGrundzustandKennlichtDialog:setText("Zeigt Signal im Grundzustand Kennlicht? (ja/nein)")
signalZielZugfahrstrasseDialog:setText("Kann Signal Ziel einer Zugstraße sein? (ja/nein)")
signalStartGeschwindigkeitDialog:setText("Geschwindigkeit ab vorherigen Signal bei Halt: (0-16)")
signalGleisabschlussDialog:setText("Ist das Signal ein Gleisabschluss (ja/nein)?")

kreuzungsDialog:setText("Kreuzungsform bitte: (geradeaus/diagonal)")

blockDialog:setText("Gleiswechselbetrieb: (ja/nein)")
blockErlaubnisDialog:setText("Streckenblock-Richtung von hier weg oder nach hier? (erlaubnishier/erlaubnisdort)")

umfahrDialog:setText("Umfahrgruppe durchlässig für Zielsignal: ([Zielsignalnummer]/beenden)")

exportNameDialog:setText("Dateipfad für Export bitte: ")

anzeigerTypDialog:setText("Zyp des Anzeigers: (Zs3/Zs6):")

dateiMenu:addEntry("speichern", "Speichern")
dateiMenu:addEntry("exportieren_fahrstrassenplan", "Fahrstraßenplan kompilieren >")
dateiMenu:addEntry("beenden", "Beenden")

spurplanMenu:addEntry("gleisfreimeldung", "Gleisfreimeldung hinzufügen")
spurplanMenu:addEntry("vorsignaldunkelschaltung", "Vorsignaldunkelschaltgruppe hinzufügen")
spurplanMenu:addEntry("gegengleis", "Gegengleisgruppe")

tileRechtsclickMenu:addEntry("neu", "Neues Element >")
tileRechtsclickMenu:addEntry("gleis", "Gleis platzieren >")
tileRechtsclickMenu:addEntry("loeschen", "Element löschen")
tileRechtsclickMenu:addEntry("spiegeln", "Element spiegelen")
tileRechtsclickMenu:addEntry("verschieben", "Element verschieben >")

neuesElementMenu:addEntry("signal", "Signalgruppe")
neuesElementMenu:addEntry("anzeiger", "Anzeiger")
neuesElementMenu:addEntry("weiche", "Weichengruppe")
neuesElementMenu:addEntry("kreuzung", "Kreuzungsgruppe")
neuesElementMenu:addEntry("block", "Streckenblockgruppe")
neuesElementMenu:addEntry("link", "Verlinkungsgruppe")

verschiebeMenu:addEntry("links", "links")
verschiebeMenu:addEntry("rechts", "rechts")
verschiebeMenu:addEntry("oben", "oben")
verschiebeMenu:addEntry("unten", "unten")

gleisMenu:addEntry("von_links_nach_rechts", "Gleis von links nach rechts")
gleisMenu:addEntry("von_links_nach_unten_rechts", "Gleis von links nach unten rechts")
gleisMenu:addEntry("von_links_nach_oben_rechts", "Gleis von links nach oben rechts")
gleisMenu:addEntry("von_unten_links_nach_rechts", "Gleis von unten links nach rechts")
gleisMenu:addEntry("von_unten_links_nach_oben_rechts", "Gleis von unten links nach oben rechts")
gleisMenu:addEntry("von_oben_links_nach_rechts", "Gleis von oben links nach rechts")
gleisMenu:addEntry("von_oben_links_nach_unten_rechts", "Gleis von oben links nach unten rechts")

local openMenu = nil

local auswahlTileX = 1
local auswahlTileY = 1

while true do
  local ev, evdev, clickX, clickY, clickMaustaste = event.pull("touch")

  if openMenu then
    if openMenu == "datei" then
      local angeclickt, x1, y1, x2, y2 = dateiMenu:click(clickX, clickY)
      if angeclickt == "beenden" then
        gpu.setBackground(0x000000)
        term.clear()
        break
      elseif angeclickt == "speichern" then
        speichern()
        statuszeile = "Gespeichert."
        zeichneMenuBand()
      elseif angeclickt == "exportieren_gleisplan" then
        local name, dx1, dy1, dx2, dy2 = exportNameDialog:open()
        exportiere_gleisplan(name)
        canvas:redrawArea(dx1, dy1, dx2, dy2)
      elseif angeclickt == "exportieren_fahrstrassenplan" then
        local name, dx1, dy1, dx2, dy2 = exportNameDialog:open()
        exportiere_fahrstrassenplan(name)
        canvas:redrawArea(dx1, dy1, dx2, dy2)
      end
      canvas:redrawArea(x1, y1, x2, y2)
    elseif openMenu == "spurplan" then
      local angeclickt, x1, y1, x2, y2 = spurplanMenu:click(clickX, clickY)
      if angeclickt == "gleisfreimeldung" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local ende, x1, y1, x2, y2 = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)

        attachment_hinzufuegen(name, ende, "gfr")
      elseif angeclickt == "vorsignaldunkelschaltung" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local ende, x1, y1, x2, y2 = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)

        attachment_hinzufuegen(name, ende, "vrd")
      elseif angeclickt == "gegengleis" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local ende, x1, y1, x2, y2 = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)

        attachment_hinzufuegen(name, ende, "ggl")
      end
      canvas:redrawArea(x1, y1, x2, y2)
    elseif openMenu == "tile" then
      local angeclickt, x1, y1, x2, y2 = tileRechtsclickMenu:click(clickX, clickY)
      canvas:redrawArea(x1, y1, x2, y2)
      if angeclickt == "neu" then
        neuesElementMenu:open(clickX, clickY)
        openMenu = "neu"
      elseif angeclickt == "verschieben" then
        verschiebeMenu:open(clickX, clickY)
        openMenu = "verschieben"
      elseif angeclickt == "gleis" then
        gleisMenu:open(clickX, clickY)
        openMenu = "gleis"
      elseif angeclickt == "loeschen" then
        platziereKachel(auswahlTileX, auswahlTileY, "null", {})
        statuszeile = "Kachel gelöscht: (" .. auswahlTileX .. "|" .. auswahlTileY .. ")"
        zeichneMenuBand()
      end
    elseif openMenu == "gleis" then
      local angeclickt, x1, y1, x2, y2 = gleisMenu:click(clickX, clickY)
      if angeclickt == "von_links_nach_rechts" then
        platziereKachel(auswahlTileX, auswahlTileY, "gleis_geradeaus", { ["nummer"] = "gleis", ["typ"] = "gleis_geradeaus", })
      elseif angeclickt == "von_links_nach_unten_rechts" then
        platziereKachel(auswahlTileX, auswahlTileY, "gleis_von_links_nach_unten_rechts", { ["nummer"] = "gleis", ["typ"] = "gleis_von_links_nach_unten_rechts", })
      elseif angeclickt == "von_links_nach_oben_rechts" then
        platziereKachel(auswahlTileX, auswahlTileY, "gleis_von_links_nach_oben_rechts", { ["nummer"] = "gleis", ["typ"] = "gleis_von_links_nach_oben_rechts", })
      elseif angeclickt == "von_unten_links_nach_rechts" then
        platziereKachel(auswahlTileX, auswahlTileY, "gleis_von_unten_links_nach_rechts", { ["nummer"] = "gleis", ["typ"] = "gleis_von_unten_links_nach_rechts", })
      elseif angeclickt == "von_unten_links_nach_oben_rechts" then
        platziereKachel(auswahlTileX, auswahlTileY, "gleis_von_oben_rechts_nach_unten_links", { ["nummer"] = "gleis", ["typ"] = "gleis_von_oben_rechts_nach_unten_links", })
      elseif angeclickt == "von_oben_links_nach_rechts" then
        platziereKachel(auswahlTileX, auswahlTileY, "gleis_von_oben_links_nach_rechts", { ["nummer"] = "gleis", ["typ"] = "gleis_von_oben_links_nach_rechts", })
      elseif angeclickt == "von_oben_links_nach_unten_rechts" then
        platziereKachel(auswahlTileX, auswahlTileY, "gleis_von_oben_links_nach_unten_rechts", { ["nummer"] = "gleis", ["typ"] = "gleis_von_oben_links_nach_unten_rechts", })
      end
      canvas:redrawArea(x1, y1, x2, y2)
      statuszeile = "Gleis platziert: (" .. auswahlTileX .. "|" .. auswahlTileY .. ")"
      zeichneMenuBand()
    elseif openMenu == "neu" then
      local angeclickt, x1, y1, x2, y2 = neuesElementMenu:click(clickX, clickY)
      canvas:redrawArea(x1, y1, x2, y2)
      if angeclickt == "signal" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local richtung = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local system = signalSystemDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local funktion = signalFunktionDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local kennlicht = signalGrundzustandKennlichtDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local zielzugfs = "true"
        local startv = 16
        local gleisabschluss = "nein"
        if funktion == "Ls" then
          zielzugfs = signalZielZugfahrstrasseDialog:open()
          canvas:redrawArea(x1, y1, x2, y2)
          gleisabschluss = signalGleisabschlussDialog:open()
          canvas:redrawArea(x1, y1, x2, y2)
        end
        if zielzugfs == "ja" then
          startv = signalStartGeschwindigkeitDialog:open()
          canvas:redrawArea(x1, y1, x2, y2)
        else
          startv = 16
        end
        if kennlicht == "ja" then
          kennlicht = true
        else
          kennlicht = false
        end
        if zielzugfs == "ja" then
          zielzugfs = true
        else
          zielzugfs = false
        end
        local zusatz = ""
        if funktion == "Vr" then
          zusatz = "_erwarten"
        end
        if gleisabschluss == "ja" then
          gleisabschluss = true
        else
          gleisabschluss = false
        end
        local daten = {
          ["nummer"] = name,
          ["typ"] = "signal",
          ["beginn"] = richtung,
          ["system"] = system,
          ["funktion"] = funktion,
          ["grz_kennlicht"] = kennlicht,
          ["zielzugfs"] = zielzugfs,
          ["startv"] = startv,
          ["gleisabschluss"] = gleisabschluss,
        }
        platziereKachel(auswahlTileX, auswahlTileY, "signal_" .. string.lower(funktion) .. "_von_" .. richtung .. "_halt" .. zusatz, daten)
        statuszeile = "Signal angelegt."
        zeichneMenuBand()
      elseif angeclickt == "anzeiger" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local richtung, x1, y1, x2, y2 = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local anzeigertyp, x1, y1, x2, y2 = anzeigerTypDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)

        local daten = {
          ["nummer"] = name,
          ["typ"] = "signal",
          ["beginn"] = richtung,
          ["system"] = "HV",
          ["funktion"] = anzeigertyp,
          ["grz_kennlicht"] = false,
          ["zielzugfs"] = false,
          ["startv"] = startv,
        }

        platziereKachel(auswahlTileX, auswahlTileY, "signal_ls_von_" .. richtung .. "_halt", daten)
      elseif angeclickt == "weiche" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local richtung = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local grundstellung = weichenNormalDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local geschwindigkeit_links = weichenVmaxLinks:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local geschwindigkeit_rechts = weichenVmaxRechts:open()
        canvas:redrawArea(x1, y1, x2, y2)

        local daten = {
          ["nummer"] = name,
          ["typ"] = "weiche",
          ["beginn"] = richtung,
          ["weichentyp"] = grundstellung,
          ["vmax_links"] = geschwindigkeit_links,
          ["vmax_rechts"] = geschwindigkeit_rechts,
        }

        local lage = "linkslage"

        if grundstellung == "linksweiche" then
          lage = "rechtslage"
        end

        platziereKachel(auswahlTileX, auswahlTileY, "weiche_" .. string.lower(grundstellung) .. "_von_" .. richtung .. "_" .. lage, daten)
        statuszeile = "Weiche angelegt."
        zeichneMenuBand()
      elseif angeclickt == "kreuzung" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local kreuzungsform = kreuzungsDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local richtung = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)

        local daten = {
          ["nummer"] = name,
          ["typ"] = "kreuzung",
          ["beginn"] = richtung,
          ["form"] = kreuzungsform,
        }

        platziereKachel(auswahlTileX, auswahlTileY, "kreuzung_von_" .. richtung .. "_" .. kreuzungsform, daten)
      elseif angeclickt == "link" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local richtung, x1, y1, x2, y2 = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)

        local daten = {
          ["nummer"] = name,
        }

        platziereKachel(auswahlTileX, auswahlTileY, "link_von_" .. richtung, daten)
      elseif angeclickt == "block" then
        local name, x1, y1, x2, y2 = elementNameDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local richtung = elementRichtungVonDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local gwb = blockDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)
        local erlaubnis = blockErlaubnisDialog:open()
        canvas:redrawArea(x1, y1, x2, y2)

        if gwb == "ja" then
          gwb = true
        else
          gwb = false
        end

        local daten = {
          ["nummer"] = name,
          ["typ"] = "block",
          ["beginn"] = richtung,
          ["gwb"] = gwb,
          ["erlaubnis"] = erlaubnis,
        }
        
        platziereKachel(auswahlTileX, auswahlTileY, "streckenblock_von_" .. richtung .. "_" .. erlaubnis, daten)
        statuszeile = "Streckenblockelement platziert."
        zeichneMenuBand()
      end
      statuszeile = "Element platziert: (" .. auswahlTileX .. "|" .. auswahlTileY .. ")"
      canvas:redrawArea(x1, y1, x2, y2)
      zeichneMenuBand()
    elseif openMenu == "verschieben" then
      local angeclickt, x1, y1, x2, y2 = verschiebeMenu:click(clickX, clickY)
      if angeclickt == "oben" then
        verschiebeKachel(auswahlTileX, auswahlTileY, auswahlTileX, auswahlTileY - 1)
      elseif angeclickt == "unten" then
        verschiebeKachel(auswahlTileX, auswahlTileY, auswahlTileX, auswahlTileY + 1)
      elseif angeclickt == "links" then
        verschiebeKachel(auswahlTileX, auswahlTileY, auswahlTileX - 1, auswahlTileY)
      elseif angeclickt == "rechts" then
        verschiebeKachel(auswahlTileX, auswahlTileY, auswahlTileX + 1, auswahlTileY)
      end
      canvas:redrawArea(x1, y1, x2, y2)
      statuszeile = "Kachel verschoben."
      zeichneMenuBand()
    end
  end
  
  if clickY == 1 then
    if clickX <= string.len("Datei |") then
      dateiMenu:open(clickX, clickY)
      openMenu = "datei"
    elseif (clickX <= (string.len(" Spurplan |") + string.len("Datei |"))) then
      spurplanMenu:open(clickX, clickY)
      openMenu = "spurplan"
    end
  else
    if clickMaustaste == 1 then
      tileRechtsclickMenu:open(clickX, clickY)
      auswahlTileX, auswahlTileY = canvas:toTileCoords(clickX, clickY)
      openMenu = "tile"
    end
  end

  canvas:render()
end
