
---
-- Implementation of bitwise operations in pure Lua.
--
-- Not suitable for time critical code. Intended as fallback for cases where a
-- native implementation is unavailable. Further optimization may be possible.
--
-- @author Diego Martínez <https://github.com/kaeza>
-- @module bitty

-- Localize as much as possible.
local tconcat = table.concat
local floor, ceil, max, log =
		math.floor, math.ceil, math.max, math.log
local tonumber, assert, type = tonumber, assert, type

local function tobittable_r(x, ...)
	if (x or 0) == 0 then return ... end
	return tobittable_r(floor(x/2), x%2, ...)
end

local function tobittable(x)
	assert(type(x) == "number", "argument must be a number")
	if x == 0 then return { 0 } end
	return { tobittable_r(x) }
end

local function makeop(cond)
	local function oper(x, y, ...)
		if not y then return x end
		x, y = tobittable(x), tobittable(y)
		local xl, yl = #x, #y
		local t, tl = { }, max(xl, yl)
		for i = 0, tl-1 do
			local b1, b2 = x[xl-i], y[yl-i]
			if not (b1 or b2) then break end
			t[tl-i] = (cond((b1 or 0) ~= 0, (b2 or 0) ~= 0)
					and 1 or 0)
		end
		return oper(tonumber(tconcat(t), 2), ...)
	end
	return oper
end

---
-- Perform bitwise AND of several numbers.
--
-- Truth table:
--
--     band(0, 0) --> 0
--     band(0, 1) --> 0
--     band(1, 0) --> 0
--     band(1, 1) --> 1
--
-- @function band
-- @tparam number ...
-- @treturn number
-- @usage
--  band(11, 6) --> 2 (1011 & 0110 = 0010)
local band = makeop(function(a, b) return a and b end)

---
-- Perform bitwise OR of several numbers.
--
-- Truth table:
--
--     bor(0, 0) --> 0
--     bor(0, 1) --> 1
--     bor(1, 0) --> 1
--     bor(1, 1) --> 1
--
-- @function bor
-- @tparam number ...
-- @treturn number
-- @usage
--  bor(11, 6) --> 15 (1011 | 0110 = 1111)
local bor = makeop(function(a, b) return a or b end)

---
-- Perform bitwise exclusive OR of several numbers.
--
-- Truth table:
--
--     bxor(0, 0) --> 0
--     bxor(0, 1) --> 1
--     bxor(1, 0) --> 1
--     bxor(1, 1) --> 0
--
-- @function bxor
-- @tparam number ...
-- @treturn number
-- @usage
--  bxor(11, 6) --> 13 (1011 ~ 0110 = 1101)
local bxor = makeop(function(a, b) return a ~= b end)

---
-- Perform bitwise negation on a number.
--
-- Truth table:
--
--     bnot(0) --> 1
--     bnot(1) --> 0
--
-- @function bnot
-- @tparam number x The number to negate.
-- @tparam ?number bits Number of bits for result. If not given, defaults to
--  the base 2 logarithm of `x`.
-- @treturn number
-- @usage
--  bnot(5)    -->   2 (~101 = 010)
--  bnot(5, 8) --> 250 (~101 = 11111010)
local function bnot(x, bits)
	return bxor(x, (2^(bits or floor(log(x, 2))))-1)
end

---
-- Shift a number's bits to the left.
--
-- Roughly equivalent to `(x * (2^bits))`.
--
-- @function blshift
-- @tparam number x The number to shift.
-- @tparam number bits Number of positions to shift by.
-- @treturn number
-- @usage
--  blshift(5, 2) --> 20 (0b101 --> 0b10100)
local function blshift(x, bits)
	return floor(x) * (2^bits)
end

---
-- Shift a number's bits to the right.
--
-- Roughly equivalent to (x / (2^bits)).
--
-- @function brshift
-- @tparam number x The number to shift.
-- @tparam number bits Number of positions to shift by.
-- @treturn number
-- @usage
--  brshift(5, 2) --> 1 (0b101 --> 0b001)
local function brshift(x, bits)
	return floor(floor(x) / (2^bits))
end

---
-- Convert a number to base 2 representation.
--
-- @function tobin
-- @tparam number x The number to convert.
-- @tparam ?number bits Minimum number of bits. If resulting string's is
--  shorter than this many characters, the result will be padded with zeros.
--  If not specified, no padding is done.
-- @treturn string
-- @usage
--  tobin(11)    --> "1011"
--  tobin(11, 8) --> "00001011"
local function tobin(x, bits)
	local r = tconcat(tobittable(x))
	return ("0"):rep((bits or 1)+1-#r)..r
end

---
-- Convert a number in base 2 representation to a decimal number.
--
-- Roughly equivalent to `tonumber(x, 2)`.
--
-- Added for symmetry with `tobin`.
--
-- @function frombin
-- @tparam string x The number to convert.
-- @treturn number
-- @usage
--  frombin("1011") --> 11
local function frombin(x)
	return tonumber(tostring(x):match("^0*(.*)"), 2)
end

---
-- Test if bits is set.
--
-- @function bisset
-- @tparam number x
-- @tparam number ... Bit(s) to check. 0 is rightmost (LSB), 1 is second from
--  right, and so on.
-- @treturn boolean True if bit is set, false otherwise. If more than one bit
--  position is specified, returns a boolean for every bit.
local function bisset(x, bit, ...)
	if not bit then return end
	return brshift(x, bit)%2 == 1, bisset(x, ...)
end

---
-- Set bits.
--
-- @function bset
-- @tparam number x
-- @tparam number ... Bit(s) to set. 0 is rightmost (LSB), 1 is second from
--  right, and so on.
-- @treturn number
-- @usage
--  bset(11, 2) --> 15 (1011 --> 1111)
local function bset(x, bit, ...)
	if not bit then return x end
	return bset(bor(x, 2^bit), ...)
end

---
-- Unset bits.
--
-- @function bunset
-- @tparam number x
-- @tparam number ... Bit(s) to unset. 0 is rightmost (LSB), 1 is second from
--  right, and so on.
-- @treturn number
-- @usage
--  bunset(11, 1) --> 9 (1011 --> 1001)
local function bunset(x, bit, ...)
	if not bit then return x end
	return bunset(band(x, bnot(2^bit, ceil(log(x, 2)))), ...)
end

local function repr(x)
	return (type(x)=="string" and ("%q"):format(x) or tostring(x))
end

local function assert_equals(x, y)
	return x==y or error("assertion failed:"
			.." expected "..repr(y)..", got "..repr(x), 2)
end

assert_equals(tobin(0xDEADBEEF), "11011110101011011011111011101111")
assert_equals(frombin("11011110101011011011111011101111"), 0xDEADBEEF)
assert_equals(bor(0xDEADBEEF, 0xCAFEBABE), 0xDEFFBEFF)
assert_equals(band(0xDEADBEEF, 0xCAFEBABE), 0xCAACBAAE)
assert_equals(bxor(0xDEADBEEF, 0xCAFEBABE), 0x14530451)
assert_equals(blshift(0xDEAD, 16), 0xDEAD0000)
assert_equals(brshift(0xDEAD0000, 16), 0xDEAD)
assert_equals(brshift(0xDEAD, 8), 0xDE)
assert_equals(bnot(0, 8), 0xFF)
assert(bisset(0x10, 4))
assert_equals(bset(0, 4), 0x10)
assert_equals(bunset(0x12, 1), 0x10)

local a, b, c, d, e = bisset(frombin("10101"), 0, 1, 2, 3, 4)
assert(a and c and e and not (b or d))

return {
	_NAME = "bitty",
	_LICENSE = "Unlicense <http://unlicense.org/>",
	bor = bor,
	band = band,
	bxor = bxor,
	bnot = bnot,
	blshift = blshift,
	brshift = brshift,
	tobin = tobin,
	frombin = frombin,
	bset = bset,
	bunset = bunset,
	bisset = bisset,
}
