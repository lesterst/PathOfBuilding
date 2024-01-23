-- Path of Building
--
-- Module: Main
-- Main module of program.
--
local ipairs = ipairs
local t_insert = table.insert
local t_remove = table.remove
local m_ceil = math.ceil
local m_floor = math.floor
local m_max = math.max
local m_min = math.min
local m_sin = math.sin
local m_cos = math.cos
local m_pi = math.pi

-- Loading Modules: It begins by loading various modules necessary for the program's functionality. These modules handle game versions, common functions, data management, item manipulation, calculations, and more.
LoadModule("GameVersions")
LoadModule("Modules/Common")
LoadModule("Modules/Data")
LoadModule("Modules/ModTools")
LoadModule("Modules/ItemTools")
LoadModule("Modules/CalcTools")
LoadModule("Modules/PantheonTools")
LoadModule("Modules/BuildSiteTools")

--[[if launch.devMode then
	for skillName, skill in pairs(data.enchantments.Helmet) do
		for _, mod in ipairs(skill.ENDGAME) do
			local modList, extra = modLib.parseMod(mod)
			if not modList or extra then
				ConPrintf("%s: '%s' '%s'", skillName, mod, extra or "")
			end
		end
	end
end]]

-- JIT (Just-In-Time) Compilation: It checks if a specific argument (--no-jit) is provided when executing the program. If found, it disables JIT compilation, likely for debugging or specific runtime considerations.
if arg and isValueInTable(arg, "--no-jit") then
	require("jit").off()
	ConPrintf("JIT Disabled")
end

local tempTable1 = { }
local tempTable2 = { }

-- Initialization: The main function initializes the program's control host and sets up various modes, such as "LIST" and "BUILD," presumably for different functionalities or interfaces within the program.
main = new("ControlHost")

function main:Init()
	self:DetectUnicodeSupport()
	self.modes = { }
	self.modes["LIST"] = LoadModule("Modules/BuildList")
	self.modes["BUILD"] = LoadModule("Modules/Build")

	-- File Handling and Paths: It determines the file paths for storing user data, default build paths, and checks if the program is running in dev mode or standalone mode. Depending on the mode, it decides where to store user data.
	if launch.devMode or (GetScriptPath() == GetRuntimePath() and not launch.installedMode) then
		-- If running in dev mode or standalone mode, put user data in the script path
		self.userPath = GetScriptPath().."/"
	else
		self.userPath = GetUserPath().."/Path of Building/"
		MakeDir(self.userPath)
	end
	self.defaultBuildPath = self.userPath.."Builds/"
	self.buildPath = self.defaultBuildPath
	MakeDir(self.buildPath)

	-- Mod Cache Handling: Depending on the mode (dev or regular), it either saves a new mod cache or loads an existing mod cache. This cache seems to be related to parsing modifications.
	-- Keyboard Shortcuts: It detects certain key combinations (CTRL or CTRL + SHIFT) for special actions, like allowing tree downloads or manipulating the mod cache.
	if launch.devMode and IsKeyDown("CTRL") then
		-- If modLib.parseMod doesn't find a cache entry it generates it.
		-- Not loading pre-generated cache causes it to be rebuilt
		self.saveNewModCache = true
	else
		-- Load mod cache
		LoadModule("Data/ModCache", modLib.parseModCache)
	end

	if launch.devMode and IsKeyDown("CTRL") and IsKeyDown("SHIFT") then
		self.allowTreeDownload = true
	end

-- Setting Defaults: Several settings and variables are initialized here, such as color codes, separators for numbers, default item affix quality, and whether to show warnings or tooltips.
	self.inputEvents = { }
	self.popups = { }
	self.tooltipLines = { }

	self.gameAccounts = { }

	self.buildSortMode = "NAME"
	self.connectionProtocol = 0
	self.nodePowerTheme = "RED/BLUE"
	self.colorPositive = defaultColorCodes.POSITIVE
	self.colorNegative = defaultColorCodes.NEGATIVE
	self.colorHighlight = defaultColorCodes.HIGHLIGHT
	self.showThousandsSeparators = true
	self.thousandsSeparator = ","
	self.decimalSeparator = "."
	self.defaultItemAffixQuality = 0.5
	self.showTitlebarName = true
	self.showWarnings = true
	self.slotOnlyTooltips = true
	self.POESESSID = ""

	-- Variable Initialization:
	--ignoreBuild is initialized to nil.
	--Various data structures (self.tree, self.uniqueDB, self.rareDB, self.sharedItemList, self.sharedItemSetList, self.toastMessages) and controls for the GUI are initialized.
	local ignoreBuild
	-- Downloading and Loading Build:
	--Checks if an argument arg[1] exists. If so, it triggers a function buildSites.DownloadBuild to download a build. Depending on the success of the download, it either sets a mode with build data or sets a default mode.
	if arg[1] then
		buildSites.DownloadBuild(arg[1], nil, function(isSuccess, data)
			if not isSuccess then
				self:SetMode("BUILD", false, data)
			else
				local xmlText = Inflate(common.base64.decode(data:gsub("-","+"):gsub("_","/")))
				self:SetMode("BUILD", false, "Imported Build", xmlText)
				self.newModeChangeToTree = true
			end
		end)
		arg[1] = nil -- Protect against downloading again this session.
		ignoreBuild = true
	end

	if not ignoreBuild then
		self:SetMode("BUILD", false, "Unnamed build")
	end
	self:LoadSettings(ignoreBuild)

	self.tree = { }
	self:LoadTree(latestTreeVersion)

	self.uniqueDB = { list = { }, loading = true }
	self.rareDB = { list = { }, loading = true }
-- Loading Item Databases:
	--Defines a function loadItemDBs() that populates databases for unique and rare items by iterating through predefined data structures (data.uniques and data.rares). It creates items based on the raw data and stores them in respective databases (self.uniqueDB.list and self.rareDB.list).
	local function loadItemDBs()
		for type, typeList in pairsYield(data.uniques) do
			for _, raw in pairs(typeList) do
				newItem = new("Item", raw, "UNIQUE", true)
				if newItem.base then
					self.uniqueDB.list[newItem.name] = newItem
				elseif launch.devMode then
					ConPrintf("Unique DB unrecognised item of type '%s':\n%s", type, raw)
				end
			end
		end

		self.uniqueDB.loading = nil
		ConPrintf("Uniques loaded")

		for _, raw in pairsYield(data.rares) do
			newItem = new("Item", raw, "RARE", true)
			if newItem.base then
				if newItem.crafted then
					if newItem.base.implicit and #newItem.implicitModLines == 0 then
						-- Automatically add implicit
						local implicitIndex = 1
						for line in newItem.base.implicit:gmatch("[^\n]+") do
							t_insert(newItem.implicitModLines, { line = line, modTags = newItem.base.implicitModTypes and newItem.base.implicitModTypes[implicitIndex] or { } })
							implicitIndex = implicitIndex + 1
						end
					end
					newItem:Craft()
				end
				self.rareDB.list[newItem.name] = newItem
			elseif launch.devMode then
				ConPrintf("Rare DB unrecognised item:\n%s", raw)
			end
		end

		self.rareDB.loading = nil
		ConPrintf("Rares loaded")
	end
	
	if self.saveNewModCache then
		local saved = self.defaultItemAffixQuality
		self.defaultItemAffixQuality = 0.5
		loadItemDBs()
		self:SaveModCache()
		self.defaultItemAffixQuality = saved
	end

	-- Configuration of GUI Controls:
	--Defines various GUI controls such as buttons (controls.options, controls.about, controls.applyUpdate, controls.checkUpdate, controls.dismissToast), labels (controls.forkLabel, controls.versionLabel, controls.devMode), and configures their behaviors, visibility, and labels based on certain conditions or states.
	self.sharedItemList = { }
	self.sharedItemSetList = { }

	self.anchorMain = new("Control", nil, 4, 0, 0, 0)
	self.anchorMain.y = function()
		return self.screenH - 4
	end
	self.controls.options = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, 0, 68, 20, "Options", function()
		self:OpenOptionsPopup()
	end)
	self.controls.about = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 72, 0, 68, 20, "About", function()
		self:OpenAboutPopup()
	end)
	self.controls.applyUpdate = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, -24, 140, 20, "^x50E050Update Ready", function()
		self:OpenUpdatePopup()
	end)
	self.controls.applyUpdate.shown = function()
		return launch.updateAvailable and launch.updateAvailable ~= "none"
	end
	self.controls.checkUpdate = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, -24, 140, 20, "", function()
		launch:CheckForUpdate()
	end)
	self.controls.checkUpdate.shown = function()
		return not launch.devMode and (not launch.updateAvailable or launch.updateAvailable == "none")
	end
	self.controls.checkUpdate.label = function()
		return launch.updateCheckRunning and launch.updateProgress or "Check for Update"
	end
	self.controls.checkUpdate.enabled = function()
		return not launch.updateCheckRunning
	end
	self.controls.forkLabel = new("LabelControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 148, -26, 0, 16, "")
	self.controls.forkLabel.label = function()
		return "^8PoB Community Fork"
	end
	self.controls.versionLabel = new("LabelControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 148, -2, 0, 16, "")
	self.controls.versionLabel.label = function()
		return "^8Version: "..launch.versionNumber..(launch.versionBranch == "dev" and " (Dev)" or launch.versionBranch == "beta" and " (Beta)" or "")
	end
	self.controls.devMode = new("LabelControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, -26, 0, 20, colorCodes.NEGATIVE.."Dev Mode")
	self.controls.devMode.shown = function()
		return launch.devMode
	end
	self.controls.dismissToast = new("ButtonControl", {"BOTTOMLEFT",self.anchorMain,"BOTTOMLEFT"}, 0, function() return -self.mainBarHeight + self.toastHeight end, 80, 20, "Dismiss", function()
		self.toastMode = "HIDING"
		self.toastStart = GetTime()
	end)
	self.controls.dismissToast.shown = function()
		return self.toastMode == "SHOWN"
	end

	self.mainBarHeight = 58
	self.toastMessages = { }
-- Displaying Developer Mode Warning:
	--If the application is in developer mode (launch.devMode) and certain conditions are met regarding the time, it adds a warning message to be displayed as a toast message in the GUI.
	if launch.devMode and GetTime() >= 0 and GetTime() < 15000 then
		t_insert(self.toastMessages, [[
^xFF7700Warning: ^7Developer Mode active!
The program is currently running in developer
mode, which is not intended for normal use.
If you are not expecting this, then you may have
set up the program from the source .zip instead
of using one of the installers. If that is the case,
please reinstall using one of the installers from
the "Releases" section of the GitHub page.]])
	end
-- Load Shared Items:
	--Calls the method LoadSharedItems() to presumably load some shared items/settings.
	self:LoadSharedItems()
-- Frame Functions:
	--Defines functions to be executed on specific frames:
	--A function named "FirstFrame" runs on the first frame. It performs specific tasks and then removes itself from further execution.
	--Another function named "LoadItems" (if self.saveNewModCache is false) creates a coroutine for loadItemDBs and executes it incrementally on subsequent frames.
	self.onFrameFuncs = {
		["FirstFrame"] = function()
			self.onFrameFuncs["FirstFrame"] = nil
			if launch.devMode then
				data.printMissingMinionSkills()
			end
			ConPrintf("Startup time: %d ms", GetTime() - launch.startTime)
		end
	}

	if not self.saveNewModCache then
		local itemsCoroutine = coroutine.create(loadItemDBs)
		
		self.onFrameFuncs["LoadItems"] = function()
			local res, errMsg = coroutine.resume(itemsCoroutine)
			if coroutine.status(itemsCoroutine) == "dead" then
				self.onFrameFuncs["LoadItems"] = nil
			end
			if not res then
				error(errMsg)
			end
		end
	end
end
-- Unicode Detection:
--DetectUnicodeSupport() determines if the Lua environment supports Unicode by checking the existence of utf8 in the global environment (_G.utf8).
function main:DetectUnicodeSupport()
	-- PoeCharm has utf8 global that normal PoB doesn't have
	self.unicode = type(_G.utf8) == "table"
	if self.unicode then
		ConPrintf("Unicode support detected")
	end
end

function main:SaveModCache()
	-- Update mod cache
	local out = io.open("Data/ModCache.lua", "w")
	out:write('local c=...')
	for line, dat in pairsSortByKey(modLib.parseModCache) do
		if not dat[1] or not dat[1][1] or (dat[1][1].name ~= "JewelFunc" and dat[1][1].name ~= "ExtraJewelFunc") then
			out:write('c["', line:gsub("\n","\\n"), '"]={')
			if dat[1] then
				writeLuaTable(out, dat[1])
			else
				out:write('nil')
			end
			if dat[2] then
				out:write(',"', dat[2]:gsub("\n","\\n"), '"}\n')
			else
				out:write(',nil}\n')
			end
		end
	end
	out:close()
end
-- Loading Tree and Initialization Functions:
--LoadTree() loads a specific tree version if it exists or returns nil.
--CanExit() checks if the application can exit and handles exit logic.
--Shutdown() performs shutdown tasks, saving settings, and calling shutdown methods for the current mode.
function main:LoadTree(treeVersion)
	if self.tree[treeVersion] then
		data.setJewelRadiiGlobally(treeVersion)
		return self.tree[treeVersion]
	elseif isValueInTable(treeVersionList, treeVersion) then
		data.setJewelRadiiGlobally(treeVersion)
		--ConPrintf("[main:LoadTree] - Lazy Loading Tree " .. treeVersion)
		self.tree[treeVersion] = new("PassiveTree", treeVersion)
		return self.tree[treeVersion]
	end
	return nil
end

function main:CanExit()
	local ret = self:CallMode("CanExit", "EXIT")
	if ret ~= nil then
		return ret
	else
		return true
	end
end

function main:Shutdown()
	self:CallMode("Shutdown")
	self:SaveSettings()
end

-- Frame Execution:
--OnFrame() is the main frame execution function:
--Handles screen size detection and adjusts layout based on screen dimensions.
--Manages mode changes and initializes mode-specific behaviors.
--Processes input events for popups or controls.
--Manages toast messages (displaying notifications).
--Draws GUI elements such as controls, popups, and drag text indicators.
function main:OnFrame()
	self.screenW, self.screenH = GetScreenSize()

	if self.screenH > self.screenW then
		self.portraitMode = true
	else
		self.portraitMode = false
	end
	while self.newMode do
		if self.mode then
			self:CallMode("Shutdown")
		end
		self.mode = self.newMode
		self.newMode = nil
		self:CallMode("Init", unpack(self.newModeArgs))
		if self.newModeChangeToTree then
			self.modes[self.mode].viewMode = "TREE"
		end
		self.newModeChangeToTree = false
	end

	self.viewPort = { x = 0, y = 0, width = self.screenW, height = self.screenH }

	if self.popups[1] then
		self.popups[1]:ProcessInput(self.inputEvents, self.viewPort)
		wipeTable(self.inputEvents)
	else
		self:ProcessControlsInput(self.inputEvents, self.viewPort)
	end

	self:CallMode("OnFrame", self.inputEvents, self.viewPort)

	if launch.updateErrMsg then
		t_insert(self.toastMessages, string.format("Update check failed!\n%s", launch.updateErrMsg))
		launch.updateErrMsg = nil
	end
	if launch.updateAvailable then
		if launch.updateAvailable == "none" then
			t_insert(self.toastMessages, "No update available\nYou are running the latest version.")
			launch.updateAvailable = nil
		elseif not self.updateAvailableShown then
			t_insert(self.toastMessages, "Update Available\nAn update has been downloaded and is ready\nto be applied.")
			self.updateAvailableShown = true
		end
	end

	-- Run toasts
	if self.toastMessages[1] then
		if not self.toastMode then
			self.toastMode = "SHOWING"
			self.toastStart = GetTime()
			self.toastHeight = #self.toastMessages[1]:gsub("[^\n]","") * 16 + 20 + 40
		end
		if self.toastMode == "SHOWING" then
			local now = GetTime()
			if now >= self.toastStart + 250 then
				self.toastMode = "SHOWN"
			else
				self.mainBarHeight = 58 + self.toastHeight * (now - self.toastStart) / 250
			end
		end
		if self.toastMode == "SHOWN" then
			self.mainBarHeight = 58 + self.toastHeight
		elseif self.toastMode == "HIDING" then
			local now = GetTime()
			if now >= self.toastStart + 75 then
				self.toastMode = nil
				self.mainBarHeight = 58
				t_remove(self.toastMessages, 1)
			else
				self.mainBarHeight = 58 + self.toastHeight * (1 - (now - self.toastStart) / 75)
			end
		end
		if self.toastMode then
			SetDrawColor(0.85, 0.85, 0.85)
			DrawImage(nil, 0, self.screenH - self.mainBarHeight, 312, self.mainBarHeight)
			SetDrawColor(0.1, 0.1, 0.1)
			DrawImage(nil, 0, self.screenH - self.mainBarHeight + 4, 308, self.mainBarHeight - 4)
			SetDrawColor(1, 1, 1)
			DrawString(4, self.screenH - self.mainBarHeight + 8, "LEFT", 20, "VAR", self.toastMessages[1]:gsub("\n.*",""))
			DrawString(4, self.screenH - self.mainBarHeight + 28, "LEFT", 16, "VAR", self.toastMessages[1]:gsub("^[^\n]*\n?",""))
		end
	end

	-- Draw main controls
	SetDrawColor(0.85, 0.85, 0.85)
	DrawImage(nil, 0, self.screenH - 58, 312, 58)
	SetDrawColor(0.1, 0.1, 0.1)
	DrawImage(nil, 0, self.screenH - 54, 308, 54)
	self:DrawControls(self.viewPort)

	if self.popups[1] then
		SetDrawLayer(10)
		SetDrawColor(0, 0, 0, 0.5)
		DrawImage(nil, 0, 0, self.screenW, self.screenH)
		self.popups[1]:Draw(self.viewPort)
		SetDrawLayer(0)
	end

	if self.showDragText then
		local cursorX, cursorY = GetCursorPos()
		local strWidth = DrawStringWidth(16, "VAR", self.showDragText)
		SetDrawLayer(20, 0)
		SetDrawColor(0.15, 0.15, 0.15, 0.75)
		DrawImage(nil, cursorX, cursorY - 8, strWidth + 2, 18)
		SetDrawColor(1, 1, 1)
		DrawString(cursorX + 1, cursorY - 7, "LEFT", 16, "VAR", self.showDragText)
		self.showDragText = nil
	end

	--[[local par = 300
	for x = 0, 750 do
		for y = 0, 750 do
			local dpsCol = (x / par * 1.5) ^ 0.5
			local defCol = (y / par * 1.5) ^ 0.5
			local mixCol = (m_max(dpsCol - 0.5, 0) + m_max(defCol - 0.5, 0)) / 2
			if main.nodePowerTheme == "RED/BLUE" then
				SetDrawColor(dpsCol, mixCol, defCol)
			elseif main.nodePowerTheme == "RED/GREEN" then
				SetDrawColor(dpsCol, defCol, mixCol)
			elseif main.nodePowerTheme == "GREEN/BLUE" then
				SetDrawColor(mixCol, dpsCol, defCol)
			end
			DrawImage(nil, x + 500, y + 200, 1, 1)
		end
	end
	SetDrawColor(0, 0, 0)
	DrawImage(nil, par + 500, 200, 2, 750)
	DrawImage(nil, 500, par + 200, 759, 2)]]

	-- Key Event Handling:
	--Processes key events in the GUI. If the F1 key is pressed (KeyUp event), it triggers the display of an "About" popup based on the current view mode (self.mode) or defaults to the "Build List" tab.
	if self.inputEvents and not itemLib.wiki.triggered then
		for _, event in ipairs(self.inputEvents) do
			if event.type == "KeyUp" and event.key == "F1" then
				local tabName = (self.modes[self.mode].viewMode and self.modes[self.mode].viewMode:lower() or "Build List") .. " tab"
				self:OpenAboutPopup(tabName or 1)
				break
			end
		end
	end
	itemLib.wiki.triggered = false

	wipeTable(self.inputEvents)

	-- TODO: this pattern may pose memory management issues for classes that don't exist for the lifetime of the program
	for _, onFrameFunc in pairs(self.onFrameFuncs) do
		onFrameFunc()
	end
end

-- Input Event Handling:
--Defines three methods (OnKeyDown, OnKeyUp, OnChar) for handling different types of key events (KeyDown, KeyUp, Char) and stores the events in self.inputEvents.
function main:OnKeyDown(key, doubleClick)
	t_insert(self.inputEvents, { type = "KeyDown", key = key, doubleClick = doubleClick })
end

function main:OnKeyUp(key)
	t_insert(self.inputEvents, { type = "KeyUp", key = key })
end

function main:OnChar(key)
	t_insert(self.inputEvents, { type = "Char", key = key })
end

-- Mode Management:
--SetMode() sets a new mode for the application based on provided arguments.
--CallMode() calls a specific function within the current mode, if it exists.
function main:SetMode(newMode, ...)
	self.newMode = newMode
	self.newModeArgs = {...}
end

function main:CallMode(func, ...)
	local modeTbl = self.modes[self.mode]
	if modeTbl and modeTbl[func] then
		return modeTbl[func](modeTbl, ...)
	end
end

--Settings Loading:
--LoadSettings() loads application settings from an XML file (Settings.xml) stored in the user's path (self.userPath).
--Parses various settings related to modes, accounts, miscellaneous configurations, such as sorting, colors, separators, warnings, etc.
--Updates application variables based on the parsed settings.
function main:LoadSettings(ignoreBuild)
	local setXML, errMsg = common.xml.LoadXMLFile(self.userPath.."Settings.xml")
	if not setXML then
		return true
	elseif setXML[1].elem ~= "PathOfBuilding" then
		launch:ShowErrMsg("^1Error parsing 'Settings.xml': 'PathOfBuilding' root element missing")
		return true
	end
	for _, node in ipairs(setXML[1]) do
		if type(node) == "table" then
			if not ignoreBuild and node.elem == "Mode" then
				if not node.attrib.mode or not self.modes[node.attrib.mode] then
					launch:ShowErrMsg("^1Error parsing 'Settings.xml': Invalid mode attribute in 'Mode' element")
					return true
				end
				local args = { }
				for _, child in ipairs(node) do
					if type(child) == "table" then
						if child.elem == "Arg" then
							if child.attrib.number then
								t_insert(args, tonumber(child.attrib.number))
							elseif child.attrib.string then
								t_insert(args, child.attrib.string)
							elseif child.attrib.boolean then
								t_insert(args, child.attrib.boolean == "true")
							end
						end
					end
				end
				self:SetMode(node.attrib.mode, unpack(args))
			elseif node.elem == "Accounts" then
				self.lastAccountName = node.attrib.lastAccountName
				self.lastRealm = node.attrib.lastRealm
				for _, child in ipairs(node) do
					if child.elem == "Account" then
						self.gameAccounts[child.attrib.accountName] = {
							sessionID = child.attrib.sessionID,
						}
					end
				end
			elseif node.elem == "Misc" then
				if node.attrib.buildSortMode then
					self.buildSortMode = node.attrib.buildSortMode
				end
				launch.connectionProtocol = tonumber(node.attrib.connectionProtocol)
				launch.proxyURL = node.attrib.proxyURL
				if node.attrib.buildPath then
					self.buildPath = node.attrib.buildPath
				end
				if node.attrib.nodePowerTheme then
					self.nodePowerTheme = node.attrib.nodePowerTheme
				end
				if node.attrib.colorPositive then
					updateColorCode("POSITIVE", node.attrib.colorPositive)
					self.colorPositive = node.attrib.colorPositive
				end
				if node.attrib.colorNegative then
					updateColorCode("NEGATIVE", node.attrib.colorNegative)
					self.colorNegative = node.attrib.colorNegative
				end
				if node.attrib.colorHighlight then
					updateColorCode("HIGHLIGHT", node.attrib.colorHighlight)
					self.colorHighlight = node.attrib.colorHighlight
				end

				-- In order to preserve users' settings through renaming/merging this variable, we have this if statement to use the first found setting
				-- Once the user has closed PoB once, they will be using the new `showThousandsSeparator` variable name, so after some time, this statement may be removed
				if node.attrib.showThousandsCalcs then
					self.showThousandsSeparators = node.attrib.showThousandsCalcs == "true"
				elseif node.attrib.showThousandsSidebar then
					self.showThousandsSeparators = node.attrib.showThousandsSidebar == "true"
				end
				if node.attrib.showThousandsSeparators then
					self.showThousandsSeparators = node.attrib.showThousandsSeparators == "true"
				end
				if node.attrib.thousandsSeparator then
					self.thousandsSeparator = node.attrib.thousandsSeparator
				end
				if node.attrib.decimalSeparator then
					self.decimalSeparator = node.attrib.decimalSeparator
				end
				if node.attrib.showTitlebarName then
					self.showTitlebarName = node.attrib.showTitlebarName == "true"
				end
				if node.attrib.betaTest then
					self.betaTest = node.attrib.betaTest == "true"
				end
				if node.attrib.defaultGemQuality then
					self.defaultGemQuality = m_min(tonumber(node.attrib.defaultGemQuality) or 0, 23)
				end
				if node.attrib.defaultCharLevel then
					self.defaultCharLevel = m_min(m_max(tonumber(node.attrib.defaultCharLevel) or 1, 1), 100)
				end
				if node.attrib.defaultItemAffixQuality then
					self.defaultItemAffixQuality = m_min(tonumber(node.attrib.defaultItemAffixQuality) or 0.5, 1)
				end
				if node.attrib.lastExportWebsite then
					self.lastExportWebsite = node.attrib.lastExportWebsite
				end
				if node.attrib.showWarnings then
					self.showWarnings = node.attrib.showWarnings == "true"
				end
				if node.attrib.slotOnlyTooltips then
					self.slotOnlyTooltips = node.attrib.slotOnlyTooltips == "true"
				end
				if node.attrib.POESESSID then
					self.POESESSID = node.attrib.POESESSID or ""
				end
				if node.attrib.invertSliderScrollDirection then
					self.invertSliderScrollDirection = node.attrib.invertSliderScrollDirection == "true"
				end
				if node.attrib.disableDevAutoSave then
					self.disableDevAutoSave = node.attrib.disableDevAutoSave == "true"
				end
			end
		end
	end
end

--main:LoadSharedItems()
--Loads shared items from the XML file into the application's memory.
--Parses the XML file and extracts shared items and item sets.
--Constructs items and item sets using the provided data and stores them in self.sharedItemList and self.sharedItemSetList respectively.
function main:LoadSharedItems()
	local setXML, errMsg = common.xml.LoadXMLFile(self.userPath.."Settings.xml")
	if not setXML then
		return true
	elseif setXML[1].elem ~= "PathOfBuilding" then
		launch:ShowErrMsg("^1Error parsing 'Settings.xml': 'PathOfBuilding' root element missing")
		return true
	end
	for _, node in ipairs(setXML[1]) do
		if type(node) == "table" then
			if node.elem == "SharedItems" then
				for _, child in ipairs(node) do
					if child.elem == "Item" then
						local rawItem = { raw = "" }
						for _, subChild in ipairs(child) do
							if type(subChild) == "string" then
								rawItem.raw = subChild
							end
						end
						local newItem = new("Item", rawItem.raw)
						t_insert(self.sharedItemList, newItem)
					elseif child.elem == "ItemSet" then
						local sharedItemSet = { title = child.attrib.title, slots = { } }
						for _, grandChild in ipairs(child) do
							if grandChild.elem == "Item" then
								local rawItem = { raw = "" }
								for _, subChild in ipairs(grandChild) do
									if type(subChild) == "string" then
										rawItem.raw = subChild
									end
								end
								local newItem = new("Item", rawItem.raw)
								sharedItemSet.slots[grandChild.attrib.slotName] = newItem
							end
						end
						t_insert(self.sharedItemSetList, sharedItemSet)
					end
				end
			end
		end
	end
end

--main:SaveSettings()
--Constructs an XML structure to save settings and shared items.
--Creates XML elements and attributes based on the application's configuration.
--Builds the XML structure with mode, accounts, shared items, and miscellaneous settings.
--Writes the constructed XML structure into the Settings.xml file using common.xml.SaveXMLFile().
function main:SaveSettings()
	local setXML = { elem = "PathOfBuilding" }
	local mode = { elem = "Mode", attrib = { mode = self.mode } }
	for _, val in ipairs({ self:CallMode("GetArgs") }) do
		local child = { elem = "Arg", attrib = { } }
		if type(val) == "number" then
			child.attrib.number = tostring(val)
		elseif type(val) == "boolean" then
			child.attrib.boolean = tostring(val)
		else
			child.attrib.string = tostring(val)
		end
		t_insert(mode, child)
	end
	t_insert(setXML, mode)
	local accounts = { elem = "Accounts", attrib = { lastAccountName = self.lastAccountName, lastRealm = self.lastRealm } }
	for accountName, account in pairs(self.gameAccounts) do
		t_insert(accounts, { elem = "Account", attrib = { accountName = accountName, sessionID = account.sessionID } })
	end
	t_insert(setXML, accounts)
	local sharedItemList = { elem = "SharedItems" }
	for _, verItem in ipairs(self.sharedItemList) do
		t_insert(sharedItemList, { elem = "Item", [1] = verItem.raw })
	end
	for _, sharedItemSet in ipairs(self.sharedItemSetList) do
		local set = { elem = "ItemSet", attrib = { title = sharedItemSet.title } }
		for slotName, verItem in pairs(sharedItemSet.slots) do
			t_insert(set, { elem = "Item", attrib = { slotName = slotName }, [1] = verItem.raw })
		end
		t_insert(sharedItemList, set)
	end
	t_insert(setXML, sharedItemList)
	t_insert(setXML, { elem = "Misc", attrib = {
		buildSortMode = self.buildSortMode,
		connectionProtocol = tostring(launch.connectionProtocol),
		proxyURL = launch.proxyURL,
		buildPath = (self.buildPath ~= self.defaultBuildPath and self.buildPath or nil),
		nodePowerTheme = self.nodePowerTheme,
		colorPositive = self.colorPositive,
		colorNegative = self.colorNegative,
		colorHighlight = self.colorHighlight,
		showThousandsSeparators = tostring(self.showThousandsSeparators),
		thousandsSeparator = self.thousandsSeparator,
		decimalSeparator = self.decimalSeparator,
		showTitlebarName = tostring(self.showTitlebarName),
		betaTest = tostring(self.betaTest),
		defaultGemQuality = tostring(self.defaultGemQuality or 0),
		defaultCharLevel = tostring(self.defaultCharLevel or 1),
		defaultItemAffixQuality = tostring(self.defaultItemAffixQuality or 0.5),
		lastExportWebsite = self.lastExportWebsite,
		showWarnings = tostring(self.showWarnings),
		slotOnlyTooltips = tostring(self.slotOnlyTooltips),
		POESESSID = self.POESESSID,
		invertSliderScrollDirection = tostring(self.invertSliderScrollDirection),
		disableDevAutoSave = tostring(self.disableDevAutoSave),
	} })
	local res, errMsg = common.xml.SaveXMLFile(setXML, self.userPath.."Settings.xml")
	if not res then
		launch:ShowErrMsg("Error saving 'Settings.xml': %s", errMsg)
		return true
	end
end

--OpenOptionsPopup()
--Creates a popup window for configuring application options.
--Dynamically generates UI controls (dropdowns, labels, checkboxes, etc.) based on settings such as connection protocol, proxy settings, build paths, colors, and more.
--Allows users to modify various settings interactively (e.g., connection protocol, proxy settings, colors, default character level, etc.).
--Provides options to save or cancel changes made in the popup.
function main:OpenOptionsPopup()
	local controls = { }

	local currentY = 20
	local popupWidth = 600

	-- local func to make a new line with a heightModifier
	local function nextRow(heightModifier)
		local pxPerLine = 26
		heightModifier = heightModifier or 1
		currentY = currentY + heightModifier * pxPerLine
	end

	-- local func to make a new section header
	local function drawSectionHeader(id, title, omitHorizontalLine)
		local headerBGColor ={ .6, .6, .6}
		controls["section-"..id .. "-bg"] = new("RectangleOutlineControl", { "TOPLEFT", nil, "TOPLEFT" }, 8, currentY, popupWidth - 17, 26, headerBGColor, 1)
		nextRow(.2)
		controls["section-"..id .. "-label"] = new("LabelControl", { "TOPLEFT", nil, "TOPLEFT" }, popupWidth / 2 - 60, currentY, 0, 16, "^7" .. title)
		nextRow(1.5)
	end

	local defaultLabelSpacingPx = -4
	local defaultLabelPlacementX = 240

	drawSectionHeader("app", "Application options")

	controls.connectionProtocol = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 100, 18, {
		{ label = "Auto", protocol = 0 },
		{ label = "IPv4", protocol = 1 },
		{ label = "IPv6", protocol = 2 },
	}, function(index, value)
		self.connectionProtocol = value.protocol
	end)
	controls.connectionProtocolLabel = new("LabelControl", { "RIGHT", controls.connectionProtocol, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Connection Protocol:")
	controls.connectionProtocol.tooltipText = "Changes which protocol is used when downloading updates and importing builds."
	controls.connectionProtocol:SelByValue(launch.connectionProtocol, "protocol")

	nextRow()
	controls.proxyType = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 80, 18, {
		{ label = "HTTP", scheme = "http" },
		{ label = "SOCKS", scheme = "socks5" },
		{ label = "SOCKS5H", scheme = "socks5h" },
	})
	controls.proxyLabel = new("LabelControl", { "RIGHT", controls.proxyType, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Proxy server:")
	controls.proxyURL = new("EditControl", { "LEFT", controls.proxyType, "RIGHT" }, 4, 0, 206, 18)

	if launch.proxyURL then
		local scheme, url = launch.proxyURL:match("(%w+)://(.+)")
		controls.proxyType:SelByValue(scheme, "scheme")
		controls.proxyURL:SetText(url)
	end

	nextRow()
	controls.buildPath = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 290, 18)
	controls.buildPathLabel = new("LabelControl", { "RIGHT", controls.buildPath, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Build save path:")
	if self.buildPath ~= self.defaultBuildPath then
		controls.buildPath:SetText(self.buildPath)
	end
	controls.buildPath.tooltipText = "Overrides the default save location for builds.\nThe default location is: '"..self.defaultBuildPath.."'"

	nextRow()
	controls.nodePowerTheme = new("DropDownControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 100, 18, {
		{ label = "Red & Blue", theme = "RED/BLUE" },
		{ label = "Red & Green", theme = "RED/GREEN" },
		{ label = "Green & Blue", theme = "GREEN/BLUE" },
	}, function(index, value)
		self.nodePowerTheme = value.theme
	end)
	controls.nodePowerThemeLabel = new("LabelControl", { "RIGHT", controls.nodePowerTheme, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Node Power colours:")
	controls.nodePowerTheme.tooltipText = "Changes the colour scheme used for the node power display on the passive tree."
	controls.nodePowerTheme:SelByValue(self.nodePowerTheme, "theme")

	nextRow()
	controls.colorPositive = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 100, 18, tostring(self.colorPositive:gsub('^(^)', '0')), nil, nil, 8, function(buf)
		local match = string.match(buf, "0x%x+")
		if match and #match == 8 then
			updateColorCode("POSITIVE", buf)
			self.colorPositive = buf
		end
	end)
	controls.colorPositiveLabel = new("LabelControl", { "RIGHT", controls.colorPositive, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Hex colour for positive values:")
	controls.colorPositive.tooltipText = "Overrides the default hex colour for positive values in breakdowns. \nExpected format is 0x000000. " ..
		"The default value is " .. tostring(defaultColorCodes.POSITIVE:gsub('^(^)', '0')) .. ".\nIf updating while inside a build, please re-load the build after saving."

	nextRow()
	controls.colorNegative = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 100, 18, tostring(self.colorNegative:gsub('^(^)', '0')), nil, nil, 8, function(buf)
		local match = string.match(buf, "0x%x+")
		if match and #match == 8 then
			updateColorCode("NEGATIVE", buf)
			self.colorNegative = buf
		end
	end)
	controls.colorNegativeLabel = new("LabelControl", { "RIGHT", controls.colorNegative, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Hex colour for negative values:")
	controls.colorNegative.tooltipText = "Overrides the default hex colour for negative values in breakdowns. \nExpected format is 0x000000. " ..
		"The default value is " .. tostring(defaultColorCodes.NEGATIVE:gsub('^(^)', '0')) .. ".\nIf updating while inside a build, please re-load the build after saving."

	nextRow()
	controls.colorHighlight = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 100, 18, tostring(self.colorHighlight:gsub('^(^)', '0')), nil, nil, 8, function(buf)
		local match = string.match(buf, "0x%x+")
		if match and #match == 8 then
			updateColorCode("HIGHLIGHT", buf)
			self.colorHighlight = buf
		end
	end)
	controls.colorHighlightLabel = new("LabelControl", { "RIGHT", controls.colorHighlight, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Hex colour for highlight nodes:")
	controls.colorHighlight.tooltipText = "Overrides the default hex colour for highlighting nodes in passive tree search. \nExpected format is 0x000000. " ..
		"The default value is " .. tostring(defaultColorCodes.HIGHLIGHT:gsub('^(^)', '0')) .."\nIf updating while inside a build, please re-load the build after saving."
			
	nextRow()
	controls.betaTest = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 20, "^7Opt-in to weekly beta test builds:", function(state)
		self.betaTest = state
	end)

	nextRow()
	drawSectionHeader("build", "Build-related options")

	controls.showThousandsSeparators = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT"}, defaultLabelPlacementX, currentY, 20, "^7Show thousands separators:", function(state)
	self.showThousandsSeparators = state
	end)
	controls.showThousandsSeparators.state = self.showThousandsSeparators

	nextRow()
	controls.thousandsSeparator = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 30, 20, self.thousandsSeparator, nil, "%w", 1, function(buf)
		self.thousandsSeparator = buf
	end)
	controls.thousandsSeparatorLabel = new("LabelControl", { "RIGHT", controls.thousandsSeparator, "LEFT" }, defaultLabelSpacingPx, 0, 92, 16, "^7Thousands separator:")

	nextRow()
	controls.decimalSeparator = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 30, 20, self.decimalSeparator, nil, "%w", 1, function(buf)
		self.decimalSeparator = buf
	end)
	controls.decimalSeparatorLabel = new("LabelControl", { "RIGHT", controls.decimalSeparator, "LEFT" }, defaultLabelSpacingPx, 0, 92, 16, "^7Decimal separator:")

	nextRow()
	controls.titlebarName = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 20, "^7Show build name in window title:", function(state)
		self.showTitlebarName = state
	end)

	nextRow()
	controls.defaultGemQuality = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 80, 20, self.defaultGemQuality, nil, "%D", 2, function(gemQuality)
		self.defaultGemQuality = m_min(tonumber(gemQuality) or 0, 23)
	end)
	controls.defaultGemQuality.tooltipText = "Set the default quality that can be overwritten by build-related quality settings in the skill panel."
	controls.defaultGemQualityLabel = new("LabelControl", { "RIGHT", controls.defaultGemQuality, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Default gem quality:")

	nextRow()
	controls.defaultCharLevel = new("EditControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 80, 20, self.defaultCharLevel, nil, "%D", 3, function(charLevel)
		self.defaultCharLevel = m_min(m_max(tonumber(charLevel) or 1, 1), 100)
	end)
	controls.defaultCharLevel.tooltipText = "Set the default level of your builds. If this is higher than 1, manual level mode will be enabled by default in new builds."
	controls.defaultCharLevelLabel = new("LabelControl", { "RIGHT", controls.defaultCharLevel, "LEFT" }, defaultLabelSpacingPx, 0, 0, 16, "^7Default character level:")

	nextRow()
	controls.defaultItemAffixQualitySlider = new("SliderControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 200, 20, function(value)
		self.defaultItemAffixQuality = round(value, 2)
		controls.defaultItemAffixQualityValue.label = (self.defaultItemAffixQuality * 100) .. "%"
	end)
	controls.defaultItemAffixQualityLabel = new("LabelControl", { "RIGHT", controls.defaultItemAffixQualitySlider, "LEFT" }, defaultLabelSpacingPx, 0, 92, 16, "^7Default item affix quality:")
	controls.defaultItemAffixQualityValue = new("LabelControl", { "LEFT", controls.defaultItemAffixQualitySlider, "RIGHT" }, -defaultLabelSpacingPx, 0, 92, 16, "50%")
	controls.defaultItemAffixQualitySlider.val = self.defaultItemAffixQuality
	controls.defaultItemAffixQualityValue.label = (self.defaultItemAffixQuality * 100) .. "%"

	nextRow()
	controls.showWarnings = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 20, "^7Show build warnings:", function(state)
		self.showWarnings = state
	end)
	controls.showWarnings.state = self.showWarnings

	nextRow()
	controls.slotOnlyTooltips = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 20, "^7Show tooltips only for affected slots:", function(state)
		self.slotOnlyTooltips = state
	end)
	controls.slotOnlyTooltips.state = self.slotOnlyTooltips
	
	nextRow()
	controls.invertSliderScrollDirection = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 20, "^7Invert slider scroll direction:", function(state)
		self.invertSliderScrollDirection = state
	end)
	controls.invertSliderScrollDirection.tooltipText = "Default scroll direction is:\nScroll Up = Move right\nScroll Down = Move left"
	controls.invertSliderScrollDirection.state = self.invertSliderScrollDirection
	
	if launch.devMode then
		nextRow()
		controls.disableDevAutoSave = new("CheckBoxControl", { "TOPLEFT", nil, "TOPLEFT" }, defaultLabelPlacementX, currentY, 20, "^7Disable Dev AutoSave:", function(state)
			self.disableDevAutoSave = state
		end)
		controls.disableDevAutoSave.tooltipText = "Do not Autosave builds while on Dev branch"
		controls.disableDevAutoSave.state = self.disableDevAutoSave
	end

	controls.betaTest.state = self.betaTest
	controls.titlebarName.state = self.showTitlebarName
	local initialNodePowerTheme = self.nodePowerTheme
	local initialColorPositive = self.colorPositive
	local initialColorNegative = self.colorNegative
	local initialColorHighlight = self.colorHighlight
	local initialThousandsSeparatorDisplay = self.showThousandsSeparators
	local initialTitlebarName = self.showTitlebarName
	local initialThousandsSeparator = self.thousandsSeparator
	local initialDecimalSeparator = self.decimalSeparator
	local initialBetaTest = self.betaTest
	local initialDefaultGemQuality = self.defaultGemQuality or 0
	local initialDefaultCharLevel = self.defaultCharLevel or 1
	local initialDefaultItemAffixQuality = self.defaultItemAffixQuality or 0.5
	local initialShowWarnings = self.showWarnings
	local initialSlotOnlyTooltips = self.slotOnlyTooltips
	local initialInvertSliderScrollDirection = self.invertSliderScrollDirection
	local initialDisableDevAutoSave = self.disableDevAutoSave

	-- last line with buttons has more spacing
	nextRow(1.5)

	controls.save = new("ButtonControl", nil, -45, currentY, 80, 20, "Save", function()
		launch.connectionProtocol = tonumber(self.connectionProtocol)
		if controls.proxyURL.buf:match("%w") then
			launch.proxyURL = controls.proxyType.list[controls.proxyType.selIndex].scheme .. "://" .. controls.proxyURL.buf
		else
			launch.proxyURL = nil
		end
		if controls.buildPath.buf:match("%S") then
			self.buildPath = controls.buildPath.buf
			if not self.buildPath:match("[\\/]$") then
				self.buildPath = self.buildPath .. "/"
			end
		else
			self.buildPath = self.defaultBuildPath
		end
		if self.mode == "LIST" then
			self.modes.LIST:BuildList()
		end
		if not launch.devMode then
			main:SetManifestBranch(self.betaTest and "beta" or "master")
		end
		main:ClosePopup()
		main:SaveSettings()
	end)
	controls.cancel = new("ButtonControl", nil, 45, currentY, 80, 20, "Cancel", function()
		self.nodePowerTheme = initialNodePowerTheme
		self.colorPositive = initialColorPositive
		updateColorCode("POSITIVE", self.colorPositive)
		self.colorNegative = initialColorNegative
		updateColorCode("NEGATIVE", self.colorNegative)
		self.colorHighlight = initialColorHighlight
		updateColorCode("HIGHLIGHT", self.colorHighlight)
		self.showThousandsSeparators = initialThousandsSeparatorDisplay
		self.thousandsSeparator = initialThousandsSeparator
		self.decimalSeparator = initialDecimalSeparator
		self.showTitlebarName = initialTitlebarName
		self.betaTest = initialBetaTest
		self.defaultGemQuality = initialDefaultGemQuality
		self.defaultCharLevel = initialDefaultCharLevel
		self.defaultItemAffixQuality = initialDefaultItemAffixQuality
		self.showWarnings = initialShowWarnings
		self.slotOnlyTooltips = initialSlotOnlyTooltips
		self.invertSliderScrollDirection = initialInvertSliderScrollDirection
		self.disableDevAutoSave = initialDisableDevAutoSave
		main:ClosePopup()
	end)
	nextRow(1.5)
	self:OpenPopup(popupWidth, currentY, "Options", controls, "save", nil, "cancel")
end

-- SetManifestBranch(branchName)
--Updates a specific attribute within an XML file (manifest.xml) that seems to handle the program's versioning or branch information.
--Opens and modifies the XML content to change the branch information based on the provided branchName.
function main:SetManifestBranch(branchName)
	local xml = require("xml")
	local manifestLocation = "manifest.xml"
	local localManXML = xml.LoadXMLFile(manifestLocation)
	if not localManXML then
		manifestLocation = "../manifest.xml"
		localManXML = xml.LoadXMLFile(manifestLocation)
	end
	if localManXML and localManXML[1].elem == "PoBVersion" then
		for _, node in ipairs(localManXML[1]) do
			if type(node) == "table" then
				if node.elem == "Version" then
					node.attrib.branch = branchName
				end
			end
		end
	end
	xml.SaveXMLFile(localManXML[1], manifestLocation)
end

-- OpenUpdatePopup()
--Generates a popup window displaying updates or changes in the application version.
--Reads and parses a changelog.txt file to extract version-specific updates and dates.
--Creates a UI text list with version numbers and their associated updates.
--Provides options to either update the application or cancel the update process.
function main:OpenUpdatePopup()
	local changeList = { }
	local changelogName = launch.devMode and "../changelog.txt" or "changelog.txt"
	local changelogFile = io.open(changelogName, "r")
	if changelogFile then
		changelogFile:close()
		for line in io.lines(changelogName) do
			local ver, date = line:match("^VERSION%[(.+)%]%[(.+)%]$")
			if ver then
				if ver == launch.versionNumber then
					break
				end
				if #changeList > 0 then
					t_insert(changeList, { height = 12 })
				end
				t_insert(changeList, { height = 20, "^7Version "..ver.." ("..date..")" })
			else
				t_insert(changeList, { height = 14, "^7"..line })
			end
		end
	end
	local controls = { }
	controls.changeLog = new("TextListControl", nil, 0, 20, 780, 542, nil, changeList)
	controls.update = new("ButtonControl", nil, -45, 570, 80, 20, "Update", function()
		self:ClosePopup()
		local ret = self:CallMode("CanExit", "UPDATE")
		if ret == nil or ret == true then
			launch:ApplyUpdate(launch.updateAvailable)
		end
	end)
	controls.cancel = new("ButtonControl", nil, 45, 570, 80, 20, "Cancel", function()
		self:ClosePopup()
	end)
	self:OpenPopup(800, 600, "Update Available", controls)
end

-- main:OpenAboutPopup(helpSectionIndex)
--This function seems to create a popup window containing information about the application.
--It reads from changelog.txt and help.txt to populate the changelog and help sections respectively.
--It creates controls for version history, help sections, and a text list control to display either the changelog or help information based on the input helpSectionIndex.
function main:OpenAboutPopup(helpSectionIndex)
	local textSize, titleSize, popupWidth = 16, 24, 810
	local changeList = { }
	local changeVersionHeights = { }
	local changelogName = launch.devMode and "../changelog.txt" or "changelog.txt"
	local changelogFile = io.open(changelogName, "r")
	if changelogFile then
		changelogFile:close()
		for line in io.lines(changelogName) do
			local ver, date = line:match("^VERSION%[(.+)%]%[(.+)%]$")
			if ver then
				if #changeList > 0 then
					t_insert(changeList, { height = textSize / 2 })
				end
				t_insert(changeVersionHeights, #changeList * textSize)
				t_insert(changeList, { height = titleSize, "^7Version "..ver.." ("..date..")" })
			else
				t_insert(changeList, { height = textSize, "^7"..line })
			end
		end
	end
	local helpList = { }
	local helpSections = { }
	local helpSectionHeights = { }
	do
		local helpName = launch.devMode and "../help.txt" or "help.txt"
		local helpFile = io.open(helpName, "r")
		if helpFile then
			helpFile:close()
			for line in io.lines(helpName) do
				local title = line:match("^---%[(.+)%]$")
				if title then
					if #helpList > 0 then
						t_insert(helpList, { height = textSize / 2 })
					end
					t_insert(helpSections, { title = title, height = #helpList })
					t_insert(helpList, { height = titleSize, "^7"..title.." ("..#helpSections..")" })
				else
					local dev = line:match("^DEV%[(.+)%]$")
					if not ( dev and not launch.devMode ) then
						line = (dev or line)
						local outdent, indent = line:match("(.*)\t+(.*)")
						if outdent then
							local indentLines = self:WrapString(indent, textSize, popupWidth - 190)
							if #indentLines > 1 then
								for i, indentLine in ipairs(indentLines) do
									t_insert(helpList, { height = textSize, (i == 1 and outdent or " "), (dev and "^x8888FF" or "^7")..indentLine })
								end
							else
								t_insert(helpList, { height = textSize, (dev and "^x8888FF" or "^7")..outdent, (dev and "^x8888FF" or "^7")..indent })
							end
						else
							local Lines = self:WrapString(line, textSize, popupWidth - 135)
							for i, line2 in ipairs(Lines) do
								t_insert(helpList, { height = textSize, (dev and "^x8888FF" or "^7")..(i > 1 and "    " or "")..line2 })
							end
						end
					end
				end
			end
			local contentsDone = false
			for sectionIndex, sectionValues in ipairs(helpSections) do
				if sectionValues.title == "Contents" then
					t_insert(helpList, (sectionValues.height + sectionIndex), { height = textSize, "^7 "})
					for i, sectionValuesInner in ipairs(helpSections) do
						t_insert(helpList, (sectionValues.height + i + sectionIndex), { height = textSize, "^7"..tostring(i)..". "..sectionValuesInner.title })
					end
				end
				helpSections[sectionIndex].height = helpSections[sectionIndex].height + (contentsDone and (#helpSections + 1) or 0)
				helpSectionHeights[sectionIndex] = helpSections[sectionIndex].height * textSize
				if sectionValues.title == "Contents" then
					contentsDone = true
				end
			end
			helpSections.total = #helpList + #helpSections + 1
		end
	end
	if helpSectionIndex and not helpSections[helpSectionIndex] then
		local newIndex = 1
		for sectionIndex, sectionValues in ipairs(helpSections) do
			if sectionValues.title:lower() == helpSectionIndex then
				newIndex = sectionIndex
				break
			end
		end
		helpSectionIndex = newIndex
	end
	local controls = { }
	controls.close = new("ButtonControl", {"TOPRIGHT",nil,"TOPRIGHT"}, -10, 10, 50, 20, "Close", function()
		self:ClosePopup()
	end)
	controls.version = new("LabelControl", nil, 0, 18, 0, 18, "^7Path of Building Community Fork v"..launch.versionNumber)
	controls.forum = new("LabelControl", nil, 0, 36, 0, 18, "^7Based on Openarl's Path of Building")
	controls.github = new("ButtonControl", nil, 0, 62, 438, 18, "^7GitHub page: ^x4040FFhttps://github.com/PathOfBuildingCommunity/PathOfBuilding", function(control)
		OpenURL("https://github.com/PathOfBuildingCommunity/PathOfBuilding")
	end)
	controls.verLabel = new("ButtonControl", { "TOPLEFT", nil, "TOPLEFT" }, 10, 85, 100, 18, "^7Version history:", function()
		controls.changelog.list = changeList
		controls.changelog.sectionHeights = changeVersionHeights
	end)
	controls.helpLabel = new("ButtonControl", { "TOPRIGHT", nil, "TOPRIGHT" }, -10, 85, 40, 18, "^7Help:", function()
		controls.changelog.list = helpList
		controls.changelog.sectionHeights = helpSectionHeights
	end)
	controls.changelog = new("TextListControl", nil, 0, 103, popupWidth - 20, 515, {{ x = 1, align = "LEFT" }, { x = 135, align = "LEFT" }}, helpSectionIndex and helpList or changeList, helpSectionIndex and helpSectionHeights or changeVersionHeights)
	if helpSectionIndex then
		controls.changelog.controls.scrollBar.offset = helpSections[helpSectionIndex].height * textSize
	end
	self:OpenPopup(popupWidth, 628, "About", controls)
end

-- main:DrawBackground(viewPort)
--This function is responsible for drawing the background of the application based on the provided viewPort dimensions.
--It checks for different background images (Background1 and Background2) and draws them accordingly.
function main:DrawBackground(viewPort)
	SetDrawLayer(nil, -100)
	SetDrawColor(0.5, 0.5, 0.5)
	if self.tree[latestTreeVersion].assets.Background2 then
		DrawImage(self.tree[latestTreeVersion].assets.Background2.handle, viewPort.x, viewPort.y, viewPort.width, viewPort.height, 0, 0, viewPort.width / 100, viewPort.height / 100)
	else
		DrawImage(self.tree[latestTreeVersion].assets.Background1.handle, viewPort.x, viewPort.y, viewPort.width, viewPort.height, 0, 0, viewPort.width / 100, viewPort.height / 100)
	end
	SetDrawLayer(nil, 0)
end

-- main:DrawArrow(x, y, width, height, dir)
--This function draws an arrow at the specified x and y coordinates based on the provided direction (dir: UP, RIGHT, DOWN, LEFT).
--It calculates the vertices of the arrow shape and then renders it.
function main:DrawArrow(x, y, width, height, dir)
	local x1 = x - width / 2
	local x2 = x + width / 2
	local xMid = (x1 + x2) / 2
	local y1 = y - height / 2
	local y2 = y + height / 2
	local yMid = (y1 + y2) / 2
	if dir == "UP" then
		DrawImageQuad(nil, xMid, y1, xMid, y1, x2, y2, x1, y2)
	elseif dir == "RIGHT" then
		DrawImageQuad(nil, x1, y1, x2, yMid, x2, yMid, x1, y2)
	elseif dir == "DOWN" then
		DrawImageQuad(nil, x1, y1, x2, y1, xMid, y2, xMid, y2)
	elseif dir == "LEFT" then
		DrawImageQuad(nil, x1, yMid, x2, y1, x2, y2, x1, yMid)
	end
end

function main:DrawCheckMark(x, y, size)
	size = size / 0.8
	x = x - size / 2
	y = y - size / 2
	DrawImageQuad(nil, x + size * 0.15, y + size * 0.50, x + size * 0.30, y + size * 0.45, x + size * 0.50, y + size * 0.80, x + size * 0.40, y + size * 0.90)
	DrawImageQuad(nil, x + size * 0.40, y + size * 0.90, x + size * 0.35, y + size * 0.75, x + size * 0.80, y + size * 0.10, x + size * 0.90, y + size * 0.20)
end

-- main:WorldToScreen(x, y, z, width, height)
--Converts world coordinates (x, y, z) to screen coordinates based on the given width and height of the viewport.
--The function involves several mathematical calculations to perform the conversion.
do
	local cos45 = m_cos(m_pi / 4)
	local cos35 = m_cos(m_pi * 0.195)
	local sin35 = m_sin(m_pi * 0.195)
	function main:WorldToScreen(x, y, z, width, height)
		-- World -> camera
		local cx = (x - y) * cos45
		local cy = -5.33 - (y + x) * cos45 * cos35 - z * sin35
		local cz = 122 + (y + x) * cos45 * sin35 - z * cos35
		-- Camera -> screen
		local sx = width * 0.5 + cx / cz * 1.27 * height
		local sy = height * 0.5 + cy / cz * 1.27 * height
		return round(sx), round(sy)
	end
end

-- main:RenderCircle(x, y, width, height, oX, oY, radius)
--Renders a circle on the screen at the given x and y coordinates with a specified radius.
--It utilizes main:WorldToScreen to convert world coordinates to screen coordinates.
function main:RenderCircle(x, y, width, height, oX, oY, radius)
	local minX = wipeTable(tempTable1)
	local maxX = wipeTable(tempTable2)
	local minY = height
	local maxY = 0
	for d = 0, 360, 0.15 do
		local r = d / 180 * m_pi
		local px, py = main:WorldToScreen(oX + m_sin(r) * radius, oY + m_cos(r) * radius, 0, width, height)
		if py >= 0 and py < height then
			px = m_min(width, m_max(0, px))
			minY = m_min(minY, py)
			maxY = m_max(maxY, py)
			minX[py] = m_min(minX[py] or px, px)
			maxX[py] = m_max(maxX[py] or px, px)
		end
	end
	for ly = minY, maxY do
		if minX[ly] then
			DrawImage(nil, x + minX[ly], y + ly, maxX[ly] - minX[ly] + 1, 1)
		end
	end
end

-- main:RenderRing(x, y, width, height, oX, oY, radius, size)
--Similar to RenderCircle but renders a ring (hollow circle) with a specified size.
function main:RenderRing(x, y, width, height, oX, oY, radius, size)
	local lastX, lastY
	for d = 0, 360, 0.2 do
		local r = d / 180 * m_pi
		local px, py = main:WorldToScreen(oX + m_sin(r) * radius, oY + m_cos(r) * radius, 0, width, height)
		if px >= -size/2 and px < width + size/2 and py >= -size/2 and py < height + size/2 and (px ~= lastX or py ~= lastY) then
			DrawImage(nil, x + px - size/2, y + py, size, size)
			lastX, lastY = px, py
		end
	end
end

-- main:StatColor(stat, base, limit)
--Determines the color code for displaying statistics based on certain conditions like exceeding a limit or differing from a base value.
function main:StatColor(stat, base, limit)
	if limit and stat > limit then
		return colorCodes.NEGATIVE
	elseif base and stat ~= base then
		return colorCodes.MAGIC
	else
		return "^7"
	end
end

-- main:MoveFolder(name, srcPath, dstPath)
--Moves a folder and its contents from the source path to the destination path.
--Recursively handles subfolders and files within the specified folder.
function main:MoveFolder(name, srcPath, dstPath)
	-- Create destination folder
	local res, msg = MakeDir(dstPath..name)
	if not res then
		self:OpenMessagePopup("Error", "Couldn't move '"..name.."' to '"..dstPath.."' : "..msg)
		return
	end

	-- Move subfolders
	local handle = NewFileSearch(srcPath..name.."/*", true)
	while handle do
		self:MoveFolder(handle:GetFileName(), srcPath..name.."/", dstPath..name.."/")
		if not handle:NextFile() then
			break
		end
	end

	-- Move files
	handle = NewFileSearch(srcPath..name.."/*")
	while handle do
		local fileName = handle:GetFileName()
		local srcName = srcPath..name.."/"..fileName
		local dstName = dstPath..name.."/"..fileName
		local res, msg = os.rename(srcName, dstName)
		if not res then
			self:OpenMessagePopup("Error", "Couldn't move '"..srcName.."' to '"..dstName.."': "..msg)
			return
		end
		if not handle:NextFile() then
			break
		end
	end

	-- Remove source folder
	local res, msg = RemoveDir(srcPath..name)
	if not res then
		self:OpenMessagePopup("Error", "Couldn't delete '"..dstPath..name.."' : "..msg)
		return
	end
end

-- main:CopyFolder(srcName, dstName)
--Copies a folder and its contents from the source path to the destination path.
--Similar to MoveFolder, but it duplicates the folder and its content instead of moving it.
function main:CopyFolder(srcName, dstName)
	-- Create destination folder
	local res, msg = MakeDir(dstName)
	if not res then
		self:OpenMessagePopup("Error", "Couldn't copy '"..srcName.."' to '"..dstName.."' : "..msg)
		return
	end

	-- Copy subfolders
	local handle = NewFileSearch(srcName.."/*", true)
	while handle do
		local fileName = handle:GetFileName()
		self:CopyFolder(srcName.."/"..fileName, dstName.."/"..fileName)
		if not handle:NextFile() then
			break
		end
	end

	-- Copy files
	handle = NewFileSearch(srcName.."/*")
	while handle do
		local fileName = handle:GetFileName()
		local srcName = srcName.."/"..fileName
		local dstName = dstName.."/"..fileName
		local res, msg = copyFile(srcName, dstName)
		if not res then
			self:OpenMessagePopup("Error", "Couldn't copy '"..srcName.."' to '"..dstName.."': "..msg)
			return
		end
		if not handle:NextFile() then
			break
		end
	end
end

function main:OpenPopup(width, height, title, controls, enterControl, defaultControl, escapeControl, scrollBarFunc)
	local popup = new("PopupDialog", width, height, title, controls, enterControl, defaultControl, escapeControl, scrollBarFunc)
	t_insert(self.popups, 1, popup)
	return popup
end

-- main:ClosePopup()
--Closes the topmost popup window.
function main:ClosePopup()
	t_remove(self.popups, 1)
end

-- main:OpenMessagePopup(title, msg)
--Opens a popup displaying a message with an 'Ok' button to close the popup.
function main:OpenMessagePopup(title, msg)
	local controls = { }
	local numMsgLines = 0
	for line in string.gmatch(msg .. "\n", "([^\n]*)\n") do
		t_insert(controls, new("LabelControl", nil, 0, 20 + numMsgLines * 16, 0, 16, line))
		numMsgLines = numMsgLines + 1
	end
	controls.close = new("ButtonControl", nil, 0, 40 + numMsgLines * 16, 80, 20, "Ok", function()
		main:ClosePopup()
	end)
	return self:OpenPopup(m_max(DrawStringWidth(16, "VAR", msg) + 30, 190), 70 + numMsgLines * 16, title, controls, "close")
end

-- main:OpenConfirmPopup(title, msg, confirmLabel, onConfirm)
--Opens a confirmation popup displaying a message with two options: Confirm and Cancel.
--Accepts a callback function (onConfirm) to execute when confirmed.
function main:OpenConfirmPopup(title, msg, confirmLabel, onConfirm)
	local controls = { }
	local numMsgLines = 0
	for line in string.gmatch(msg .. "\n", "([^\n]*)\n") do
		t_insert(controls, new("LabelControl", nil, 0, 20 + numMsgLines * 16, 0, 16, line))
		numMsgLines = numMsgLines + 1
	end
	local confirmWidth = m_max(80, DrawStringWidth(16, "VAR", confirmLabel) + 10)
	controls.confirm = new("ButtonControl", nil, -5 - m_ceil(confirmWidth/2), 40 + numMsgLines * 16, confirmWidth, 20, confirmLabel, function()
		main:ClosePopup()
		onConfirm()
	end)
	t_insert(controls, new("ButtonControl", nil, 5 + m_ceil(confirmWidth/2), 40 + numMsgLines * 16, confirmWidth, 20, "Cancel", function()
		main:ClosePopup()
	end))
	return self:OpenPopup(m_max(DrawStringWidth(16, "VAR", msg) + 30, 190), 70 + numMsgLines * 16, title, controls, "confirm")
end

-- main:OpenNewFolderPopup(path, onClose)
--Opens a popup for creating a new folder with an input field for the folder name.
--Invokes onClose with the newly created folder name or without any arguments if canceled.
function main:OpenNewFolderPopup(path, onClose)
	local controls = { }
	controls.label = new("LabelControl", nil, 0, 20, 0, 16, "^7Enter folder name:")
	controls.edit = new("EditControl", nil, 0, 40, 350, 20, nil, nil, "\\/:%*%?\"<>|%c", 100, function(buf)
		controls.create.enabled = buf:match("%S")
	end)
	controls.create = new("ButtonControl", nil, -45, 70, 80, 20, "Create", function()
		local newFolderName = controls.edit.buf
		local res, msg = MakeDir(path..newFolderName)
		if not res then
			main:OpenMessagePopup("Error", "Couldn't create '"..newFolderName.."': "..msg)
			return
		end
		if onClose then
			onClose(newFolderName)
		end
		main:ClosePopup()
	end)
	controls.create.enabled = false
	controls.cancel = new("ButtonControl", nil, 45, 70, 80, 20, "Cancel", function()
		if onClose then
			onClose()
		end
		main:ClosePopup()
	end)
	main:OpenPopup(370, 100, "New Folder", controls, "create", "edit", "cancel")
end

-- main:SetWindowTitleSubtext(subtext)
--Sets the window title for the application, appending a subtext if provided.
function main:SetWindowTitleSubtext(subtext)
	if not subtext or not self.showTitlebarName then
		SetWindowTitle(APP_NAME)
	else
		SetWindowTitle(subtext.." - "..APP_NAME)
	end
end

-- main:WrapString(str, height, width)
--Wraps a string to fit within a specified width using a provided font height.
--Splits the string into multiple lines to ensure it fits within the given dimensions.
do
	local wrapTable = { }
	function main:WrapString(str, height, width)
		wipeTable(wrapTable)
		local lineStart = 1
		local lastSpace, lastBreak
		while true do
			local s, e = str:find("%s+", lastSpace)
			if not s then
				s = #str + 1
				e = #str + 1
			end
			if s > #str then
				t_insert(wrapTable, str:sub(lineStart, -1))
				break
			end
			lastBreak = s - 1
			lastSpace = e + 1
			if DrawStringWidth(height, "VAR", str:sub(lineStart, s - 1)) > width then
				t_insert(wrapTable, str:sub(lineStart, lastBreak))
				lineStart = lastSpace
			end
		end
		return wrapTable
	end
end

return main
