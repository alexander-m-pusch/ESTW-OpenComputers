local fs = {}

--Fahrstraßenrechner vom OCS-Stellwerk.
--Geschrieben von Alexander 'ampericus' Pusch, 2022/2023
--(C) Lizensiert unter der GNU GPLv3

local konfiguration = {}
local globalplan_elemente = {}

local ls = {}
local w = {}
local block = {}

local upd = {}

--dreckig im sinne von "mark as dirty"
local dreckig = {}
local elemente = {}

elemente.base = {}

local function stoerung(grund)

end

function elemente.base:neu(typ)
  local o = {
    ["typ"] = typ,
    ["nachbarn"] = {},
    ["verriegelzaehler"] = 0,
    ["spurplanfunktion"] = {},
  }

  setmetatable(o, self)
  self.__index = self

  return o
end

function elemente.base:setze_nummer(num)
  self["num"] = num
end

function elemente.base:nummer()
  return self["num"]
end

function elemente.base:nachbar(ende_lokal, element)
  self["nachbarn"][ende_lokal] = {}
  self["nachbarn"][ende_lokal]["element"] = element
end

function elemente.base:verriegeln()
  self["verriegelzaehler"] = self["verriegelzaehler"] + 1
end

function elemente.base:entriegeln()
  self["verriegelzaehler"] = self["verriegelzaehler"] - 1
end

function elemente.base:verriegelt()
  return (self["verriegelzaehler"] > 0)
end

function elemente.base:hilfsentriegeln()
  self["verriegelzaehler"] = 0
end

function elemente.base:spurplankabel(von, funktion)
  local event = require("event")

  event.push("fahrstrasse", "spurplankabel", self:nummer(), von)
  if self["typ"] == "weiche" then
    local ark = nil
    local naechstes_element = nil

    if self["nachbarn"]["spitze"] then
      if self["nachbarn"]["spitze"]["element"]:nummer() == von then
        ark = "spitze"
      else
        ark = self["lage"]
      end
      naechstes_element = self["nachbarn"][self:gegenueber(ark)]["element"]
    else
      ark = self["lage"]
    end

    if not naechstes_element then return end
    
    local fortfahren = true
    if self["spurplanfunktion"][funktion["typ"]] then
      fortfahren = self["spurplanfunktion"][funktion["typ"]](self, ark, funktion["inhalt"])
    end

    if not fortfahren then return end
    if not naechstes_element then return end

    return naechstes_element:spurplankabel(self:nummer(), funktion)
  elseif self["typ"] == "kreuzung" then
    local ark = "a"
    if self["nachbarn"]["b"] then
      if self["nachbarn"]["b"]["element"]:nummer() == von then
        ark = "b"
      end
    elseif self["nachbarn"]["c"] then
      if self["nachbarn"]["c"]["element"]:nummer() == von then
       ark = "c"
      end
    elseif self["nachbarn"]["d"] then
      if self["nachbarn"]["d"]["element"]:nummer() == von then
        ark = "d"
      end
    end

    local naechstes_ende = "c"
    if ark == "b" then
      naechstes_ende = "d"
    elseif ark == "c" then
      naechstes_ende = "a"
    elseif ark == "d" then
      naechstes_ende = "b"
    end

    local naechstes_element = nil
    if self["nachbarn"][naechstes_ende] then
      naechstes_element = self["nachbarn"][naechstes_ende]["element"]
    end

    local fortfahren = true
    if self["spurplanfunktion"][funktion["typ"]] then
      fortfahren = self["spurplanfunktion"][funktion["typ"]](self, ark, funktion["inhalt"])
    end

    if not naechstes_element then return false end

    return naechstes_element:spurplankabel(self:nummer(), funktion)
  else
    local ark = "ende"
    local naechste_richtung = nil
    if self["nachbarn"]["anfang"] then
      if self["nachbarn"]["anfang"]["element"]:nummer() == von then
        ark = "anfang"
        naechste_richtung = "ende"
      else
        --ark = "ende"
        naechste_richtung = "anfang"
      end
    end

    local fortfahren = true
    if self["spurplanfunktion"][funktion["typ"]] then
      fortfahren = self["spurplanfunktion"][funktion["typ"]](self, ark, funktion["inhalt"])
    end

    if self["spurplanfunktion"]["__endall"] then
      fortfahren = false --für Streckenblock
    end

    if not naechste_richtung then
      return false
    end

    if self["gleisabschluss"] then fortfahren = false end

    if fortfahren then
      return self["nachbarn"][naechste_richtung]["element"]:spurplankabel(self:nummer(), funktion)
    end
  end
end

elemente["weiche"] = elemente.base:neu("weiche")
elemente["kreuzung"] = elemente.base:neu("kreuzung")
elemente["signal"] = elemente.base:neu("signal")
elemente["gleisfreimeldung"] = elemente.base:neu("gleisfreimeldung")
elemente["block"] = elemente.base:neu("block")
elemente["umfahrgruppe"] = elemente.base:neu("umfahrgruppe")

function elemente.kreuzung:flankenschutz(von, lock)
  return true
end

function elemente.kreuzung:freifahren(ark, inhalt)
  if inhalt["frei"] then
    self["lage"] = nil
  end
  return true
end

function elemente.kreuzung:hilfsaufloesung(inhalt)
  local event = require("event")

  event.push("fahrstrasse", "fsha", self:nummer(), self["verriegelzaehler"])

  self:entriegeln()

  update(self:nummer())
  return true
end

function elemente.kreuzung:fahrstrasse(von, ufgt, nach, zugfahrstrasse)
  local ark = "a"
  if self["nachbarn"]["b"]["element"]:nummer() == von then ark = "b" end
  if self["nachbarn"]["c"]["element"]:nummer() == von then ark = "c" end
  if self["nachbarn"]["d"]["element"]:nummer() == von then ark = "d" end

  local naechstes_ende = "c"
  if ark == "b" then naechstes_ende = "d" end
  if ark == "c" then naechstes_ende = "a" end
  if ark == "d" then naechstes_ende = "b" end

  if not self:verriegelt() then
    return self["nachbarn"][naechstes_ende]["element"]:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)
  else
    return false, 20, "Kreuzung ist bereits als Fahrstraße beansprucht"
  end
end

function elemente.kreuzung:spurplan_einhaengen(von, inhalt)
  self["spurplanfunktion"] = {
    ["hilfsaufloesung"] = self.hilfsaufloesung,
  }
end

function elemente.umfahrgruppe:flankenschutz(von, lock)
  return true
end

function elemente.umfahrgruppe:durchlaessigfuer(nach)
  if not self["durchlaessig"] then self["durchlaessig"] = {} end
  self["durchlaessig"][nach] = true
end

function elemente.umfahrgruppe:hilfsaufloesung(inhalt)
  local event = require("event")
  self:entriegeln()

  event.push("fahrstrasse", "fsha", self:nummer(), self["verriegelzaehler"])

  return true
end

function elemente.umfahrgruppe:fahrstrasse(von, ufgt, nach, zugfahrstrasse)
  local ark = "ende"
  if self["nachbarn"]["anfang"]["element"]:nummer() == von then
    ark = "anfang"
  end

  local naechstes_ende = "anfang"

  if ark == "anfang" then
    naechstes_ende = "ende"
  end

  if ark == "ende" then
    return self["nachbarn"][naechstes_ende]["element"]:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)
  end

  if ufgt or self["durchlaessig"][nach] then
    return self["nachbarn"][naechstes_ende]["element"]:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)
  else
    return false, 10, "Umfahrgruppe nicht durchlässig"
  end
end

function elemente.umfahrgruppe:spurplan_einhaengen()
  self["spurplanfunktion"] = {
    ["hilfsaufloesung"] = self.hilfsaufloesung,
  }
end

function elemente.weiche:lagedef(lage, flankenschutztransport, vmax)
  if not self["lagen"] then
    self["lagen"] = {}
  end

  self["lagen"][lage] = {
    ["vmax"] = vmax,
    ["flankenschutztransport"] = flankenschutztransport,
  }
end

function elemente.weiche:umlegen(lage)
  if self:verriegelt() then return false end
  if self["lagen"][lage] then
    self["lage"] = lage
    self["dreckig"] = true
    update(self:nummer())
    return true
  end
end

function elemente.weiche:spurplan_einhaengen()
  self["spurplanfunktion"] = {
    ["hilfsaufloesung"] = self.hilfsaufloesung,
    ["freifahren"] = self.freifahren,
  }
end

function elemente.weiche:hilfsaufloesung(ark, inhalt)
  local event = require("event")
  self:entriegeln()

  event.push("fahrstrasse", "fsha", self:nummer(), self["verriegelzaehler"])

  update(self:nummer())

  return true
end

function elemente.weiche:hilfsaufloesung(ark, inhalt)
  local event = require("event")
  self:entriegeln()

  event.push("fahrstrasse", "fsha", self:nummer(), self["verriegelzaehler"])

  update(self:nummer())

  return true
end

function elemente.weiche:freifahren(ark, inhalt)
  if inhalt["frei"] then
    self:entriegeln()
  end
  return true
end

function elemente.weiche:flankenschutz(von, lock)
  return true
end

function elemente.weiche:gegenueber(von)
  if von == "links" then return "spitze" end
  if von == "rechts" then return "spitze" end
  if von == "spitze" then return self["lage"] end
end

function elemente.weiche:vr(ark, inhalt)
  if self["lagen"][self["lage"]]["vmax"] < inhalt["v_hp"] then
    inhalt["v_hp"] = self["lagen"][self["lage"]]["vmax"]
  end

  local naechstes_ende = self:gegenueber(ark)
  return self["nachbarn"][naechstes_ende]["element"]:spurplankabel(self["lage"], inhalt)
end

function elemente.weiche:fahrstrasse(von, ufgt, nach, zugfahrstrasse)
  local event = require("event")
  local ark = "spitze"

  if von == self["nachbarn"]["links"]["element"]:nummer() then
    ark = "links"
  elseif von == self["nachbarn"]["rechts"]["element"]:nummer() then
    ark = "rechts"
  end

  event.push("fahrstrasse", "abtastung", self:nummer(), von, nach, self["lage"], ufgt)

  if ark == "spitze" then
    if self:verriegelt() then
      return false, 20, "Weiche verriegelt"
    elseif ufgt then
      local andere = "links"
      if self["lage"] == "links" then
        andere = "rechts"
      end
      
      local erfolg_flankenschutz = self["nachbarn"][andere]["element"]:flankenschutz(self:nummer(), false)
      
      if not erfolg_flankenschutz then
        return false, 20, "Flankenschutz kann nicht hergestellt werden"
      end
      
      event.push("fahrstrasse", "abtastung", self:nummer(), self:gegenueber(ark))
      local erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal = self["nachbarn"][self:gegenueber(ark)]["element"]:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)
      
      if erfolg then
        self:verriegeln()
        update(self:nummer())
        self["nachbarn"][andere]["element"]:flankenschutz(self:nummer(), true)
      end

      if type(geschwindigkeit_hp) == "number" then
        geschwindigkeit_hp = math.min(geschwindigkeit_hp, self["lagen"][self["lage"]]["vmax"])
      end

      return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
    else
      hoechster_fehler = 0
      local lage = self["lage"]
      self["lage"] = self["vorzugslage"]
      local erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal = self["nachbarn"][self:gegenueber(ark)]["element"]:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)
      if erfolg then
        self:verriegeln()
        update(self:nummer())
        if type(geschwindigkeit_hp) == "number" then
          geschwindigkeit_hp = math.min(geschwindigkeit_hp, self["lagen"][self["lage"]]["vmax"])
        end
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
      else
        hoechster_fehler = geschwindigkeit_hp
        if self["lage"] == "links" then
          self["lage"] = "rechts"
        else
          self["lage"] = "links"
        end
        erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal = self["nachbarn"][self:gegenueber(ark)]["element"]:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)
        if erfolg then
          self:verriegeln()
          update(self:nummer())

          if type(geschwindigkeit_hp) == "number" then
            geschwindigkeit_hp = math.min(geschwindigkeit_hp, self["lagen"][self["lage"]]["vmax"])
          end

          return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
        else
          self["lage"] = lage
          return erfolg, math.max(geschwindigkeit_hp, hoechster_fehler)
        end
      end
    end
  else
    if self:verriegelt() then
      if not (ark == self["lage"]) then
        return false, 30, "Weiche liegt falsch"
      else
        local andere = "links"
        if ark == "links" then
          andere = "rechts"
        end

        local erfolg_fs = self["nachbarn"][andere]["element"]:flankenschutz(self:nummer(), false)

        if not erfolg_fs then
          return false, 20, "Flankenschutzweiche kann nicht hergestellt werden"
        end

        local erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal = self["nachbarn"][self:gegenueber(ark)]["element"]:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)

        if erfolg then
          self["nachbarn"][andere]["element"]:flankenschutz(self:nummer(), true)
          self:verriegeln()

          if type(geschwindigkeit_hp) == "number" then
            geschwindigkeit_hp = math.min(geschwindigkeit_hp, self["lagen"][self["lage"]]["vmax"])
          end

          return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
        else
          return erfolg, geschwindigkeit_hp, geschwindigkeit_vr
        end
      end
    else
      local andere = "links"
      if ark == "links" then
        andere = "rechts"
      end

      local erfolg_fs = self["nachbarn"][andere]["element"]:flankenschutz(self:nummer(), false)

      if not erfolg_fs then
        return false, 20, "Flankenschutzweiche kann nicht hergestellt werden."
      end

      local erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal = self["nachbarn"][self:gegenueber(ark)]["element"]:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)

      event.push("fahrstrasse", "echostrom", self:nummer(), geschwindigkeit_hp, geschwindigkeit_vr)

      if erfolg then
        self["nachbarn"][andere]["element"]:flankenschutz(self:nummer(), true)
        self["lage"] = ark
        self:verriegeln()
        update(self:nummer())
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
      else
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr
      end
    end
  end
end

function elemente.signal:sigdef(system, funktion)
  self["system"] = system
  self["funktion"] = funktion
  self["startv"] = 16
end

function elemente.signal:setstartv(startv)
  self["startv"] = tonumber(startv)
end

function elemente.signal:grundzustand_kennlicht(grz)
  self["grz_kennlicht"] = grz
end

function elemente.signal:flankenschutz(von, lock)
  return true
end

function elemente.signal:spurplan_einhaengen(von, inhalt)
  self["spurplanfunktion"] = {
    ["vr"] = self.vr_setzen,
    ["hilfsaufloesung"] = self.hilfsaufloesung,
    ["signalhalt"] = self.signalhalt,
    ["freifahren"] = self.freifahren,
  }
end

function elemente.signal:hilfsaufloesung(ark, inhalt)
  local event = require("event")

  event.push("fahrstrasse", "fsha", self:nummer(), self["verriegelzaehler"])

  self:entriegeln()
  --self["zielsignal"] = nil

  update(self:nummer())
  if ark == "anfang" then
    return true
  end

  self:grundzustand()

  if (self["funktion"] == "Hp") or (self["funktion"] == "Ms") then
    event.push("fahrstrasse", "fsha", "abbruch", self:nummer(), ark)
    self:vorsignalinformation()
    return false
  elseif inhalt["rfs"] and (self["funktion"] == "Ls") then
    event.push("fahrstrasse", "fsha", "abbruch", self:nummer(), inhalt["rfs"])
    return false
  end

  return true
end

function elemente.signal:signalhalt(ark, inhalt)
  if ark == "anfang" then
    return true
  end

  self:grundzustand()

  if (self["funktion"] == "Hp") or (self["funktion"] == "Ms") then
    self:vorsignalinformation()
    return false
  elseif inhalt["sh1"] and (self["funktion"] == "Ls") then
    return false
  end

  return true
end

function elemente.signal:freifahren(ark, inhalt)
  if ark == "anfang" then return true end

  self["v_vr"] = 0
  self["v_hp"] = 0
  self["f_vr"] = false

  if inhalt["frei"] then 
    self:entriegeln()
  end

  update(self:nummer())

  return true
end

function elemente.signal:vorsignalinformation()
  local paket = {
    ["typ"] = "vr",
    ["inhalt"] = {
      ["v_vr"] = self["v_hp"],
      ["f_vr"] = true,
      ["v_hp"] = self["v_hp"],
    },
  }

  if (self["v_hp"] == 0) or (self["v_hp"] == "s") or (self["v_hp"] == "e") or (self["v_hp"] == "g") or (self["v_hp"] == "v") then
    paket["inhalt"]["v_hp"] = self["startv"]
    paket["inhalt"]["f_vr"] = false
  end

  if self["nachbarn"]["anfang"]["element"] then
    return self["nachbarn"]["anfang"]["element"]:spurplankabel(self:nummer(), paket)
  end
end

function elemente.signal:vr_setzen(ark, inhalt)
  if ark == "anfang" then return true end
  
  self["v_vr"] = inhalt["v_vr"]
  self["f_vr"] = inhalt["f_vr"]
  
  if ((self["funktion"] == "Ms") or (self["funktion"] == "Hp")) then
    if not (self["v_hp"] == 0) then
      if not (self["v_hp"] == "k") then
        self["v_hp"] = inhalt["v_hp"]
      end
    end

    v_hp = inhalt["v_hp"]

    update(self:nummer())
    if self["v_hp"] > 0 then
      self["nachbarn"]["anfang"]["element"]:spurplankabel(self:nummer(), { ["typ"] = vr, ["inhalt"] = { ["v_vr"] = v_hp, }, })
    end
    return false
  elseif self["funktion"] == "Zs3" then
    --wir unterbrechen die weitergabe der Vorsignalgeschwindigkeit, da wir selbst als Ziel agieren
    inhalt["v_vr"] = self["v_hp"]
    inhalt["v_hp"] = 16
    self["v_hp"] = inhalt["v_hp"]

    update(self:nummer())

    return self["nachbarn"]["anfang"]["element"]:spurplankabel(self:nummer(), { ["typ"] = "vr", ["inhalt"] = inhalt, })
  end

  update(self:nummer())

  return true
end

function elemente.signal:fahrstrasse(von, ufgt, nach, zugfahrstrasse)
  local event = require("event")

  event.push("fahrstrasse", "Abtastung", self:nummer(), von, nach)
  local ark = "ende"
  local erstes_signal = false
  if not von then
    --wir sind am Beginn einer Fahrstraße
    ark = "anfang"
    erstes_signal = true
  elseif self["nachbarn"]["anfang"]["element"]:nummer() == von then
    ark = "anfang"
  end

  if von and (not (tostring(nach) == self:nummer())) then
    if self:verriegelt() then
      event.push("fahrstrasse", "Abtastung", self:nummer(), "Signal ist verriegelt.")
      return false, 20, "Signal " .. self:nummer() .. " ist verriegelt"
    end
  end

  local naechste_richtung = "anfang"
  if ark == "anfang" then
    naechste_richtung = "ende"
  end

  local naechstes_element = self["nachbarn"][naechste_richtung]["element"]

  if ark == "anfang" then
    --als erstes überprüfen wir, ob wir das Ziel der Fahrstraße sind
    --wenn ja: super, geschwindigkeitsinformation nach hinten durchreichen!
    --wenn nein: überprüfen, ob wir eine zugfahrstraße sind
    --  wenn ja: überprüfen, ob wir ziel einer zugfahrstraße sein können
    --    wenn ja: überprüfen, ob wir kennlicht zeigen können
    --      wenn ja: wir sind betrieblich abgeschaltet
    --      wenn nein: fehler, wir müssten eigentlich Ziel der fahrstraße sein
    --    wenn nein: weitergeben, wir sind entweder Zs oder Sh, beide für uns bei der fahrstraßensuche uninteressant
    --  wenn nein: überprüfen, ob wir ziel einer rangierfahrstraße sein können
    --    wenn ja: fehler, wir sollten hier eigentlich enden
    --    wenn nein: weiterreichen

    if self:nummer() == tostring(nach) then
      --Wir sind das Zielsignal
      self["zielsignal"] = true
      if type(self["v_hp"]) == "number" then
        if self["v_hp"] > 0 then
          self["rfs"] = not zugfahrstrasse
          event.push("fahrstrasse", self:nummer(), "Ziel erreicht", self["v_hp"])
          update(self:nummer())
          return true, 16, self["v_hp"], true, self
        else
          self["rfs"] = not zugfahrstrasse
          event.push("fahrstrasse", self:nummer(),  "Ziel erreicht", self["startv"])
          update(self:nummer())
          return true, self["startv"], 0, false, self
        end
      else
        event.push("fahrstrasse", self:nummer(), "Ziel erreicht", self["startv"])
        self["v_hp"] = 0
        update(self:nummer())
        return true, self["startv"], 0, false, self
      end
    else
      if zugfahrstrasse then
        if (self["funktion"] == "Hp") or (self["funktion"] == "Ms") then
          if not (self["grz_kennlicht"]) and not erstes_signal then
            event.push("fahrstrasse", self:nummer(), "Fahrstraße führt an Hauptsignal vorbei")
            return false, 10, "Fahrstraße führt an Hp vorbei"
          end
        end
      else
        if ((self["funktion"] == "Hp") or (self["funktion"] == "Ms") or (self["funktion"] == "Ls")) and not erstes_signal then
          event.push("fahrstrasse", self:nummer(), "Fahrstraße führt an Signal vorbei")
          return false, 10, "Fahrstraße führt an Signal vorbei"
        end
      end
    end
  end

  --jetzt prüfen wir noch, ob das Signal verriegelt ist, falls ja, prüfen wir, ob wir das start- oder zielsignal sind,

  if not (self:nummer() == nach) then
    if self:verriegelt() then
      event.push("fahrstrasse", self:nummer(), "Signal ist verriegelt")
      return false, 20, "Signal " .. self:nummer() .. " ist verriegelt"
    end
  end

  if self["gleisabschluss"] then
    event.push("fahrstrasse", self:nummer(), "Fahrstraße an Gleisabschluss vorbei ist ungültig!")
    return false, 10, "Fahrstraße an Gleisabschluss " .. self:nummer() .. " vorbei ist ungültig"
  end

  local erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal = naechstes_element:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)

  event.push("fahrstrasse", "echostrom", self:nummer(), geschwindigkeit_hp, geschwindigkeit_vr)

  if not erfolg then
    return false, geschwindigkeit_hp, geschwindigkeit_vr
  else
    --zuerst: wir verriegeln uns, egal, was ist,
    --und dann hängen wir uns an der letzten gleisfreimeldung ein
    self:verriegeln()

    if ark == "ende" then
      update(self:nummer())
      return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
    end

    if zugfahrstrasse then
      if self["funktion"] == "Zs3" then
        self["v_hp"] = geschwindigkeit_hp
        update(self:nummer())
        return erfolg, 16, geschwindigkeit_hp, fahrtbegriff_hp, zielsignal
      elseif self["funktion"] == "Zs3v" then
        self["v_vr"] = geschwindigkeit_vr
        update(self:nummer())
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
      elseif self["funktion"] == "Zs6" then
        update(self:nummer())
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
      elseif self["funktion"] == "Vr" then
        self["v_vr"] = geschwindigkeit_vr
        update(self:nummer())
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
      elseif self["funktion"] == "Ls" then
        self["v_hp"] = "s"
        update(self:nummer())
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
      elseif erstes_signal then
        event.push("fahrstrasse", "signal", geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, self["verriegelzaehler"])
        self["v_hp"] = geschwindigkeit_hp
        self["v_vr"] = geschwindigkeit_vr
        self["f_vr"] = fahrtbegriff_vr
        self:vorsignalinformation()
        update(self:nummer())
        return erfolg, geschwindigkeit_hp
      elseif self["grz_kennlicht"] then
        self["v_hp"] = "k"
        self["v_vr"] = geschwindigkeit_vr
        self["f_vr"] = fahrtbegriff_vr
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
      end
    else
      if (self["funktion"] == "Zs3") or (self["funktion"] == "Zs3v") or (self["funktion"] == "Vr") then
        return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
      end
      self["v_hp"] = "s"
      self["v_vr"] = 0
      self["f_vr"] = false
      update(self:nummer())
      return erfolg, geschwindigkeit_hp
    end
  end
end

function elemente.signal:getstartv(element)
  return self["startv"]
end

function elemente.signal:ersgt()
  self["v_hp"] = "e"
  update(self:nummer())
end

function elemente.signal:vorsgt()
  self["v_hp"] = "v"
  update(self:nummer())
end

function elemente.signal:zs8()
  self["v_hp"] = "g"
  update(self:nummer())
end

function elemente.signal:grundzustand()
  local computer = require("computer")

  if self["eingehangene_vr"] then
    for num, sig in pairs(self["eingehangene_vr"]) do
      sig:grundzustand()
    end
  end

  local grundv_hp = 0

  if self["grz_kennlicht"] then
    grundv_hp = "k"
  end

  self["v_hp"] = grundv_hp
  self["v_vr"] = 0
  self["f_vr"] = false
  self["rfs"] = false
  update(self:nummer())

  computer.beep(750)
end

function elemente.gleisfreimeldung:flankenschutz(von, lock)
  return true
end

function elemente.gleisfreimeldung:spurplan_einhaengen()
  self["spurplanfunktion"] = {
    ["freifahren"] = self.freifahren,
  }
end

function elemente.gleisfreimeldung:gleiskontakt(freigefahren)
  if not freigefahren then return false end
  self:entriegeln()
  self["nachbarn"][self["aufloeserichtung"]]["element"]:spurplanstecker(self:nummer(), { ["typ"] = "freifahren", ["inhalt"] = { ["frei"] = freigefahren, }, })
end

function elemente.gleisfreimeldung:freifahren(ark, inhalt)
  self:entriegeln()
  
  return false
end

function elemente.gleisfreimeldung:fahrstrasse(von, ufgt, nach, zugfahrstrasse)
  local event = require("event")
  local ark = "ende"
  if self["nachbarn"]["anfang"]["element"]:nummer() == von then
    ark = "anfang"
  end

  self["aufloeserichtung"] = ark

  local naechstes_ende = "anfang"
  if ark == "anfang" then
    naechstes_ende = "ende"
  end

  event.push("fahrstrasse", "Abtastung", self:nummer())
  local naechstes_element = self["nachbarn"][naechstes_ende]["element"]

  local erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal = naechstes_element:fahrstrasse(self:nummer(), ufgt, nach, zugfahrstrasse)

  if not erfolg then
    return erfolg, geschwindigkeit_hp, geschwindigkeit_vr
  else
    self:verriegeln()
    return erfolg, geschwindigkeit_hp, geschwindigkeit_vr, fahrtbegriff_vr, zielsignal
  end
end

function elemente.block:gwb(gwb)
  self["gwb"] = false
end

function elemente.block:fahrstrasse(von, ufgt, nach, zugfahrstrasse)
  local event = require("event")

  if not zugfahrstrasse then
    event.push("fahrstrasse", "abtastung", "Rangierfahrstraße auf Streckengleis ist unzulässig")
    return false, 10, "Rangierfahrstraße auf Streckengleis ist unzulässig"
  end

  if not (self:nummer() == nach) then
    event.push("fahrstrasse", "abtastung", "Falsches Ziel.")
    return false, 10, "Falsches Ziel"
  end

  event.push("fahrstrasse", "abtastung", self:nummer(), von, nach)
  if self:verriegelt() then
    event.push("fahrstrasse", "abtastung", "Streckenblock ist verriegelt!")
    return false, 20, "Streckenblock ist verriegelt!"
  else
    self:verriegeln()
    block:send(self:nummer(), "vorblock")
    return true, 16, 0, false, self
  end
end

function elemente.block:erlaubnisabgabe()
  --TODO an Blockrechner senden
end

function elemente.block:flankenschutz(lock)
  return true
end

function elemente.block:rueckblock()
  self:entriegeln()
  
  fsha(self:nummer()) --lol das ist gefrickelt
end

function elemente.block:spurplan_einhaengen()
  self["spurplanfunktion"] = {
    ["__endall"] = true,
  }
end

function fahrstr_gen(start, ziel, zugfahrt, umfahrstrasse)
  local event = require("event")
  if not (globalplan_elemente[start]) then
    event.push("fahrstrasse", start, ziel, zugfahrt, umfahrstrasse, "Startpunkt existiert nicht")
    return nil, 99, "Ungültiger Fahrstraßenstartpunkt"
  end

  if not (globalplan_elemente[start]["typ"] == "signal") then
    event.push("fahrstrasse", start, ziel, zugfahrt, umfahrstrasse, "Ungültiger Startpunkt")
    return nil, 99, "Ungültiger Fahrstraßenstartpunkt"
  end

  return globalplan_elemente[start]:fahrstrasse(nil, umfahrstrasse, ziel, zugfahrt)
end

function update_internal(nummer)
  element = globalplan_elemente[nummer]
  if not element then element = {} end

  --upd:send(nummer)

  if element["typ"] == "signal" then
    ls:send(nummer, element["system"], element["funktion"], element["v_vr"], element["v_hp"], element["f_vr"])
  elseif element["typ"] == "weiche" then
    w:send(nummer, element["lage"])
  elseif element["typ"] == "block" then
    --TODO
  end

  upd:send(nummer)
end

function update(nummer)
  local thread = require("thread")

  udt = thread.create(update_internal, nummer)
  udt:detach()
end

function fsha(nummer)
  local event = require("event")
  event.push("fahrstrasse", "fsha_pre", nummer)
  if globalplan_elemente[nummer]["typ"] == "signal" then
    globalplan_elemente[nummer]["zielsignal"] = nil
  end
  globalplan_elemente[nummer]["nachbarn"]["anfang"]["element"]:spurplankabel(nummer,  { ["typ"] = "hilfsaufloesung", ["inhalt"] = { ["rfs"] = globalplan_elemente[nummer]["rfs"], }, })
end

local function anforderung_handler(nummer)
  local event = require("event")

  if globalplan_elemente[nummer] then
    update(nummer)
    event.push("fahrstrasse", "anforderung", nummer, true, true)
    return true, true
  else
    event.push("fahrstrasse", "anforderung", nummer, true, false)
    return true, false
  end
end

local function gleisfreimeldung_handler(nummer, freigefahren)
  if globalplan_elemente["nummer"] then
    local element = globalplan_elemente["nummer"]
    if element.typ == "gleisfreimeldung" then
      element:gleiskontakt(freigefahren)
    elseif element.typ == "signal" then
      element:grundzustand()
    end
  end
end

local function eingabe_handler(befehl, arg1, arg2)
  local event = require("event")
  local erhalt = false
  local erfolg = false
  local statuscode = nil
  kommentar = nil
  antworttelegramm = {}
  if befehl == "zfs" then
    erfolg, statuscode, kommentar = fahrstr_gen(arg1, arg2, true, false)
  elseif befehl == "zufs" then
    erfolg, statuscode, kommentar = fahrstr_gen(arg1, arg2, true, true)
  elseif befehl == "rfs" then
    erfolg, statuscode, kommentar = fahrstr_gen(arg1, arg2, false, false)
  elseif befehl == "rufs" then
    erfolg, statuscode, kommentar = fahrstr_gen(arg1, arg2, false, true)
  elseif befehl == "wum" then
    if globalplan_elemente[arg1] then
      if globalplan_elemente[arg1].typ == "weiche" then
        erfolg = globalplan_elemente[arg1]:umlegen(arg2)
      end
    end
  elseif befehl == "sht" then
    if globalplan_elemente[arg1] then
      if globalplan_elemente[arg1].typ == "signal" then
        globalplan_elemente[arg1]:signalhalt()
        erfolg = true
      end
    end
  elseif befehl == "zs8" then
    if globalplan_elemente[arg1] then
      if globalplan_elemente[arg1].typ == "signal" then
        globalplan_elemente[arg1]:zs8()
        erfolg = true
      end
    end
  elseif befehl == "ersgt" then
    if globalplan_elemente[arg1] then
      if globalplan_elemente[arg1].typ == "signal" then
        globalplan_elemente[arg1]:ersgt()
        erfolg = true
      end
    end
  elseif befehl == "vorsgt" then
    if globalplan_elemente[arg1] then
      if globalplan_elemente[arg1].typ == "signal" then
        globalplan_elemente[arg1]:vorsgt()
        erfolg = true
      end
    end
  elseif befehl == "verriegeln" then
    if globalplan_elemente[arg1] then
      globalplan_elemente[arg1]:verriegeln()
      erfolg = true
    end
  elseif befehl == "hilfsentriegeln" then
    if globalplan_elemente[arg1] then
      globalplan_elemente[arg1]:hilfsentriegeln()
      erfolg = true
    end
  elseif befehl == "fsha" then
    if globalplan_elemente[arg1] then
      if (globalplan_elemente[arg1].typ == "signal") or (globalplan_elemente[arg1].typ == "block") then
        fsha(arg1)
        erfolg = true
      end
    end
  elseif befehl == "hilfsentriegeln" then
    if globalplan_elemente[arg1] then
      globalplan_elemente[arg1]:hilfsentriegeln()
      erfolg = true
    end
  elseif befehl == "info" then
    if globalplan_elemente[arg1] then
      local el = globalplan_elemente[arg1]

      antworttelegramm = {
        ["verriegelt"] = el["verriegelzaehler"]
      }

      if el["typ"] == "weiche" then
        antworttelegramm["lage"] = el["lage"]
      elseif el["typ"] == "signal" then
        antworttelegramm["v_hp"] = el["v_hp"]
        antworttelegramm["v_vr"] = el["v_vr"]
        antworttelegramm["f_vr"] = el["f_vr"]
      elseif el["typ"] == "block" then
        antworttelegramm["erlaubnis"] = el["erlaubnis"]
      end

      kommentar = antworttelegramm
      erfolg = true
    end
  elseif befehl == "blockfrei" then
    local blel = globalplan_elemente[arg1]

    if blel then
      local event = require("event")
      if blel["typ"] == "block" then
        blel:rueckblock()
        erfolg = true
      end
    end
  end

  event.push("fahrstrasse", befehl, arg1, arg2, erfolg, statuscode)

  if globalplan_elemente[arg1] then
    erhalt = true
  end

  return erhalt, erfolg, kommentar
end

local ftp = nil

function fs.start(tinyftp, ziel, modem, name)
  local term = require("term")
  term.clear()
  print("Fahrstraßenrechner startet!")
  
  ftp = tinyftp

  print("Fordere OCS-Bibliothek an..")
  local erfolg, err = tinyftp:download("/estw/lib/libocs/base.lua", "/software/lib/libocs/base.lua")

  if not erfolg then
    error("OCS: " .. err)
  end

  print("Lade OCS-Bibliothek..")

  local libocs = require("/estw/lib/libocs.base")

  local module = {
    [1] = "eingabe",
    [2] = "gleisfreimeldung",
    [3] = "anforderung",
    [4] = "blockrueckmeldung",
  }

  local ocsverbindung = libocs:connect(name, modem, ziel, module, true)

  if not ocsverbindung then
    error("OCS kann sich nicht verbinden!")
  end

  print("OCS verbunden!")
  print("Fordere Subkomponenten an!")

  local erfolg, err = tinyftp:download("/estw/lib/libocs/ls.lua", "/software/lib/libocs/ls.lua")

  if not erfolg then
    error("OCS-LS kann nicht angefordert werden: " .. err)
  end

  local erfolg, err = tinyftp:download("/estw/lib/libocs/w.lua", "/software/lib/libocs/w.lua")

  if not erfolg then
    error("OCS-W kann nicht angefordert werden: " .. err)
  end

  local erfolg, err = tinyftp:download("/estw/lib/libocs/gfr.lua", "/software/lib/libocs/gfr.lua")

  if not erfolg then
    error("OCS-GFR kann nicht angefordert werden: " .. err)
  end

  local erfolg, err = tinyftp:download("/estw/lib/libocs/eg.lua", "/software/lib/libocs/eg.lua")

  if not erfolg then
    error("OCS-AG kann nicht angefordert werden: " .. err)
  end

  local erfolg, err = tinyftp:download("/estw/lib/libocs/req.lua", "/software/lib/libocs/req.lua")

  if not erfolg then
    error("OCS-REQ kann nicht angeordert werden: " .. err)
  end

  --local erfolg, err = tinyftp:download("/estw/lib/libocs/bkreq.lua", "/software/lib/libocs/bkreq.lua")

  --if not erfolg then
  --  error("OCS-BKREQ kann nicht angefordert werden: " .. err)
  --end

  local erfolg, err = tinyftp:download("/estw/lib/libocs/bk.lua", "/software/lib/libocs/bk.lua")

  if not erfolg then
    error("OCS-BLOCK kann nicht angefordert werden: " .. err)
  end

  local erfolg, err = tinyftp:download("/estw/lib/libocs/upd.lua", "/software/lib/libocs/upd.lua")

  if not erfolg then
    error("OCS-UPD kann nicht angefordert werden: " .. err)
  end

  print("Subkomponenten angefordert, lade Komponenten!")

  local libocsls = require("/estw/lib/libocs.ls")
  local libocsw = require("/estw/lib/libocs.w")
  local libocsgfr = require("/estw/lib/libocs.gfr")
  local libocseg = require("/estw/lib/libocs.eg")
  local libocsreq = require("/estw/lib/libocs.req")
  --local libocsbkreq = require("/estw/lib/libocs.bkreq")
  local libocsblock = require("/estw/lib/libocs.bk")
  local libocsupd = require("/estw/lib/libocs.upd")

  print("Subkomponenten geladen!")

  ls = libocsls:init(ocsverbindung)
  w = libocsw:init(ocsverbindung)
  block = libocsblock:init(ocsverbindung)

  local req = libocsreq:init(ocsverbindung)
  local gfr = libocsgfr:init(ocsverbindung)
  --local bkack = libocsbkack:init(ocsverbindung)
  local eg = libocseg:init(ocsverbindung)
  upd = libocsupd:init(ocsverbindung)

  req:subscribe(anforderung_handler)
  gfr:subscribe(gleisfreimeldung_handler)

  eg:subscribe(eingabe_handler)

  ocsverbindung:subscribe(req)
  ocsverbindung:subscribe(gfr)
  --ocsverbindung:subscribe(block)
  ocsverbindung:subscribe(eg)

  ocsverbindung:listener_thread()

  print("Fordere Fahrstraßenplan an!")

  local erfolg, err = tinyftp:download("/estw/etc/fsp.cfg", "/konfiguration/fsr/" .. name .. "/fsp.cfg")

  if not erfolg then
    error("Fahrstraßenplan kann nicht angefordert werden: " .. err)
  end

  local serialization = require("serialization")
  
  local fsprawh = io.open("/estw/etc/fsp.cfg", "r")
  fsprawh:seek("set", 0)
  local fspraw = fsprawh:read("*a")
  fsprawh:close()

  local erfolg, fsp = pcall(serialization.unserialize, fspraw)

  if not erfolg then
    error("Fahrstraßenplan ist unlesbar!")
  end

  print("Fahrstraßenplan geladen!")
  print("Erzeuge Fahrwegelemente!")
  
  for nummer, element in pairs(fsp) do
    print("Verarbeite Element " .. nummer)
    if element["typ"] == "signal" then
      print("Lege Signal " .. nummer .. " an")
      local neu = elemente.signal:neu()
      neu:setze_nummer(nummer)
      neu:sigdef(element["system"], element["funktion"])
      neu:setstartv(element["startv"])
      neu:grundzustand_kennlicht(element["grz"])
      neu["gleisabschluss"] = element["gleisabschluss"]

      globalplan_elemente[nummer] = neu
    elseif element["typ"] == "umfahrgruppe" then
      print("Lege Umfahrgruppe " .. nummer .. " an")
      local neu = elemente.umfahrgruppe:neu()
      neu:setze_nummer(nummer)
      for von, nach in pairs(element["durchlaessig"]) do
        neu:durchlaessigfuer(nach)
      end

      globalplan_elemente[nummer] = neu
    elseif element["typ"] == "weiche" then
      print("Lege Weiche " .. nummer .. " an")
      local neu = elemente.weiche:neu()
      neu:setze_nummer(nummer)

      for lage, tbl in pairs(element["lagen"]) do
        neu:lagedef(lage, tbl["flankenschutztransport"], tbl["vmax"])
      end

      neu["lage"] = element["grundstellung"]
      neu["vorzugslage"] = element["grundstellung"]

      globalplan_elemente[nummer] = neu
    elseif element["typ"] == "gleisfreimeldung" then
      print("Lege Gleiskontakt " .. nummer .. " an")
      local neu = elemente.gleisfreimeldung:neu()
      neu:setze_nummer(nummer)

      globalplan_elemente[nummer] = neu
    elseif element["typ"] == "kreuzung" then
      print("Lege Kreuzung " .. nummer .. " an")
      local neu = elemente.kreuzung:neu()

      neu:setze_nummer(nummer)
      globalplan_elemente[nummer] = neu
    elseif element["typ"] == "block" then
      print("Lege Streckenblock " .. nummer .. " an")
      
      local neu = elemente.block:neu()

      neu:setze_nummer(nummer)
      neu:gwb(element["gwb"])

      globalplan_elemente[nummer] = neu
    end
  end

  for nummer, element in pairs(globalplan_elemente) do
    local fspr = fsp[nummer]

    element:spurplan_einhaengen()

    for ende, nachbar in pairs(fspr["nachbarn"]) do
      element:nachbar(ende, globalplan_elemente[nachbar])
    end

    if element["typ"] == "signal" then
      element:grundzustand()
    end
  end

  local thread = require("thread")

  thread.create(update_internal)

  print("Fahrstraßenrechner gestartet!")

  local event = require("event")

  while true do
    local ev, arg1, arg2, arg3, arg4, arg5, arg6 = event.pull("fahrstrasse")
    if arg2 == nil then arg2 = "" end
    if arg3 == nil then arg3 = "" end
    if arg4 == nil then arg4 = "" end
    if arg5 == nil then arg5 = "" end
    if arg6 == nil then arg6 = "" end
    print(tostring(arg1) .. " " .. tostring(arg2) .. " " .. tostring(arg3) .. " " .. tostring(arg4) .. " " .. tostring(arg5) .. " " .. tostring(arg6))
  
    if arg1 == "anforderung" then
      if not arg4 then
        local fth = io.open("/estw/log/unbekannte_elemente.txt", "a")
        fth:write(tostring(arg3) .. "\n")
        fth:close()

        ftp:remove("/log/" .. name .. "/missing.txt")
        ftp:upload("/estw/log/unbekannte_elemente.txt", "/log/" .. name .. "/missing.txt")
      end
    end
  end
end

mcserver@Debian-bullseye-latest-amd64-base:~/MinecraftServer/world/opencomputers/24b18f04-4723-4a6f-a894-25dccc397482/fsr$ 
