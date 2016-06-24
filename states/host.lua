host = {}

function host:init()
    self.unsequencedPackets = 0
    self.packetNumberRec = {} -- stores latest packet received from each player
    self.packetNumber = 0

    self.timers = {}
    self.timers.userlist = 0

    self.timer = 0
    self.tick = 1/30 -- server sends 30 state packets per second
    self.tock = 0

    self.server = socket.Server:new("*", 22122, 0)
    print('--- server ---')
    print('running on '..self.server.hostname..":"..self.server.port)

    self.peerNames = {}

    self.server:on("connect", function(data, peer)
        self:sendUserlist()
        self:sendAllPlayers(peer)
        self:addPlayer(peer)

        peer:emit("packetNumber", self.packetNumber)
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

        local index = peer.server:index()
        self.peerNames[index] = username
        self:sendUserlist()
        self.packetNumberRec[index] = 0
    end)

    self.server:on("disconnect", function(data, peer)
        local index = peer.server:index()
        self.peerNames[index] = nil
        self.peerNames[index] = "disconnected user"
        self:sendUserlist()

        -- player should also be removed from the Group here
    end)

    self.server:on("playerInput", function(data, peer)
        local index = peer.server:index()
        local player = self.objects.objects[index]

        local packetNumber = data.packetNum
        local receivedPacket = self.packetNumberRec[index]

        if packetNumber < receivedPacket then
            self.unsequencedPackets = self.unsequencedPackets + 1
        else
            self.packetNumberRec[index] = packetNumber

            player.inputLeft = data.inputLeft
            player.inputRight = data.inputRight
            player.inputJump = data.inputJump
        end
    end)

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

function host:addPlayer(peer)
    local index = peer.server:index()
    local player = Player:new(1700, 1300) -- starting location
    player.peerIndex = index

    self.objects:add(index, player)

    peer:emit("index", peer.server:index()) -- tell the client who they are
    self.server:emitToAll("newPlayer", {x = player.position.x, y = player.position.y, color = player.color, index = index})
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
end

function host:sendUserlist()
    local userlist = {}
    for k, name in pairs(self.peerNames) do
        table.insert(userlist, name)
    end
    self.server:emitToAll("userlist", userlist) 
end

function host:update(dt)
    self.map:update(dt)

    self.objects:execute("simulateInput")
    self.objects:execute("update", dt, self.world, true)

    -- calculate the average positon between all players and place the camera there
    local num = #self.objects.objects
    if num == 0 then num = 1 end -- ensure no division by 0
    local pos = vector(0, 0)
    for k, obj in pairs(self.objects.objects) do
        pos = pos + obj.position * (1/num)
    end
    self.camera:lockPosition(pos.x, pos.y)


    self.timer = self.timer + dt
    self.tock = self.tock + dt

    self.server:update(dt)

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

        for k, player in pairs(self.objects.objects) do
            local xPos = math.floor(player.position.x*1000)/1000
            local yPos = math.floor(player.position.y*1000)/1000
            local xVel = math.floor(player.velocity.x*1000)/1000
            local yVel = math.floor(player.velocity.y*1000)/1000
            local isJumping = player.isJumping
            local jumpTimer = player.jumpTimer

            self.server:emitToAll("playerState", {packetNum = self.packetNumber, index = k, x = xPos, y = yPos, vx = xVel, vy = yVel, isJ = isJumping, jT = jumpTimer, inputLeft = player.inputLeft, inputRight = player.inputRight, inputJump = player.inputJump}, "unsequenced")
        
            player.position.x = xPos
            player.position.y = yPos
            player.velocity.x = xVel
            player.velocity.y = yVel
        end

        self.packetNumber = self.packetNumber + 1
    end
end

function host:draw()
    -- draw the map and objects
    love.graphics.setColor(255, 255, 255)

    self.camera:attach()

    self.map:setDrawRange(self.camera.x-love.graphics.getWidth()/2, self.camera.y-love.graphics.getHeight()/2, love.graphics.getWidth(), love.graphics.getHeight())
    self.map:draw()

    -- todo: draw own player in front
    self.objects:execute("draw")

    self.camera:detach() 

    -- draw performance text and network details
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

    love.graphics.print('Out of order packets: '..self.unsequencedPackets, 700, 5)
end
