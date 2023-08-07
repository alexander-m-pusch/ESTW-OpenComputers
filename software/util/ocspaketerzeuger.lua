local serialization = require("serialization")

local fh = io.open("/home/p.pkt", "w")
fh:seek("set", 0)
fh:write(serialization.serialize(paket))
fh:close()
