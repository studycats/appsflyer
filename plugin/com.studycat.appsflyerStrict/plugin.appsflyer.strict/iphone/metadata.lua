local metadata =
{
	plugin =
	{
		format = 'staticLibrary',
		staticLibs = { 'plugin_appsflyerStrict', },
		frameworks = { 'AppsFlyerLib' },
		frameworksOptional = { 'AdServices', 'iAd' },
		delegates = { 'CoronaAppsFlyerDelegate' }
	},
}

return metadata
