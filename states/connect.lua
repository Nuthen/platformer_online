connect = {}

require "entities.input"

function connect:init()
    self.nameInput = Input:new(0, 0, 400, 100, font[24])
    self.nameInput:centerAround(love.graphics.getWidth()/2, love.graphics.getHeight()/2-150)
    self.nameInput.border = {127, 127, 127}

    self.addressInput = Input:new(0, 0, 400, 100, font[24])
    self.addressInput.text = "127.0.0.1"
    self.addressInput:centerAround(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
    self.addressInput.border = {127, 127, 127}
end

function connect:enter(previous, name)
    if name then
        state.switch(game, "127.0.0.1", name)
    end
end

function connect:keypressed(key, code)
    self.addressInput:keypressed(key, code)
    self.nameInput:keypressed(key, code)
end

function connect:keyreleased(key, code)
    if self.addressInput.text ~= "" and key == "return" then
        state.switch(game, self.addressInput.text, self.nameInput.text)
    end
end

function connect:mousereleased(x, y, button)

end

function connect:textinput(text)
    self.addressInput:textinput(text)
    self.nameInput:textinput(text)
end

function connect:update(dt)
    self.addressInput:update(dt)
    self.nameInput:update(dt)
end

function connect:draw()
    love.graphics.setColor(255, 255, 255)
    love.graphics.setFont(fontBold[24])
    
    love.graphics.print("Name", self.nameInput.x, self.nameInput.y-30)
    self.nameInput:draw()
    
    love.graphics.print("IP Address", self.addressInput.x, self.addressInput.y-30)
    self.addressInput:draw()
end
