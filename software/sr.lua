local signalrechner = {}

local rio = {}
local rop = {}

local signale = {}

local function uebersetze_stellbefehle(system, funktion, v_hp, v_vr, f_vr, hv_alt_hp, hv_alt_vr)
    --system: Signalsystem (Ks, H/V, Hl muss ich bei bedarf dazufrickeln, hoffentlich nicht)
    --funktion: Signalfunktion (Hp, Vr, Ms, Ls, etc pp)
    --v_hp: Zul. Geschwindigkeit ab dem Signal
    --v_vr: Zul. Geschwindigkeit ab dem nächsten Signal
    --f_vr: Signalstellung nächstes Hp (true wenn nächstes Signal etwas anderes als Hp0 zeigt, sonst immer false)
    
    --Dieser Code hier ist mit Ausnahme von wenigen Änderungen 1:1 aus dem alten CC-ESTW übernommen worden, von daher auch dieser jetzt merkwürdig ohne
    --Kontext anmutende Kommentar hier:

    --"sicherheitshalber, da ja irgendein umnachteter
    --programmierer (Hallo, Alex!) ja das ganze als
    --Zahl anstatt als Zeichenkette übermitteln könnte"

    --der war hier, weil ich damals versehentlich den Signalbegriff irgendwie als Zahl übermittelt habe, was zu allerlei lustigen Effekten geführt hat.
    
    local stellbefehle = {}
   
    --print(parsignal .. " " .. funktion .. " " .. system)
    
    --print(textutils.serialize(signal))
    
    if (funktion == "Hp") or (funktion == "Ms") then
        if v_hp == "v" then
            --Hp0 + Zs7
            stellbefehle[1] = "Hp0Zs7"
            if (system == "HV") and (funktion == "Ms") then
              stellbefehle[2] = "VrDunkel"
            end
        elseif v_hp == "s" then
            --Hp0 + Sh1
            stellbefehle[1] = "Hp0Sh1"
            if (system == "HV") and (funktion == "Ms") then
              stellbefehle[2] = "VrDunkel"
            end
        elseif v_hp == "e" then
            --Hp0 + Zs1
            stellbefehle[1] = "Hp0Zs1"
            if (system == "HV") and (funktion == "Ms") then
              stellbefehle[2] = "VrDunkel"
            end
        elseif v_hp == "g" then
            --Hp0 + Zs8
            stellbefehle[1] = "Hp0Zs8"
            if (system == "HV") and (funktion == "Ms") then
              stellbefehle[2] = "VrDunkel"
            end
        else
            if v_hp == 0 then
                stellbefehle[1] = "Hp0"
                if (system == "HV") and (funktion == "Ms") then
                  stellbefehle[2] = "VrDunkel"
                end
            elseif v_hp == "d" then
              stellbefehle[1] = "HpDunkel"
              if (system == "HV") and (funktion == "Ms") then
                stellbefehle[2] = "VrDunkel"
              end
            elseif v_hp == "k" then
              stellbefehle[1] = "HpKennlicht"
              if (system == "HV") and (funktion == "Ms") then
                if v_vr == "k" then
                  stellbefehle[2] = "VrKennlicht"
                elseif v_vr == 0 then
                  stellbefehle[2] = "Vr0"
                elseif v_vr <= 6  then
                  stellbefehle[2] = "Vr2"
                  stellbefehle[3] = "Zs3vKennz" .. v_vr
                else
                  stellbefehle[2] = "Vr1"
                  stellbefehle[3] = "Zs3vKennz" .. v_vr
                end
              end
            else
                --nach H/V und Ks aufschlüsseln
                if system == "HV" then
                    if v_hp <= 6 then
                        if not hv_alt_hp then
                          stellbefehle[1] = "Hp2"
                        end
                        stellbefehle[2] = "Zs3Kennz" .. v_hp
                    else
                        stellbefehle[1] = "Hp1"
                        if not (v_hp == 16) then
                          stellbefehle[2] = "Zs3Kennz" .. v_hp
                          if hv_alt_hp then
                            stellbefehle[1] = nil
                          end
                        end
                    end
                    if funktion == "Ms" then
                        if f_vr then
                            --Vr1
                            if v_vr <= 6 then
                                if not hv_alt_vr then
                                  stellbefehle[3] = "Vr2"
                                end
                                stellbefehle[4] = "Zs3vKennz" .. v_vr
                            else
                                stellbefehle[3] = "Vr1"
                                if not (v_vr == 16) then
                                  stellbefehle[4] = "Zs3vKennz" .. v_vr
                                  if v_vr == 0 then
                                    stellbefehle[4] = nil
                                  end
                                  if hv_alt_vr then
                                    stellbefehle[3] = nil
                                  end
                                end
                            end
                        else
                          if v_vr == "d" then
                            stellbefehle[3] = "VrDunkel"
                          elseif v_vr == "k" then
                            stellbefehle[3] = "VrKennlicht"
                          else
                              --Vr0
                              stellbefehle[3] = "Vr0"
                              if (not (v_vr == 0)) and (not (v_vr == 16)) then
                                stellbefehle[4] = "Zs3vKennz" .. v_vr
                              end
                          end
                        end
                    end
                elseif system == "Ks" then
                    stellbefehle[1] = "Ks1"
                    if not (v_hp == 16) then
                      stellbefehle[2] = "Zs3Kennz" .. v_hp
                    end
                    if funktion == "Ms" then
                        if f_vr then
                            if not (v_vr == 16) and (v_vr < v_hp) then --fahrt mit Geschwindigkeitsreduzierung
                                stellbefehle[3] = "Zs3vKennz" .. v_vr
                                stellbefehle[1] = "Ks1Blink" --magic value, wir später aussortiert
                            end
                        else
                            stellbefehle[1] = "Ks2" --nachträgliche abwertung
                            if not (v_vr == 0) then
                              stellbefehle[3] = "Zs3vKennz" .. v_vr
                            end
                        end
                    end
                end
            end
        end
    elseif funktion == "Vr" then
        if f_vr then --Vr1 / Ks1
            --print(signal .. " " .. f_vr)
            if system == "HV" then
                if tonumber(v_vr) <= 6 then
                    if not hv_alt_vr then
                      stellbefehle[1] = "Vr2"
                    end
                    stellbefehle[2] = "Zs3vKennz" .. v_vr
                    if v_vr == 0 then
                      stellbefehle[2] = nil
                    end
                else
                    stellbefehle[1] = "Vr1"
                    if not (v_vr == 16) then
                      stellbefehle[2] = "Zs3vKennz" .. v_vr
                      if hv_alt_vr then
                        stellbefehle[1] = nil
                      end
                    end
                end
            elseif system == "Ks" then
                stellbefehle[1] = "Ks1"
                if not v_vr == 16 and blink then
                    stellbefehle[2] = "Zs3vKennz" .. v_vr
                    stellbefehle[1] = "Ks1Blink"
                end
            end
        else --Vr0 / Ks2
            if system == "HV" then
                stellbefehle[1] = "Vr0"
                stellbefehle[2] = "Zs3vKennz" .. v_vr
                if v_vr == 0 then
                  stellbefehle[2] = nil
                end
            elseif system == "Ks" then
                stellbefehle[1] = "Ks2"
                stellbefehle[2] = "Zs3vKennz" .. v_vr
                if v_vr == 0 then
                  stellbefehle[2] = nil
                end
            end
        end
    elseif funktion == "Ls" then
        if v_hp == "s" then
          stellbefehle[1] = "Hp0Sh1"
        elseif v_hp == "k" then
          stellbefehle[1] = "HpKennlicht"
        elseif tonumber(v_hp) == 0 then
            stellbefehle[1] = "Hp0"
        end
    elseif funktion == "Zs3" then
        if v_hp > 0 then
          stellbefehle[1] = "Zs3Kennz" .. v_hp
        end
    elseif funktion == "Zs3v" then
        if v_vr > 0 then
          stellbefehle[1] = "Zs3vKennz" .. v_vr
        end
    elseif funktion == "Zs2" then
        stellbefehle[1] = "Zs2Kennz" .. v_hp
    elseif funktion == "Zs2v" then
        stellbefehle[1] = "Zs2vKennz" .. v_hp
    elseif funktion == "Zs6" then
      if v_hp == "g" then
        stellbefehle[1] = "Zs6"
      end
    end
       
    return stellbefehle
end

local function istblink(system, begriff)
  if system == "HV" then
    if begriff == "Hp0Zs8" then return true end
  elseif system == "Ks" then  
    if begriff == "Ks1Blink" then return true end
    if begriff == "Hp0Zs1" then return true end
  elseif system == "Hl" then
    --bitte nich
  end

  return false
end

function empfaenger(nummer, system, funktion, v_vr, v_hp, f_vr)
  local event = require("event")

  event.push("esignal", nummer, system, funktion, v_hp, v_vr, f_vr)

  local computer = require("computer")
  local signal = rio[nummer]

  local serialization = require("serialization")

  if not signal then
    event.push("esignal", nummer, "Nicht unser Signal")
    return false -- nicht unsere Baustelle
  end

  local hv_alt_hp = false
  local hv_alt_vr = false

  if signal["meta"] then
    hv_alt_hp = signal["meta"]["hv_alt_hp"]
    hv_alt_vr = signal["meta"]["hv_alt_vr"]
  end

  local begriffe = uebersetze_stellbefehle(system, funktion, v_hp, v_vr, f_vr, hv_alt_hp, hv_alt_vr)

  for _, begriff in pairs(begriffe) do
    if istblink(system, begriff) then
      if not (signal["begriffe"]["Ks1"] or signal["begriffe"]["Hp0Zs1"]) then
        return true, false
      end
    else
      if not signal["begriffe"][begriff] then
        event.push("esignal", nummer, "Signal kann angeforderten Begriff nicht anzeigen", begriff)
        return true, false
      end
    end
    --wir prüfen einfach nur, ob das signal den angeforderten begriff überhaupt anzeigen kann
    --wenn ja: alles paletti, wenn nicht, meckern wir
  end

  if not signale[nummer] then
    signale[nummer] = {}
  end

  signale[nummer]["begriffe"] = begriffe
  signale[nummer]["system"] = system
  signale[nummer]["neu"] = true

  event.push("esignal", nummer, "Signal erfolgreich gestellt", serialization.serialize(signale[nummer]["begriffe"]))
  return true, true
end

local blinkan = true
local timerid = 0

function output()
  local computer = require("computer")
  local event = require("event")
  local zeitf = 0
  while true do
    event.pull(0.5 - zeitf, "neverfired")

    local zeitv = computer.uptime()

    for nummer, signal in pairs(signale) do
      if not signal["begriffe"] then signal["begriffe"] = {} end
      if signal["neu"] then
        --local zaehler = 0
        for begr, tab in pairs(rio[nummer]["begriffe"]) do
          --event.push("esignal", nummer, begr, tab["adresse"], tab["seite"], tab["dev"])
          rop[tab["dev"]].setBundledOutput(tab["seite"], { [tonumber(tab["adresse"])] = 0 } )
          --zaehler = zaehler + 1
        end
        
        --event.push("esignal", "i", nummer, zaehler)
        signal["neu"] = false
      else
        for _, begriff in pairs(signal["begriffe"]) do
          local blinkend = false
          if begriff == "Ks1Blink" then
            begriff = "Ks1" --Liebes EBA, wieso zum Geier ist ein blinkendes Ks1 kein eigenes Signalbild?
                            --wegen so einer gequirlten Scheiße darf ich hier basteln
            blinkend = true
          end
          if begriff == "Hp0Zs8" then
            begriff = "Hp0Zs1"
  
            blinkend = true
          end
          --event.push("esignal", nummer, begriff, rio[nummer]["begriffe"][begriff]["adresse"])
          local redstone = rop[rio[nummer]["begriffe"][begriff]["dev"]]
          if not blinkend then
            redstone.setBundledOutput(rio[nummer]["begriffe"][begriff]["seite"], { [tonumber(rio[nummer]["begriffe"][begriff]["adresse"])] = 255 } )
          else
            if blinkan then
              redstone.setBundledOutput(rio[nummer]["begriffe"][begriff]["seite"], { [tonumber(rio[nummer]["begriffe"][begriff]["adresse"])] = 255 } )
            else
              redstone.setBundledOutput(rio[nummer]["begriffe"][begriff]["seite"], { [tonumber(rio[nummer]["begriffe"][begriff]["adresse"])] = 0 } )
            end
          end
        end
      end
    end
    blinkan = not blinkan --das ist furchtbar
    zeitf = computer.uptime() - zeitv
  end
end

function signalrechner.start(tinyftp, ziel, modem, name)
  local term = require("term")
  local computer = require("computer")
  local fs = require("filesystem")
  local serialization = require("serialization")
  local component = require("component")
  local thread = require("thread")

  if not fs.exists("/estw/") then fs.mkdir("/estw/") end

  term.clear()
  print("Signalrechner startet!")
  os.sleep(0.5)
  print("Fordere OCS-Basislibrary an..")

  local erfolg, err = tinyftp:download("/estw/lib/libocs/base.lua", "/software/lib/libocs/base.lua")
  if not erfolg then
    error("LibOCS-Download: " .. err)
  end

  if not fs.exists("/estw/lib/") then fs.makeDirectory("/estw/lib/") end

  local libocs = require("/estw/lib/libocs.base")

  local module = {
    [1] = "lichtsignal",
  }
  
  local ocsverbindung, err = libocs:connect(name, modem, ziel, module)

  if not ocsverbindung then
    error("OCS-Verbindung: " .. err)
  end

  print("Erfolgreich mit OCS verbunden!")
  print("Fordere OCS-LS-Schnittstelle an...")
  os.sleep(0.5)

  if not fs.exists("/estw/lib/libocs/") then fs.makeDirectory("/estw/lib/libocs/") end

  local erfolg, err = tinyftp:download("/estw/lib/libocs/ls.lua", "/software/lib/libocs/ls.lua")
  if not erfolg then
    error("OCS-LS-Download: " .. err)
  end

  local libocs_ls = require("/estw/lib/libocs.ls")

  local ocs_ls = libocs_ls:init(ocsverbindung)
  ocs_ls:subscribe(empfaenger)

  print("OCS-LS-Schnittstelle geladen, lade Konfiguration herunter...")

  if not fs.exists("/estw/etc/") then fs.makeDirectory("/estw/etc/") end

  local erfolg, err = tinyftp:download("/estw/etc/rio.cfg", "/konfiguration/sr/" .. name ..  "/rio.cfg")
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

  for signal, tbl in pairs(rio) do
    for begr, begtbl in pairs(tbl["begriffe"]) do
      if not rop[begtbl["dev"]] then
        print("Erzeuge für Begriff " .. signal .. ":" .. begr)
        rop[begtbl["dev"]] = component.proxy(begtbl["dev"])
        if not rop[begtbl["dev"]] then
          fehlerhaft[begr] = { ["begriff"] = begr, ["signal"] = signal}
        end
      end
    end
  end

  local zaehler = 0
  local errorstr = ""
  for _, tbl in pairs(fehlerhaft) do
    print("Ungültig: " .. tbl["signal"] .. " - " .. tbl["begriff"])
    errorstr = errorstr .. tbl["signal"] .. " - " .. tbl["begriff"] .. "\n"
    zaehler = zaehler + 1
  end

  if not (zaehler == 0) then
    error("Es sind " .. zaehler .. " ungültige Geräte deklariert worden:\n" .. errorstr)
  end

  print("Konfiguration eingelesen!")

  ocsverbindung:subscribe(ocs_ls)
  ocsverbindung:listener_thread()

  print("Fordere Signalbegriffe an...")

  for signal, sigtab in pairs(rio) do
    signale[signal] = {}
    local erhalt, erfolg = ocsverbindung:request(signal)
    if not erfolg then
      print("Signal " .. signal .. " kann nicht angefordert werden!")
      print("Ermittle default-Begriff...")
      
      signale[signal]["begriffe"] = {}
      signale[signal]["neu"] = true

      if sigtab["begriffe"]["Hp0"] then
        print("Schalte Hp0 an")
        signale[signal]["begriffe"][1] = "Hp0"
        if sigtab["begriffe"]["VrDunkel"] then
          signale[signal]["begriffe"][2] = "VrDunkel"
          print("Schalte Vorsignal dunkel")
        end
      elseif sigtab["begriffe"]["Vr0"] then
        print("Schalte Vorsignal auf Vr0")
        signale[signal]["begriffe"][1] = "Vr0"
      elseif sigtab["begriffe"]["Ks2"] then
        print("Schalte Vorsignal auf Ks2")
        signale[signal]["begriffe"][1] = "Ks2"
      end
    end
  end
  
  thread.create(output)

  print("Signalrechner gestartet!")
  print("[SR DARF NUR DURCH FACHKRAFT LST BEDIENT WERDEN]")

  local event = require("event")
  while true do
    local ev, arg1, arg2, arg3, arg4, arg5, arg6 = event.pull("esignal")
    if not arg1 then arg1 = "" end
    if not arg2 then arg2 = "" end
    if not arg3 then arg3 = "" end
    if not arg4 then arg4 = "" end
    if not arg5 then arg5 = "" end
    if not arg6 then arg6 = "" end
    print(tostring(arg1) .. " " .. tostring(arg2) .. " " .. tostring(arg3) .. " " .. tostring(arg4) .. " " .. tostring(arg5) .. " " .. tostring(arg6))
  end
end

return signalrechner
