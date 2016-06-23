Input = class("Input")

function Input:initialize(x, y, w, h, fontType, align)
    self.text = ""
    self.font = fontType or font[32]
    self.x = x
    self.y = y
    self.width = w or self.font:getWidth(text)
    self.height = h or self.font:getHeight(text)
    self.align = align or "left"

    self.selected = false

    self.hovering = {33, 33, 33, 127}
    self.active = {0, 0, 0, 127}
    self.bg = {0, 0, 0, 64}
    self.fg = {255, 255, 255, 255}
    self.border = nil
    self.alpha = 0

    self.caretTimer = 0
    self.textLimit = math.huge
    self.singleWord = false
end

function Input:update(dt)
    self.caretTimer = self.caretTimer + dt

    if self.caretTimer >= 1 then self.caretTimer = 0 end

    if self:hover() and love.mouse.isDown(1) then
        self.selected = true
    elseif not self:hover() and love.mouse.isDown(1) then
        self.selected = false
    end
end

function Input:textinput(text)
    if self.selected and self.text:len() ~= self.textLimit then
        -- if input can only be a single word, remove spaces
        if self.singleWord then
            text = text:gsub("%s+", "")
        end

        self.text = self.text .. text
    end
end

function Input:keypressed(key, isrepeat)
    if self.selected then
        if key == "backspace" then
            love.keyboard.setKeyRepeat(true)
            self.text = string.sub(self.text, 1, -2)
        elseif key == "return" then
            self.selected = false
        end
    end
end

function Input:draw()
    local oldColor = {love.graphics.getColor()}

    if self:hover() and not self.selected then
        love.graphics.setColor(self.hovering)
    elseif self.selected then
        love.graphics.setColor(self.active)
    else
        love.graphics.setColor(self.bg)
    end

    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    local x = self.x 
    local y = self.y + self.height/2 - self.font:getHeight(self.text)/2
    love.graphics.setFont(self.font)

    if self.border then
        love.graphics.setColor(self.border)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    end

    love.graphics.setColor(self.fg)

    if self.align == "left" then
        x = x + 15
        love.graphics.print(self.text, x, y)
    elseif self.align == "center" then
        x = x + (self.width/2 - self.font:getWidth(self.text)/2) - 15
        love.graphics.print(self.text, x, y)
    elseif self.align == "right" then
        x = x + (self.width - self.font:getWidth(self.text)) - 15
        love.graphics.print(self.text, x, y)
    end

    -- blinking caret
    if self.selected then
        love.graphics.setLineWidth(3)

        if self.caretTimer > 0.5 then
            self.alpha = 255
        else
            self.alpha = 0
        end

        love.graphics.setColor(255, 255, 255, self.alpha)
        love.graphics.line(
            x + self.font:getWidth(self.text)+2, y+5,
            x + self.font:getWidth(self.text)+2, y+self.font:getHeight(self.text)-5
        )
    end

    love.graphics.setColor(oldColor)
end

function Input:setFont(font)
    self.font = font
    self.width =  self.font:getWidth(self.text)
    self.height = self.font:getHeight(self.text)
    return self
end

function Input:centerAround(x, y)
    self.x = x - self.width/2
    self.y = y - self.height/2
    return self
end

function Input:hover()
    local xBound = love.mouse.getX() > self.x and love.mouse.getX() < self.x+self.width
    local yBound = love.mouse.getY() > self.y and love.mouse.getY() < self.y+self.height

    return xBound and yBound
end

function Input:onClicked()

end
