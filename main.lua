--[[

    LÖVE Main File
    Init program

]]

testRAM = nil

function initWindow()
    love.graphics.setBackgroundColor(0,0,0)
end

function requireFiles()
    require("classes.BUS")
    require("classes.GenericCPU")
    require("classes.GenericBUSDevice")
    require("classes.RAM")
end

local testCPU = nil
function love.load()
    requireFiles()

    testCPU = GenericCPU:new()
    local testBUS = BUS:new(testCPU)
    testRAM = RAM:new({
        addressableBytes = 0xFF
    })

    testBUS:addDevice(testRAM)

    --for i = 0, testRAM.addressableBytes, 1 do testCPU:write(i, math.random(0, 255)) end
    --[[ This is a dick
    testCPU:write(0x27, 0xFF)
    testCPU:write(0x28, 0xFF)
    testCPU:write(0x36, 0xFF)
    testCPU:write(0x39, 0xFF)
    testCPU:write(0x45, 0xFF)
    testCPU:write(0x4A, 0xFF)
    testCPU:write(0x55, 0xFF)
    testCPU:write(0x5A, 0xFF)
    testCPU:write(0x65, 0xFF)
    testCPU:write(0x6A, 0xFF)
    testCPU:write(0x75, 0xFF)
    testCPU:write(0x7A, 0xFF)
    testCPU:write(0x85, 0xFF)
    testCPU:write(0x8A, 0xFF)
    testCPU:write(0x95, 0xFF)
    testCPU:write(0x9A, 0xFF)
    testCPU:write(0xA5, 0xFF)
    testCPU:write(0xAA, 0xFF)
    testCPU:write(0xA1, 0xFF)
    testCPU:write(0xA2, 0xFF)
    testCPU:write(0xA3, 0xFF)
    testCPU:write(0xB0, 0xFF)
    testCPU:write(0xB4, 0xFF)
    testCPU:write(0xC0, 0xFF)
    testCPU:write(0xD0, 0xFF)
    testCPU:write(0xE1, 0xFF)
    testCPU:write(0xBB, 0xFF)
    testCPU:write(0xAC, 0xFF)
    testCPU:write(0xAD, 0xFF)
    testCPU:write(0xAE, 0xFF)
    testCPU:write(0xBF, 0xFF)
    testCPU:write(0xCF, 0xFF)
    testCPU:write(0xDF, 0xFF)
    testCPU:write(0xEE, 0xFF) ]]

    --[[ Sample Program
        Counts from 0 to 256 in steps of 16, then loops

        CLC
        LDA 0
        ADD 16
        STA $10
        BCC 12
        JMP $91
        ...
        JMP $80
    ]]
    testCPU:write(0xAC, 0x0B) -- $AC JMP
    testCPU:write(0xAD, 0x80) -- $AD 0x80 (128)
    testCPU:write(0x80, 0x04) -- $80 CLC
    testCPU:write(0x81, 0x0F) -- $81 LDA
    testCPU:write(0x82, 0x00) -- $82 0x00 (0)
    testCPU:write(0x91, 0x01) -- $91 ADD
    testCPU:write(0x92, 0x10) -- $92 0x10 (16)
    testCPU:write(0x93, 0x0C) -- $93 STA
    testCPU:write(0x94, 0x10) -- $94 0x10 (16)
    testCPU:write(0x95, 0x0A) -- $95 BCC
    testCPU:write(0x96, 0x8C) -- $96 0x8C (140 -> +12)
    testCPU:write(0x97, 0x0B) -- $97 JMP
    testCPU:write(0x98, 0x91) -- $98 0x91 (145)

    initWindow()
end

local t = 0
function love.update(dt)
    t = t + dt
    if t > 0.1 then
        testCPU:Clock()
        t = 0
    end
end

function love.draw()
    if not testRAM then return end

    -- Print the full memory contents to screen
    local mem = testRAM.__memory
    for address = 0, testRAM.addressableBytes, 16 do
        for offset = 0, 15, 1 do
            love.graphics.setColor(255, 255, 255, mem[address + offset] or 0)
            love.graphics.rectangle("fill", offset * 16, math.floor(address / 16) * 16, 16, 16)
        end
    end

    -- Print the current Program Counter Position
    local pc = testCPU.__pc
    local MSB = bit.band(0xF0, pc)
    local LSB = bit.band(0x0F, pc)
    love.graphics.setColor(255, 0, 0, 255)
    love.graphics.rectangle("line", LSB * 16, math.floor(MSB / 16) * 16, 16, 16)
    -- Print the current Stack Pointer Position
    local stckpnt = testCPU.__stkp
    MSB = bit.band(0xF0, stckpnt)
    LSB = bit.band(0x0F, stckpnt)
    love.graphics.setColor(0, 255, 0, 255)
    love.graphics.rectangle("line", LSB * 16, math.floor(MSB / 16) * 16, 16, 16)
end
