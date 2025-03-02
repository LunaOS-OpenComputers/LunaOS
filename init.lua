--------------------------------------------- System Check --------------------------------------------

-- Get GPU and screen components
local GPUAddress = component.list("gpu")()
local screenAddress = component.list("screen")()

if not GPUAddress or not screenAddress then
  error("GPU or screen not found!")
end

local gpu = component.proxy(GPUAddress) -- Get the GPU component
local screen = component.proxy(screenAddress) -- Get the screen component

-- Init Settings
local debugMode = true

-- Initialize cursor position and screen resolution
local cursorX, cursorY = 1, 1
local screenWidth, screenHeight = gpu.maxResolution()
local maxScreenWidth, maxScreenHeight = gpu.maxResolution()
gpu.setResolution(screenWidth, screenHeight)


-- Function to wrap text into lines
local function wrapText(text, maxWidth)
  local lines = {}
  
  -- Split the text into lines based on newlines
  for line in text:gmatch("[^\r\n]+") do
    -- Replace tabs with spaces for consistent formatting
    line = line:gsub("\t", "  ")
      
    -- If the line is longer than maxWidth, wrap it
    while #line > maxWidth do
      -- Find the last space within maxWidth
      local wrapAt = line:sub(1, maxWidth):find("%s[^%s]*$") or maxWidth
      lines[#lines + 1] = line:sub(1, wrapAt) -- Do not trim spaces
      line = line:sub(wrapAt + 1) -- Move to the next part of the line
    end
  
    -- Add the remaining part of the line
    if #line > 0 then
      lines[#lines + 1] = line -- Do not trim spaces
    end
  end

  return lines
end

-- Function to print on-screen
local function print(...)
    local _, maxHeight = gpu.getResolution()
    local cursorY = 1
    local lines = wrapText(table.concat({...}, " "), 80) -- Assuming maxWidth is 80 characters
    
    for _, line in ipairs(lines) do
        gpu.set(1, cursorY, line)
        cursorY = cursorY + 1
        if cursorY > maxHeight then
            -- Reset to the top of the screen if reaching the bottom
            cursorY = 1
        end
    end
end

-- Helper function to split strings by a separator
local function split(str, sep)
    if sep == nil then sep = "\n" end
    local result = {}
    local start = 1
    repeat
        local sepStart, sepEnd = str:find(sep, start)
        table.insert(result, str:sub(start, (sepStart or 0) - 1))
        start = sepEnd and sepEnd + 1 or nil
    until not start
    return result
end

-- Handle screen scrolling
local function scroll()
    gpu.copy(1, 2, screenWidth, screenHeight - 1, 0, -1)  -- Move lines up
    gpu.fill(1, screenHeight, screenWidth, 1, " ")         -- Clear bottom line
    cursorY = math.max(cursorY - 1, 1)                      -- Adjust cursor
end

-- ComputerCraft-style write function
function write(text)
    for _, line in ipairs(split(text, "\n")) do
        local remaining = line
        while #remaining > 0 do
            if cursorY > screenHeight then scroll() end
            
            local space = screenWidth - cursorX + 1
            local chunk = remaining:sub(1, space)
            gpu.set(cursorX, cursorY, chunk)
            
            cursorX = cursorX + #chunk
            remaining = remaining:sub(space + 1)
            
            if cursorX > screenWidth then
                cursorX = 1
                cursorY = cursorY + 1
            end
        end
        
        -- Handle implicit newline from split
        cursorX = 1
        cursorY = cursorY + 1
    end
    
    -- Adjust for final line (no newline at end)
    cursorY = cursorY - 1
    if cursorX == 1 and cursorY >= 1 then
        cursorY = math.max(cursorY - 1, 1)
        cursorX = screenWidth + 1
    end
end

local function debugPrint(...)
	if debugMode then
		--write(
		print(...)
	end
end
  
-- Function to display a centered, wrapped message on the screen
local function displayCenteredMessage(message)
  gpu.setBackground(0x000000) -- Black background
  gpu.setForeground(0xFFFFFF) -- White text
  gpu.fill(1, 1, screenWidth, screenHeight, " ") -- Clear the screen

  -- Wrap the message into lines
  local wrappedLines = wrapText(message, screenWidth)

  -- Calculate vertical position to center the text
  local startY = math.floor((screenHeight - #wrappedLines) / 2)

  -- Display each line centered horizontally
  for i, line in ipairs(wrappedLines) do
    local x = math.floor((screenWidth - #line) / 2)
    gpu.set(x, startY + i - 1, line)
  end
end

-- Function to display a warning message
local function warning(message)
  debugPrint("[WARNING] "..message)
end

-- Check GPU depth and memory requirements
local requirementsMet = true
local screenRequirementsPassed = (component.invoke(GPUAddress, "getDepth") == 8 and true or false)
local memoryRequirementsPassed = (computer.totalMemory() < 1024 * 1024 * 2 and false or true)

debugPrint("Booting LunaOS Standalone...")

debugPrint("Running checks...")
if component.invoke(GPUAddress, "getDepth") == 8 then
  debugPrint("Display Check Passed")
else
  warning("Tier 3 GPU and screen are required")
  requirementsMet = false
end

if computer.totalMemory() >= 1024 * 1024 * 2 then
  debugPrint("Memory Check Passed")
else
  warning("At least 2x Tier 3.5 RAM modules are required")
  requirementsMet = false
end

-- If requirements are not met, display the message and wait
if not requirementsMet then
  displayCenteredMessage("Please upgrade your hardware to meet the requirements.")
  while true do
    computer.pullSignal() -- Keep the script running to display the message
  end
end

---------------------------------------- System initialization ----------------------------------------

-- Obtaining boot filesystem component proxy
local bootFilesystemProxy = component.proxy(component.invoke(component.list("eeprom")(), "getData"))

-- Executes file from boot HDD during OS initialization (will be overriden in filesystem library later)
function dofile(path)
  local stream, reason = bootFilesystemProxy.open(path, "r")
  
  if stream then
    local data, chunk = ""
    
    while true do
      chunk = bootFilesystemProxy.read(stream, math.huge)
      
      if chunk then
        data = data .. chunk
      else
        break
      end
    end

    bootFilesystemProxy.close(stream)

    local result, reason = load(data, "=" .. path)
    
    if result then
      return result()
    else
      error(reason)
    end
  else
    error(reason)
  end
end

-- Initializing global package system
package = {
  paths = {
    ["/LunaOS/lib/"] = true
  },
  loaded = {},
  loading = {}
}

-- Checks existense of specified path. It will be overriden after filesystem library initialization
local requireExists = bootFilesystemProxy.exists

-- Works the similar way as native Lua require() function
function require(module)
  -- For non-case-sensitive filesystems
  local lowerModule = unicode.lower(module)

  if package.loaded[lowerModule] then
    return package.loaded[lowerModule]
  elseif package.loading[lowerModule] then
    error("recursive require() call found: library \"" .. module .. "\" is trying to require another library that requires it\n" .. debug.traceback())
  else
    local errors = {}

    local function checkVariant(variant)
      if requireExists(variant) then
        return variant
      else
        table.insert(errors, "  variant \"" .. variant .. "\" not exists")
      end
    end

    local function checkVariants(path, module)
      return
        checkVariant(path .. module .. ".lua") or
        checkVariant(path .. module) or
        checkVariant(module)
    end

    local modulePath
    for path in pairs(package.paths) do
      modulePath =
        checkVariants(path, module) or
        checkVariants(path, unicode.upper(unicode.sub(module, 1, 1)) .. unicode.sub(module, 2, -1))
      
      if modulePath then
        package.loading[lowerModule] = true
        local result = dofile(modulePath)
        package.loaded[lowerModule] = result or true
        package.loading[lowerModule] = nil
        
        return result
      end
    end

    error("unable to locate library \"" .. module .. "\":\n" .. table.concat(errors, "\n"))
  end
end

local function drawProgressBar(curNum, maxNum)
  -- Functions inside to make this work w/o errors
  local function centrize(width)
    return math.floor(screenWidth / 2 - width / 2)
  end

  -- Calculate progress and position
  local title, width = "LunaOS", 30
  local x, y, part = centrize(width), math.floor(screenHeight / 2 - 1), math.ceil(width * curNum / maxNum)
  
  -- Draw the title
  gpu.setForeground(0xFFFFFF) -- White text
  gpu.set(centrize(#title), y, title)

  -- Draw the progress bar
  gpu.setForeground(0xFFFFFF) -- White for filled part
  gpu.set(x, y + 2, string.rep("█", part))

  gpu.setForeground(0xFFFFFF) -- White for unfilled part
  gpu.set(x + part, y + 2, string.rep("░", width - part))
end

-- Displays title and currently required library when booting OS
local UIRequireTotal, UIRequireCounter = 14, 0

local function UIRequire(module)
  -- Increment the counter
  UIRequireCounter = UIRequireCounter + 1

  -- Update the progress bar
  drawProgressBar(UIRequireCounter, UIRequireTotal)

  -- Load and return the required module
  return require(module)
end

-- Preparing screen for loading libraries
gpu.setBackground(0x000000)
gpu.fill(1, 1, screenWidth, screenHeight, " ")

-- Loading libraries
local success, err = pcall(function()
  bit32 = bit32 or UIRequire("Bit32")
  local paths = UIRequire("Paths")
  local event = UIRequire("Event")
  local filesystem = UIRequire("Filesystem")

  -- Setting main filesystem proxy to what are we booting from
  filesystem.setProxy(bootFilesystemProxy)

  -- Replacing requireExists function after filesystem library initialization
  requireExists = filesystem.exists

  -- Loading other libraries
  UIRequire("Component")
  UIRequire("Keyboard")
  UIRequire("Color")
  UIRequire("Text")
  UIRequire("Number")
  local image = UIRequire("Image")
  local screen = UIRequire("Screen")

  -- Setting currently chosen GPU component as screen buffer main one
  screen.setGPUAddress(GPUAddress)

  local GUI = UIRequire("GUI")
  local system = UIRequire("System")
  UIRequire("Network")

  -- Filling package.loaded with default global variables for OpenOS bitches
  package.loaded.bit32 = bit32
  package.loaded.computer = computer
  package.loaded.component = component
  package.loaded.unicode = unicode

  ---------------------------------------- Main loop ----------------------------------------

  -- Creating OS workspace, which contains every window/menu/etc.
  local workspace = GUI.workspace()
  system.setWorkspace(workspace)

  -- "double_touch" event handler
  local doubleTouchInterval, doubleTouchX, doubleTouchY, doubleTouchButton, doubleTouchUptime, doubleTouchcomponentAddress = 0.3
  event.addHandler(
    function(signalType, componentAddress, x, y, button, user)
      if signalType == "touch" then
        local uptime = computer.uptime()
        
        if doubleTouchX == x and doubleTouchY == y and doubleTouchButton == button and doubleTouchcomponentAddress == componentAddress and uptime - doubleTouchUptime <= doubleTouchInterval then
          computer.pushSignal("double_touch", componentAddress, x, y, button, user)
          event.skip("touch")
        end

        doubleTouchX, doubleTouchY, doubleTouchButton, doubleTouchUptime, doubleTouchcomponentAddress = x, y, button, uptime, componentAddress
      end
    end
  )

  -- Screen component attaching/detaching event handler
  event.addHandler(
    function(signalType, componentAddress, componentType)
      if (signalType == "component_added" or signalType == "component_removed") and componentType == "screen" then
        local GPUAddress = screen.getGPUAddress()

        local function bindScreen(address)
          screen.setScreenAddress(address, false)
          screen.setColorDepth(screen.getMaxColorDepth())

          workspace:draw()
        end

        if signalType == "component_added" then
          if not component.invoke(GPUAddress, "getScreen") then
            bindScreen(componentAddress)
          end
        else
          if not component.invoke(GPUAddress, "getScreen") then
            local address = component.list("screen")()
            
            if address then
              bindScreen(address)
            end
          end
        end
      end
    end
  )

  -- Logging in
  system.authorize()

  -- Main loop with UI regeneration after errors 
  while true do
    local success, path, line, traceback = system.call(workspace.start, workspace, 0)
    
    if success then
      break
    else
      system.updateWorkspace()
      system.updateDesktop()
      workspace:draw()
      
      system.error(path, line, traceback)
      workspace:draw()
    end
  end
end)

if not success then
  screenWidth, screenHeight = math.floor(maxScreenWidth / 2), math.floor(maxScreenHeight / 2)
  gpu.setResolution(screenWidth, screenHeight)
  -- Display the error message on the screen
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(1, 1, screenWidth, screenHeight, " ")
  gpu.setBackground(component.invoke(GPUAddress, "getDepth") == 1 and 0x000000 or 0x0000FF)
  do
	for i = 1, screenHeight do
	  for j = 1, screenWidth do
		gpu.set(j, i, " ")
	  end
	end
  end
  local wrappedText = wrapText("A fatal error occurred that caused LunaOS to crash. Please monitor the ticket that will be uploaded to the Github for changes to the system for updates.\n \n" .. tostring(err), screenWidth)
  for k, v in pairs(wrappedText) do
    gpu.set(1, k, v)
  end
  for i = 1, 4 do
	computer.beep(1000, 0.01)
  end
  while true do
	computer.pullSignal()
  end
end