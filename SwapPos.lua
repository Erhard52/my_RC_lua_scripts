-- toolName = TNS|SwapPOS|TNE
-- ============================================================
-- SingleSwitchSwap.lua  -  EdgeTX single-switch position swapper
-- Place in /SCRIPTS/TOOLS/ on the SD card.
-- Requires EdgeTX 2.8+
-- ============================================================

local THREE_POS_SWITCHES = {"SA","SB","SC","SD","SE","SG","6P"}
local TWO_POS_SWITCHES   = {"SF","SH","SI","SJ"}
local LABELS_PATH        = "/MODELS/labels.yml"
local LINES_PER_RUN      = 50

-- Information Strings
local ABOUT_AUTH = "Author: E. Schreck"
local ABOUT_VERS = "version 1.2"
local ABOUT_DATE = "Date: 5/24/2026"

-- UI state
local needBuild  = 0
local targetSw   = nil
local pos1       = nil
local pos2       = nil
local saveAs     = nil
local resultMsg  = {}
local exitFlag   = false

-- Work state
local workPhase   = 0
local workFile    = nil
local workLines   = {}
local workCurrent = ""
local workPath    = nil
local workOutPath = nil
local workChanged = 0
local workIdx     = 1

-- ============================================================
-- High-Speed Single Switch Digit Swapper
-- ============================================================
local function swapSwitchPositions(line)
    local TMP = "XXTMPXX"
    local orig = line
    
    -- Explicitly swap targetSw + pos1 with targetSw + pos2 using a safe temporary flag
    local new = string.gsub(orig, targetSw .. pos1, TMP)
    new = string.gsub(new, targetSw .. pos2, targetSw .. pos1)
    new = string.gsub(new, TMP, targetSw .. pos2)
    
    return new
end

-- ============================================================
-- Read chunk using string.find for fast line splitting
-- ============================================================
local function readChunk()
    local data = io.read(workFile, 512)
    if data == nil or data == "" then
        if string.len(workCurrent) > 0 then
            workLines[#workLines + 1] = workCurrent
            workCurrent = ""
        end
        io.close(workFile)
        workFile = nil
        return true
    end
    local combined = workCurrent .. data
    workCurrent = ""
    local pos = 1
    while true do
        local nl = string.find(combined, "\n", pos, true)
        if nl then
            local line = string.sub(combined, pos, nl - 1)
            if string.len(line) > 0 and string.sub(line, -1) == "\r" then
                line = string.sub(line, 1, -2)
            end
            workLines[#workLines + 1] = line
            pos = nl + 1
        else
            workCurrent = string.sub(combined, pos)
            break
        end
    end
    return false
end

local function findModelPath(labelLines)
    local modelName = model.getInfo().name
    local currentFile = nil
    for _, line in ipairs(labelLines) do
        local fname = string.match(line, "^%s+(model%d+%.yml)%s*:")
        if fname then currentFile = fname end
        if currentFile then
            local name = string.match(line, '%s+name:%s*"([^"]+)"')
            if name and name == modelName then
                return "/MODELS/" .. currentFile
            end
        end
    end
    return nil
end

-- ============================================================
-- Non-blocking work phases
-- ============================================================
local function doWork()
    if workPhase == 1 then
        local done = readChunk()
        if done then
            local path = findModelPath(workLines)
            if not path then
                resultMsg = {"ERROR: model not found in labels.yml"}
                workPhase = 0
                needBuild = 6
                return
            end
            workPath    = path
            workLines   = {}
            workCurrent = ""
            workFile    = io.open(workPath, "r")
            if not workFile then
                resultMsg = {"ERROR: Cannot open", workPath}
                workPhase = 0
                needBuild = 6
                return
            end
            workPhase = 2
        end

    elseif workPhase == 2 then
        local done = readChunk()
        if done then
            workChanged = 0
            workIdx     = 1
            workPhase   = 3
        end

    elseif workPhase == 3 then
        local count = 0
        while workIdx <= #workLines and count < LINES_PER_RUN do
            local old = workLines[workIdx]
            local new = swapSwitchPositions(old)
            
            if new ~= old then 
                workChanged = workChanged + 1 
            end
            workLines[workIdx] = new
            
            workIdx = workIdx + 1
            count   = count + 1
        end
        if workIdx > #workLines then
            workOutPath = workPath
            if saveAs == "new" then
                workOutPath = string.gsub(workPath, "%.yml$", "_swapped.yml")
            end
            workFile = io.open(workOutPath, "w")
            if not workFile then
                resultMsg = {"ERROR: Cannot write", workOutPath}
                workPhase = 0
                needBuild = 6
                return
            end
            workIdx   = 1
            workPhase = 4
        end

    elseif workPhase == 4 then
        local count = 0
        while workIdx <= #workLines and count < LINES_PER_RUN do
            io.write(workFile, workLines[workIdx] .. "\n")
            workIdx = workIdx + 1
            count   = count + 1
        end
        if workIdx > #workLines then
            io.close(workFile)
            workFile  = nil
            workPhase = 0
            
            local dispP1 = pos1
            local dispP2 = pos2
            if targetSw == "6P" then
                dispP1 = "6P" .. (tonumber(pos1) - 9)
                dispP2 = "6P" .. (tonumber(pos2) - 9)
            else
                dispP1 = targetSw .. pos1
                dispP2 = targetSw .. pos2
            end
            
            resultMsg = {
                "Done! " .. workChanged .. " line(s) changed.",
                "Swapped: " .. dispP1 .. " <-> " .. dispP2,
                "File: " .. workOutPath
            }
            needBuild = 6
        end
    end
end

-- ============================================================
-- LVGL UI Selection Pages
-- ============================================================
local function buildAbout()
    lvgl.clear()
    local pg = lvgl.page({title="Position Swap", subtitle="About"})
    
    pg:label({x=40, y=50, text="EdgeTX Switch Swapper Utility", color=BLACK})
    pg:label({x=40, y=90, text=ABOUT_AUTH})
    pg:label({x=40, y=120, text=ABOUT_VERS})
    pg:label({x=40, y=150, text=ABOUT_DATE})
    
    pg:button({x=40, y=210, w=150, h=45, text="Back",
        press=function() needBuild = 1 end})
end

local function buildHelp()
    lvgl.clear()
    local pg = lvgl.page({title="Position Swap", subtitle="Help Guidelines"})
    
    pg:button({x=340, y=5, w=120, h=32, text="Return",
        press=function() needBuild = 1 end})
    
    -- Safe multi-line string block to protect memory constraints
    local helpText = "this script works on ONE switch and allows to swap function of different switch positions.\n\n"
                  .. "Example:\n"
                  .. "switch SE has the following flight modes:\n"
                  .. "  up: thermal | middle: normal | down: landing\n\n"
                  .. "now if you want to switch that from top to middle position:\n"
                  .. "  normal thermal landing\n\n"
                  .. "you would select switch SE and then select position 1 and 2.\n"
                  .. "if it turns out you chose the wrong positions just revert it by repeating the same swap of 1 and 2 and then use 0 and 1 instead.\n\n"
                  .. "as before you need to power cycle the radio to enable that modified model script."

    pg:label({x=15, y=50, w=450, text=helpText})
end

local function buildDone()
    lvgl.clear()
    local pg = lvgl.page({title="Position Swap", subtitle="Complete"})
    local y = 30
    for _, msg in ipairs(resultMsg) do
        pg:label({x=20, y=y, text=msg})
        y = y + 30
    end
    pg:label({x=20, y=y+8, text="Power cycle radio to apply changes."})
    pg:button({x=20,  y=200, w=200, h=50, text="Another Swap",
        press=function()
            targetSw  = nil
            pos1      = nil
            pos2      = nil
            saveAs    = nil
            needBuild = 1
        end})
    pg:button({x=250, y=200, w=200, h=50, text="Exit",
        press=function() exitFlag = true end})
end

local function buildWorking()
    lvgl.clear()
    local pg = lvgl.page({title="Position Swap", subtitle="Working..."})
    pg:label({x=20, y=80,  text="Processing switch parameters, please wait."})
    pg:label({x=20, y=116, text="Executing high-speed pattern substitutions."})
    pg:label({x=20, y=152, text="Do not touch the radio switches."})
end

local function buildConfirm()
    lvgl.clear()
    local pg = lvgl.page({title="Position Swap", subtitle="Confirm"})
    
    local labelText = "Target: Swap " .. targetSw .. pos1 .. "  <->  " .. targetSw .. pos2
    if targetSw == "6P" then
        labelText = "Target: Swap 6P" .. (tonumber(pos1) - 9) .. "  <->  6P" .. (tonumber(pos2) - 9)
    end
    
    pg:label({x=20, y=25, text=labelText})
    pg:label({x=20, y=60, text="WARNING: Backup your SD card first!"})
    pg:label({x=20, y=88, text="This will modify your model file"})
    pg:label({x=20, y=112, text="directly on the SD card."})
    pg:button({x=20,  y=210, w=200, h=45, text="Proceed",
        press=function() saveAs="overwrite"; needBuild=5 end})
    pg:button({x=250, y=210, w=200, h=45, text="Cancel",
        press=function() needBuild=1 end})
end

local function build6PosMatrix()
    lvgl.clear()
    local pg = lvgl.page({title="Position Swap", subtitle="Select 6POS Positions"})
    pg:label({x=20, y=15, text="Choose external labeled positions to swap:"})
    
    -- Left Column Pairs
    pg:button({x=30, y=50, w=200, h=40, text="6P1 <-> 6P2",
        press=function() pos1="10"; pos2="11"; needBuild=4 end})
    pg:button({x=30, y=100, w=200, h=40, text="6P2 <-> 6P3",
        press=function() pos1="11"; pos2="12"; needBuild=4 end})
    pg:button({x=30, y=150, w=200, h=40, text="6P3 <-> 6P4",
        press=function() pos1="12"; pos2="13"; needBuild=4 end})
        
    -- Right Column Pairs
    pg:button({x=250, y=50, w=200, h=40, text="6P4 <-> 6P5",
        press=function() pos1="13"; pos2="14"; needBuild=4 end})
    pg:button({x=250, y=100, w=200, h=40, text="6P5 <-> 6P6",
        press=function() pos1="14"; pos2="15"; needBuild=4 end})
    pg:button({x=250, y=150, w=200, h=40, text="6P1 <-> 6P6",
        press=function() pos1="10"; pos2="15"; needBuild=4 end})
        
    pg:button({x=140, y=210, w=200, h=42, text="Back",
        press=function() needBuild=1 end})
end

local function buildSelectPositions()
    lvgl.clear()
    local pg = lvgl.page({title="Position Swap", subtitle="Select positions for " .. targetSw})
    pg:label({x=20, y=20, text="Choose which two states to swap:"})
    
    pg:button({x=60, y=70, w=360, h=44, text="Position 0 <-> Position 1",
        press=function() pos1="0"; pos2="1"; needBuild=4 end})
        
    pg:button({x=60, y=125, w=360, h=44, text="Position 1 <-> Position 2",
        press=function() pos1="1"; pos2="2"; needBuild=4 end})
        
    pg:button({x=60, y=180, w=360, h=44, text="Position 0 <-> Position 2",
        press=function() pos1="0"; pos2="2"; needBuild=4 end})
end

local function buildSelectSwitch()
    lvgl.clear()
    local pg = lvgl.page({title="Position Swap", subtitle="Select target switch"})
    
    -- Dedicated Navigation Header
    pg:button({x=20,  y=10, w=100, h=32, text="About",
        press=function() needBuild=8 end})
    pg:button({x=130, y=10, w=100, h=32, text="Help",
        press=function() needBuild=9 end})

    -- Left Column Layout
    pg:label({x=30, y=60, text="3-POS / 6-POS", color=BLACK})
    local yLeft = 85
    for _, name in ipairs(THREE_POS_SWITCHES) do
        local n = name
        pg:button({x=30, y=yLeft, w=180, h=32, text=n,
            press=function() 
                targetSw=n
                if n == "6P" then
                    needBuild=7
                else
                    needBuild=3 
                end
            end})
        yLeft = yLeft + 35
    end
    
    -- Right Column Layout
    pg:label({x=260, y=60, text="2-POS SWITCHES", color=BLACK})
    local yRight = 85
    for _, name in ipairs(TWO_POS_SWITCHES) do
        local n = name
        pg:button({x=260, y=yRight, w=180, h=32, text=n,
            press=function() 
                targetSw = n
                pos1     = "0"
                pos2     = "1"
                needBuild = 4 
            end})
        yRight = yRight + 35
    end
end

-- ============================================================
-- EdgeTX entry points
-- ============================================================
local function init()
    if lvgl == nil then return end
    buildSelectSwitch()
end

local function run(event, touchState)
    if lvgl == nil then
        lcd.drawText(10, 10, "LVGL required (EdgeTX 2.8+)", BOLD)
        return 0
    end
    if exitFlag then return 2 end

    if needBuild ~= 0 then
        local nb = needBuild
        needBuild = 0
        if     nb == 1 then buildSelectSwitch()
        elseif nb == 3 then buildSelectPositions()
        elseif nb == 4 then buildConfirm()
        elseif nb == 5 then
            buildWorking()
            workPhase   = 1
            workLines   = {}
            workCurrent = ""
            workIdx     = 1
            workFile    = io.open(LABELS_PATH, "r")
            if not workFile then
                resultMsg = {"ERROR: Cannot open labels.yml"}
                needBuild = 6
            end
        elseif nb == 6 then buildDone()
        elseif nb == 7 then build6PosMatrix()
        elseif nb == 8 then buildAbout()
        elseif nb == 9 then buildHelp()
        end
        return 0
    end

    if workPhase > 0 then doWork() end

    return 0
end

return {init=init, run=run, useLvgl=true}