function set_clipboard(text)
    io.popen('pbcopy','w'):write(text):close()
end

function get_clipboard()
    local text
    text = io.popen('pbpaste'):close()
    return text
end

local handle = io.popen("pbpaste")
local result = handle:read("*a")
print(result)
handle:close()

-- local pipe = io.popen("powershell get-clipboard", "r")
-- local clipboard = pipe:read("*a")
-- print("Clipboard: " .. clipboard)
-- pipe:close()