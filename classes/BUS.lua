BUS = {
    __cpu = nil,
    __maxAddress = nil,
    __nextFreeAddress = 0x00,
    __deviceMapping = {},

    __findDevice = function(self, address)
        if address > self.__maxAddress then error(string.format("Address $%X out of range")) end
        if address >= self.__nextFreeAddress then return nil, nil, nil end
        local foundAddr = 0x00
        local device = nil
        for startAddr, dev in pairs(self.__deviceMapping) do
            if startAddr > address then break end
            foundAddr = startAddr
            device = dev
        end
        return device, address - foundAddr, foundAddr
    end,

    addDevice = function(self, device)
        if not device.__type == "BUSDevice" then error("Trying to attach non-BUSDevice to BUS") end
        local requiredBytes = device.addressableBytes
        if self.__nextFreeAddress + requiredBytes > self.__maxAddress then error(string.format("Address $%X out of range. Too many devices on the BUS?")) end

        self.__deviceMapping[self.__nextFreeAddress] = device:new()

        self.__nextFreeAddress = self.__nextFreeAddress + requiredBytes + 1
    end,

    read = function(self, address, readOnly)
        local device, addressOffset, startAddr = self:__findDevice(address)
        if not device then error(string.format("No device attached to BUS for address $%X", address)) end
        if not device.__readable or not device.read then error("Device is not readable") end
        return device:read(addressOffset)
    end,
    write = function(self, address, value)
        local device, addressOffset, startAddr = self:__findDevice(address)
        if not device then error(string.format("No device attached to BUS for address $%X", address)) end
        if not device.__writable or not device.write then error("Device is not writable") end
        return device:write(addressOffset, value)
    end,

    new = function(self, cpu)
        if not cpu or cpu.__type ~= "CPU" then
            error("No CPU attached on instantiation of BUS")
        end
        o = {
            __cpu = cpu,
            __maxAddress = cpu.maxAddressableAddress
        }

        setmetatable(o, self)
		self.__type = "BUS"
        self.__index = self

        cpu.read = function(self, address, readOnly)
            return o:read(address, readOnly)
        end
        cpu.write = function(self, address, value)
            return o:write(address, value)
        end
        return o
    end
}
