-- Universe Generator
-- Here, shit gets real

Universe = {
	probes = {},
	stars = {},
	planets = {},
	satellites = {},
	meteors = {},
	comets = {},
	stations = {}
}

function Universe:iterator()
	local pointer = 0
	local bodyTables = {"probes", "stars", "planets", "satellites", "meteors", "comets", "stations"}
	return function()
		pointer = pointer + 1
		if pointer <= #bodyTables then
			return pointer, bodyTables[pointer]
		else
			return nil
		end
	end
end

function Universe:generate(seed)
	-- Create star systems randomly
	print(seed, os.time())
	math.randomseed(seed or os.time())
	local x,y = math.random(-32768,32768),math.random(-32768,32768)

	local S = self:createStar(x,y)
	
	love.event.quit()

	local St = self.stations[math.random(#self.stations)]
	local v,dir = addVectors(getOrbitVelocity(St,St.size*2),0, St.v,St.dir)
	Probe.new({name = "PROBE", x = St.x, y = St.y - St.size*2, v = v, dir = dir})
end

function planOrbit(orbitTable, buffer, quantum, massRange, sizeRange, gravThreshold)
	while true do
		local intvl, range = 0,0
		
		for i = 1,#orbitTable,2 do
			if range < (orbitTable[i+1] - orbitTable[i]) then
				intvl = i
				range = (orbitTable[i+1] - orbitTable[i])
			end
		end
		
		if range < quantum then
			break
		end

		local mass, size, space
		repeat
			mass, size = 2^math.random(unpack(massRange)), 2^math.random(unpack(sizeRange))
			space = math.sqrt(Physics.K * mass / gravThreshold)
		until space*2 <= range
		
		local dist = math.randomNormal(0.5, 0.1) * (range - space*2) + orbitTable[intvl]
		table.insert(orbitTable, intvl+1, dist - space)
		table.insert(orbitTable, intvl+2, dist + space)
		table.insert(buffer, {dist, mass, size, space})
	end

	io.stdout:flush()
end

-- Second idea for generation
-- Instead of trying to fit stuff, generate it procedurally making sure everything fits
-- Also, just for starters, let's 
function Universe:createStar(x, y)
	local mass = 2^math.random(10,13)
	local size = 2^math.random(9,11)
	local density = mass/size
	print(mass,size)
	
	-- Define color based on density
	local color
	if density > 8 then
		color = {255,255,255,255}
	elseif density > 4 then
		color = {0,208,255,255}
	elseif density > 2 then
		color = {0,128,255,255}
	elseif density > 1 then
		color = {255,255,0,255}
	elseif density > 0.5 then
		color = {255,192,64,255}
	else
		color = {192,0,0,255}
	end
	
	-- Define orbit range
	local orbitrange = {size*2, math.sqrt(Physics.K * mass / 2^-10)}
	print(mass, size, orbitrange[2])

	-- Plan out the planetary orbits
	local planets = {}
	planOrbit(orbitrange, planets, mass, {5,11}, {7,9}, 2^-2)
	print("Planets:", #planets)

	-- Plan out the asteroid belt orbits
	local belts = {}
	planOrbit(orbitrange, belts, mass/2, {2,4}, {3,5}, 2^6)
	print("Belts:",#belts)

	-- Plan out the comet/roamer orbits
	local comets = {}
	planOrbit(orbitrange, comets, mass/4, {2,5}, {4,6}, 2^7)
	print("Comets:",#comets)

	-- Plan out stellar space stations
	local stations = {}
	planOrbit(orbitrange, stations, mass/8, {3,3}, {4,4}, 2^6)
	print("Stations:",#stations)

	local palette = {
		grad1 = {0,0,0,32},
		grad2 = {0,0,0,16},
		flare = {0,0,0,192},
		spots = {0,0,0,128}
	}
	for c = 1,3 do
		palette.grad1[c] = color[c]
		palette.grad2[c] = color[c] * math.randomNormal(0.5, 0.1)
		palette.flare[c] = color[c] * math.randomNormal(1.5, 0.1)
		palette.spots[c] = color[c] * math.randomNormal(0.25, 0.01)
	end

	S = Star.new({name = string.format("STAR%02X",math.random(0xff)), x = x, y = y, mass = mass, size = size,
		color = color, texture_params = {
			{"gradient", palette.grad1, palette.grad2, 1024},
			{"noise", palette.flare},
			{"blotch", palette.spots, 8, 0.25}
		}
	})

	local angle
	for i,P in ipairs(planets) do
		angle = math.random() * 2*math.pi
		local _r = P[1]
		local _x = x + math.cos(angle) * _r
		local _y = y + math.sin(angle) * _r
		local _mass = P[2]
		local _size = P[3]
		local _space = P[4]
		local _v = getOrbitVelocity(S, _r)
		if math.random() < 0.5 then _v = -_v end

		local _dv, _ddir = addVectors(_v, angle+0.5*math.pi, S.v, S.dir)

		self:createPlanet(_x, _y, _dv, _ddir, _mass, _size, _space)
	end

	for i,P in ipairs(stations) do
		if math.random() < 0.25 then
			StData = stations[math.random(#stations)]

			angle = math.random() * 2*math.pi
			local _r = StData[1]
			local _x = x + math.cos(angle) * _r
			local _y = y + math.sin(angle) * _r
			local _mass = StData[2]
			local _size = StData[3]
			local _space = StData[4]
			local _v = getOrbitVelocity(S, _r)
			if math.random() < 0.5 then _v = -_v end

			local _dv, _ddir = addVectors(_v, angle+0.5*math.pi, S.v, S.dir)

			St = Station.new({name = string.format("SS%04X", math.random(0xffff)), x = _x, y = _y, v = _dv, dir = _ddir})
			print(St)
		end
	end
end

function Universe:createPlanet(x, y, v, vdir, mass, size, omax)
	local density = mass/size
	local atmosize = density * size/2
	if density < 1 then atmosize = 0 end

	-- Randomize common minerals and determine main color
	local base_minerals = {
	{"Fe", {192,64,64,255}},
	{"Si", {255,192,144,255}},
	{"Ca", {192,192,192,255}},
	{"Cu", {64,144,64,255}},
	{"Al", {192,208,255,255}},
	{"Ag", {144,144,144,255}},
	{"Au", {144,128,64,255}},
	{"C",  {72,72,72,255}},
	{"S",  {192,192,0,255}}
	}
	local minerals = {}
	local base_color = nil
	local min_concentration, max_concentration = #base_minerals, (#base_minerals)^2
	while #base_minerals > 0 do
		local i = math.random(1,#base_minerals)
		local rock = base_minerals[i]
		if not base_color then
			base_color = rock[2]
		end
		minerals[rock[1]] = math.random(min_concentration, max_concentration)
		max_concentration = max_concentration - min_concentration
		min_concentration = min_concentration - 1 
		table.remove(base_minerals, i)
	end

	-- Randomize rare minerals
	for i,rock in ipairs({"U","Ra","Pu"}) do
		minerals[rock] = math.random(0,1)
	end

	-- Parameter for atmosphere and liquid composition
	local base_elements = {
		{"O",  {0,192,255,255}},
		{"C",  {128,144,32,255}},
		{"S",  {192,192,0,255}},
		{"Cl", {192,255,192,255}},
		{"F",  {255,208,192,255}},
		{"N",  {208,208,208,255}}
	}
	local base_element = nil

	-- Randomize atmosphere (if any)
	local base_gases = {
		O = {"H2O"},
		C = {"CH4", "CO2"},
		S = {"SO2"},
		Cl = {"Cl"},
		F = {"F"},
		N = {"N", "NH3"}
	}
	local atmosphere = nil
	local amosphere_color = nil
	if density >= 1 then
		atmosphere = {}
		while #base_elements > 0 do
			local i = math.random(1,#base_elements)
			local gas = base_elements[i]
			if not atmosphere_color then
				atmosphere_color = gas[2]
			end
			if not base_element then
				base_element = gas[1]
			end

			for i,G in ipairs(base_gases[gas[1]]) do
				atmosphere[G] = math.random(1,#base_elements)
			end
			table.remove(base_elements, i)
		end

		-- Randomize omnipresent gases(H, He)
		for i,gas in ipairs({"He","H"}) do
			atmosphere[gas] = math.random(i,5*i)
		end
	end

	-- Randomize liquid composition (if any)
	local base_liquids = {
		O = {"H2O"},
		C = {},
		S = {"H2SO4"},
		Cl = {"HCl"},
		F = {"HF"},
		N = {"NH4"}
	}
	local liquids = nil
	if density > 1 then
		liquids = {}
		for i,L in ipairs(base_liquids[base_element]) do
			liquids[L] = math.random(1,math.ceil(density))
		end
	end

	local orbitrange = {(size + atmosize)*2, math.sqrt(Physics.K * mass / 2^-2)}
	-- Plan out satellites
	local moons = {}
	planOrbit(orbitrange, moons, mass, {5,8}, {4,7}, 2^3)
	print("Satellites:", #moons)

	-- Plan out planetary space stations
	local stations = {}
	planOrbit(orbitrange, stations, mass/4, {3,3}, {4,4}, 2^6)
	print("Stations:",#stations)

	io.stdout:flush()
	local type = "rocky"

	if density >= 8 then
		type = "gas giant"
	end

	print(type)
	io.stdout:flush()

	local params,atmo_params = {},{}
	if not atmosphere_color then atmosphere_color = {0,0,0,0} end
	local palette = {
		grad1 = {0,0,0,255},
		grad2 = {0,0,0,255},
		atmo1 = {0,0,0,16},
		atmo2 = {0,0,0,0}
	}
	if type == "rocky" then
		palette["grain"] = {0,0,0,128}
		palette["craters"] = {0,0,0,64}
		for c = 1,3 do
			palette.grad1[c] = base_color[c]
			palette.grad2[c] = base_color[c] * math.randomNormal(0.5, 0.1)
			palette.grain[c] = base_color[c] * math.randomNormal(0.5, 0.05)
			palette.craters[c] = base_color[c] * math.randomNormal(0.3, 0.02)
			palette.atmo1[c] = atmosphere_color[c]
			palette.atmo2[c] = atmosphere_color[c] * math.randomNormal(0.5, 0.1)
		end
		params = {
			{"gradient", palette.grad1, palette.grad2, 128},
			{"noise", palette.grain},
			{"blotch", palette.craters, 8, math.random()*0.6}
		}
		atmo_params = {
			{"gradient", palette.atmo1, palette.atmo2, 128}
		}
	elseif type == "gas giant" then
		palette["clouds"] = {0,0,0,32}
		palette["noise1"] = {0,0,0,16}
		palette["noise2"] = {0,0,0,8}
		for c = 1,3 do
			palette.grad1[c] = base_color[c]
			palette.grad2[c] = base_color[c] * math.randomNormal(0.5, 0.1)
			palette.atmo1[c] = atmosphere_color[c]
			palette.atmo2[c] = atmosphere_color[c] * math.randomNormal(0.5, 0.1)
			palette.clouds[c] = atmosphere_color[c] * math.randomNormal(1.5, 0.2)
			palette.noise1[c] = atmosphere_color[c] * math.randomNormal(1.0, 0.2)
			palette.noise2[c] = atmosphere_color[c] * math.randomNormal(0.5, 0.2)
			params = {
				{"gradient", palette.grad1, palette.grad2, 128}
			}
			atmo_params = {
				{"gradient", palette.atmo1, palette.atmo2, 128},
				{"blotch", palette.clouds, 16, math.random()*0.5},
				{"noise", palette.noise1},
				{"noise", palette.noise2}
			}
		end
	end

	P = Planet.new({name = string.format("PL%03X",math.random(0xfff)), x = x, y = y, mass = mass, size = size, v = v, dir = dir, vrot = math.random() * math.pi/8,
		minerals = minerals, liquids = liquids, atmosphere = atmosphere,
		atmosphere_size = atmosize,
		color = base_color, texture_params = params, atmosphere_params = atmo_params
	})

	local angle
	for i,M in ipairs(moons) do
		angle = math.random() * 2*math.pi
		local _r = M[1]
		local _x = x + math.cos(angle) * _r
		local _y = y + math.sin(angle) * _r
		local _mass = M[2]
		local _size = M[3]
		local _space = M[4]
		local _v = getOrbitVelocity(P, _r)
		if math.random() < 0.5 then _v = -_v end

		local _dv, _ddir = addVectors(_v, angle+0.5*math.pi, P.v, P.dir)

		self:createSatellite(_x, _y, _dv, _ddir, _mass, _size, _space)
	end

	-- Space Station
	if #stations > 0 then
		StData = stations[math.random(#stations)]

		angle = math.random() * 2*math.pi
		local _r = StData[1]
		local _x = x + math.cos(angle) * _r
		local _y = y + math.sin(angle) * _r
		local _mass = StData[2]
		local _size = StData[3]
		local _space = StData[4]
		local _v = getOrbitVelocity(P, _r)
		if math.random() < 0.5 then _v = -_v end

		local _dv, _ddir = addVectors(_v, angle+0.5*math.pi, P.v, P.dir)

		St = Station.new({name = string.format("SS%04X", math.random(0xffff)), x = _x, y = _y, v = _dv, dir = _ddir})
		print(St)
	end
end

function Universe:createSatellite(x, y, v, vdir, mass, size, omax)
	local density = mass/size
	local atmosize = density * size/2

	-- Randomize common minerals and determine main color
	local base_minerals = {
	{"Fe", {192,64,64,255}},
	{"Si", {255,192,144,255}},
	{"Ca", {192,192,192,255}},
	{"Cu", {64,144,64,255}},
	{"Al", {192,208,255,255}},
	{"Ag", {144,144,144,255}},
	{"Au", {144,128,64,255}},
	{"C",  {72,72,72,255}},
	{"S",  {192,192,0,255}}
	}
	local minerals = {}
	local base_color = nil
	local min_concentration, max_concentration = #base_minerals, (#base_minerals)^2
	while #base_minerals > 0 do
		local i = math.random(1,#base_minerals)
		local rock = base_minerals[i]
		if not base_color then
			base_color = rock[2]
		end
		minerals[rock[1]] = math.random(min_concentration, max_concentration)
		max_concentration = max_concentration - min_concentration
		min_concentration = min_concentration - 1 
		table.remove(base_minerals, i)
	end

	-- Randomize rare minerals
	for i,rock in ipairs({"U","Ra","Pu"}) do
		minerals[rock] = math.random(0,1)
	end

	local params = {}
	local palette = {
		grad1 = {0,0,0,255},
		grad2 = {0,0,0,255},
		grain = {0,0,0,128},
		craters = {0,0,0,64}
	}
	for c = 1,3 do
		palette.grad1[c] = base_color[c]
		palette.grad2[c] = base_color[c] * math.randomNormal(0.5, 0.1)
		palette.grain[c] = base_color[c] * math.randomNormal(0.5, 0.05)
		palette.craters[c] = base_color[c] * math.randomNormal(0.3, 0.02)
	end
	params = {
		{"gradient", palette.grad1, palette.grad2, 128},
		{"noise", palette.grain},
		{"blotch", palette.craters, 8, math.random()*0.6}
	}
	
	M = Satellite.new({name = string.format("SAT%03X",math.random(0xfff)), x = x, y = y, mass = mass, size = size, v = v, dir = dir, vrot = math.random() * math.pi/16,
		minerals = minerals,
		color = base_color, texture_params = params
	})
end

return Universe