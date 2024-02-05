-- Simple Lua script

function testFunction()
    local info = debug.getinfo(1, 'nSl')
    print("Function name:", info.name)
    print("Source file:", info.source)
    print("Current line:", info.currentline)
end

testFunction()
