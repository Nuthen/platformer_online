Enemy = class('Enemy')

function Enemy:initialize(x, y, color, peerIndex)
	local x, y = x or math.random(0, love.graphics.getWidth()), y or math.random(0, love.graphics.getHeight())
	self.position = vector(x, y)
	self.lastSentPos = vector(x, y)
	self.velocity = vector(0, 0)
	self.lastSentVel = vector(0, 0)

	self.width = 40
	self.height = 40
	self.speed = 240
	self.color = color or {math.random(0, 225), math.random(0, 225), math.random(0, 225)}

	-- this is the goal position to be tweened towards
	-- on the client, it slowly moves it to where the server says it should be
	self.goalX = self.position.x
	self.goalY = self.position.y

	self.showRealPos = false
	self.autono = false

	self.rotateX = 0
	self.rotateY = 0

	self.circleSize = math.random(1, 3)

	-- this is the value of a Enemy in the array of Enemys, as determined by the server
	-- there is an issue with peerIndex and disconnect
	self.peerIndex = peerIndex or 0

	self.directionLimit = 18 -- -1

	self.lerpTween = nil -- stores the tween for interpolation of a non-client Enemy

	self.deg = 0
	self.lastSentDeg = 0
end

-- client function to enable autonomous movement
function Enemy:setAutono()
	self.autono = not self.autono

	self.rotateX = self.position.x
	self.rotateY = self.position.y
end

-- used by server
function Enemy:update(dt, time, players)
	local closestPlayer = nil
	local closestDist = 0

	-- finds the player closest to the enemy and stores it in closest player
	for k, player in pairs(players) do
		local dist = math.sqrt((self.position.x - player.position.x)^2 + (self.position.y - player.position.y)^2)
		if not closestPlayer or dist < closestDist then
			closestPlayer = player
			closestDist = dist
		end
	end

	local player = closestPlayer

	self.angle = math.atan2(player.position.y - self.position.y, player.position.x - self.position.x)

	if self.directionLimit > 0 then
		self.angle = math.floor((self.angle/math.rad(360/self.directionLimit)) + .5)*math.rad(360/self.directionLimit)
	end
	
	self.deg = math.deg(self.angle)

	local dx = math.cos(self.angle)
	local dy = math.sin(self.angle)

	self.velocity.x = dx * self.speed
	self.velocity.y = dy * self.speed

	self.position.x = self.position.x + self.velocity.x * dt
	self.position.y = self.position.y + self.velocity.y * dt
end

-- used by the client to set the interpolation tween
-- the Enemy will move towards the specified location
function Enemy:setTween(goalX, goalY)
	self.goalX = goalX
	self.goalY = goalY

	if self.lerpTween then
		self.lerpTween:stop()
	end

	local dist = vector(goalX - self.position.x, goalY - self.position.y):len()
	local time = dist / self.speed

	self.lerpTween = flux.to(self.position, time, {x = goalX, y = goalY})
end

-- used by the client for only the local Enemy. The client can predict where his 
-- used by the server to predict Enemy movement - dead-reckoning
function Enemy:movePrediction(dt)
	self.position.x = self.position.x + self.velocity.x * dt
	self.position.y = self.position.y + self.velocity.y * dt
end

function Enemy:draw(showRealPos)
	showRealPos = showRealPos or false

	love.graphics.setColor(self.color)

	--love.graphics.rectangle('fill', self.position.x, self.position.y, self.width, self.height)
	love.graphics.circle('fill', self.position.x, self.position.y, self.width/2)

	if showRealPos then
		love.graphics.setColor(255, 0, 0, 165)
		love.graphics.rectangle('fill', self.goalX, self.goalY, self.width, self.height)
	end
	love.graphics.setColor(255, 255, 255)
end