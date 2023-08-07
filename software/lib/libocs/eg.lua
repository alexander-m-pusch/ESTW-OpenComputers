local eg = {}

function eg:init(ocs)
  local o = {
    ["bus"] = "eingabe",
    ["ocs"] = ocs,
  }

  setmetatable(o, self)
  self.__index = self

  return o
end

function eg:send(befehl, arg1, arg2)
  local inhalt = {
    ["typ"] = self.bus,
    ["inhalt"] = {
      ["befehl"] = befehl,
      ["arg1"] = arg1,
      ["arg2"] = arg2,
    },
  }

  return self["ocs"]:send(inhalt)
end

function eg:callback(inhalt)
  if not self["callback_internal"] then return false end
  return self["callback_internal"](inhalt["befehl"], inhalt["arg1"], inhalt["arg2"])
end

function eg:subscribe(fun)
  self["callback_internal"] = fun
end

return eg
