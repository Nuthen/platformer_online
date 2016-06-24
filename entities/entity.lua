Entity = class("Entity", GameObject)

function Entity:initialize(x, y, w, h)
    GameObject.initialize(self)
    self.position = vector(x, y)
    self.oldVelocity = vector(0, 0)
    self.velocity = vector(0, 0)
    self.acceleration = vector(0, 0)
    self.friction = 15
    self.gravity = vector(0, 200)
    self.speed = 10000
    self.facing = 1
    self.width = w or 20
    self.height = h or 50
    self.color = {255, 255, 255, 255}
    self.center = vector(x + self.width/2, y + self.height/2)

    self.isJumping = false
    self.jumpForce = -8100
    self.jumpTime = 0.15
    self.jumpTimer = 0
end

function Entity:update(dt)
    GameObject.update(self, dt)

    -- change facing direction depending on last acceleration
    if self.acceleration.x > 0 then
        self.facing = 1
    elseif self.acceleration.x < 0 then
        self.facing = -1
    end

    self.center = vector(self.position.x + self.width/2, self.position.y + self.height/2)

    self.jumpTimer = math.max(0, self.jumpTimer - dt)
end

function Entity:jump()
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
function Entity:stopJump()
    self.isJumping = false
    self.acceleration.y = 0
    self.velocity.y = 0
    self.jumpTimer = 0
end

function Entity:draw()
    GameObject.draw(self)
end