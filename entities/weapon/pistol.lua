Pistol = class("Pistol", Weapon)

function Pistol:initialize(x, y)
    Weapon.initialize(self, x, y)

    self.angle = 0
    self.range = 500

    self.readyToFire = false
    self.rateOfFire = 2
    self.damage = 25
    
    self.timer = 0

    self.target = vector(x, y)
end

function Pistol:attach(object, x, y)
    self.attached = true
    self.parent = object 
    self.offset = vector(x or 0, y or 0)
end

function Pistol:unattach()
    self.attached = false
    self.parent = nil
    self.offset = vector(0, 0)
end

function Pistol:aim(angle)
    self.angle = angle
end

function Pistol:aimAt(x, y)
    self.angle = vector(x, y):angleTo()
end

function Pistol:update(dt)
    Weapon.update(self)

    -- attached to a parent object
    if self.attached then
        self.position = self.parent.position + self.offset
    end

    self.target = vector(math.cos(self.angle), math.sin(self.angle)) * self.range

    self.timer = math.max(0, self.timer - dt)
    self.readyToFire = self.timer <= 0
end

function Pistol:shoot()
    if self.readyToFire then
        self.timer = (1 / self.rateOfFire)

        local filter = function(item)
            return true
        end
        local objects, len = game.world:querySegment(self.position.x, self.position.y, self.position.x + self.target.x, self.position.y + self.target.y, filter)

        for i, object in pairs(objects) do
            if object.properties and object.properties.isGround then
                break
            end
            if object.health then
                object.health = object.health - self.damage
            end
        end
    end
end

function Pistol:draw()
    Weapon.draw(self)

    love.graphics.line(self.position.x, self.position.y, self.position.x + self.target.x, self.position.y + self.target.y)
end
