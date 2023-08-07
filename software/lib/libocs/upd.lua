local upd = {}

function upd:init(ocs)
  local o = {
    ["bus"] = "ausgabe",
    ["ocs"] = ocs,
  }

  setmetatable(o, self)
  self.__index = self

  return o
end

function upd:send(nummer)
  local inhalt = {
    ["typ"] = self["bus"],
    ["inhalt"] = {
      ["nummer"] = nummer,
    },
  }

  return self["ocs"]:send(inhalt, true)
end

function upd:callback(inhalt)
  if not self["callback_internal"] then return false end
  return self["callback_internal"](inhalt["nummer"])
end

function upd:subscribe(fun)
  self["callback_internal"] = fun
end

return upd
