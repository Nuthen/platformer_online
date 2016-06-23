game = {}

inspect = require "lib.inspect"
require "entities.input"

function game:init()
    self.ownPlayerIndex = 0
    self.packetNumber = 0
    self.unsequencedPackets = 0

    self.client = socket.Client:new("localhost", 22122, true)
    self.client.timeout = 0 -- 8
    print('--- game ---')
    
    self.client:on("connect", function(data)
        self.client:emit("identify", self.username)
    end)

    self.client:on("packetNumber", function(data)
        self.packetNumber = data
    end)

    self.users = {}
    self.client:on("userlist", function(data)
        self.users = data
        print(inspect(data))
    end)

    self.client:on("error", function(data)
        error(data)
    end)

    self.client:on("newPlayer", function(data)
        local index = data.index
        local player = Player:new(data.x, data.y, data.color, index)
        self.objects:add(index, player)
    end)

    self.client:on("index", function(data)
        self.ownPlayerIndex = data
    end)

    self.client:on("movePlayer", function(data)
        local player = self.objects.objects[data.index]
        local packetNumber = data.packetNum

        if packetNumber < self.packetNumber then
            self.unsequencedPackets = self.unsequencedPackets + 1
        else
            self.packetNumber = packetNumber

            if player then
                player:updatePos(data.x, data.y, self.world)
                player.velocity.x = data.vx
                player.velocity.y = data.vy

                player.isJumping = data.isJ
                player.jumpTimer = data.jT

                if data.index ~= self.ownPlayerIndex then
                    player.inputLeft = data.inputLeft
                    player.inputRight = data.inputRight
                    player.inputJump = data.inputJump
                end
            end
        end
    end)

    self.chatting = false
    self.chatInput = Input:new(0, 0, 400, 100, font[24])
    self.chatInput:centerAround(love.graphics.getWidth()/2, love.graphics.getHeight()/2-150)
    self.chatInput.border = {127, 127, 127}

    self.timer = 0
    self.tick = 1/60
    self.tock = 0

    self.showRealPos = false

    self.objects = Group:new()

    self.objects.onAdd = function(obj)
        self.world:add(obj, obj.position.x, obj.position.y, obj.width, obj.height)

        -- dynamically recreate the enemies group based on the objects group
        self.enemies = self.objects:filter(function(obj)
            if obj.class then
                return obj:isInstanceOf(Enemy) or obj.class:isSubclassOf(Enemy)
            end
        end)
    end

    self.objects.onRemove = function(obj)
        self.world:remove(obj)
    end
end

function game:enter(prev, hostname, username)
    self.client.hostname = hostname
    self.client:connect()
    
    self.username = username

    -- initialize camera, load the level
    self.camera = Camera(0, 0)
    self.camera.smoother = function (dx, dy)
        local dt = love.timer.getDelta() * 10
        return dx*dt, dy*dt
    end

    self.world = bump.newWorld()
    self.map = sti.new("assets/levels/1.lua", {"bump"})

    self.map:bump_init(self.world)
end

function game:quit()
    -- if client is not disconnected, the server won't remove it until the game closes
    self.client:disconnect()
end

function game:keypressed(key, code)
    if key == 'f1' then
        self.showRealPos = not self.showRealPos
    end

    local ownPlayer = self.objects.objects[self.ownPlayerIndex]
    ownPlayer:keypressed(key, code)
end

function game:keyreleased(key, code)

end

function game:mousereleased(x, y, button)

end

function game:textinput(text)

end

function game:update(dt)
    --
    self.map:update(dt)

    local ownPlayer = self.objects.objects[self.ownPlayerIndex]

    if ownPlayer then
        ownPlayer:input()
    end

    self.objects:execute("update", dt, self.world, false)

    self.timer = self.timer + dt
    self.tock = self.tock + dt
    

    if ownPlayer then
        self.camera:lockPosition(ownPlayer.position.x, ownPlayer.position.y)
    else
        self.camera:lockPosition(1700, 1300)
    end

    self.client:update(dt)

    if self.tock >= self.tick then
        self.tock = 0

        if ownPlayer then
            local xPos = math.floor(ownPlayer.position.x*1000)/1000
            local yPos = math.floor(ownPlayer.position.y*1000)/1000
            local xVel = math.floor(ownPlayer.velocity.x*1000)/1000
            local yVel = math.floor(ownPlayer.velocity.y*1000)/1000
            local isJumping = ownPlayer.isJumping
            local jumpTimer = ownPlayer.jumpTimer

            -- possible location for optimization: only send an update if it has changed since the last acked packet from the server
            self.client:emit("entityState", {x = xPos, y = yPos, vx = xVel, vy = yVel, isJ = isJumping, jT = jumpTimer, inputLeft = ownPlayer.inputLeft, inputRight = ownPlayer.inputRight, inputJump = ownPlayer.inputJump})


            -- quantize player positions to match simulations
            ownPlayer.position.x = xPos
            ownPlayer.position.y = yPos
            ownPlayer.velocity.x = xVel
            ownPlayer.velocity.y = yVel
        end
    end
end

function game:draw()
    love.graphics.setColor(255, 255, 255)

    -- draw the map and objects
    self.camera:attach()

    self.map:setDrawRange(self.camera.x-love.graphics.getWidth()/2, self.camera.y-love.graphics.getHeight()/2, love.graphics.getWidth(), love.graphics.getHeight())
    self.map:draw()

    self.objects:execute("draw", self.showRealPos)

    self.camera:detach()


    -- draw performance and network text
    love.graphics.setColor(125, 125, 125)

    love.graphics.print('FPS: '..love.timer.getFPS(), 300, 5)

    love.graphics.setFont(font[20])
    love.graphics.print("client : " .. self.username, 5, 5)

    love.graphics.print("You are currently playing with:", 5, 40)

    for i, user in ipairs(self.users) do
        love.graphics.print(i .. ". " .. user, 5, 40+25*i)
    end

    love.graphics.print("You are #"..self.ownPlayerIndex, 5, 500)

    -- print the ping
    local ping = self.client.server:round_trip_time() or -1
    love.graphics.print('Ping: '.. ping .. 'ms', 140, 40+25)

    -- print the amount of data sent
    local sentData = self.client.host:total_sent_data()
    sentDataSec = sentData/self.timer
    sentData = math.floor(sentData/1000) / 1000 -- MB
    sentDataSec = math.floor(sentDataSec/10) / 100 -- KB/s
    love.graphics.print('Sent Data: '.. sentData .. ' MB', 46, 420)
    love.graphics.print('| ' .. sentDataSec .. ' KB/s', 250, 420)

    local packetsSentSec = packetsSent / self.timer
    packetsSentSec = math.floor(packetsSentSec*10000)/10000
    love.graphics.print('Sent Packets: '.. packetsSent, 370, 420)
    love.graphics.print('| ' .. packetsSentSec .. ' packet/s', 594, 420)

    -- print the amount of data received
    local receivedData = self.client.host:total_received_data()
    receivedDataSec = receivedData/self.timer
    receivedData = math.floor(receivedData/1000) / 1000 -- converted to MB and rounded some
    receivedDataSec = math.floor(receivedDataSec/10) / 100 -- should be in KB/s
    love.graphics.print('Received Data: '.. receivedData .. ' MB', 5, 450)
    love.graphics.print('| ' .. receivedDataSec .. ' KB/s', 250, 450)

    local packetsReceivedSec = packetsReceived / self.timer
    packetsReceivedSec = math.floor(packetsReceivedSec*10000)/10000
    love.graphics.print('Received Packets: '.. packetsReceived, 370, 450)
    love.graphics.print('| ' .. packetsReceivedSec .. ' packet/s', 594, 450)

    love.graphics.print('Out of order packets: '..self.unsequencedPackets, 700, 5)

    love.graphics.print('Packet number: '..self.packetNumber, 700, 50)

    local ownPlayer = self.objects.objects[self.ownPlayerIndex]
    if ownPlayer then
        love.graphics.print('Error dist: '..ownPlayer.errorOffset:len(), 700, 130)
    end
end
