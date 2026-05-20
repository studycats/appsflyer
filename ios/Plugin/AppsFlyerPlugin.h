//
//  AppsFlyerPlugin.h
//  AppsFlyer Plugin
//
//  Copyright (c) 2018 Corona Labs Inc. All rights reserved.
//

#ifndef AppsFlyerPlugin_H
#define AppsFlyerPlugin_H

#import "CoronaLua.h"
#import "CoronaMacros.h"

// This corresponds to the name of the library, e.g. [Lua] require "plugin.library"
// where the '.' is replaced with '_'
#if PLUGIN_STRICT
CORONA_EXPORT int luaopen_plugin_appsflyer_strict(lua_State *L);
#else
CORONA_EXPORT int luaopen_plugin_appsflyer(lua_State *L);
#endif


#endif // AppsFlyerPlugin_H
