--!strict
-- The programming lesson's checker: a tiny Python subset, run step-limited in plain Luau (nothing is ever loaded or
-- executed as real code). Enough for school tasks:
--   print(a, b, ...)      name = expr      name += expr / -= / *=      for i in range(a[, b[, step]]):  (indented block)
--   expressions: numbers, "strings" or 'strings', names, + - * / // % ** and ( ), str(x), int(x), len(s)
-- Output is what print would write, one line per call. The same module checks on the client (Run) and the server.

local CodeCheck = {}

CodeCheck.MAX_STEPS = 5000
CodeCheck.MAX_SOURCE = 2000
CodeCheck.MAX_TEXT = 400 -- longest string a program may build (the server runs this on what a player typed)

type Float = { float: number }
type Value = number | string | Float

local function isFloat(v: any): boolean
	return type(v) == "table" and v.float ~= nil
end

local function num(v: any): number
	return if isFloat(v) then v.float else v
end

local function fmt(v: Value): string
	if type(v) == "string" then
		return v
	elseif isFloat(v) then
		local n = (v :: Float).float
		if n == math.floor(n) and math.abs(n) < 1e15 then
			return string.format("%d.0", n)
		end
		local s = string.format("%.15g", n)
		return s
	end
	return string.format("%d", v :: number)
end

local function typeName(v: Value): string
	return if type(v) == "string" then "str" elseif isFloat(v) then "float" else "int"
end

-- Tokens of one line: { kind, value }.
local function tokenize(line: string): { { kind: string, value: string } }
	local tokens = {}
	local i = 1
	local n = #line
	while i <= n do
		local c = string.sub(line, i, i)
		if c == " " or c == "\t" then
			i += 1
		elseif c == "#" then
			break
		elseif c == '"' or c == "'" then
			local j = string.find(line, c, i + 1, true)
			if not j then
				error("a string is not closed: add the closing quote")
			end
			table.insert(tokens, { kind = "str", value = string.sub(line, i + 1, j - 1) })
			i = j + 1
		elseif string.match(c, "%d") or (c == "." and string.match(string.sub(line, i + 1, i + 1), "%d")) then
			local s = string.match(line, "^%d*%.?%d*", i) :: string
			table.insert(tokens, { kind = "num", value = s })
			i += #s
		elseif string.match(c, "[%a_]") then
			local s = string.match(line, "^[%w_]+", i) :: string
			table.insert(tokens, { kind = "name", value = s })
			i += #s
		else
			local two = string.sub(line, i, i + 1)
			if two == "//" or two == "**" or two == "+=" or two == "-=" or two == "*=" or two == "==" then
				table.insert(tokens, { kind = "op", value = two })
				i += 2
			elseif string.find("+-*/%(),=:", c, 1, true) then
				table.insert(tokens, { kind = "op", value = c })
				i += 1
			else
				error(`unexpected character '{c}'`)
			end
		end
	end
	return tokens
end

type State = { vars: { [string]: Value }, out: { string }, steps: number }

local function step(state: State)
	state.steps += 1
	if state.steps > CodeCheck.MAX_STEPS then
		error("the program runs too long (an endless loop?)")
	end
end

local function arith(op: string, a: Value, b: Value): Value
	if op == "+" and type(a) == "string" and type(b) == "string" then
		if #a + #b > CodeCheck.MAX_TEXT then
			error("the text gets too long")
		end
		return a .. b
	end
	if op == "*" and type(a) == "string" and type(b) == "number" and not isFloat(b) then
		if #a * math.max(b, 0) > CodeCheck.MAX_TEXT then
			error("the text gets too long")
		end
		return string.rep(a, math.max(b, 0))
	end
	if type(a) == "string" or type(b) == "string" then
		error(`can't use {op} on {typeName(a)} and {typeName(b)} (try str() to join text and numbers)`)
	end
	local x, y = num(a), num(b)
	local float = isFloat(a) or isFloat(b)
	if op == "+" then
		return if float then { float = x + y } else x + y
	elseif op == "-" then
		return if float then { float = x - y } else x - y
	elseif op == "*" then
		return if float then { float = x * y } else x * y
	elseif op == "**" then
		return if float or y < 0 then { float = x ^ y } else x ^ y
	end
	if y == 0 then
		error("division by zero")
	end
	if op == "/" then
		return { float = x / y }
	elseif op == "//" then
		return if float then { float = x // y } else x // y
	elseif op == "%" then
		return if float then { float = x % y } else x % y
	end
	error(`unknown operator {op}`)
end

-- Expression parser (precedence climbing) over a token list from position `pos`.
local function expression(tokens: { any }, pos: number, state: State): (Value, number)
	local primary: (number) -> (Value, number)
	local binary: (number, number) -> (Value, number)
	local PREC = { ["+"] = 1, ["-"] = 1, ["*"] = 2, ["/"] = 2, ["//"] = 2, ["%"] = 2, ["**"] = 3 }

	local function args(p: number): ({ Value }, number)
		local list = {}
		if tokens[p] and tokens[p].value == ")" then
			return list, p + 1
		end
		while true do
			local v
			v, p = binary(p, 1)
			table.insert(list, v)
			local t = tokens[p]
			if t and t.value == "," then
				p += 1
			elseif t and t.value == ")" then
				return list, p + 1
			else
				error("missing ) after the arguments")
			end
		end
	end

	primary = function(p: number): (Value, number)
		step(state)
		local t = tokens[p]
		if not t then
			error("the line ends too early")
		end
		if t.kind == "num" then
			if string.find(t.value, ".", 1, true) then
				return { float = tonumber(t.value) :: number }, p + 1
			end
			return tonumber(t.value) :: number, p + 1
		elseif t.kind == "str" then
			return t.value, p + 1
		elseif t.value == "(" then
			local v, q = binary(p + 1, 1)
			if not tokens[q] or tokens[q].value ~= ")" then
				error("missing )")
			end
			return v, q + 1
		elseif t.value == "-" then
			local v, q = primary(p + 1)
			return arith("-", 0, v), q
		elseif t.kind == "name" then
			local nextTok = tokens[p + 1]
			if nextTok and nextTok.value == "(" then
				local list, q = args(p + 2)
				if t.value == "str" and #list == 1 then
					return fmt(list[1]), q
				elseif t.value == "int" and #list == 1 then
					local v = list[1]
					if type(v) == "string" then
						local n = tonumber(v)
						if not n or n ~= math.floor(n) then
							error(`int() can't read '{v}'`)
						end
						return n, q
					end
					local n = num(v)
					return if n >= 0 then math.floor(n) else -math.floor(-n), q
				elseif t.value == "len" and #list == 1 and type(list[1]) == "string" then
					return utf8.len(list[1] :: string) or #(list[1] :: string), q
				end
				error(`{t.value}() is not part of this lesson (use print, str, int, len)`)
			end
			local v = state.vars[t.value]
			if v == nil then
				error(`name '{t.value}' is not defined`)
			end
			return v, p + 1
		end
		error(`unexpected '{t.value}'`)
	end

	binary = function(p: number, minPrec: number): (Value, number)
		local left, q = primary(p)
		while true do
			local t = tokens[q]
			local prec = t and t.kind == "op" and PREC[t.value]
			if not prec or prec < minPrec then
				return left, q
			end
			local right
			right, q = binary(q + 1, if t.value == "**" then prec else prec + 1)
			left = arith(t.value, left, right)
			step(state)
		end
	end

	return binary(pos, 1)
end

type Line = { indent: number, tokens: { any }, number: number }

local function block(lines: { Line }, from: number, to: number, state: State)
	local i = from
	while i <= to do
		local line = lines[i]
		local toks = line.tokens
		step(state)
		local first = toks[1]
		if first.kind == "name" and first.value == "print" then
			if not toks[2] or toks[2].value ~= "(" then
				error("print needs brackets: print(...)")
			end
			local parts = {}
			local p = 3
			if toks[p] and toks[p].value == ")" then
				p += 1
			else
				while true do
					local v
					v, p = expression(toks, p, state)
					table.insert(parts, fmt(v))
					if toks[p] and toks[p].value == "," then
						p += 1
					elseif toks[p] and toks[p].value == ")" then
						p += 1
						break
					else
						error("missing ) at the end of print")
					end
				end
			end
			if toks[p] then
				error(`unexpected '{toks[p].value}' after print(...)`)
			end
			table.insert(state.out, table.concat(parts, " "))
			if #state.out > 200 then
				error("too much output")
			end
			i += 1
		elseif first.kind == "name" and first.value == "for" then
			local var, inTok, rangeTok = toks[2], toks[3], toks[4]
			if not var or var.kind ~= "name" or not inTok or inTok.value ~= "in" or not rangeTok
				or rangeTok.value ~= "range" or not toks[5] or toks[5].value ~= "(" then
				error("write loops as: for i in range(...):")
			end
			if toks[#toks].value ~= ":" then
				error("a for line ends with a colon :")
			end
			local inner = { table.unpack(toks, 6, #toks - 2) }
			if toks[#toks - 1].value ~= ")" then
				error("missing ) in range(...)")
			end
			local bounds = {}
			local p = 1
			while p <= #inner do
				local v
				v, p = expression(inner, p, state)
				if type(v) ~= "number" then
					error("range() takes whole numbers")
				end
				table.insert(bounds, v)
				if inner[p] and inner[p].value == "," then
					p += 1
				end
			end
			local a, b, s = 0, bounds[1], 1
			if #bounds >= 2 then
				a, b = bounds[1], bounds[2]
			end
			if #bounds == 3 then
				s = bounds[3]
			end
			if not b or s == 0 or #bounds > 3 then
				error("range() takes one, two or three numbers")
			end
			-- The loop's body: the following lines indented deeper.
			local last = i
			while lines[last + 1] and lines[last + 1].indent > line.indent do
				last += 1
			end
			if last == i then
				error(`line {line.number}: the loop needs an indented body`)
			end
			local v = a
			while (s > 0 and v < b) or (s < 0 and v > b) do
				state.vars[var.value] = v
				block(lines, i + 1, last, state)
				v += s
			end
			i = last + 1
		elseif first.kind == "name" and toks[2] and (toks[2].value == "=" or toks[2].value == "+="
			or toks[2].value == "-=" or toks[2].value == "*=") then
			local v, p = expression(toks, 3, state)
			if toks[p] then
				error(`unexpected '{toks[p].value}'`)
			end
			local op = toks[2].value
			if op ~= "=" then
				local old = state.vars[first.value]
				if old == nil then
					error(`name '{first.value}' is not defined`)
				end
				v = arith(string.sub(op, 1, 1), old, v)
			end
			state.vars[first.value] = v
			i += 1
		else
			error("this lesson only uses print, variables (x = ...) and for loops")
		end
	end
end

-- Runs the program. Returns the output lines, or nil and an error message ("line 2: ...").
function CodeCheck.run(source: string): ({ string }?, string?)
	if #source > CodeCheck.MAX_SOURCE then
		return nil, "the program is too long"
	end
	local lines: { Line } = {}
	local n = 0
	for raw in string.gmatch(source .. "\n", "([^\n]*)\n") do
		n += 1
		raw = string.gsub(raw, "\r", "")
		local indentText = string.match(raw, "^[ \t]*") :: string
		local indent = #string.gsub(indentText, "\t", "    ")
		local ok, tokens = pcall(tokenize, raw)
		if not ok then
			return nil, `line {n}: {string.gsub(tostring(tokens), "^.-:%d+: ", "")}`
		end
		if #tokens > 0 then
			table.insert(lines, { indent = indent, tokens = tokens, number = n })
		end
	end
	if #lines == 0 then
		return nil, "the program is empty"
	end
	for k, line in lines do
		local prev = lines[k - 1]
		local opens = prev and prev.tokens[#prev.tokens].value == ":"
		if line.indent > 0 and not opens and (not prev or line.indent > prev.indent) then
			return nil, `line {line.number}: unexpected indent`
		end
	end
	local state: State = { vars = {}, out = {}, steps = 0 }
	local ok, err = pcall(function()
		block(lines, 1, #lines, state)
	end)
	if not ok then
		return nil, (string.gsub(tostring(err), "^.-:%d+: ", ""))
	end
	return state.out, nil
end

-- Lines without trailing spaces, without empty lines at the end.
local function clean(lines: { string }): string
	local out = {}
	for _, l in lines do
		table.insert(out, (string.gsub(l, "%s+$", "")))
	end
	while #out > 0 and out[#out] == "" do
		table.remove(out)
	end
	return table.concat(out, "\n")
end

-- Right when the program runs and prints exactly the expected lines.
function CodeCheck.grade(expect: string, source: string): boolean
	local out = CodeCheck.run(source)
	if not out then
		return false
	end
	return clean(out) == clean(string.split(expect, "\n"))
end

return CodeCheck
