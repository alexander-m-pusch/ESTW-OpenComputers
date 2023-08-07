local args = {...}

print("Fahrstraßenplanlinker für die ESTW-Software")
print("Geschrieben von Alexander 'ampericus' Pusch")
print("Copyright (C) 2022, Lizensiert unter der GNU GPLv3")

if #args < 3 then
  print("fspld <ausgabedatei> <plan1> <plan2> ... <planN>")
  return
end

local serialization = require("serialization")

local ausgabe = args[1]

local buffer = {}

for i = 2, #args do
  print("Lese Plan " .. args[i] .. " ein")
  local fh = io.open(args[i], "r")
  fh:seek("set", 0)
  local fraw = fh:read("*a")
  fh:close()
  local buf_file = serialization.unserialize(fraw)

  os.sleep(1)

  for element, eltb in pairs(buf_file) do
    print("Verarbeite Element " .. element)
    buffer[element] = eltb --deep copy
    os.sleep(0.05)
  end
end

print("Fahrstraßenpläne eingelesen, wird gelinkt..")

local ofh = io.open(args[1], "w")
ofh:seek("set", 0)
ofh:write(serialization.serialize(buffer))
ofh:close()

print("Gelinkter Fahrstraßenplan nach " .. args[1] .. " gelinkt.")
