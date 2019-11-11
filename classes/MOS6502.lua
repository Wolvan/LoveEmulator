MOS6502 = GenericCPU:new({
    maxAddressableAddress = 0xFFFF,

    --[[
        Addressing Modes
        The 6502 features 13 Addressing modes mutating the opcode
    ]]
    -- Implied Addressing
    IMP = function(self)
        return self.__A, 0
    end,
    -- Immediate Address
    IMM = function(self)
        local addrAbs = self.__pc
        self.__pc = self.__pc + 1
        return addrAbs, 0
    end,
    -- Zero Page Addressing
    ZP0 = function(self)
        local addrAbs = bit.band(self:read(self.__pc), 0x00FF)
        self.__pc = self.__pc + 1
        return addrAbs, 0
    end,
    -- Indexed Zero Page X Addressing
    ZPX = function(self)
        local addrAbs = bit.band(self:read(self.__pc) + self.__X, 0x00FF)
        self.__pc = self.__pc + 1
        return addrAbs, 0
    end,
    -- Indexed Zero Page Y Addressing
    ZPY = function(self)
        local addrAbs = bit.band(self:read(self.__pc) + self.__Y, 0x00FF)
        self.__pc = self.__pc + 1
        return addrAbs, 0
    end,
    -- Relative Addressing
    REL = function(self)
        local addrRel = bit.band(0x00FF, self:read(self.__pc))
        self.__pc = self.__pc + 1
        if bit.band(addrRel, 0x80) then
            addrRel = -128 + addrRel - 128
        end
        return addrRel, 0
    end,
    -- Absolute Addressing
    ABS = function(self)
        local lo = self:read(self.__pc)
        self.__pc = self.__pc + 1
        local hi = self:read(self.__pc)
        self.__pc = self.__pc + 1

        local addrAbs = bit.bor(bit.lshift(hi, 8), lo)
        return addrAbs, 0
    end,
    -- Indexed Absolute X Addressing
    ABX = function(self)
        local lo = self:read(self.__pc)
        self.__pc = self.__pc + 1
        local hi = self:read(self.__pc)
        self.__pc = self.__pc + 1

        local addrAbs = bit.bor(bit.lshift(hi, 8), lo)

        addrAbs = addrAbs + self.__X

        if (bit.band(addrAbs, 0xFF00) ~= (bit.lshift(hi, 8))) then
            return addrAbs, 1
        else
            return addrAbs, 0
        end
    end,
    -- Indexed Absolute Y Addressing
    ABY = function(self)
        local lo = self:read(self.__pc)
        self.__pc = self.__pc + 1
        local hi = self:read(self.__pc)
        self.__pc = self.__pc + 1

        local addrAbs = bit.bor(bit.lshift(hi, 8), lo)

        addrAbs = addrAbs + self.__Y

        if (bit.band(addrAbs, 0xFF00) ~= (bit.lshift(hi, 8))) then
            return addrAbs, 1
        else
            return addrAbs, 0
        end
    end,
    -- Absolute Indirect
    IND = function(self)
        local ptr_lo = self:read(self.__pc)
        self.__pc = self.__pc + 1
        local ptr_hi = self:read(self.__pc)
        self.__pc = self.__pc + 1

        local ptr = bit.bor(bit.lshift(ptr_hi, 8), ptr_lo)
        local addrAbs = 0x0000
        if ptr_lo == 0x00FF then
            addrAbs = bit.bor(bit.lshift(self:read(bit.band(ptr, 0xFF00)), 8), self:read(ptr + 0))
        else
            addrAbs = bit.bor(bit.lshift(self:read(ptr + 1), 8), self:read(ptr + 0))
        end

        return addrAbs, 0
    end,
    -- Indexed Indirect Addressing
    IZX = function(self)
        local temp = self:read(self.__pc)
        self.__pc = self.__pc + 1

        local lo = self:read(bit.band(temp + self.__X, 0x00FF))
        local hi = self:read(bit.band(temp + self.__X + 1), 0x00FF)

        local addrAbs = bit.bor(bit.lshift(hi, 8), lo)

        return addrAbs, 0
    end,
    -- Indirect Indexed Addressing
    IZY = function(self)
        local t = self:read(self.__pc)
        self.__pc = self.__pc + 1

        local lo = self:read(bit.band(t, 0x00FF))
        local hi = self:read(bit.band(t + 1, 0x00FF))

        local addrAbs = bit.bor(bit.lshift(hi, 8), lo)
        addrAbs = addrAbs + self.__Y

        if bit.band(addrAbs, 0xFF00) ~= bit.lshift(hi, 8) then
            return addrAbs, 1
        else
            return addrAbs, 0
        end
    end,

    --[[
        Opcodes
        The 6502 features 56 legal opcodes and 256 opcodes in total.
        The legal opcodes are implemented, the illegal ones caught in
        a special opcode function.
    ]]
    ADC = function(self, fetched)
        local tmp = self.__A + fetched + self:GetFlag("C")
        self:SetFlag("C", tmp > 255)
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0)
        self:SetFlag("N", bit.band(tmp, 0x80))
        self:SetFlag("V", bit.band(bit.band(bit.bxor(self.__A, tmp), bit.bnot(bit.bxor(self.__A, fetched))), 0x0080))
        self.__A = bit.band(tmp, 0x00FF)
        return 1
    end,
    AND = function(self, fetched)
        self.__A = bit.band(self.__A, fetched)
        self:SetFlag("Z", self.__A == 0x00)
        self:SetFlag("N", bit.band(self.__A, 0x80))
        return 1
    end,
    ASL = function(self, fetched, addrMode, address)
        local tmp = bit.lshift(fetched, 1)
        self:SetFlag("C", bit.band(tmp, 0xFF00) > 0)
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(tmp, 0x80))
        if addrMode == "IMP" then
            self.__A = bit.band(tmp, 0x00FF)
        else
            self:write(address, bit.band(tmp, 0x00FF))
        end
        return 0
    end,

    BCC = function(self, fetched)
        if self:GetFlag("C") == 0 then
            self.__timingControlCycles = self.__timingControlCycles + 1
            local addrAbs = self.__pc + fetched
            if bit.band(addrAbs, 0xFF00) ~= bit.band(self.__pc, 0xFF00) then
                self.__timingControlCycles = self.__timingControlCycles + 1
            end
            self.__pc = addrAbs
        end
        return 0
    end,
    BCS = function(self, fetched)
        if self:GetFlag("C") == 1 then
            self.__timingControlCycles = self.__timingControlCycles + 1
            local addrAbs = self.__pc + fetched
            if bit.band(addrAbs, 0xFF00) ~= bit.band(self.__pc, 0xFF00) then
                self.__timingControlCycles = self.__timingControlCycles + 1
            end
            self.__pc = addrAbs
        end
        return 0
    end,
    BEQ = function(self, fetched)
        if self:GetFlag("Z") == 1 then
            self.__timingControlCycles = self.__timingControlCycles + 1
            local addrAbs = self.__pc + fetched
            if bit.band(addrAbs, 0xFF00) ~= bit.band(self.__pc, 0xFF00) then
                self.__timingControlCycles = self.__timingControlCycles + 1
            end
            self.__pc = addrAbs
        end
        return 0
    end,
    BIT = function(self, fetched)
        local tmp = bit.band(self.__A, fetched)
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(fetched, bit.lshift(1, 7)))
        self:SetFlag("V", bit.band(fetched, bit.lshift(1, 6)))
        return 0
    end,
    BMI = function(self, fetched)
        if self:GetFlag("N") == 1 then
            self.__timingControlCycles = self.__timingControlCycles + 1
            local addrAbs = self.__pc + fetched
            if bit.band(addrAbs, 0xFF00) ~= bit.band(self.__pc, 0xFF00) then
                self.__timingControlCycles = self.__timingControlCycles + 1
            end
            self.__pc = addrAbs
        end
        return 0
    end,
    BNE = function(self, fetched)
        if self:GetFlag("Z") == 0 then
            self.__timingControlCycles = self.__timingControlCycles + 1
            local addrAbs = self.__pc + fetched
            if bit.band(addrAbs, 0xFF00) ~= bit.band(self.__pc, 0xFF00) then
                self.__timingControlCycles = self.__timingControlCycles + 1
            end
            self.__pc = addrAbs
        end
        return 0
    end,
    BPL = function(self, fetched)
        if self:GetFlag("N") == 0 then
            self.__timingControlCycles = self.__timingControlCycles + 1
            local addrAbs = self.__pc + fetched
            if bit.band(addrAbs, 0xFF00) ~= bit.band(self.__pc, 0xFF00) then
                self.__timingControlCycles = self.__timingControlCycles + 1
            end
            self.__pc = addrAbs
        end
        return 0
    end,
    BRK = function(self)
        self.__pc = self.__pc + 1

        self:SetFlag("I", 1)
        self:write(0x0100 + self.__stkp, bit.band(bit.rshift(self.__pc, 8), 0x00FF))
        self.__stkp = self.__stkp - 1
        self:write(0x0100 + self.__stkp, bit.band(self.__pc, 0x00FF))
        self.__stkp = self.__stkp - 1

        self:SetFlag("B", 1)
        self:write(0x0100 + self.__stkp, self.__STSREG)
        self.__stkp = self.__stkp - 1
        self:SetFlag("B", 0)

        self.__pc = bit.bor(self:read(0xFFFE), bit.lshift(self:read(0xFFFF), 8))
        return 0
    end,
    BVC = function(self, fetched)
        if self:GetFlag("V") == 0 then
            self.__timingControlCycles = self.__timingControlCycles + 1
            local addrAbs = self.__pc + fetched
            if bit.band(addrAbs, 0xFF00) ~= bit.band(self.__pc, 0xFF00) then
                self.__timingControlCycles = self.__timingControlCycles + 1
            end
            self.__pc = addrAbs
        end
        return 0
    end,
    BVS = function(self, fetched)
        if self:GetFlag("V") == 1 then
            self.__timingControlCycles = self.__timingControlCycles + 1
            local addrAbs = self.__pc + fetched
            if bit.band(addrAbs, 0xFF00) ~= bit.band(self.__pc, 0xFF00) then
                self.__timingControlCycles = self.__timingControlCycles + 1
            end
            self.__pc = addrAbs
        end
        return 0
    end,

    CLC = function(self)
        self:SetFlag("C", false)
        return 0
    end,
    CLD = function(self)
        self:SetFlag("D", false)
        return 0
    end,
    CLI = function(self)
        self:SetFlag("I", false)
        return 0
    end,
    CLV = function(self)
        self:SetFlag("V", false)
        return 0
    end,
    CMP = function(self, fetched)
        local tmp = self.__A - fetched
        self:SetFlag("C", self.__A >= fetched)
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(tmp, 0x0080))
        return 1
    end,
    CPX = function(self)
        local tmp = self.__X - fetched
        self:SetFlag("C", self.__X >= fetched)
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(tmp, 0x0080))
        return 1
    end,
    CPY = function(self)
        local tmp = self.__Y - fetched
        self:SetFlag("C", self.__Y >= fetched)
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(tmp, 0x0080))
        return 1
    end,

    DEC = function(self, fetched, _, address)
        local temp = fetched - 1
        self:write(address, bit.band(temp, 0x00FF))
        self:SetFlag("Z", bit.band(temp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(temp, 0x0080))
        return 0
    end,
    DEX = function(self)
        self.__X = bit.band(self.__X - 1, 0x00FF)
        self:SetFlag("Z", self.__X == 0x00)
        self:SetFlag("N", bit.band(self.__X, 0x80))
        return 0
    end,
    DEY = function(self)
        self.__Y = bit.band(self.__Y - 1, 0x00FF)
        self:SetFlag("Z", self.__Y == 0x00)
        self:SetFlag("N", bit.band(self.__Y, 0x80))
        return 0
    end,

    EOR = function(self, fetched)
        self.__A = bit.bxor(self.__A, fetched)
        self:SetFlag("Z", self.__A == 0x00)
        self:SetFlag("N", bit.band(self.__A, 0x80))
        return 1
    end,

    INC = function(self, fetched, _, address)
        local temp = fetched + 1
        self:write(address, bit.band(temp, 0x00FF))
        self:SetFlag("Z", bit.band(temp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(temp, 0x0080))
        return 0
    end,
    INX = function(self)
        self.__X = bit.band(self.__X + 1, 0x00FF)
        self:SetFlag("Z", self.__X == 0x00)
        self:SetFlag("N", bit.band(self.__X, 0x80))
        return 0
    end,
    INY = function(self)
        self.__Y = bit.band(self.__Y + 1, 0x00FF)
        self:SetFlag("Z", self.__Y == 0x00)
        self:SetFlag("N", bit.band(self.__Y, 0x80))
        return 0
    end,

    JMP = function(self, _, __, address)
        self.__pc = address
        return 0
    end,
    JSR = function(self, _, __, address)
        self.__pc = self.__pc - 1
        self:write(0x0100 + self.__stkp, bit.band(bit.rshift(self.__pc, 8), 0x00FF))
        self.__stkp = self.__stkp - 1
        self:write(0x0100 + self.__stkp, bit.band(self.__pc, 0x00FF))
        self.__stkp = self.__stkp - 1

        self.__pc = address
        return 0
    end,

    LDA = function(self, fetched)
        self.__A = fetched
        self:SetFlag("Z", self.__A == 0x00)
        self:SetFlag("N", bit.band(self.__A, 0x80))
        return 1
    end,
    LDX = function(self, fetched)
        self.__X = fetched
        self:SetFlag("Z", self.__X == 0x00)
        self:SetFlag("N", bit.band(self.__X, 0x80))
        return 1
    end,
    LDY = function(self, fetched)
        self.__Y = fetched
        self:SetFlag("Z", self.__Y == 0x00)
        self:SetFlag("N", bit.band(self.__Y, 0x80))
        return 1
    end,
    LSR = function(self, fetched, addrMode, address)
        local tmp = bit.rshift(fetched, 1)
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(tmp, 0x80))
        if addrMode == "IMP" then
            self.__A = bit.band(tmp, 0x00FF)
        else
            self:write(address, bit.band(tmp, 0x00FF))
        end
        return 0
    end,

    NOP = function(self, _, __, ___, opcode)
        if  opcode == 0x1C or
            opcode == 0x3C or
            opcode == 0x5C or
            opcode == 0x7C or
            opcode == 0xDC or
            opcode == 0xFC
        then
            return 1
        else
            return 0
        end
    end,

    ORA = function(self, fetched)
        self.__A = bit.bor(self.__A, fetched)
        self:SetFlag("Z", self.__A == 0x00)
        self:SetFlag("N", bit.band(self.__A, 0x80))
        return 1
    end,

    PHA = function(self)
        self:write(0x0100 + self.__stkp, self.__A)
        self.__stkp = self.__stkp - 1
        return 0
    end,
    PHP = function(self)
        self:write(0x0100 + self.__stkp, bit.bor(self.__STSREG, bit.lshift(1, 4), bit.lshift(1, 5))) -- B, U
        self:SetFlag("B", 0)
        self:SetFlag("U", 0)
        self.__stkp = self.__stkp - 1
        return 0
    end,
    PLA = function(self)
        self.__stkp = self.__stkp + 1
        self.__A = self:read(0x0100 + self.__stkp)
        self:SetFlag("Z", self.__A == 0x00)
        self.SetFlag("N", bit.band(self.__A, 0x80))
        return 0
    end,
    PLP = function(self)
        self.__stkp = self.__stkp + 1
        self.__STSREG = self:read(0x0100 + self.__stkp)
        self:SetFlag("U", 1)
        return 0
    end,

    ROL = function(self, fetched, addrMode, address)
        local tmp = bit.bor(bit.lshift(fetched, 1), self:GetFlag("C"))
        self:SetFlag("C", bit.band(tmp, 0xFF00))
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(tmp, 0x0080))

        if addrMode == "IMP" then
            self.__A = bit.band(tmp, 0x00FF)
        else
            self:write(address, bit.band(tmp, 0x00FF))
        end
        return 0
    end,
    ROR = function(self, fetched, addrMode, address)
        local tmp = bit.bor(bit.lshift(self:GetFlag("C"), 7), bit.rshift(fetched, 1))
        self:SetFlag("C", bit.band(fetched, 0x01))
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0x00)
        self:SetFlag("N", bit.band(tmp, 0x0080))

        if addrMode == "IMP" then
            self.__A = bit.band(tmp, 0x00FF)
        else
            self:write(address, bit.band(tmp, 0x00FF))
        end
        return 0
    end,
    RTI = function(self)
        self.__stkp = self.__stkp + 1
        local status = self:read(0x0100 + self.__stkp)
        status = bit.band(status, bit.bnot(bit.lshift(1, 4))) -- ~B
        status = bit.band(status, bit.bnot(bit.lshift(1, 5))) -- ~U

        self.__stkp = self.__stkp + 1
        self.__pc = self:read(0x0100 + self.__stkp)
        self.__stkp = self.__stkp + 1
        self.__pc = bit.bor(self.__pc, bit.lshift(self:read(0x0100 + self.__stkp), 8))
        return 0
    end,
    RTS = function(self)
        self.__stkp = self.__stkp + 1
        self.__pc = self:read(0x0100 + self.__stkp)
        self.__stkp = self.__stkp + 1
        self.__pc = bit.bor(self.__pc, bit.lshift(self:read(0x0100 + self.__stkp), 8))

        self.__pc = self.__pc + 1
        return 0
    end,

    SBC = function(self, fetched)
        fetched = bit.bxor(fetched, 0x00FF)
        local tmp = self.__A + fetched + self:GetFlag("C")
        self:SetFlag("C", tmp > 255)
        self:SetFlag("Z", bit.band(tmp, 0x00FF) == 0)
        self:SetFlag("N", bit.band(tmp, 0x80))
        self:SetFlag("V", bit.band(bit.band(bit.bxor(self.__A, tmp), bit.bnot(bit.bxor(self.__A, fetched))), 0x0080))
        self.__A = bit.band(tmp, 0x00FF)
        return 1
    end,
    SEC = function(self)
        self:SetFlag("C", true)
        return 0
    end,
    SED = function(self)
        self:SetFlag("D", true)
        return 0
    end,
    SEI = function(self)
        self:SetFlag("I", true)
        return 0
    end,
    STA = function(self, _, __, address)
        self:write(address, self.__A)
        return 0
    end,
    STX = function(self, _, __, address)
        self:write(address, self.__X)
        return 0
    end,
    STY = function(self, _, __, address)
        self:write(address, self.__Y)
        return 0
    end,

    TAX = function(self)
        self.__X = self.__A
        self:SetFlag("Z", self.__X == 0x00)
        self:SetFlag("N", bit.band(self.__X, 0x80))
        return 0
    end,
    TAY = function(self)
        self.__Y = self.__A
        self:SetFlag("Z", self.__Y == 0x00)
        self:SetFlag("N", bit.band(self.__Y, 0x80))
        return 0
    end,
    TSX = function(self)
        self.__X = self.__stkp
        self:SetFlag("Z", self.__X == 0x00)
        self:SetFlag("N", bit.band(self.__X, 0x80))
        return 0
    end,
    TXA = function(self)
        self.__A = self.__X
        self:SetFlag("Z", self.__A == 0x00)
        self:SetFlag("N", bit.band(self.__A, 0x80))
        return 0
    end,
    TXS = function(self)
        self.__stkp = self.__X
        return 0
    end,
    TYA = function(self)
        self.__A = self.__Y
        self:SetFlag("Z", self.__A == 0x00)
        self:SetFlag("N", bit.band(self.__A, 0x80))
        return 0
    end,

    XXX = function(self)
        return 0
    end,

    __opcodes = {
		{ mnemonic = "BRK", opcode = "BRK", addrMode = "IMM", cycles = 7 },{ mnemonic = "ORA", opcode = "ORA", addrMode = "IZX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 3 },{ mnemonic = "ORA", opcode = "ORA", addrMode = "ZP0", cycles = 3 },{ mnemonic = "ASL", opcode = "ASL", addrMode = "ZP0", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "PHP", opcode = "PHP", addrMode = "IMP", cycles = 3 },{ mnemonic = "ORA", opcode = "ORA", addrMode = "IMM", cycles = 2 },{ mnemonic = "ASL", opcode = "ASL", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "ORA", opcode = "ORA", addrMode = "ABS", cycles = 4 },{ mnemonic = "ASL", opcode = "ASL", addrMode = "ABS", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },
		{ mnemonic = "BPL", opcode = "BPL", addrMode = "REL", cycles = 2 },{ mnemonic = "ORA", opcode = "ORA", addrMode = "IZY", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "ORA", opcode = "ORA", addrMode = "ZPX", cycles = 4 },{ mnemonic = "ASL", opcode = "ASL", addrMode = "ZPX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "CLC", opcode = "CLC", addrMode = "IMP", cycles = 2 },{ mnemonic = "ORA", opcode = "ORA", addrMode = "ABY", cycles = 4 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "ORA", opcode = "ORA", addrMode = "ABX", cycles = 4 },{ mnemonic = "ASL", opcode = "ASL", addrMode = "ABX", cycles = 7 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },
		{ mnemonic = "JSR", opcode = "JSR", addrMode = "ABS", cycles = 6 },{ mnemonic = "AND", opcode = "AND", addrMode = "IZX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "BIT", opcode = "BIT", addrMode = "ZP0", cycles = 3 },{ mnemonic = "AND", opcode = "AND", addrMode = "ZP0", cycles = 3 },{ mnemonic = "ROL", opcode = "ROL", addrMode = "ZP0", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "PLP", opcode = "PLP", addrMode = "IMP", cycles = 4 },{ mnemonic = "AND", opcode = "AND", addrMode = "IMM", cycles = 2 },{ mnemonic = "ROL", opcode = "ROL", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "BIT", opcode = "BIT", addrMode = "ABS", cycles = 4 },{ mnemonic = "AND", opcode = "AND", addrMode = "ABS", cycles = 4 },{ mnemonic = "ROL", opcode = "ROL", addrMode = "ABS", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },
		{ mnemonic = "BMI", opcode = "BMI", addrMode = "REL", cycles = 2 },{ mnemonic = "AND", opcode = "AND", addrMode = "IZY", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "AND", opcode = "AND", addrMode = "ZPX", cycles = 4 },{ mnemonic = "ROL", opcode = "ROL", addrMode = "ZPX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "SEC", opcode = "SEC", addrMode = "IMP", cycles = 2 },{ mnemonic = "AND", opcode = "AND", addrMode = "ABY", cycles = 4 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "AND", opcode = "AND", addrMode = "ABX", cycles = 4 },{ mnemonic = "ROL", opcode = "ROL", addrMode = "ABX", cycles = 7 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },
		{ mnemonic = "RTI", opcode = "RTI", addrMode = "IMP", cycles = 6 },{ mnemonic = "EOR", opcode = "EOR", addrMode = "IZX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 3 },{ mnemonic = "EOR", opcode = "EOR", addrMode = "ZP0", cycles = 3 },{ mnemonic = "LSR", opcode = "LSR", addrMode = "ZP0", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "PHA", opcode = "PHA", addrMode = "IMP", cycles = 3 },{ mnemonic = "EOR", opcode = "EOR", addrMode = "IMM", cycles = 2 },{ mnemonic = "LSR", opcode = "LSR", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "JMP", opcode = "JMP", addrMode = "ABS", cycles = 3 },{ mnemonic = "EOR", opcode = "EOR", addrMode = "ABS", cycles = 4 },{ mnemonic = "LSR", opcode = "LSR", addrMode = "ABS", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },
		{ mnemonic = "BVC", opcode = "BVC", addrMode = "REL", cycles = 2 },{ mnemonic = "EOR", opcode = "EOR", addrMode = "IZY", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "EOR", opcode = "EOR", addrMode = "ZPX", cycles = 4 },{ mnemonic = "LSR", opcode = "LSR", addrMode = "ZPX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "CLI", opcode = "CLI", addrMode = "IMP", cycles = 2 },{ mnemonic = "EOR", opcode = "EOR", addrMode = "ABY", cycles = 4 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "EOR", opcode = "EOR", addrMode = "ABX", cycles = 4 },{ mnemonic = "LSR", opcode = "LSR", addrMode = "ABX", cycles = 7 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },
		{ mnemonic = "RTS", opcode = "RTS", addrMode = "IMP", cycles = 6 },{ mnemonic = "ADC", opcode = "ADC", addrMode = "IZX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 3 },{ mnemonic = "ADC", opcode = "ADC", addrMode = "ZP0", cycles = 3 },{ mnemonic = "ROR", opcode = "ROR", addrMode = "ZP0", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "PLA", opcode = "PLA", addrMode = "IMP", cycles = 4 },{ mnemonic = "ADC", opcode = "ADC", addrMode = "IMM", cycles = 2 },{ mnemonic = "ROR", opcode = "ROR", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "JMP", opcode = "JMP", addrMode = "IND", cycles = 5 },{ mnemonic = "ADC", opcode = "ADC", addrMode = "ABS", cycles = 4 },{ mnemonic = "ROR", opcode = "ROR", addrMode = "ABS", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },
		{ mnemonic = "BVS", opcode = "BVS", addrMode = "REL", cycles = 2 },{ mnemonic = "ADC", opcode = "ADC", addrMode = "IZY", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "ADC", opcode = "ADC", addrMode = "ZPX", cycles = 4 },{ mnemonic = "ROR", opcode = "ROR", addrMode = "ZPX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "SEI", opcode = "SEI", addrMode = "IMP", cycles = 2 },{ mnemonic = "ADC", opcode = "ADC", addrMode = "ABY", cycles = 4 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "ADC", opcode = "ADC", addrMode = "ABX", cycles = 4 },{ mnemonic = "ROR", opcode = "ROR", addrMode = "ABX", cycles = 7 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },
		{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "STA", opcode = "STA", addrMode = "IZX", cycles = 6 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "STY", opcode = "STY", addrMode = "ZP0", cycles = 3 },{ mnemonic = "STA", opcode = "STA", addrMode = "ZP0", cycles = 3 },{ mnemonic = "STX", opcode = "STX", addrMode = "ZP0", cycles = 3 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 3 },{ mnemonic = "DEY", opcode = "DEY", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "TXA", opcode = "TXA", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "STY", opcode = "STY", addrMode = "ABS", cycles = 4 },{ mnemonic = "STA", opcode = "STA", addrMode = "ABS", cycles = 4 },{ mnemonic = "STX", opcode = "STX", addrMode = "ABS", cycles = 4 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 4 },
		{ mnemonic = "BCC", opcode = "BCC", addrMode = "REL", cycles = 2 },{ mnemonic = "STA", opcode = "STA", addrMode = "IZY", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "STY", opcode = "STY", addrMode = "ZPX", cycles = 4 },{ mnemonic = "STA", opcode = "STA", addrMode = "ZPX", cycles = 4 },{ mnemonic = "STX", opcode = "STX", addrMode = "ZPY", cycles = 4 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 4 },{ mnemonic = "TYA", opcode = "TYA", addrMode = "IMP", cycles = 2 },{ mnemonic = "STA", opcode = "STA", addrMode = "ABY", cycles = 5 },{ mnemonic = "TXS", opcode = "TXS", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 5 },{ mnemonic = "STA", opcode = "STA", addrMode = "ABX", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },
		{ mnemonic = "LDY", opcode = "LDY", addrMode = "IMM", cycles = 2 },{ mnemonic = "LDA", opcode = "LDA", addrMode = "IZX", cycles = 6 },{ mnemonic = "LDX", opcode = "LDX", addrMode = "IMM", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "LDY", opcode = "LDY", addrMode = "ZP0", cycles = 3 },{ mnemonic = "LDA", opcode = "LDA", addrMode = "ZP0", cycles = 3 },{ mnemonic = "LDX", opcode = "LDX", addrMode = "ZP0", cycles = 3 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 3 },{ mnemonic = "TAY", opcode = "TAY", addrMode = "IMP", cycles = 2 },{ mnemonic = "LDA", opcode = "LDA", addrMode = "IMM", cycles = 2 },{ mnemonic = "TAX", opcode = "TAX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "LDY", opcode = "LDY", addrMode = "ABS", cycles = 4 },{ mnemonic = "LDA", opcode = "LDA", addrMode = "ABS", cycles = 4 },{ mnemonic = "LDX", opcode = "LDX", addrMode = "ABS", cycles = 4 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 4 },
		{ mnemonic = "BCS", opcode = "BCS", addrMode = "REL", cycles = 2 },{ mnemonic = "LDA", opcode = "LDA", addrMode = "IZY", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "LDY", opcode = "LDY", addrMode = "ZPX", cycles = 4 },{ mnemonic = "LDA", opcode = "LDA", addrMode = "ZPX", cycles = 4 },{ mnemonic = "LDX", opcode = "LDX", addrMode = "ZPY", cycles = 4 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 4 },{ mnemonic = "CLV", opcode = "CLV", addrMode = "IMP", cycles = 2 },{ mnemonic = "LDA", opcode = "LDA", addrMode = "ABY", cycles = 4 },{ mnemonic = "TSX", opcode = "TSX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 4 },{ mnemonic = "LDY", opcode = "LDY", addrMode = "ABX", cycles = 4 },{ mnemonic = "LDA", opcode = "LDA", addrMode = "ABX", cycles = 4 },{ mnemonic = "LDX", opcode = "LDX", addrMode = "ABY", cycles = 4 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 4 },
		{ mnemonic = "CPY", opcode = "CPY", addrMode = "IMM", cycles = 2 },{ mnemonic = "CMP", opcode = "CMP", addrMode = "IZX", cycles = 6 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "CPY", opcode = "CPY", addrMode = "ZP0", cycles = 3 },{ mnemonic = "CMP", opcode = "CMP", addrMode = "ZP0", cycles = 3 },{ mnemonic = "DEC", opcode = "DEC", addrMode = "ZP0", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "INY", opcode = "INY", addrMode = "IMP", cycles = 2 },{ mnemonic = "CMP", opcode = "CMP", addrMode = "IMM", cycles = 2 },{ mnemonic = "DEX", opcode = "DEX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "CPY", opcode = "CPY", addrMode = "ABS", cycles = 4 },{ mnemonic = "CMP", opcode = "CMP", addrMode = "ABS", cycles = 4 },{ mnemonic = "DEC", opcode = "DEC", addrMode = "ABS", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },
		{ mnemonic = "BNE", opcode = "BNE", addrMode = "REL", cycles = 2 },{ mnemonic = "CMP", opcode = "CMP", addrMode = "IZY", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "CMP", opcode = "CMP", addrMode = "ZPX", cycles = 4 },{ mnemonic = "DEC", opcode = "DEC", addrMode = "ZPX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "CLD", opcode = "CLD", addrMode = "IMP", cycles = 2 },{ mnemonic = "CMP", opcode = "CMP", addrMode = "ABY", cycles = 4 },{ mnemonic = "NOP", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "CMP", opcode = "CMP", addrMode = "ABX", cycles = 4 },{ mnemonic = "DEC", opcode = "DEC", addrMode = "ABX", cycles = 7 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },
		{ mnemonic = "CPX", opcode = "CPX", addrMode = "IMM", cycles = 2 },{ mnemonic = "SBC", opcode = "SBC", addrMode = "IZX", cycles = 6 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "CPX", opcode = "CPX", addrMode = "ZP0", cycles = 3 },{ mnemonic = "SBC", opcode = "SBC", addrMode = "ZP0", cycles = 3 },{ mnemonic = "INC", opcode = "INC", addrMode = "ZP0", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 5 },{ mnemonic = "INX", opcode = "INX", addrMode = "IMP", cycles = 2 },{ mnemonic = "SBC", opcode = "SBC", addrMode = "IMM", cycles = 2 },{ mnemonic = "NOP", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "SBC", addrMode = "IMP", cycles = 2 },{ mnemonic = "CPX", opcode = "CPX", addrMode = "ABS", cycles = 4 },{ mnemonic = "SBC", opcode = "SBC", addrMode = "ABS", cycles = 4 },{ mnemonic = "INC", opcode = "INC", addrMode = "ABS", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },
		{ mnemonic = "BEQ", opcode = "BEQ", addrMode = "REL", cycles = 2 },{ mnemonic = "SBC", opcode = "SBC", addrMode = "IZY", cycles = 5 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 8 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "SBC", opcode = "SBC", addrMode = "ZPX", cycles = 4 },{ mnemonic = "INC", opcode = "INC", addrMode = "ZPX", cycles = 6 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 6 },{ mnemonic = "SED", opcode = "SED", addrMode = "IMP", cycles = 2 },{ mnemonic = "SBC", opcode = "SBC", addrMode = "ABY", cycles = 4 },{ mnemonic = "NOP", opcode = "NOP", addrMode = "IMP", cycles = 2 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },{ mnemonic = "???", opcode = "NOP", addrMode = "IMP", cycles = 4 },{ mnemonic = "SBC", opcode = "SBC", addrMode = "ABX", cycles = 4 },{ mnemonic = "INC", opcode = "INC", addrMode = "ABX", cycles = 7 },{ mnemonic = "???", opcode = "XXX", addrMode = "IMP", cycles = 7 },
	},

    Clock = function(self)
        if self.__timingControlCycles == 0 then
            local opcode = self:read(self.__pc)
            local lookup = self.__opcodes[opcode + 1]
            self.__pc = self.__pc + 1
            self.__timingControlCycles = lookup.cycles

            local fetched = 0x00

            local addrRes, addCycleAdd = self[lookup.addrMode](self)
            if lookup.addrMode == "IMP" or lookup.addrMode == "REL" then
                fetched = addrRes
            else
                fetched = self:read(addrRes)
            end
            local addCycleOp = self[lookup.opcode](self, fetched, lookup.addrMode, addrRes, opcode)

            self.__timingControlCycles = self.__timingControlCycles + bit.band(addCycleAdd, addCycleOp)
        end
        self.__timingControlCycles = self.__timingControlCycles - 1
    end,

    reset = function(self)
        self.__A = 0x00
        self.__X = 0x00
        self.__Y = 0x00
        self.__stkp = 0xFD
        self.__STSREG = bit.bor(0x00, bit.lshift(1, 5))

        local addr = 0xFFFC
        local lo = self:read(addr + 0)
        local hi = self:read(addr + 1)

        self.__pc = bit.bor(bit.lshift(hi, 8), lo)

        self.__timingControlCycles = 8
    end,
    irq = function(self)
        if self:GetFlag("I") == 0 then
            self:write(0x0100 + self.__stkp, bit.band(bit.rshift(self.__pc, 8), 0x00FF));
            self.__stkp = self.__stkp - 1
            self:write(0x0100 + self.__stkp, bit.band(self.__pc, 0x00FF));
            self.__stkp = self.__stkp - 1

            self:SetFlag("B", 0)
            self:SetFlag("U", 1)
            self:SetFlag("I", 1)
            self:write(0x0100 + self.__stkp, self.__STSREG)
            self.__stkp = self.__stkp - 1

            local addr = 0xFFFE
            local lo = self:read(addr + 0)
            local hi = self:read(addr + 1)

            self.__pc = bit.bor(bit.lshift(hi, 8), lo)

            self.__timingControlCycles = 7
        end
    end,
    nmi = function(self)
        self:write(0x0100 + self.__stkp, bit.band(bit.rshift(self.__pc, 8), 0x00FF));
        self.__stkp = self.__stkp - 1
        self:write(0x0100 + self.__stkp, bit.band(self.__pc, 0x00FF));
        self.__stkp = self.__stkp - 1

        self:SetFlag("B", 0)
        self:SetFlag("U", 1)
        self:SetFlag("I", 1)
        self:write(0x0100 + self.__stkp, self.__STSREG)
        self.__stkp = self.__stkp - 1

        local addr = 0xFFFA
        local lo = self:read(addr + 0)
        local hi = self:read(addr + 1)

        self.__pc = bit.bor(bit.lshift(hi, 8), lo)

        self.__timingControlCycles = 7
    end,

    disassemble = function(self, nStart, nStop)
        local addr = nStart
        local val = 0x00
        local lo = 0x00
        local hi = 0x00
        local lines = {}
        local lines_index = {}

        while (addr <= nStop) do
            local line_addr = addr

            local lookup = self.__opcodes[self:read(addr, true) + 1]
            addr = addr + 1

            local str = string.format("$%04X: %s ", addr, lookup.mnemonic)

            if lookup.addrMode == "IMP" then
                str = str.."{IMP}"
            elseif lookup.addrMode == "IMM" then
                local val = self:read(addr, true)
                addr = addr + 1
                str = str..string.format("$%02X {IMM}", val)
            elseif lookup.addrMode == "ZP0" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = 0x00
                str = str..string.format("$%02X {ZP0}", lo)
            elseif lookup.addrMode == "ZPX" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = 0x00
                str = str..string.format("$%02X, X {ZPX}", lo)
            elseif lookup.addrMode == "ZPY" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = 0x00
                str = str..string.format("$%02X, Y {ZPY}", lo)
            elseif lookup.addrMode == "IZX" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = 0x00
                str = str..string.format("($%02X, X) {IZX}", lo)
            elseif lookup.addrMode == "IZY" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = 0x00
                str = str..string.format("($%02X), Y {IZY}", lo)
            elseif lookup.addrMode == "ABS" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = self:read(addr, true)
                addr = addr + 1
                str = str..string.format("$%04X {ABS}", bit.bor(bit.lshift(hi, 8), lo))
            elseif lookup.addrMode == "ABX" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = self:read(addr, true)
                addr = addr + 1
                str = str..string.format("$%04X, X {ABX}", bit.bor(bit.lshift(hi, 8), lo))
            elseif lookup.addrMode == "ABY" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = self:read(addr, true)
                addr = addr + 1
                str = str..string.format("$%04X, Y {ABY}", bit.bor(bit.lshift(hi, 8), lo))
            elseif lookup.addrMode == "IND" then
                lo = self:read(addr, true)
                addr = addr + 1
                hi = self:read(addr, true)
                addr = addr + 1
                str = str..string.format("($%04X) {IND}", bit.bor(bit.lshift(hi, 8), lo))
            elseif lookup.addrMode == "REL" then
                local val = self:read(addr, true)
                local addrRel =  bit.band(0x00FF, val)
                addr = addr + 1
                if bit.band(addrRel, 0x80) then
                    addrRel = -128 + addrRel - 128
                end
                str = str..string.format("$%02X [$%04X] {REL}", val, addr + addrRel)
            end

            lines[line_addr] = str
            lines_index[#lines_index + 1] = line_addr
        end

        return lines, lines_index
    end
})
