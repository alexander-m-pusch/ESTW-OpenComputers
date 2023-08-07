local w = {}

function w:init(ocs)
  local o = {
    ["bus"] = "weiche",
    ["ocs"] = ocs,
  }

  setmetatable(o, self)
  self.__index = self

  return o
end

function w:request(nummer)
  local inhalt = {
    ["typ"] = "anforderung",
    ["inhalt"] = {
      ["nummer"] = nummer,
    },
  }

  self["ocs"]:send(inhalt)
end

function w:send(nummer, lage)
  local inhalt = {
    ["typ"] = self.bus,
    ["inhalt"] = {
      ["nummer"] = nummer,
      ["lage"] = lage,
    },
  }

  self["ocs"]:send(inhalt)
end

function w:callback(inhalt)
  if not self["callback_internal"] then return false end
  return self["callback_internal"](inhalt["nummer"], inhalt["lage"])
end

function w:subscribe(fun)
  self["callback_internal"] = fun
end

return w
