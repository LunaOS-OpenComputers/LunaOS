local GUI = require("GUI")
local system = require("System")
local internet = require("Internet")
local json = require("JSON")
local fs = require("Filesystem")
local image = require("Image")
local text = require("Text")
local number = require("Number")
local paths = require("Paths")
local bigLetters = require("bigLetters")
local screen = require("Screen")

--------------------------------------------------------------------------------------------------------
-- Configuration and Initial Setup
--------------------------------------------------------------------------------------------------------

local workspace, window = system.addWindow(GUI.filledWindow(1, 1, 130, 30, 0x2D2D2D))
local configPath = paths.user.applicationData .. "Weather/Config.cfg"
local resources = fs.path(system.getCurrentScript())
local locale = system.getCurrentScriptLocalization()

-- Default configuration structure
local defaultConfig = {
    regions = {
        {
            name = "London",
            api = "OpenWeatherMap",
            coordinates = {lat=51.5074, lon=-0.1278},
            cache = {data=nil, lastUpdated=0}
        }
    },
    currentRegion = 1,
    apis = {
        OpenWeatherMap = {
            key = "98ba4333281c6d0711ca78d2d0481c3d",
            url = "https://api.openweathermap.org/data/3.0/onecall",
            cacheTime = 1800 -- 30 minutes
        },
        NOAA = {
            key = "your-noaa-key-here",
            url = "https://api.weather.gov/points/",
            cacheTime = 900 -- 15 minutes
        }
    }
}

-- Load or initialize config
local config = fs.exists(configPath) and fs.readTable(configPath) or defaultConfig
if not config.regions then config = defaultConfig end

--------------------------------------------------------------------------------------------------------
-- Weather API Handlers
--------------------------------------------------------------------------------------------------------

local apiHandlers = {
    OpenWeatherMap = {
        fetch = function(region)
            local api = config.apis.OpenWeatherMap
            local url = api.url .. "?lat=" .. region.coordinates.lat .. "&lon=" .. region.coordinates.lon ..
                      "&exclude=minutely,hourly&appid=" .. api.key .. "&units=metric"
            local result, err = internet.request(url)
            return result and json.decode(result), err
        end,
        parse = function(data)
            return {
                current = {
                    temp = data.current.temp,
                    feels_like = data.current.feels_like,
                    humidity = data.current.humidity,
                    weather = data.current.weather[1].main,
                    icon = data.current.weather[1].icon
                },
                alerts = data.alerts or {},
                daily = data.daily
            }
        end
    },
    NOAA = {
        fetch = function(region)
            local api = config.apis.NOAA
            local pointUrl = api.url .. region.coordinates.lat .. "," .. region.coordinates.lon
            local result, err = internet.request(pointUrl)
            if not result then return nil, err end
            
            local pointData = json.decode(result)
            local forecastUrl = pointData.properties.forecastHourly
            return internet.request(forecastUrl)
        end,
        parse = function(data)
            -- NOAA specific parsing logic
        end
    }
}

--------------------------------------------------------------------------------------------------------
-- UI Components and Layout
--------------------------------------------------------------------------------------------------------

-- Main weather container
local weatherContainer = window:addChild(GUI.container(1, 1, 1, 23))

-- Top toolbar
local toolbar = window:addChild(GUI.panel(1, 1, window.width, 3, 0x3C3C3C))
local components = {
    regionSelector = toolbar:addChild(GUI.comboBox(2, 1, 25, 3, 0xE1E1E1, 0x4B4B4B, 0x2D2D2D, 0xE1E1E1)),
    addButton = toolbar:addChild(GUI.button(28, 1, 3, 3, 0x4B4B4B, 0xFFFFFF, 0x696969, "+")),
    refreshButton = toolbar:addChild(GUI.button(32, 1, 3, 3, 0x4B4B4B, 0xFFFFFF, 0x696969, "⟳"))
}

-- Initialize region selector
local function updateRegionSelector()
    components.regionSelector:clear()
    for _, region in ipairs(config.regions) do
        components.regionSelector:addItem(region.name)
    end
    components.regionSelector:setSelectedIndex(config.currentRegion)
end

--------------------------------------------------------------------------------------------------------
-- Core Functions
--------------------------------------------------------------------------------------------------------

local function showAlertWindow(alerts)
    local alertWin = GUI.window(1, 1, 80, 20, "Weather Alerts")
    local layout = alertWin:addChild(GUI.layout(1, 1, 80, 20, 1, 1))
    
    for _, alert in ipairs(alerts) do
        layout:addChild(GUI.text(1, 1, 0xFF0000, alert.event))
        layout:addChild(GUI.text(1, 1, 0xFFFFFF, alert.description))
        layout:addChild(GUI.text(1, 1, 0xAAAAAA, "Issued: " .. os.date("%c", alert.start)))
        layout:addChild(GUI.text(1, 1, 0xAAAAAA, "Expires: " .. os.date("%c", alert.end)))
    end
    
    workspace:addModal(alertWin)
    workspace:draw()
end

local function updateWeatherDisplay(weatherData)
    weatherContainer:removeChildren()
    
    -- Current weather
    local current = weatherContainer:addChild(GUI.panel(2, 1, 40, 8, 0x2D2D2D))
    current:addChild(GUI.text(2, 2, 0xFFFFFF, "Current: " .. weatherData.current.temp .. "°C"))
    current:addChild(GUI.text(2, 4, 0xAAAAAA, "Feels like: " .. weatherData.current.feels_like .. "°C"))
    
    -- Alerts button
    if #weatherData.alerts > 0 then
        local alertBtn = weatherContainer:addChild(GUI.button(2, 10, 15, 3, 0xFF0000, 0xFFFFFF, 0x2D2D2D, "View Alerts (" .. #weatherData.alerts .. ")"))
        alertBtn.onTouch = function() showAlertWindow(weatherData.alerts) end
    end
    
    -- Forecast
    local yPos = 14
    for i = 1, 7 do
        local day = weatherData.daily[i]
        local forecast = weatherContainer:addChild(GUI.panel(2 + (i-1)*18, yPos, 16, 6, 0x3C3C3C))
        forecast:addChild(GUI.text(2, 1, 0xFFFFFF, os.date("%a", day.dt)))
        forecast:addChild(GUI.text(2, 3, 0xAAAAAA, math.floor(day.temp.min) .. "/" .. math.floor(day.temp.max) .. "°C"))
    end
end

local function fetchWeather(forceRefresh)
    local region = config.regions[config.currentRegion]
    local api = config.apis[region.api]
    
    if not forceRefresh and region.cache.data and (os.time() - region.cache.lastUpdated < api.cacheTime) then
        updateWeatherDisplay(region.cache.data)
        return
    end
    
    local handler = apiHandlers[region.api]
    local rawData, err = handler.fetch(region)
    if not rawData then
        GUI.alert("Error fetching data: " .. (err or "unknown"))
        return
    end
    
    local processed = handler.parse(rawData)
    region.cache = {data=processed, lastUpdated=os.time()}
    updateWeatherDisplay(processed)
    fs.writeTable(configPath, config)
end

--------------------------------------------------------------------------------------------------------
-- Event Handlers and Initialization
--------------------------------------------------------------------------------------------------------

-- Region management dialog
components.addButton.onTouch = function()
    local addWin = GUI.window(1, 1, 60, 20, "Add Region")
    -- Add input fields and API selection
    workspace:addModal(addWin)
end

components.refreshButton.onTouch = function()
    fetchWeather(true)
end

components.regionSelector.onItemSelected = function(index)
    config.currentRegion = index
    fetchWeather(false)
end

window.onResize = function(w, h)
    window.backgroundPanel.width = w
    window.backgroundPanel.height = h
    weatherContainer.width = w
    weatherContainer.height = h - 4
end

-- Initial setup
updateRegionSelector()
fetchWeather(false)
workspace:draw()

return window