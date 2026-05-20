local library = require("CoronaLibrary")

local appsflyer = library:new{
	name = "plugin.appsflyer",
	publisherId = "com.studycat.appsflyer"
}

local notSupported = " is not supported on Mac or Windows simulators. Please build for device."

function appsflyer.init()
	print("appsflyer.init()" .. notSupported)
end

function appsflyer.logEvent()
	print("appsflyer.logEvent()" .. notSupported)
end

function appsflyer.getVersion()
	print("appsflyer.getVersion()" .. notSupported .. " (isStrict=N/A on simulator)")
end

function appsflyer.setHasUserConsent()
	print("appsflyer.setHasUserConsent()" .. notSupported)
end

function appsflyer.logPurchase()
	print("appsflyer.logPurchase()" .. notSupported)
end

function appsflyer.getAppsFlyerUID()
	print("appsflyer.getAppsFlyerUID()" .. notSupported)
end

return appsflyer
