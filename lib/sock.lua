local sock = {}

require "enet"

sock.Server = class("Server")

function sock.Server:initialize(hostname, port, timeout)
    self.hostname = hostname or "localhost"
    self.port = port or 22122
    self.host = enet.host_create(hostname .. ":" .. port)
    self.timeout = timeout or 100

    if not self.host then
        error("Failed to create the host. Is there another server running on :"..self.port.."?")
    end

    self.logList = {}
    self.triggers = {}
    -- active peer list
    self.peers = {}
    -- similar to active peer list, except this is a list of sock.Client instances
    self.clients = {}
end

function sock.Server:getClient(peer)
    for i, client in pairs(self.clients) do
        if peer == client.server then
            return client
        end
    end
end

function sock.Server:update(dt)
    local event = self.host:service(self.timeout)
    
    if event then
        if event.type == "connect" then
            local eventClient = sock.Client:new(event.peer)
            table.insert(self.peers, event.peer)
            table.insert(self.clients, eventClient)
            self:_activateTriggers("connect", event.data, eventClient)
            self:log(event.type, tostring(event.peer) .. " connected")
         
        elseif event.type == "disconnect" then
            -- remove from the active peer list
            for i, peer in pairs(self.peers) do
                if peer == event.peer then
                    table.remove(self.peers, i)
                end
            end
            local eventClient = self:getClient(event.peer)
            for i, client in pairs(self.clients) do
                if client == eventClient then
                    table.remove(self.clients, i)
                end
            end
            self:_activateTriggers("disconnect", event.data, eventClient)
            self:log(event.type, tostring(event.peer) .. " disconnected")
        
        elseif event.type == "receive" then
            local message = bitser.loads(event.data)
            local eventClient = self:getClient(event.peer)
            self:_activateTriggers(message.name, message.data, eventClient)
            self:log(event.type, message.data)
        end
    end
end

function sock.Server:emitToAll(name, data, flag)
    local message = {
        name = name,
        data = data,
    }
    local serializedMessage = bitser.dumps(message)

    flag = flag or "reliable"

    packetsSent = packetsSent + #self.peers

    self.host:broadcast(serializedMessage, 0, flag)
end

-- Useful for when the client does something locally, but other clients
-- need to be updated at the same time. This way avoids duplicating objects by
-- never sending its own event to itself in the first place.
function sock.Server:emitToAllBut(peer, name, data, flag)
    local message = {
        name = name,
        data = data,
    }
    local serializedMessage = bitser.dumps(message)

    flag = flag or "reliable"

    for i, p in pairs(self.peers) do
        if p ~= peer then
            packetsSent = packetsSent + 1
            p:send(serializedMessage, 0, flag)
        end
    end
end

function sock.Server:on(name, callback)
    if not self.triggers[name] then
        self.triggers[name] = {}
    end

    table.insert(self.triggers[name], callback)

    packetsReceived = packetsReceived + 1

    return callback
end

function sock.Server:_activateTriggers(name, data, client)
    if self.triggers[name] then
        for k, callback in pairs(self.triggers[name]) do
            callback(data, client)
            packetsReceived = packetsReceived + 1
        end
    else
        self:log("warning", "Tried to activate trigger: '" .. name .. "' but it does not exist.")
    end
end

function sock.Server:removeCallbackOn(name, callback)
    if self.triggers[name] then
        for k,v in pairs(self.triggers[name]) do
            if v == callback then
                self.triggers[name][k] = nil            
            end
        end
    end
end

function sock.Server:log(event, data)
    local time = os.date("%X") -- something like 24:59:59
    local line = "[SERVER]["..time.."]".."["..string.upper(event).."] "..tostring(data) 
    table.insert(self.logList, line)
    print(line)
end


sock.Client = class("Client")

function sock.Client:initialize(serverOrHostname, port, deferConnect)
    -- Don't connect to the server right away
    deferConnect = deferConnect or true

    if port ~= nil and serverOrHostname ~= nil then
        self.hostname = serverOrHostname
        self.port = port
        self.host = enet.host_create()
       
        if not deferConnect then
            self:connect()
        end
    else
        self.server = serverOrHostname
        self.connectId = self.server:connect_id()
        assert(self.connectId ~= 0)
    end

    self.timeout = 0
    self.triggers = {}
    self.logList = {}
end

function sock.Client:connect()
    self.server = self.host:connect(self.hostname .. ":" .. self.port)
    self.connectId = self.server:connect_id()
end

function sock.Client:disconnect(code)
    code = code or 0
    self.server:disconnect_later(code)
    if self.host then
        self.host:flush()
    end
end

function sock.Client:update(dt)
    local event = self.host:service(self.timeout)
    
    if event then
        if event.type == "connect" then
            self:_activateTriggers("connect", event.data)
            self:log(event.type, "Connected to " .. tostring(self.server))

        elseif event.type == "receive" then
            local message = bitser.loads(event.data)
            self:_activateTriggers(message.name, message.data)
            self:log(event.type, message.data)

        elseif event.type == "disconnect" then
            self:_activateTriggers("disconnect", event.data)
            self:log(event.type, "Disconnected from " .. tostring(self.server))
        end
    end
end

function sock.Client:emit(name, data, flag)
    local message = {
        name = name,
        data = data,
    }
    local serializedMessage = nil
    
    flag = flag or "reliable"

    -- 'Data' = binary data class in Love
    if type(message.data) == "userdata" then
        serializedMessage = message.data
    else
        serializedMessage = bitser.dumps(message)
    end

    self.server:send(serializedMessage, 0, flag)

    packetsSent = packetsSent + 1
end

function sock.Client:on(name, callback)
    if not self.triggers[name] then
        self.triggers[name] = {}
    end

    table.insert(self.triggers[name], callback)   

    packetsReceived = packetsReceived + 1 

    return callback
end

function sock.Client:_activateTriggers(name, data)
    if self.triggers[name] then
        for k,v in pairs(self.triggers[name]) do
            v(data)
            packetsReceived = packetsReceived + 1
        end
    else
        self:log("warning", "Tried to activate trigger: '" .. name .. "' but it does not exist.")
    end
end

function sock.Client:removeCallbackOn(name, callback)
    if self.triggers[name] then
        for k,v in pairs(self.triggers[name]) do
            if v == callback then
                self.triggers[name][k] = nil            
            end
        end
    end
end

function sock.Client:log(event, data)
    local time = os.date("%X") -- something like 24:59:59
    local line = "[CLIENT]["..time.."]".."["..string.upper(event).."] "..tostring(data) 
    table.insert(self.logList, line)
    print(line)
end

return sock
