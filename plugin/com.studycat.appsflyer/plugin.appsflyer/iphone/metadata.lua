local metadata =
{
	plugin =
	{
		format = 'staticLibrary',
		staticLibs = { 'plugin_appsflyer', },
		frameworks = { 'AppsFlyerLib' },
		frameworksOptional = { 'AdServices', 'iAd' },
		delegates = { 'CoronaAppsFlyerDelegate' }
	},
}

return metadata
