game = {}

inspect = require "lib.inspect"
require "entities.input"

function game:init()
    self.ownPlayerIndex = 0

    self.packetNumber = 0
    self.packetTime = 0 -- a simulated sort of packet number for time comparisons
    self.lastPacketNumber = 0

    self.bufferFrames = 5

    self.unsequencedPackets = 0

    self.packetQueue = {} -- used for jitter buffer

    self.client = socket.Client:new("localhost", 22122, true)
    self.client.timeout = 0 -- 8
    print('--- game ---')
    
    self.client:on("connect", function(data)
        self.client:emit("identify", self.username)
    end)

    self.client:on("packetNumber", function(data)
        self.packetNumber = data
        self.packetTime = data - self.bufferFrames
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
        --table.insert(self.players, connectId, player)  -- changed here to debug
        self.objects:add(index, player)
    end)

    self.client:on("index", function(data)
        self.ownPlayerIndex = data
    end)

    self.client:on("movePlayer", function(data)
        table.insert(self.packetQueue, data)

        local packetNumber = data.packetNum

        if packetNumber > self.packetNumber then
            self.packetNumber = packetNumber
        end
    end)

    self.chatting = false
    self.chatInput = Input:new(0, 0, 400, 100, font[24])
    self.chatInput:centerAround(love.graphics.getWidth()/2, love.graphics.getHeight()/2-150)
    self.chatInput.border = {127, 127, 127}

    self.timer = 0
    self.tick = 1/60
    self.tock = 0

    self.serverTick = 1/30
    self.serverTock = 0

    self.showRealPos = false

    self.readCount = 2

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

    --self.player = self.objects:add(Player:new(1700, 1300))
end

function game:quit()
    -- if client is not disconnected, the server won't remove it until the game closes
    self.client:disconnect()
end

function game:keypressed(key, code)
    if key == 'f1' then
        self.showRealPos = not self.showRealPos
    end

    if key == '-' then
        self.bufferFrames = self.bufferFrames - 1
        self.packetTime = self.packetNumber - self.bufferFrames
    elseif key == '=' then
        self.bufferFrames = self.bufferFrames + 1
        self.packetTime = self.packetNumber - self.bufferFrames
    end


    self.objects:execute("keypressed", key, code)
end

function game:keyreleased(key, code)

end

function game:mousereleased(x, y, button)

end

function game:textinput(text)

end

-- this is for jitter buffering
-- packets are delayed to reduce inconsistent packet receiving
function game:dequeuePackets()
    for i = #self.packetQueue, 1, -1 do
        local data = self.packetQueue[i]

        local player = self.objects.objects[data.index]
        local packetNumber = data.packetNum

        if packetNumber <= self.packetTime then
            if packetNumber < self.lastPacketNumber then
                self.unsequencedPackets = self.unsequencedPackets + 1
            else
                self.lastPacketNumber = packetNumber

                if player then
                    if data.index ~= self.ownPlayerIndex then
                        --player:setTween(data.x, data.y)
                    else
                        --player.position.x = data.x
                        --player.position.y = data.y
                        --player.goalX = data.x
                        --player.goalY = data.y
                    end

                    player:updatePos(data.x, data.y, self.world)
                    player.velocity.x = data.vx --player.prevVelocity.x
                    player.velocity.y = data.vy --player.prevVelocity.y
                    --player.prevVelocity.x = data.vx
                    --player.prevVelocity.y = data.vy
                    player.isJumping = data.isJ
                    player.jumpTimer = data.jT

                    if data.index ~= self.ownPlayerIndex then
                        player.inputLeft = data.inputLeft
                        player.inputRight = data.inputRight
                        player.inputJump = data.inputJump
                    end
                end
            end

            table.remove(self.packetQueue, i)
        end
    end
end

function game:update(dt)
    self:dequeuePackets()

    --
    self.map:update(dt)

    self.objects:execute("update", dt, self.world, false)

    --if self.player.position.y > 5000 then
    --    self.player:reset()
    --end


    self.timer = self.timer + dt
    self.tock = self.tock + dt
    self.serverTock = self.serverTock + dt
    
    -- only do an input update for your own player
    --local clientId = self.client.connectId
    --local player = self.players[self.ownPlayerIndex]  -- changed here to debug
    --if player then
        --player:inputUpdate(self.timer)
        --player:simulateMovement(dt)
        --player:movePrediction(dt)

    --    player:bumpUpdate(dt)
    --end

    --for k, enemy in pairs(self.enemies) do
    --   enemy:update(dt, game.timer, self.players)
        --enemy:movePrediction(dt)
        --enemy:setTween(enemy.position.x, enemy.position.y)
    --end

    local ownPlayer = self.objects.objects[self.ownPlayerIndex]


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

            --if xPos ~= ownPlayer.lastSentPos.x or yPos ~= ownPlayer.lastSentPos.y or xVel ~= ownPlayer.lastSentVel.x or yVel ~= ownPlayer.lastSentVel.y then
                self.client:emit("entityState", {x = xPos, y = yPos, vx = xVel, vy = yVel, isJ = isJumping, jT = jumpTimer, inputLeft = ownPlayer.inputLeft, inputRight = ownPlayer.inputRight, inputJump = ownPlayer.inputJump})

                ownPlayer.lastSentPos.x, ownPlayer.lastSentPos.y = xPos, yPos
                ownPlayer.lastSentVel.x, ownPlayer.lastSentVel.y = yVel, xVel

                ownPlayer.position.x = xPos
                ownPlayer.position.y = yPos
                ownPlayer.velocity.x = xVel
                ownPlayer.velocity.y = yVel
            --end
        end
    end

    if self.serverTock >= self.serverTick then
        self.serverTock = 0

        self.packetTime = self.packetTime + 1
    end
end

function game:draw()
    love.graphics.setColor(255, 255, 255)

    ---
    love.graphics.setColor(255, 255, 255)

    self.camera:attach()

    self.map:setDrawRange(self.camera.x-love.graphics.getWidth()/2, self.camera.y-love.graphics.getHeight()/2, love.graphics.getWidth(), love.graphics.getHeight())
    self.map:draw()

    self.objects:execute("draw")

    self.camera:detach()

    if self.joystick then
        love.graphics.setColor(255, 255, 255, 255)
        love.graphics.print(self.joystick:getGamepadAxis("leftx"), 5, 5)
        love.graphics.print(self.joystick:getGamepadAxis("lefty"), 5, 25)
        love.graphics.print(math.atan2(self.joystick:getGamepadAxis("lefty"), self.joystick:getGamepadAxis("leftx")), 5, 45)

        love.graphics.print(self.joystick:getGamepadAxis("triggerright"), 5, 70)
        --love.graphics.print(tostring(self.player.startPosition), 5, 100)
    else
        --love.graphics.print(self.player.position.y, 5, 5)
        --local enemy = self.enemies:get(1)
        --love.graphics.print(enemy.position.y, 5, 25)
    end
    --

    --[[
    for k, player in pairs(self.players) do
        player:draw(self.showRealPos)
    end

    for k, enemy in pairs(self.enemies) do
        enemy:draw()
    end
    ]]

    love.graphics.setColor(125, 125, 125)

    love.graphics.print('FPS: '..love.timer.getFPS(), 300, 5)

    love.graphics.setFont(font[20])
    love.graphics.print("client : " .. self.username, 5, 5)

    love.graphics.print("You are currently playing with:", 5, 40)

    for i, user in ipairs(self.users) do
        love.graphics.print(i .. ". " .. user, 5, 40+25*i)
    end

    love.graphics.print("You are #"..self.ownPlayerIndex, 5, 500)

    -- print each player's name
    local j = 1
    --for k, player in pairs(self.players) do
    --    love.graphics.print('#'..player.peerIndex, 100, 40+25*j)
    --    j = j + 1
    --end

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
    love.graphics.print('Packet time      : '..self.packetTime, 700, 80)

    local ownPlayer = self.objects.objects[self.ownPlayerIndex]
    if ownPlayer then
        love.graphics.print('Error dist: '..ownPlayer.errorOffset:len(), 700, 130)
    end
    
    love.graphics.print('Buffer frames: '..self.bufferFrames, 700, 170)
end
