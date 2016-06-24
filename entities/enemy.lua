Enemy = class("Enemy", Entity)

function Enemy:initialize(x, y, w, h)
    Entity.initialize(self, x, y, w, h)
    self.friction = 15
    self.gravity = vector(0, 100)
    self.speed = 4000
    self.facing = 1
    self.color = {255, 255, 255, 255}

    self.health = 100

    self.jumpQueryWidth = 50
    self.jumpQueryHeight = self.height

    self.nearestPlayer = nil
    self.nearestPlayerIndex = nil

    self.errorOffset = vector(0, 0)
end

function Enemy:update(dt, world, player)
    Entity.update(self, dt)

    self.inputLeft = false
    self.inputRight = false

    if self.nearestPlayer then
        if self.nearestPlayer.position.x > self.position.x then
            self.acceleration.x = self.speed
        else
            self.acceleration.x = -self.speed
        end
    end

    local filter = function(item)
        return item.properties and item.properties.isGround
    end

    local leftItems = world:queryRect(self.position.x - self.jumpQueryWidth, self.position.y, self.jumpQueryWidth, self.jumpQueryHeight)
    local rightItems = world:queryRect(self.position.x + self.width, self.position.y, self.jumpQueryWidth, self.jumpQueryHeight)

    if self.nearestPlayer then
        if self.nearestPlayer.position.y < self.position.y and (#leftItems > 0 or #rightItems > 0) then
            self:jump()
        end
    end

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
end

function Enemy:move(dt, world)
    -- verlet integration, much more accurate than euler integration for constant acceleration and variable timesteps
    self.acceleration = self.acceleration + self.gravity
    self.oldVelocity = self.velocity
    self.velocity = self.velocity + (self.acceleration - self.friction*self.velocity) * dt
    self.desiredVelocity = (self.oldVelocity + self.velocity) * 0.5 * dt

    local actualX, actualY, collisions = world:move(self, self.position.x+self.desiredVelocity.x, self.position.y+self.desiredVelocity.y, function(item, other) 
        if other.class and other:isInstanceOf(Player) then
            return false
        end

        if other.class and other:isInstanceOf(Enemy) then
            return false
        end

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

function Enemy:draw()
    Entity.draw(self)

    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.position.x + self.errorOffset.x, self.position.y + self.errorOffset.y, self.width, self.height)

    love.graphics.print(self.health, self.position.x + self.errorOffset.x, self.position.y + self.errorOffset.y-20)
end

function Enemy:updatePos(x, y, world)
    self.errorOffset = self.position + self.errorOffset - vector(x, y)

    self.position = vector(x, y)
    world:update(self, x, y)
end