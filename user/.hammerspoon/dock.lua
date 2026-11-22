local M = {}

local DELL_VENDOR = 16700
local DOCK_PRODUCTS = {
    [45166] = true,
    [45167] = true,
}

local logPath = os.getenv("HOME") ..
    "/.local/state/dock-automation/events.log"

local docked = nil
local debounceTimer = nil

local function log(message)
    local line = os.date("%Y-%m-%d %H:%M:%S") ..
        " | " .. message

    print("[dock] " .. line)

    local file = io.open(logPath, "a")
    if file then
        file:write(line .. "\n")
        file:close()
    end
end

local function matchesDock(device)
    return device.vendorID == DELL_VENDOR
       and DOCK_PRODUCTS[device.productID] == true
end

local function detectDock()
    local devices = hs.usb.attachedDevices()

    if not devices then
        log("USB enumeration failed")
        return nil
    end

    for _, device in pairs(devices) do
        if matchesDock(device) then
            return true
        end
    end

    return false
end

local networkScript = os.getenv("HOME") ..
    "/.config/dock-automation/network.sh"

local streamScript = os.getenv("HOME") ..
    "/.config/dock-automation/stream.sh"

local transitionNumber = 0
local activeTask = nil

local function runStep(script, mode, sequence, callback)
    if sequence ~= transitionNumber then
        return
    end

    local task
    task = hs.task.new("/bin/zsh", function(exitCode, stdout, stderr)
        if activeTask == task then
            activeTask = nil
        end

        if sequence ~= transitionNumber then
            log("Ignoring outdated task: " .. mode)
            return
        end

        log("Step " .. mode .. " exited: " .. tostring(exitCode))

        if stderr and stderr ~= "" then
            log("ERROR: " .. stderr)
        end

        if callback then
            callback(exitCode)
        end
    end, {script, mode})

    if not task then
        log("ERROR: Could not create task: " .. mode)
        return
    end

    activeTask = task
    log("Starting step: " .. mode)

    if not task:start() then
        activeTask = nil
        log("ERROR: Could not start task: " .. mode)
    end
end

local fanScript = os.getenv("HOME") ..
    "/.config/dock-automation/fan.sh"

local fanTask = nil

local function runFan(mode)
    if fanTask and fanTask:isRunning() then
        fanTask:terminate()
    end

    local task
    task = hs.task.new("/bin/zsh", function(code, stdout, stderr)
        if fanTask == task then
            fanTask = nil
        end
        log("Fan " .. mode .. " exited: " .. tostring(code))
        if code ~= 0 then
            log("Fan error: " .. (stderr or "unknown"))
        end
    end, {fanScript, mode})

    if task then
        fanTask = task
        log("Starting fan transition: " .. mode)
        if not task:start() then
            fanTask = nil
            log("ERROR: Fan task failed to start")
        end
    end
end

local maintenanceScript = os.getenv("HOME") ..
    "/.config/dock-automation/brew-maintenance.sh"

local maintenanceTask = nil

local function runMaintenance()
    if maintenanceTask and maintenanceTask:isRunning() then
        log("Maintenance already running")
        return
    end

    local task
    task = hs.task.new("/bin/zsh", function(code, stdout, stderr)
        if maintenanceTask == task then
            maintenanceTask = nil
        end

        log("Maintenance task exited: " .. tostring(code))

        if code ~= 0 then
            log("Maintenance task error: " .. (stderr or ""))
        end
    end, {maintenanceScript})

    if task then
        maintenanceTask = task
        log("Starting background maintenance")
        if not task:start() then
            maintenanceTask = nil
            log("ERROR: Maintenance failed to start")
        end
    end
end

local audioScript = os.getenv("HOME") ..
    "/.config/dock-automation/audio.sh"

local audioTask = nil

local function runAudio(mode)
    if audioTask and audioTask:isRunning() then
        audioTask:terminate()
    end

    local task
    task = hs.task.new("/bin/zsh", function(code, stdout, stderr)
        if audioTask == task then
            audioTask = nil
        end

        log("Audio " .. mode .. " exited: " .. tostring(code))

        if code ~= 0 then
            log("ERROR: Audio " .. mode .. " failed")
        end

        if stderr and stderr ~= "" then
            log("Audio stderr: " .. stderr)
        end
    end, {audioScript, mode})

    if not task then
        log("ERROR: Cannot create audio task")
        return
    end

    audioTask = task
    log("Starting audio transition: " .. mode)

    if not task:start() then
        audioTask = nil
        log("ERROR: Cannot start audio task")
    end
end

local function transition(mode)
    transitionNumber = transitionNumber + 1
    local sequence = transitionNumber

    runFan(mode)

    if activeTask and activeTask:isRunning() then
        log("Canceling previous task")
        activeTask:terminate()
    end

    activeTask = nil

    runStep(networkScript, mode, sequence, function(exitCode)
        if mode == "connected" then
            if exitCode == 0 then
                runStep(streamScript, "start", sequence)
                runMaintenance()
                runAudio("connected")
            else
                log("Ethernet unavailable; streaming skipped")
            end
        else
            if exitCode ~= 0 then
                log("WARNING: Wi-Fi restoration failed; attempting cleanup")
            end
            runStep(streamScript, "stop", sequence)
            runAudio("disconnected")
        end
    end)
end

local function onConnected()
    log("CONNECTED | Dell WD19TB")
    transition("connected")
end

local function onDisconnected()
    log("DISCONNECTED | Dell WD19TB")
    transition("disconnected")
end

function M.reconcile(reason)
    local present = detectDock()

    if present == nil then
        return
    end

    if docked == present then
        return
    end

    docked = present

    log("State change: " .. reason)

    if present then
        onConnected()
    else
        onDisconnected()
    end
end

local function scheduleReconcile(reason)
    if debounceTimer then
        debounceTimer:stop()
    end

    debounceTimer = hs.timer.doAfter(2, function()
        debounceTimer = nil
        M.reconcile(reason)
    end)
end

M.usbWatcher = hs.usb.watcher.new(function(device)
    if not matchesDock(device) then
        return
    end

    log(string.format(
        "USB %s | vendor=%d product=%d",
        device.eventType,
        device.vendorID,
        device.productID
    ))

    scheduleReconcile("USB " .. device.eventType)
end)

M.usbWatcher:start()

M.wakeWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake then
        scheduleReconcile("system wake")
    end
end)

M.wakeWatcher:start()

-- Recovery if a USB event was missed.
M.recoveryTimer = hs.timer.doEvery(60, function()
    M.reconcile("periodic verification")
end)

hs.timer.doAfter(2, function()
    M.reconcile("Hammerspoon startup")
end)

log("Dock watcher initialized")

return M
