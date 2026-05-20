--
--  main.lua
--  AppsFlyer Sample App
--
--  Copyright (c) 2018 Corona Labs Inc. All rights reserved.
--

local appsflyer = require( "plugin.appsflyer.strict" )

local widget = require( "widget" )
local json = require("json")

-----------------------
-- Setup
-----------------------
display.setStatusBar( display.HiddenStatusBar )
display.setDefault( "background", 1 )

local logString = ""

local processEventTable = function(event)
  local logString = json.prettify(event):gsub("\\","")
  logString = "\nPHASE: "..event.phase.." - - - - - - - - - - - -\n" .. logString
  print(logString)
  eventDataTextBox.text = logString .. eventDataTextBox.text
end

-- set app id and store data
local devKey = "HUU38wfRNaN6ieLQbb9iFh"
local appID

if (system.getInfo( "platformName" ) == "Android") then
  appID = "com.coronalab.appsflyer"
else -- iOS
  appID = "1069377843"
end

print( "Using " .. appID )

local appsflyerListener = function(event)
  processEventTable(event)
end

appsflyer.init(appsflyerListener, {
  appID = appID,
  devKey = devKey,
  enableDebugLogging = true
})

-----------------------
-- UI
-----------------------
local AppsFlyerLogo = display.newImage( "AppsFlyer-logo.png" )
AppsFlyerLogo.anchorY = 0
AppsFlyerLogo.x, AppsFlyerLogo.y = display.contentCenterX, 0
AppsFlyerLogo:scale( 0.14, 0.14 )

local subTitle = display.newText {
  text = "plugin for Corona SDK",
  x = display.contentCenterX,
  y = 75,
  font = display.systemFont,
  fontSize = 20
}
subTitle:setTextColor( 0.2, 0.2, 0.2 )

eventDataTextBox = native.newTextBox( display.contentCenterX, display.contentHeight - 50, 310, 150)
eventDataTextBox.placeholder = "Event data will appear here"

local revenueEvent = {
  monetizationNetwork = "ironsource",
  currencyIso4217Code = "USD",
  value = 0.0021656780242919923,
  countryCode = "TJ",
  adUnitName = "da5529f386dd83cf",
  adSource = "AppLovin",
  adFormat = "rewardedVideo"
}

local logCustomEventButton = widget.newButton {
  label = "Log Add Revenue",
  onRelease = function(event)
    appsflyer.logRevenueAds(json.encode(revenueEvent))

    --[[appsflyer.logPurchase({ 
      productId = "1",
      price = "100",
      currency = "USD",
      transactionId = "2",
      parameters = { first = "1", second = "2" }
    })--]]
  end
}
logCustomEventButton.x = display.contentCenterX;
logCustomEventButton.y = 120;
