GenericBUSDevice = {
    addressableBytes = 0x01,

    __readable = false,
    __writable = false,

    read = function(self, address, readonly)
        return 0x1
    end,
    write = function(self, address, value)
        value = tonumber(value)
        if not value or value < 0 or value > 255 then error("Value must be 1 byte") end
        if address > self.addressableBytes then error(string.format("Address $%X out of range", address)) end
        return true
    end,

    new = function(self, o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self
        self.__type = "BUSDevice"
        return o
    end
}
