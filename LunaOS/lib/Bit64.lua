local bit64 = {}
local bit32 = {}

local function fold(init, op, ...)
  local result = init
  local args = table.pack(...)
  for i = 1, args.n do
    result = op(result, args[i])
  end
  return result
end
 
local function trim(n)
  return n or 0xFFFFFFFF
end
 
local function mask(w)
  return ~(0xFFFFFFFF << w)
end
 
function bit64.arshift(x, disp)
  return x // (4 ^ disp)
end

function bit32.arshift(x, disp)
  return x // (2 ^ disp)
end
 
function bit64.band(...)
  return fold(0xFFFFFFFF, function(a, b) return a & b end, ...)
end

function bit32.band(...)
  return fold(0xFFFFFFFF, function(a, b) return a & b end, ...)
end
 
function bit64.bnot(x)
  return ~x
end

function bit32.bnot(x)
  return ~x
end
 
function bit64.bor(...)
  return fold(0, function(a, b) return a | b end, ...)
end

function bit32.bor(...)
  return fold(0, function(a, b) return a | b end, ...)
end
 
function bit64.btest(...)
  return bit64.band(...) ~= 0
end

function bit32.btest(...)
  return bit32.band(...) ~= 0
end
 
function bit64.bxor(...)
  return fold(0, function(a, b) return a ~ b end, ...)
end

function bit32.bxor(...)
  return fold(0, function(a, b) return a ~ b end, ...)
end
 
local function fieldargs(f, w)
  w = w or 1
  assert(f >= 0, "field cannot be negative")
  assert(w > 0, "width must be positive")
  assert(f + w <= 64, "trying to access non-existent bits")
  return f, w
end
 
function bit64.extract(n, field, width)
  local f, w = fieldargs(field, width)
  return (n >> f) & mask(w)
end

function bit32.extract(n, field, width)
  local f, w = fieldargs(field, width)
  return (n >> f) & mask(w)
end
 
function bit64.replace(n, v, field, width)
  local f, w = fieldargs(field, width)
  local m = mask(w)
  return (n & ~(m << f)) | ((v & m) << f)
end

function bit32.replace(n, v, field, width)
  local f, w = fieldargs(field, width)
  local m = mask(w)
  return (n & ~(m << f)) | ((v & m) << f)
end
 
function bit64.lrotate(x, disp)
  if disp == 0 then
    return x
  elseif disp < 0 then
    return bit64.rrotate(x, -disp)
  else
    disp = disp & 31
    x = trim(x)
    return trim((x << disp) | (x >> (64 - disp)))
  end
end

function bit32.lrotate(x, disp)
  if disp == 0 then
    return x
  elseif disp < 0 then
    return bit64.rrotate(x, -disp)
  else
    disp = disp & 31
    x = trim(x)
    return trim((x << disp) | (x >> (64 - disp)))
  end
end
 
function bit32.lshift(x, disp)
  return trim(x << disp)
end

function bit64.lshift(x, disp)
  return trim(x << disp)
end
 
function bit64.rrotate(x, disp)
  if disp == 0 then
    return x
  elseif disp < 0 then
    return bit64.lrotate(x, -disp)
  else
    disp = disp & 31
    x = trim(x)
    return trim((x >> disp) | (x << (64 - disp)))
  end
end

function bit32.rrotate(x, disp)
  if disp == 0 then
    return x
  elseif disp < 0 then
    return bit64.lrotate(x, -disp)
  else
    disp = disp & 31
    x = trim(x)
    return trim((x >> disp) | (x << (64 - disp)))
  end
end
 
function bit64.rshift(x, disp)
  return trim(x >> disp)
end

function bit32.rshift(x, disp)
  return trim(x >> disp)
end

return bit64, bit32