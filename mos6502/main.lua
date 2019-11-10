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
        JMP $8000
        NOP
    ]]--
    local prog = "A2 0A 8E 00 00 A2 03 8E 01 00 AC 00 00 A9 00 18 6D 01 00 88 D0 FA 8D 02 00 EA 4C 00 80 EA"

    local insert = 0x8000
    for w in prog:gmatch("%S+") do
        cpu:write(insert, tonumber(w, 16))
        insert = insert + 1
    end

    cpu:write(0xFFFC, 0x00)
    cpu:write(0xFFFD, 0x80)

    local lines, linesIndex = cpu:disassemble(0x8000, 0x801F)

    for i,addr in pairs(linesIndex) do print(lines[addr]) end
end

local t = 0
local d = 0
function love.update(dt)
    t = t + dt
    if t > CLOCKSPEED then
        cpu:Clock()
        t = 0
    end
    if d > 0.2 then
        if love.keyboard.isDown("r") then
            cpu:reset()
        elseif love.keyboard.isDown("n") then
            cpu:nmi()
        elseif love.keyboard.isDown("i") then
            cpu:irq()
        end
    else
        d = d + dt
    end
end

local function writeLetter(letter, x, y)
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.print(letter, x + 4, y + 1)
end
local CELLSIZE = 2
function love.draw()
    if not cpu or not ram then return end

    -- Print the full memory contents to screen
    local mem = ram.__memory
    for address = 0, ram.addressableBytes, 256 do
        for offset = 0, 255, 1 do
            love.graphics.setColor(255, 255, 255, mem[address + offset] or 0)
            love.graphics.rectangle("fill", offset * CELLSIZE, math.floor(address / 256) * CELLSIZE, CELLSIZE, CELLSIZE)
        end
    end

    -- Print the current Program Counter Position
    local pc = cpu.__pc
    local MSB = bit.band(0xFF00, pc)
    local LSB = bit.band(0x00FF, pc)
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.rectangle("fill", LSB * CELLSIZE, math.floor(MSB / 256) * CELLSIZE, CELLSIZE, CELLSIZE)
    writeLetter(string.format("PC$%04X", pc), 100, 512)

    -- Print the current Stack Pointer Position
    local stckpnt = cpu.__stkp
    MSB = bit.band(0xFF00, stckpnt)
    LSB = bit.band(0x00FF, stckpnt)
    love.graphics.setColor(0, 255, 0, 255)
    love.graphics.rectangle("fill", LSB * CELLSIZE, math.floor(MSB / 256) * CELLSIZE, CELLSIZE, CELLSIZE)
    writeLetter(string.format("StkPnt$%04X", stckpnt), 200, 512)

    -- Print the registers
    -- A
    love.graphics.setColor(255, 255, 255, cpu.__A)
    love.graphics.rectangle("fill", 0, 512, 16, 16)
    writeLetter("A", 0, 512)
    -- X
    love.graphics.setColor(255, 255, 255, cpu.__X)
    love.graphics.rectangle("fill", 16, 512, 16, 16)
    writeLetter("X", 16, 512)
    -- Y
    love.graphics.setColor(255, 255, 255, cpu.__Y)
    love.graphics.rectangle("fill", 32, 512, 16, 16)
    writeLetter("Y", 32, 512)

    -- Print status flags
    local flags = {"C", "Z", "I", "D", "B", "U", "V", "N"}
    for index, flag in pairs(flags) do
        love.graphics.setColor(255, 255, 255, cpu:GetFlag(flag) * 255)
        love.graphics.rectangle("fill", 512 - (16 * index), 512, 16, 16)
        writeLetter(flag, 512 - (16 * index), 512)
    end
end
