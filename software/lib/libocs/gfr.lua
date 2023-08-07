local gfr = {}

function gfr:init(ocs)
  local o = {
    ["bus"] = "gleisfreimeldung",
    ["ocs"] = ocs,
  }

  setmetatable(o, self)
  self.__index = self
  
  return o
end

function gfr:subscribe(fun)
  self["callback_internal"] = fun
end

function gfr:send(nummer, freigefahren)
  local inhalt = {
    ["typ"] = self.bus,
    ["inhalt"] = {
      ["nummer"] = nummer,
      ["freigefahren"] = freigefahren,
    },
  }

  return self["ocs"]:send(inhalt)
end

function gfr:callback(inhalt)
  if not self["callback_internal"] then return false end
  return self["callback_internal"](inhalt["nummer"], inhalt["freigefahren"])
end

return gfr
