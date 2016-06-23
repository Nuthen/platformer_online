host = {}

function host:init()
    self.ownPlayerIndex = 0

    self.server = socket.Server:new("*", 22122, 0)
    print('--- server ---')
    print('running on '..self.server.hostname..":"..self.server.port)

    self.peerNames = {}

    self.server:on("connect", function(data, peer)
        self:sendUserlist()
        self:sendAllPlayers(peer)
        self:addPlayer(peer)
        --self:sendAllEnemies(peer)
    end)

    self.server:on("identify", function(username, peer)
        print("IDENTIFY -------------")
        self.server:log("identify", tostring(peer) .. " identified as " .. username)

        for i, name in pairs(self.peerNames) do
            if name == username then
                peer:emit("error", "Someone with that username is already connected.")
                peer:disconnect()
                self.server:log("identify", tostring(peer) .. " identified as an already existing username.")
                return
            end
        end

        local connectId = peer.server:index()-- self.server:getClient(peer).connectId
        self.peerNames[connectId] = username
        self:sendUserlist()
    end)

    self.server:on("disconnect", function(data, peer)
        local connectId = peer.server:index() -- self.server:getClient(peer).connectId
        self.peerNames[connectId] = nil
        self.peerNames[connectId] = "disconnected user"
        self:sendUserlist()
    end)

    self.server:on("entityState", function(data, peer)
        local connectId = peer.server:index() -- self.server:getClient(peer).connectId
        local player = self.objects.objects[connectId]

        -- disabled so that server controls the positon of the player, not the client
        --[[
        player.position.x = data.x
        player.position.y = data.y

        player.velocity.x = data.vx
        player.velocity.y = data.vy
        player.isJumping = data.isJ
        player.jumpTimer = data.jT
        ]]

        player.inputLeft = data.inputLeft
        player.inputRight = data.inputRight
        player.inputJump = data.inputJump

        --self.server:log("entityState", "true" and data.inputLeft or "false" ..' '.. "true" and data.inputRight or "false" ..' '.. "true" and data.inputJump or "false" )
    end)

    self.timers = {}
    self.timers.userlist = 0

    self.timer = 0
    self.tick = 1/30 -- server sends 30 state packets per second
    self.tock = 0

    self.enemyTick = 5
    self.enemyTock = 0
    self.enemyDifferenceTick = 0
    self.currentEnemyIndex = 1

    self.enemyMax = 10000

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

    self.packetNumber = 0
end

function host:addPlayer(peer)
    local index = peer.server:index() -- self.server:getClient(peer).connectId
    local player = Player:new(1700, 1300)
    player.peerIndex = index

    --table.insert(self.players, connectId, player) -- changed here to debug
    self.objects:add(index, player)

    self.server:emitToAll("newPlayer", {x = player.position.x, y = player.position.y, color = player.color, index = index}) -- changed here to debug

    peer:emit("index", peer.server:index()) -- changed here to debug
end

function host:sendAllPlayers(peer)
    for k, player in pairs(self.objects.objects) do
        peer:emit("newPlayer", {x = player.position.x, y = player.position.y, color = player.color, index = k})
    end
end

function host:enter()
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

function host:sendUserlist()
    local userlist = {}
    for k, name in pairs(self.peerNames) do
        table.insert(userlist, name)
    end
    self.server:emitToAll("userlist", userlist) 
end

function host:update(dt)
    --
    self.map:update(dt)

    self.objects:execute("update", dt, self.world, true)

    --if self.player.position.y > 5000 then
    --    self.player:reset()
    --end

    local pos = vector(0, 0)
    for k, obj in pairs(self.objects.objects) do
        pos = pos + obj.position * (1/2)
        --self.camera:lockPosition(obj.position.x, obj.position.y)
        
        --break
    end
    --pos = pos / #self.objects

    self.camera:lockPosition(pos.x, pos.y)
    --self.camera:lockPosition(1700, 1300)
    --


    self.timer = self.timer + dt
    self.tock = self.tock + dt
    self.enemyTock = self.enemyTock + dt

    self.server:update(dt)

    --for k, player in pairs(self.players) do
        --player:movePrediction(dt)
    --    player:bumpUpdate(dt)
    --end

    --for k, enemy in pairs(self.enemies) do
    --    enemy:update(dt, self.timer, self.players)
    --end

    if self.tock >= self.tick then
        self.tock = 0

        -- check if the user is still connected
        self.timers.userlist = self.timers.userlist + dt

        if self.timers.userlist > 5 then
            self.timers.userlist = 0

            for k, peer in pairs(self.server.peers) do
                if peer:state() == "disconnected" then
                    self.peerNames[peer] = nil
                end
            end
        end
        --

        for k, player in pairs(self.objects.objects) do
            local xPos = math.floor(player.position.x*1000)/1000
            local yPos = math.floor(player.position.y*1000)/1000
            local xVel = math.floor(player.velocity.x*1000)/1000
            local yVel = math.floor(player.velocity.y*1000)/1000
            local isJumping = player.isJumping
            local jumpTimer = player.jumpTimer

            --if xPos ~= player.lastSentPos.x or yPos ~= player.lastSentPos.y then
                self.server:emitToAll("movePlayer", {packetNum = self.packetNumber, index = k, x = xPos, y = yPos, vx = xVel, vy = yVel, isJ = isJumping, jT = jumpTimer, inputLeft = player.inputLeft, inputRight = player.inputRight, inputJump = player.inputJump}, "unsequenced")
                self.packetNumber = self.packetNumber + 1

                player.lastSentPos.x, player.lastSentPos.y = xPos, yPos
            --end
        end
    end
end

function host:draw()
    ---
    love.graphics.setColor(255, 255, 255)

    self.camera:attach()

    self.map:setDrawRange(self.camera.x-love.graphics.getWidth()/2, self.camera.y-love.graphics.getHeight()/2, love.graphics.getWidth(), love.graphics.getHeight())
    self.map:draw()

    self.objects:execute("draw")

    self.camera:detach() 

    --

    love.graphics.setColor(125, 125, 125)

    love.graphics.setFont(font[16])
    love.graphics.print('FPS: '..love.timer.getFPS(), 5, 5)
    love.graphics.print("Memory usage: " .. collectgarbage("count"), 5, 25)

    love.graphics.print("Connected users:", 5, 40)
    local j = 1
    for i, name in pairs(self.peerNames) do
        love.graphics.print(name, 5, 40+25*j)
        j = j + 1
    end

    for i, peer in ipairs(self.server.peers) do
        local ping = peer:round_trip_time() or -1
        love.graphics.print('Ping: '..ping, 140, 40+25*i)
    end

    -- print the amount of data sent
    local sentData = self.server.host:total_sent_data()
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
    local receivedData = self.server.host:total_received_data()
    receivedDataSec = receivedData/self.timer
    receivedData = math.floor(receivedData/1000) / 1000 -- converted to MB and rounded some
    receivedDataSec = math.floor(receivedDataSec/10) / 100 -- should be in KB/s
    love.graphics.print('Received Data: '.. receivedData .. ' MB', 5, 450)
    love.graphics.print('| ' .. receivedDataSec .. ' KB/s', 250, 450)

    local packetsReceivedSec = packetsReceived / self.timer
    packetsReceivedSec = math.floor(packetsReceivedSec*10000)/10000
    love.graphics.print('Received Packets: '.. packetsReceived, 370, 450)
    love.graphics.print('| ' .. packetsReceivedSec .. ' packet/s', 594, 450)
    
end
