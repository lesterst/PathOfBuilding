-- #@
-- This wrapper allows the program to run headless on any OS (in theory)
-- It can be run using a standard lua interpreter, although LuaJIT is preferable

print("HeadlessWrapper")

local basePath = "../runtime/lua/?.lua"
local subPath = "../runtime/lua/sha1/?.lua;"
package.path = package.path .. ";" .. basePath .. ";" .. subPath
-- print(package.path)

-- Make table.unpack available as a global variable
unpack = table.unpack

-- This is the path to emmy_core.dll. The ?.dll at the end is intentional.
package.cpath = package.cpath .. ";/Users/stevenlester/.vscode/extensions/tangzx.emmylua-0.5.19/debugger/emmy/mac/arm64/?.dylib"
local dbg = require("emmy_core")
-- This port must match the Visual Studio Code configuration. Default is 9966.
dbg.tcpListen("localhost", 9966)
-- Uncomment the next line if you want Path of Building to block until the debugger is attached
dbg.waitIDE()
-- /Users/stevenlester/.vscode/extensions/tangzx.emmylua-0.5.19/debugger/emmy/mac/arm64/emmy_core.dylib

-- lualocal scriptPath = debug.getinfo(1, 'S').source:match("@?(.*/)")
-- print(scriptPath)

-- function testFunction()
--     local info = debug.getinfo(1, 'nSl')
--     print("Function name:", info.name)
--     print("Source file:", info.source)
--     print("Current line:", info.currentline)
-- end
-- testFunction()

-- Callbacks
local callbackTable = { }
local mainObject

function runCallback(name, ...)
	if callbackTable[name] then
		return callbackTable[name](...)
	elseif mainObject and mainObject[name] then
		return mainObject[name](mainObject, ...)
	end
end
function SetCallback(name, func)
	callbackTable[name] = func
end
function GetCallback(name)
	return callbackTable[name]
end
function SetMainObject(obj)
	mainObject = obj
end

-- Image Handles
local imageHandleClass = { }
imageHandleClass.__index = imageHandleClass
function NewImageHandle()
	return setmetatable({ }, imageHandleClass)
end
function imageHandleClass:Load(fileName, ...)
	self.valid = true
end
function imageHandleClass:Unload()
	self.valid = false
end
function imageHandleClass:IsValid()
	return self.valid
end
function imageHandleClass:SetLoadingPriority(pri) end
function imageHandleClass:ImageSize()
	return 1, 1
end

-- Rendering
function RenderInit() end
function GetScreenSize()
	return 1920, 1080
end
function SetClearColor(r, g, b, a) end
function SetDrawLayer(layer, subLayer) end
function SetViewport(x, y, width, height) end
function SetDrawColor(r, g, b, a) end
function DrawImage(imgHandle, left, top, width, height, tcLeft, tcTop, tcRight, tcBottom) end
function DrawImageQuad(imageHandle, x1, y1, x2, y2, x3, y3, x4, y4, s1, t1, s2, t2, s3, t3, s4, t4) end
function DrawString(left, top, align, height, font, text) end
function DrawStringWidth(height, font, text)
	return 1
end
function DrawStringCursorIndex(height, font, text, cursorX, cursorY)
	return 0
end
function StripEscapes(text)
	return text:gsub("%^%d",""):gsub("%^x%x%x%x%x%x%x","")
end
function GetAsyncCount()
	return 0
end

-- Search Handles
function NewFileSearch() end

-- General Functions
function SetWindowTitle(title) end
function GetCursorPos()
	return 0, 0
end
function SetCursorPos(x, y) end
function ShowCursor(doShow) end
function IsKeyDown(keyName) end
function Copy(text) end
function Paste() end
function Deflate(data)
	-- TODO: Might need this
	return ""
end
function Inflate(data)
	-- TODO: And this
	return ""
end
function GetTime()
	return 0
end
function GetScriptPath()
	return ""
end
function GetRuntimePath()
	return ""
end
function GetUserPath()
	return ""
end
function MakeDir(path) end
function RemoveDir(path) end
function SetWorkDir(path) end
function GetWorkDir()
	return ""
end
function LaunchSubScript(scriptText, funcList, subList, ...) end
function AbortSubScript(ssID) end
function IsSubScriptRunning(ssID) end
function LoadModule(fileName, ...)
	if not fileName:match("%.lua") then
		fileName = fileName .. ".lua"
	end
	-- print("LoadModule",fileName)
	local func, err = loadfile(fileName)
	if func then
		return func(...)
	else
		error("LoadModule() error loading '"..fileName.."': "..err)
	end
end
function PLoadModule(fileName, ...)
	if not fileName:match("%.lua") then
		fileName = fileName .. ".lua"
	end
	print("PLoadModule",fileName)
	local func, err = loadfile(fileName)
	if func then
		return PCall(func, ...)
	else
		error("PLoadModule() error loading '"..fileName.."': "..err)
	end
end
function PCall(func, ...)
	local ret = { pcall(func, ...) }
	if ret[1] then
		table.remove(ret, 1)
		return nil, unpack(ret)
	else
		return ret[2]
	end	
end
function ConPrintf(fmt, ...)
	-- Optional
	print(string.format(fmt, ...))
end
function ConPrintTable(tbl, noRecurse) end
function ConExecute(cmd) end
function ConClear() end
function SpawnProcess(cmdName, args) end
function OpenURL(url) end
function SetProfiling(isEnabled) end
function Restart() end
function Exit() end

local l_require = require
function require(name)
	-- Hack to stop it looking for lcurl, which we don't really need
	if name == "lcurl.safe" then
		return
	end
	return l_require(name)
end


dofile("Launch.lua")

-- Prevents loading of ModCache
-- Allows running mod parsing related tests without pushing ModCache
-- The CI env var will be true when run from github workflows but should be false for other tools using the headless wrapper 
mainObject.continuousIntegrationMode = os.getenv("CI")

runCallback("OnInit")
runCallback("OnFrame") -- Need at least one frame for everything to initialise

if mainObject.promptMsg then
	-- Something went wrong during startup
	print(mainObject.promptMsg)
	io.read("*l")
	return
end

-- The build module; once a build is loaded, you can find all the good stuff in here
build = mainObject.main.modes["BUILD"]
-- Here's some helpful helper functions to help you get started
function newBuild()
	mainObject.main:SetMode("BUILD", false, "Help, I'm stuck in Path of Building!")
	runCallback("OnFrame")
end

function loadBuildFromXML(xmlText, name)
	mainObject.main:SetMode("BUILD", false, name or "", xmlText)
	runCallback("OnFrame")
end
function loadBuildFromJSON(getItemsJSON, getPassiveSkillsJSON)
	mainObject.main:SetMode("BUILD", false, "")
	runCallback("OnFrame")
	local charData = build.importTab:ImportItemsAndSkills(getItemsJSON)
	build.importTab:ImportPassiveTreeAndJewels(getPassiveSkillsJSON, charData)
	-- You now have a build without a correct main skill selected, or any configuration options set
	-- Good luck!
end

-- Function to read the contents of a file
function readFile(filename)
    local file = io.open(filename, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return content
    else
        return nil
    end
end

-- Path to your XML file
local xmlFilePath = "/Users/stevenlester/projects/poebuilds/caustic arrow ballista pathfinder me after weighted sum rework.xml"

-- Read XML content from the file
local xmlContent = readFile(xmlFilePath)
print("xml build file loaded")
-- Check if the file was read successfully
if xmlContent then
    -- Assume you have a build name
    local buildName = "Your Build Name"

    -- Call the function
    loadBuildFromXML(xmlContent, buildName)
else
    print("Failed to read XML file.")
end
