--!strict
export type Cell = {
	Up: { [number]: number },
	Down: { [number]: number },
	Left: { [number]: number },
	Right: { [number]: number },

	Weight: number,
}

local function random(weights: { [any]: number })
	local totalPossibility = 0
	local rand = math.random()

	for _, v in pairs(weights) do
		totalPossibility += v
	end

	local possibility = totalPossibility

	for k, v in pairs(weights) do
		possibility -= v
		if rand > possibility / totalPossibility then
			return k
		end
	end

	error("Error generating random")
end

local function deepCopy(tbl)
	if type(tbl) == "table" then
		local newTbl = {}

		for i, v in pairs(tbl) do
			newTbl[i] = type(v) == "table" and deepCopy(v) or v
		end

		return newTbl
	else
		return tbl
	end
end

local CW = {}

CW.__index = CW

function getOrder(tbl)
	local order = {}
	for i, v in pairs(tbl) do
		table.insert(order, i)
	end
	return order
end

function createArray(col: number, row: number, cell: any): { [number]: { [number]: any } }
	local tbl = {}
	for y = 1, col do
		tbl[y] = {}
		for x = 1, row do
			tbl[y][x] = deepCopy(cell)
		end
	end
	return tbl
end

function CW.createCell(
	up: { [number]: number },
	down: { [number]: number },
	left: { [number]: number },
	right: { [number]: number },

	cellsAmount: number,
	weight: number
): Cell
	local urutans = {}
	for i = 1, cellsAmount do
		table.insert(urutans, i)
	end

	return {
		Up = up,
		Down = down,
		Left = left,
		Right = right,
		Weight = weight,
		-- collapsed = false,
		-- options = urutans
	}
end

function CW.createWeights()
	return {}
end

function CW.new(col, row, tbl: { [number]: Cell }, weights: { [number]: number }?)
	local self = setmetatable({}, CW)
	self.DefaultOptions = { collapsed = false, options = getOrder(tbl) }
	self.CWArray = createArray(col, row, self.DefaultOptions)
	self.CellsTbl = tbl
	self.Weights = weights or {}

	return self
end

function CW:Start()
	local givenCellsTbl = self.CellsTbl -- or cellsTbl
	--defining
	local arrayTbl = self.CWArray

	--adding empty tables in the shapesTbl (if there is one)
	for _, shape in pairs(givenCellsTbl) do
		for i, shapeDirs in pairs(shape) do
			if typeof(shapeDirs) == "table" and #shapeDirs == 0 then
				shape[i] = getOrder(givenCellsTbl)
			end
		end
	end

	--setting a similarly "changed event" system for the table
	for iy: number, y in pairs(arrayTbl) do
		for ix: number, x in pairs(y) do
			if type(x) == "table" then
				rawset(
					x,
					"Proxy",
					setmetatable({}, {
						__newindex = function(k, i, v)
							--set the collapsed value on to the 'real' table
							rawset(x, i, v)

							--update the other entrophy of all cells within the table
							local right = arrayTbl[iy - 1] and arrayTbl[iy - 1][ix]
							local left = arrayTbl[iy + 1] and arrayTbl[iy + 1][ix]
							local up = arrayTbl[iy][ix + 1]
							local down = arrayTbl[iy][ix - 1]

							local directions = { Up = up, Down = down, Left = left, Right = right }

							if i == "options" and type(v) == "number" then
								if givenCellsTbl[v] then
									for dirName, neighbor in pairs(directions) do
										if type(neighbor.options) == "table" then
											for pSi, possibleShape in pairs(neighbor.options) do
												if
													givenCellsTbl[v][dirName]
													and not table.find(givenCellsTbl[v][dirName], possibleShape)
												then
													neighbor.options[pSi] = nil
												end
											end
										end
									end
								end
							elseif i == "options" and type(v) == "table" then
								for dirName, neighbor: any in pairs(directions) do
									if type(neighbor.options) == "number" then
										local oriOptions = neighbor.options
										rawset(neighbor, "options", 0)
										neighbor.Proxy.options = oriOptions
									end
								end
							end
						end,
					})
				)
			end
		end
	end
end

function CW:Collapse(col, row, collapsedValue): number? -- collapsedValue = optional!
	local tbl = self.CWArray

	if tbl[col][row].collapsed then
		return
	end

	local opts = {}
	local optsTotal = 0
	for _, v in pairs(tbl[col][row].options) do
		if v then
			local cell: Cell = self.CellsTbl[v]
			if cell then
				opts[v] = cell.Weight
				optsTotal += 1
			end
		end
	end

	local s, _collapsedValue = pcall(random, opts)
	collapsedValue = if s then _collapsedValue else nil

	if not collapsedValue then
		return
	end

	tbl[col][row].Proxy.collapsed = true
	tbl[col][row].Proxy.options = collapsedValue

	return collapsedValue
end

function CW:Uncollapse(col, row, pos)
	local tbl = self.CWArray
	tbl[col][row].Proxy.collapsed = false
	tbl[col][row].Proxy.options = deepCopy(self.DefaultOptions.options)
end

function CW:Destroy()
	local function clearTbl(t)
		for k, v in pairs(t) do
			if type(v) == "table" then
				clearTbl(t[k])
			end
			self[k] = nil
		end
	end

	clearTbl(self)
	setmetatable(self, nil)
	return
end

return CW
