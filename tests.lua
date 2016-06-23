luaunit = require "lib.luaunit"
sock = require "lib.sock"

TestServer = {}

function TestServer:setUp()
    self.server = sock.Server:new("localhost", 22122)
end

function TestServer:testConnection()
    local client = sock.Client:new("localhost", 22122)
    luaunit.assertNotNil(client.server:status())
    luaunit.assertEquals(client.server:status(), "connected")
end

function TestServer:testEmit()
    
end

function TestServer:tearDown()
    
end

os.exit(luaunit.LuaUnit.run())
