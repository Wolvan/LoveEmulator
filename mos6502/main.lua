--[[

    LÖVE Main File for emulated MOS6502
    Init program

]]

local CLOCKSPEED = 0.01

local function initWindow()
    love.graphics.setBackgroundColor(0,0,0)
    love.graphics.setFont(love.graphics.newFont("resources/pixel.otf"), 16)
end
local function requireFiles()
    require("classes.BUS")
    require("classes.GenericCPU")
    require("classes.MOS6502")
    require("classes.GenericBUSDevice")
    require("classes.RAM")
end

local cpu = nil
local ram = nil

local function writeProgramToMemory(insert, prog)
    for w in prog:gmatch("%S+") do
        cpu:write(insert, tonumber(w, 16))
        insert = insert + 1
    end
end

function love.load()
    requireFiles()
    initWindow()

    cpu = MOS6502:new()

    local bus = BUS:new(cpu)

    ram = RAM:new({
        addressableBytes = 64 * 1024 -- 64kB
    })

    bus:addDevice(ram)

    --for i = 0, ram.addressableBytes, 1 do cpu:write(i, math.random(0, 255)) end

    --[[
        The following program is being executed upon reset

        *=$8000
        LDX #10
        STX $0000
        LDX #3
        STX $0001
        LDY $0000
        LDA #0
        CLC
        loop
        ADC $0001
        DEY
        BNE loop
        STA $0002
        NOP
        JMP $8100
        NOP
    ]]--
    writeProgramToMemory(0x8000, "A2 0A 8E 00 00 A2 03 8E 01 00 AC 00 00 A9 00 18 6D 01 00 88 D0 FA 8D 02 00 EA 4C 00 81 EA")

    --[[
        *=$8100
        LDX #0
        LDY #0
        loop
        DEY
        BNE loop
        loop2
        DEX
        BNE loop2
        JMP $8200
    ]]
    writeProgramToMemory(0x8100, "A2 00 A0 00 88 D0 FD CA D0 FD 4C 00 82")
    --[[
        *=$8200
        LDX #0
        LDY #0
        loop
        INY
        BNE loop
        loop2
        INX
        BNE loop2
        JMP $8300
    ]]
    writeProgramToMemory(0x8200, "A2 00 A0 00 C8 D0 FD E8 D0 FD 4C 00 83")

    --[[
        *=$8300
        LDX #0
        STX $0010
        CLZ
        loop
        INC $0010
        BNE loop
        loop2
        DEC $0010
        BNE loop2
        JMP $8400
    ]]
    writeProgramToMemory(0x8300, "A2 00 8E 10 00 EE 10 00 D0 FB CE 10 00 D0 FB 4C 00 84")
    --[[
        *=$8400
        LDX #9
        DEX
        BEQ skipjmp
        JMP $8402
        skipjmp
        NOP
        JMP $8500
    ]]
    writeProgramToMemory(0x8400, "A2 09 CA F0 03 4C 02 84 EA 4C 00 85")

    cpu:write(0xFFFC, 0x00)
    cpu:write(0xFFFD, 0x80)
end

local drawMode = false
local page = 0x80
local autotick = false

local t = 0
local d = 0
function love.update(dt)
    t = t + dt
    if t > CLOCKSPEED then
        if cpu.__timingControlCycles > 0 or autotick then cpu:Clock() end
        t = 0
    end
    if d > 0.2 then
        if love.keyboard.isDown("r") then
            cpu:reset()
            d = 0
        elseif love.keyboard.isDown("n") then
            cpu:nmi()
            d = 0
        elseif love.keyboard.isDown("i") then
            cpu:irq()
            d = 0
        elseif love.keyboard.isDown("m") then
            drawMode = not drawMode
            d = 0
        elseif love.keyboard.isDown(" ") then
            if cpu.__timingControlCycles == 0 then cpu:Clock() end
            d = 0
        elseif love.keyboard.isDown("up") then
            page = page + 1
            if page > 0xFF then page = 0x00 end
            d = 0
        elseif love.keyboard.isDown("down") then
            page = page - 1
            if page < 0x00 then page = 0xFF end
            d = 0
        elseif love.keyboard.isDown("right") then
            page = page + 16
            if page > 0xFF then page = 0x00 end
            d = 0
        elseif love.keyboard.isDown("left") then
            page = page - 16
            if page < 0x00 then page = 0xFF end
            d = 0
        elseif love.keyboard.isDown("c") then
            autotick = not autotick
            d = 0
        end
    else
        d = d + dt
    end
end

local function writeLetter(letter, x, y)
    love.graphics.print(letter, x + 4, y + 1)
end
local function writeMonospace(str, x, y)
    for j = 0, #str - 1, 1 do
        local c = str:sub(j + 1, j + 1)
        love.graphics.print(c, x + j * 9, y)
    end
end

local CELLSIZE = 2

local function getPageContents(pageHiByte)
    local mem = ram.__memory
    local lines = {}
    local baseAddr = bit.lshift(pageHiByte, 8)
    for address = 0, 255, 16 do
        local values = {baseAddr = bit.band(baseAddr + address)}
        for offset = 0, 15, 1 do
            values[#values + 1] = {
                value = mem[bit.band(baseAddr + address) + offset] or 0,
                address = bit.band(baseAddr + address) + offset
            }
        end
        lines[#lines + 1] = values
    end
    return lines
end
local function writePageContents(pageHiByte, pc, stckpnt, x, y)
    local pageContents = getPageContents(pageHiByte)
    for i = 0, #pageContents - 1, 1 do
        local values = pageContents[i + 1]
        love.graphics.setColor(255, 255, 255, 255)
        writeMonospace(string.format("$%04X", values.baseAddr), x, i * 10 + y)
        for j = 0, #values - 1, 1 do
            local value = values[j + 1]
            if value.address == stckpnt then love.graphics.setColor(0, 255, 0, 255)
            elseif value.address == pc then love.graphics.setColor(255, 0, 0, 255)
            else love.graphics.setColor(255, 255, 255, 255) end
            writeMonospace(string.format("%02X", value.value), j * 25 + 60 + x, i * 10 + y)
        end
    end
end

function love.draw()
    if not cpu or not ram then return end

    local pc = cpu.__pc
    local stckpnt = cpu.__stkp
    local mem = ram.__memory
    if drawMode then
        -- Print the full memory contents to screen
        for address = 0, ram.addressableBytes, 256 do
            for offset = 0, 255, 1 do
                love.graphics.setColor(255, 255, 255, mem[address + offset] or 0)
                love.graphics.rectangle("fill", offset * CELLSIZE, math.floor(address / 256) * CELLSIZE, CELLSIZE, CELLSIZE)
            end
        end

        -- Print the current Program Counter Position
        local MSB = bit.band(0xFF00, pc)
        local LSB = bit.band(0x00FF, pc)
        love.graphics.setColor(255, 0, 0, 255)
        love.graphics.rectangle("fill", LSB * CELLSIZE, math.floor(MSB / 256) * CELLSIZE, CELLSIZE, CELLSIZE)

        -- Print the current Stack Pointer Position
        MSB = bit.band(0xFF00, stckpnt)
        LSB = bit.band(0x00FF, stckpnt)
        love.graphics.setColor(0, 255, 0, 255)
        love.graphics.rectangle("fill", LSB * CELLSIZE, math.floor(MSB / 256) * CELLSIZE, CELLSIZE, CELLSIZE)
    else
        -- Print pages to screen
        writePageContents(0x00, pc, stckpnt, 0, 0)
        writePageContents(page, pc, stckpnt, 0, 180)

        -- Print current instruction
        local lines, lineIndex = cpu:disassemble(pc, pc + 16)
        for index, addr in pairs(lineIndex) do
            if addr == pc then love.graphics.setColor(255, 0, 0, 255)
            else love.graphics.setColor(255, 255, 255, 255) end
            writeMonospace(lines[addr], 0, 360 + (index - 1) * 10)
        end
    end

    love.graphics.setColor(255, 0, 0, 255)
    writeLetter(string.format("PC$%04X", pc), 150, 512)
    writeLetter(string.format("%02X (%03d)", mem[pc] or 0, mem[pc] or 0), 150, 522)
    writeLetter(string.format("StkPtr$%04X", stckpnt), 250, 512)
    writeLetter(string.format("%02X (%03d)", mem[stckpnt] or 0, mem[stckpnt] or 0), 250, 522)

    -- Print the registers
    -- A
    writeMonospace(string.format("A %02X (%03d)", cpu.__A, cpu.__A), 3, 512)
    -- X
    writeMonospace(string.format("X %02X (%03d)", cpu.__X, cpu.__X), 3, 522)
    -- Y
    writeMonospace(string.format("Y %02X (%03d)", cpu.__Y, cpu.__Y), 3, 532)

    -- Print status flags
    local flags = {"C", "Z", "I", "D", "B", "U", "V", "N"}
    for index, flag in pairs(flags) do
        if cpu:GetFlag(flag) == 1 then
            love.graphics.setColor(0, 255, 0)
        else
            love.graphics.setColor(255, 0, 0)
        end
        writeLetter(flag, 512 - (16 * index), 512)
    end
end
