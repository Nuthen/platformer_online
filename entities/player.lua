Player = class("Player", Entity)

function Player:initialize(world, x, y, color)
	local x, y = x or math.random(0, love.graphics.getWidth()), y or math.random(0, love.graphics.getHeight())
	Entity.initialize(self, x, y)

	self.startPosition = vector(x, y)
    self.friction = 15
    self.gravity = vector(0, 100)
	self.speed = 5750

	self.xAxis = "leftx"
    self.yAxis = "lefty"
    self.deadzone = 0.3
    self.inputMode = "keyboardmouse"
    self.aim = vector(0, 0)

    self.velocityXTol = 0

    self:reset(world)

	self.color = color or {math.random(0, 225), math.random(0, 225), math.random(0, 225)}

    self.index = 0
end

function Player:reset(world)
    -- stops position from pointing to the same memory block as startPosition
    self.position.x = self.startPosition.x
    self.position.y = self.startPosition.y
    self.desiredVelocity = vector(0, 0)
    if world:hasItem(self) then
        world:update(self, self.position.x+self.desiredVelocity.x, self.position.y+self.desiredVelocity.y)
    end
    self.oldVelocity = vector(0, 0)
    self.velocity = vector(0, 0)
    self.acceleration = vector(0, 0)
    self.facing = 1

    self.isJumping = false
    self.jumpForce = -8100
    self.jumpTime = 0.15
    self.jumpTimer = 0

    self.inputLeft = false
	self.inputRight = false
	self.inputJump = false
    self.inputShoot = false

	self.errorOffset = vector(0, 0)

	self.weapon = Pistol:new()
    self.weapon:attach(self, self.width/2, self.height/2)

    self.maxHealth = 100
    self.health = self.maxHealth
end

function Player:joystickpressed(joystick, button)
    -- A button
    if button == 1 then
        self:jump()
    end
    
    -- B button
    if button == 2 then

    end

    -- X button
    if button == 3 then

    end

    -- Y button
    if button == 4 then
        --self:reset()
    end

    -- Left button
    if button == 5 then

    end
    
    -- Right button
    if button == 6 then

    end
end

function Player:keypressed(key, code)
	if (key == "space" or key == "w") then
	    self:jump()
	end

	if key == "lshift" then

    end
end

function Player:mousepressed(x, y, button)
    if button == 2 then

    end
end

function Player:mousemoved(x, y, dx, dy, isTouch)
    self.inputMode = "keyboardmouse"
end

function Player:getAccelX(joystick)
    if joystick then
        local leftXAxis = joystick:getGamepadAxis(self.xAxis)
        local leftYAxis = joystick:getGamepadAxis(self.yAxis)
        local angle = math.atan2(leftYAxis, leftXAxis)
        local deadzone = self.deadzone

        if math.abs(leftXAxis) > deadzone then
            return math.cos(angle) * self.speed
        end
    end

    self.inputLeft = false
    self.inputRight = false

    if love.keyboard.isDown("a") then
    	self.inputLeft = true
        return -self.speed
    elseif love.keyboard.isDown("d") then
    	self.inputRight = true
        return self.speed
    end

    return 0
end

function Player:input(joystick, camera)
	self.acceleration.x = self:getAccelX(joystick)
    
	self.inputJump = false
    self.inputShoot = false

	if joystick then
	    if joystick:isGamepadDown("a") then
	        self:jump()
	       	self.inputJump = true
	    end
	end

	if love.keyboard.isDown("space") or love.keyboard.isDown("w") then
	    self:jump()
	    self.inputJump = true
	end

    if love.mouse.isDown(1) then
        --self:shoot()
        if self.weapon.readyToFire then
            self.inputShoot = true
            self.weapon.timer = (1 / self.weapon.rateOfFire)
        end
    end

    if self.inputMode == "keyboardmouse" then
        local mouseX, mouseY = camera:mousePosition()
        self.weapon:aimAt(mouseX - self.weapon.position.x, mouseY - self.weapon.position.y)
    end
end

function Player:simulateInput()
	self.acceleration.x = 0

    if self.inputLeft then
    	self.acceleration.x = -self.speed
    elseif self.inputRight then
   		self.acceleration.x = self.speed
    end

    if self.inputJump then
    	self:jump()
    end
end

function Player:shoot(world, index)
    self.weapon:shoot(world, index)
end

function Player:update(dt, world, host)
	Entity.update(self, dt)

    self:move(dt, world)
    local errorDist = self.errorOffset:len()
    if errorDist >= 1 then
    	self.errorOffset = self.errorOffset * 0.85
    elseif errorDist < 1 then
    	self.errorOffset = self.errorOffset * 0.95
    end

    if errorDist <= 0.01 then
    	self.errorOffset = vector(0, 0)
    end

    self.weapon:update(dt)
end

function Player:move(dt, world)
    -- verlet integration, much more accurate than euler integration for constant acceleration and variable timesteps
    self.acceleration = self.acceleration + self.gravity
    self.oldVelocity = self.velocity
    self.velocity = self.velocity + (self.acceleration - self.friction*self.velocity) * dt
    self.desiredVelocity = (self.oldVelocity + self.velocity) * 0.5 * dt

    local actualX, actualY, collisions = world:move(self, self.position.x+self.desiredVelocity.x, self.position.y+self.desiredVelocity.y, function(item, other) 
        if other.class and (other:isInstanceOf(Player) or other:isInstanceOf(Enemy)) then return false end
        return "slide"
    end)
    self.position.x, self.position.y = actualX, actualY

    if collisions then
        for i=1, #collisions do
            local col = collisions[i]

            -- collision with the top of a surface (falling on the ground)
            if col.normal.y == -1 then
                self:stopJump()
            end

            -- collision with the bottom of a surface (bumping your head)
            -- this will stop your jumping motion, but it doesn't allow you to jump again
            -- until you hit the ground
            if col.normal.y == 1 then
                self.acceleration.y = 0
                self.velocity.y = 0
                self.jumpTimer = 0
            end


            if collisions[i].normal.x == 1 or collisions[i].normal.x == -1 then
                self.velocity.x = 0
            end
        end
    end

    return collisions
end

function Player:draw(showRealPos)
	showRealPos = showRealPos or false

	love.graphics.setColor(self.color)

	love.graphics.rectangle('fill', self.position.x + self.errorOffset.x, self.position.y + self.errorOffset.y, self.width, self.height)

	if showRealPos then
		love.graphics.setColor(255, 0, 0, 165)
		love.graphics.rectangle('fill', self.position.x, self.position.y, self.width, self.height)
	end

    love.graphics.setColor(255, 0, 0)
    love.graphics.rectangle('fill', self.position.x, self.position.y - 7, self.width * self.health/self.maxHealth, 5)

    self.weapon:draw()
	love.graphics.setColor(255, 255, 255)
end

function Player:updatePos(x, y, world)
	self.errorOffset = self.position + self.errorOffset - vector(x, y)

	self.position = vector(x, y)
    world:update(self, x, y)

    self.weapon:draw()
end