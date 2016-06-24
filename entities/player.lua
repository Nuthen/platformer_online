Player = class('Player')

function Player:initialize(x, y, color)
	local x, y = x or math.random(0, love.graphics.getWidth()), y or math.random(0, love.graphics.getHeight())
	self.startPosition = vector(x, y)
	self.position = vector(x, y)

	self.velocity = vector(0, 0)
    self.oldVelocity = vector(0, 0)
    self.acceleration = vector(0, 0)

    self.friction = 25
    self.gravity = vector(0, 200)

	self.width = 20
	self.height = 50
	self.speed = 5750
	self.color = color or {math.random(0, 225), math.random(0, 225), math.random(0, 225)}

    self.isJumping = false
    self.jumpForce = -15000 -- inconsistent jumping from the original?
    self.jumpTime = 0.15
    self.jumpTimer = 0

	self.inputLeft = false
	self.inputRight = false
	self.inputJump = false

	self.errorOffset = vector(0, 0)
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
    --self.jumpForce = -8100
    --self.jumpTime = 0.15
    self.jumpTimer = 0

    self.hasDashed = false
    self.dashTime = 0.5
    self.dashTimer = 0
    self.dashSpeed = 4000

    self.deadzone = 0.3

    --self.weapon = Pistol:new()
    --self.weapon:attach(self, self.width/2, self.height/2)
end

function Player:keypressed(key, code)
	if (key == "space" or key == "w") then
	    self:jump()
	end
end

function Player:getAccelX()
    if game.joystick then
        local leftXAxis = game.joystick:getGamepadAxis(self.xAxis)
        local leftYAxis = game.joystick:getGamepadAxis(self.yAxis)
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

function Player:input()
	self.acceleration.x = self:getAccelX()

	    --local dashDir = self:getDash()
	    --self.velocity.x = self.velocity.x + 5000 * dashDir
	    --if dashDir ~= 0 then
	    --    self.hasDashed = true
	    --    self.dashTimer = self.dashTime
	    --end

	self.inputJump = false

	if game.joystick then
	    if game.joystick:isGamepadDown("a") then
	        self:jump()
	       	self.inputJump = true
	    end
	end

	if love.keyboard.isDown("space") or love.keyboard.isDown("w") then
	    self:jump()
	    self.inputJump = true
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

function Player:update(dt, world, host)
	--Entity.update(self, dt)
    self.jumpTimer = math.max(0, self.jumpTimer - dt)

    self:move(dt, world)

    -- change facing direction depending on last acceleration
    if self.acceleration.x > 0 then
        self.facing = 1
    elseif self.acceleration.x < 0 then
        self.facing = -1
    end

    --self.dashTimer = math.max(0, self.dashTimer - dt)

    --self.hasDashed = self.dashTimer > 0

    --if math.abs(self.velocity.x) <= self.velocityXTol then
    --    self.velocity.x = 0
    --end

    local errorDist = self.errorOffset:len()
    if errorDist >= 1 then
    	self.errorOffset = self.errorOffset * 0.85
    elseif errorDist < 1 then
    	self.errorOffset = self.errorOffset * 0.95
    end

    if errorDist <= 0.01 then
    	self.errorOffset = vector(0, 0)
    end

    if host then
    	if self.position.y > 5000 then
	        self:reset(world)
	    end
    end
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

	love.graphics.setColor(255, 255, 255)
end


function Player:jump()
    if not self.isJumping and (self.acceleration.y == 0) then
        self.isJumping = true
        self.jumpTimer = self.jumpTime
    end

    if self.isJumping and self.jumpTimer > 0 then
        self.acceleration.y = self.jumpForce
    end
end

-- this function should be called in the user-defined collision code
-- when the entity hits the ground, or must stop jumping immediately
function Player:stopJump()
    self.isJumping = false
    self.acceleration.y = 0
    self.velocity.y = 0
    self.jumpTimer = 0
end

function Player:updatePos(x, y, world)
	self.errorOffset = self.position + self.errorOffset - vector(x, y)

	self.position = vector(x, y)
    world:update(self, x, y)
end