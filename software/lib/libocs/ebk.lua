local bkack = {}

function bkack:init(ocs)
  local o = {
    ["bus"] = "weiche",
    ["ocs"] = ocs,
  }

  setmetatable(o, self)
  self.__index = self

  return o
end

function bkack:send(nummer, befehl)
  local inhalt = {
    ["typ"] = self.bus,
    ["inhalt"] = {
      ["nummer"] = nummer,
      ["befehl"] = befehl,
    },
  }

  self["ocs"]:send(inhalt)
end

function bkack:callback(inhalt)
  if not self["callback_internal"] then return false end
  return self["callback_internal"](inhalt["nummer"], inhalt["befehl"])
end

function bkack:subscribe(fun)
  self["callback_internal"] = fun
end

return bkack
