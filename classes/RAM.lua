RAM = GenericBUSDevice:new({
    __memory = {},
    __readable = true,
    __writable = true,

    read = function(self, address, readonly)
        if address > self.addressableBytes then error(string.format("Address $%X out of range", address)) end
        return self.__memory[address] or 0x00
    end,
    write = function(self, address, value)
        value = tonumber(value)
        if not value or value < 0 or value > 255 then error("Value must be 1 byte") end
        if address > self.addressableBytes then error(string.format("Address $%X out of range", address)) end
        self.__memory[address] = value
        return true
    end
})
