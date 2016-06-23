
local Group = class("Group")

function Group:initialize(canAddTwice)
    self.objects = {}
    self.canAddTwice = canAddTwice or false
end

-- Adds an object to the group
-- Two types of function calls:
-- add(object) or
-- add("name", object)
function Group:add(nameOrObject, object)
    local obj = nameOrObject
    if object then
        obj = object
    end
    
    if not self.canAddTwice and self:has(obj) then
        error("Can't add the same object twice. ("..tostring(nameOrObject)..")")
    end

    if object then
        self.objects[nameOrObject] = obj
    else
        table.insert(self.objects, nameOrObject)
    end

    if self.onAdd then
        self.onAdd(obj)
    end

    return obj
end

-- Removes an object from the group
function Group:remove(obj)
    if type(obj) == "string" then
        self.objects[obj] = nil
    else
        for i, v in pairs(self.objects) do
            if v == obj then
                table.remove(self.objects, i)
            end
        end
    end

    if self.onRemove then
        self.onRemove(obj)
    end
end

-- Clears the group
function Group:clear()
    self.objects = {}
end

function Group:get(keyOrIndex)
    return self.objects[keyOrIndex]
end

-- Returns whether the group has an object/value or not
function Group:has(obj)
    if type(obj) == "string" then
        return self.objects[obj] ~= nil
    else
        for i, v in pairs(self.objects) do
            if v == obj then
                return true
            end
        end
    end
    return false
end

-- Runs a given function on all the objects in the class
-- e.g. Group:execute("update", dt)
-- basically turns into object.update(object, dt)
function Group:execute(f, ...)
    for k, object in pairs(self.objects) do
        if object[f] ~= nil then
            object[f](object, ...)
        end
    end
end

-- Standard filter function
-- Returns a Group, not a table
function Group:filter(f)
    local filtered = Group:new()
    for k, object in pairs(self.objects) do
        local result = f(object)
        assert(result == true or result == false)
        if result then
            filtered:add(object)
        end
    end
    return filtered
end

-- local g = Group:new()
-- local player = g:add("player", Group:new())
-- local enemy = g:add("enemy", Group:new())
-- local boss = g:add(Group:new())
-- g:add(Group:new())
-- g:add("boss")

-- assert(g:has("player"))
-- assert(not g:has("boss"))
-- assert(g:has(boss))

-- assert(g:get("player") == player)
-- assert(g:get("enemy") == enemy)
-- assert(g:get("boss") == nil)

-- assert(g:get(1) == boss)

-- g:remove("enemy")

-- assert(not g:has("enemy"))
-- assert(g:get("enemy") == nil)

-- g:remove(boss)

-- assert(not g:has(boss))
-- assert(g:get(boss) == nil)


return Group
