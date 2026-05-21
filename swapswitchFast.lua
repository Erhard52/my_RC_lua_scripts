-- toolName = TNS|SwapSwitchFast|TNE
-- ============================================================
-- SwapSwitch.lua  -  EdgeTX TOOLS script for TX16S
-- Place in /SCRIPTS/TOOLS/ on the SD card.
-- Requires EdgeTX 2.8+
-- ============================================================

local SWITCHES    = {"SA","SB","SC","SD","SE","SF","SG","SH"}
local LABELS_PATH = "/MODELS/labels.yml"
local LINES_PER_RUN = 50

-- UI state
local needBuild  = 0
local sw1        = nil
local sw2        = nil
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
-- High-Speed Bidirectional Pattern Matcher (Optimized)
-- ============================================================
local function swapLine(line)
    local TMP = "XXTMPXX"
    
    -- Executes entirely in native C, bypassing slow Lua character concat loops
    local new = string.gsub(line, sw1 .. "([0-2])", TMP .. "%1")
    new = string.gsub(new, sw2 .. "([0-2])", sw1 .. "%1")
    new = string.gsub(new, TMP .. "([0-2])", sw2 .. "%1")
    
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
            local new = swapLine(old)
            
            -- FIX: Explicitly assign the returned string to apply modifications to the data stream
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
            resultMsg = {
                "Done! " .. workChanged .. " line(s) changed.",
                "Swapped: " .. sw1 .. " <-> " .. sw2,
                "File: " .. workOutPath
            }
            needBuild = 6
        end
    end
end

-- ============================================================
-- LVGL pages
-- ============================================================
local function buildDone()
    lvgl.clear()
    local pg = lvgl.page({title="SwapSwitch", subtitle="Complete"})
    local y = 30
    for _, msg in ipairs(resultMsg) do
        pg:label({x=20, y=y, text=msg})
        y = y + 30
    end
    pg:label({x=20, y=y+8, text="Power cycle radio to apply changes."})
    pg:button({x=20,  y=200, w=200, h=50, text="Another Swap",
        press=function()
            sw1       = nil
            sw2       = nil
            saveAs    = nil
            needBuild = 1
        end})
    pg:button({x=250, y=200, w=200, h=50, text="Exit",
        press=function() exitFlag = true end})
end

local function buildWorking()
    lvgl.clear()
    local pg = lvgl.page({title="SwapSwitch", subtitle="Working..."})
    pg:label({x=20, y=80,  text="Processing, please wait."})
    pg:label({x=20, y=116, text="This takes only a few seconds now."})
    pg:label({x=20, y=152, text="Do not touch the radio."})
end

local function buildConfirm()
    lvgl.clear()
    local pg = lvgl.page({title="SwapSwitch", subtitle="Confirm swap"})
    pg:label({x=20, y=25, text="Swap:  " .. sw1 .. "  <->  " .. sw2})
    pg:label({x=20, y=60, text="WARNING: Backup your SD card first!"})
    pg:label({x=20, y=88, text="This will modify your model file"})
    pg:label({x=20, y=112, text="directly on the SD card."})
    pg:label({x=20, y=140, text="Make sure you have a backup of"})
    pg:label({x=20, y=164, text="your SD card before proceeding!"})
    pg:button({x=20,  y=210, w=200, h=45, text="Proceed",
        press=function() saveAs="overwrite"; needBuild=5 end})
    pg:button({x=250, y=210, w=200, h=45, text="Cancel",
        press=function() needBuild=1 end})
end

local function buildSelectSw2()
    lvgl.clear()
    local pg = lvgl.page({title="SwapSwitch", subtitle="Swap " .. sw1 .. " with?"})
    local y = 25
    for _, name in ipairs(SWITCHES) do
        if name ~= sw1 then
            local n = name
            pg:button({x=100, y=y, w=260, h=44, text=n,
                press=function() sw2=n; needBuild=4 end})
            y = y + 52
        end
    end
end

local function buildSelectType()
    lvgl.clear()
    local pg = lvgl.page({title="SwapSwitch", subtitle="Select first switch to swap"})
    local y = 25
    for _, name in ipairs(SWITCHES) do
        local n = name
        pg:button({x=100, y=y, w=260, h=44, text=n,
            press=function() sw1=n; needBuild=3 end})
        y = y + 52
    end
end

-- ============================================================
-- EdgeTX entry points
-- ============================================================
local function init()
    if lvgl == nil then return end
    buildSelectType()
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
        if     nb == 1 then buildSelectType()
        elseif nb == 3 then buildSelectSw2()
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
        end
        return 0
    end

    if workPhase > 0 then doWork() end

    return 0
end

return {init=init, run=run, useLvgl=true}