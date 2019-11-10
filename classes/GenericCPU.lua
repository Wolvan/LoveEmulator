local STATUSFLAGS = {
    C = bit.lshift(1, 0), --Carry
    Z = bit.lshift(1, 1), --Zero
    I = bit.lshift(1, 2), --Disable Interrupts
    D = bit.lshift(1, 3), --Decimal Mode
    B = bit.lshift(1, 4), --Break
    U = bit.lshift(1, 5), --Unused
    V = bit.lshift(1, 6), --Overflow
    N = bit.lshift(1, 7)  --Negative
}

local function resolveFlag(flag)
    if type(flag) == "number" then return flag
    else return STATUSFLAGS[flag] end
end

GenericCPU = {
    maxAddressableAddress = 0xFF,

    __A = 0x0,
    __X = 0x0,
    __Y = 0x0,
    __STSREG = 0x0,
    __stkp = 0x10,
    __pc = 0x80,
    __timingControlCycles = 0,

    __opcodes = {
        { opcode = "NOP", cycles = 1, addrsMode = "IMP" },
        { opcode = "ADD", cycles = 1, addrsMode = "IMM" },
        { opcode = "SUB", cycles = 1, addrsMode = "IMM" },
        { opcode = "STA", cycles = 1, addrsMode = "ABS" },
        { opcode = "CLC", cycles = 1, addrsMode = "IMP" },
        { opcode = "STX", cycles = 1, addrsMode = "ABS" },
        { opcode = "STY", cycles = 1, addrsMode = "ABS" },
        { opcode = "LDX", cycles = 1, addrsMode = "ABS" },
        { opcode = "LDY", cycles = 1, addrsMode = "ABS" },
        { opcode = "LDA", cycles = 1, addrsMode = "ABS" },
        { opcode = "BCC", cycles = 1, addrsMode = "IMM" },
        { opcode = "JMP", cycles = 1, addrsMode = "IMM" },
        { opcode = "STA", cycles = 1, addrsMode = "IMM" },
        { opcode = "STX", cycles = 1, addrsMode = "IMM" },
        { opcode = "STY", cycles = 1, addrsMode = "IMM" },
        { opcode = "LDA", cycles = 1, addrsMode = "IMM" },
    },

    __fetch = function(self, addressingMode)
        if addressingMode == "IMP" then return nil
        elseif addressingMode == "ABS" then
            local addr = self:read(self.__pc)
            self.__pc = self.__pc + 1
            return self:read(addr)
        elseif addressingMode == "IMM" then
            local val = self:read(self.__pc)
            self.__pc = self.__pc + 1
            return val
        end
    end,

    GetFlag = function(self, flag)
        if bit.band(self.__STSREG, resolveFlag(flag)) > 0 then
            return 1
        else
            return 0
        end
    end,
    SetFlag = function(self, flag, value)
        if value == 0 or value == false then
            self.__STSREG = bit.band(self.__STSREG, bit.bnot(resolveFlag(flag)))
        else
            self.__STSREG = bit.bor(self.__STSREG, resolveFlag(flag))
        end
    end,

    Clock = function(self)
        if self.__timingControlCycles == 0 then
            local lookup = self.__opcodes[self:read(self.__pc) + 1]
            self.__pc = self.__pc + 1
            self.__timingControlCycles = lookup.cycles
            local fetchedVal = self:__fetch(lookup.addrsMode)
            self[lookup.opcode](self, fetchedVal)
        end
        self.__timingControlCycles = self.__timingControlCycles - 1
    end,

    NOP = function(self, fetchVal)
    end,
    ADD = function(self, fetchVal)
        self.__A = (self.__A + fetchVal)
        if self.__A > 255 then
            self:SetFlag(STATUSFLAGS.C, true)
            self.__A = self.__A % 256
        end
    end,
    SUB = function(self, fetchVal)

    end,
    STA = function(self, fetchVal)
        self:write(fetchVal, self.__A)
    end,
    STX = function(self, fetchVal)
        self:write(fetchVal, self.__X)
    end,
    STY = function(self, fetchVal)
        self:write(fetchVal, self.__Y)
    end,
    LDA = function(self, fetchVal)
        self.__A = fetchVal
    end,
    LDX = function(self, fetchVal)
        self.__X = fetchVal
    end,
    LDY = function(self, fetchVal)
        self.__Y = fetchVal
    end,
    CLC = function(self, fetchVal)
        self:SetFlag(STATUSFLAGS.C, false)
    end,
    BCC = function(self, fetchVal)
        if self:GetFlag(STATUSFLAGS.C) == 1 then
            self.__pc = self.__pc + (fetchVal - 128)
        end
    end,
    JMP = function(self, fetchVal)
        self.__pc = fetchVal
    end,

    new = function(self, o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self
        self.__type = "CPU"
        return o
    end
}
