local ls = {}

function ls:init(ocs)
  local o = {
    ["bus"] = "lichtsignal",
    ["ocs"] = ocs,
  }

  setmetatable(o, self)
  self.__index = self
  
  return o
end

function ls:send(nummer, system, funktion, v_vr, v_hp, f_vr)
  local inhalt = {
    ["typ"] = self.bus,
    ["inhalt"] = {
      ["nummer"] = nummer,
      ["system"] = system,
      ["funktion"] = funktion,
      ["v_vr"] = v_vr,
      ["v_hp"] = v_hp,
      ["f_vr"] = f_vr,
    },
  }
  return self["ocs"]:send(inhalt)
end

function ls:callback(inhalt)
  if not self["callback_internal"] then return false end
  return self["callback_internal"](inhalt["nummer"], inhalt["system"], inhalt["funktion"], inhalt["v_vr"], inhalt["v_hp"], inhalt["f_vr"])
end

function ls:subscribe(fun)
  self["callback_internal"] = fun
end

return ls
