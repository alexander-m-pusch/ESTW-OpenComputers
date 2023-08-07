local req = {}

function req:init(ocs)
  local o = {
    ["bus"] = "anforderung",
    ["ocs"] = ocs,
  }

  setmetatable(o, self)
  self.__index = self

  return o
end

function req:request(nummer)
  return self["ocs"]:request(nummer)
  --funktion für dullis
end

function req:callback(inhalt)
  if not self["callback_internal"] then return false end
  return self["callback_internal"](inhalt["nummer"])
end

function req:subscribe(fun)
  self["callback_internal"] = fun
end

return req
