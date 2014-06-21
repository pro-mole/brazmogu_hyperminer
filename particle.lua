-- Particle System

Particles = {
	parts = {}
}

function Particles:reset()
	parts = {}
end

function Particles:add(particleType, x, y, size, v, vdir, vrot, fade, alpha, timer)
	local P = particleType.new(x, y, size, v, vdir, vrot, fade, alpha, timer)

	table.insert(self.parts, P)
end

function Particles:remove(particle)
	for i,P in ipairs(self.parts) do
		if P == particle then
			table.remove(self.parts, i)
			break
		end
	end
end

function Particles:update(dt)
	for i,P in ipairs(self.parts) do
		P:update(dt)
	end
end

function Particles:draw()
	for i,P in ipairs(self.parts) do
		P:draw()
	end
end

-- Particle Types
-- Primitive Particle Type
_Particle = {}

function _Particle.new(x, y, size, v, vdir, vrot, fade, alpha, timer)
	local P = {
		x = x,
		y = y,
		size = size,
		v = v or 0,
		vdir = vdir or 0,
		vrot = vrot or 0,
		angle = 0,
		fade = fade or 64,
		alpha = alpha or 255,
		timer = timer or 2
	}

	P.__index = _Particle

	return setmetatable(P, _Particle)
end

function _Particle:update(dt)
	self.timer = self.timer - dt
	if self.timer <= 0 then
		Particles:remove(self)
	end

	self.angle = self.angle + self.vrot*dt
	self.x = self.x + self.v * math.cos(self.vdir) * dt
	self.y = self.y + self.v * math.sin(self.vdir) * dt
	if self.alpha > 0 then
		self.alpha = self.alpha - self.fade * dt
	end
end

function _Particle:draw()
	love.graphics.setColor(255,255,255,self.alpha)
	love.graphics.circle("fill", self.x, self.y, self.size)
end

PartSquare = {update = _Particle.update}

function PartSquare.new(x, y, size, v, vdir, vrot, fade, alpha, timer)
	local P = {
		x = x,
		y = y,
		size = size,
		v = v or 0,
		vdir = vdir or 0,
		vrot = vrot or 0,
		angle = 0,
		fade = fade or 64,
		alpha = alpha or 255,
		timer = timer or 2,
	}

	return setmetatable(P, {__index = PartSquare})
end

function PartSquare:draw()
	love.graphics.setColor(255,255,255,self.alpha)
	love.graphics.push()
	love.graphics.translate(self.x, self.y)
	love.graphics.rotate(self.angle)

	love.graphics.rectangle("fill", -self.size/2, -self.size/2, self.size, self.size)

	love.graphics.pop()
end

return Particles