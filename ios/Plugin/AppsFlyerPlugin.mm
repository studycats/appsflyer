//
//  AppsFlyerPlugin.mm
//  AppsFlyer Plugin
//
//  Copyright (c) 2018 Corona Labs Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "CoronaRuntime.h"
#import "CoronaAssert.h"
#import "CoronaEvent.h"
#import "CoronaLua.h"
#import "CoronaLibrary.h"
#import "CoronaLuaIOS.h"

// Plugin specific imports
#import "AppsFlyerPlugin.h"
#import <AppsFlyerLib/AppsFlyerLib.h>


// some macros to make life easier, and code more readable
#define UTF8StringWithFormat(format, ...) [[NSString stringWithFormat:format, ##__VA_ARGS__] UTF8String]
#define MsgFormat(format, ...) [NSString stringWithFormat:format, ##__VA_ARGS__]
#define UTF8IsEqual(utf8str1, utf8str2) (strcmp(utf8str1, utf8str2) == 0)

#define NoValue INT_MAX

// ----------------------------------------------------------------------------
// Plugin Constants
// ----------------------------------------------------------------------------


#if PLUGIN_STRICT
    #define PLUGIN_NAME        "plugin.appsflyer.strict"
#else
    #define PLUGIN_NAME        "plugin.appsflyer"
#endif
#define PLUGIN_VERSION     "1.2.0"
#define PLUGIN_SDK_VERSION [[AppsFlyerLib shared] getSDKVersion]

static const char EVENT_NAME[]    = "analyticsRequest";
static const char PROVIDER_NAME[] = "appsflyer";

// analytics types
static NSString * const TYPE_ATTRIBUTION = @"attribution";

// event phases
static NSString * const PHASE_INIT     = @"init";
static NSString * const PHASE_RECEIVED = @"received";
static NSString * const PHASE_RECORDED = @"recorded";
static NSString * const PHASE_FAILED   = @"failed";

// message constants
static NSString * const ERROR_MSG   = @"ERROR: ";
static NSString * const WARNING_MSG = @"WARNING: ";

// add missing keys
static const char EVENT_DATA_KEY[]  = "data";

@implementation NSData (HexString)

// ----------------------------------------------------------------------------
// NSData extension to convert hex string to data
// ----------------------------------------------------------------------------

+ (NSData *)dataFromHexString:(NSString *)string
{
  string = [string lowercaseString];
  NSMutableData *data= [NSMutableData new];
  unsigned char whole_byte;
  char byte_chars[3] = {'\0','\0','\0'};
  NSUInteger i = 0;
  NSUInteger length = string.length;
  
  while (i < length-1) {
    char c = [string characterAtIndex:i++];
    
    if (c < '0' || (c > '9' && c < 'a') || c > 'f') {
      continue;
    }
    
    byte_chars[0] = c;
    byte_chars[1] = [string characterAtIndex:i++];
    whole_byte = strtol(byte_chars, NULL, 16);
    [data appendBytes:&whole_byte length:1];
  }
  
  return data;
}

@end

// ----------------------------------------------------------------------------
// plugin class and delegate definitions
// ----------------------------------------------------------------------------

@interface AppsFlyerDelegate: NSObject <AppsFlyerLibDelegate>

@property (nonatomic, assign) CoronaLuaRef coronaListener;             // Reference to the Lua listener
@property (nonatomic, assign) id<CoronaRuntime> coronaRuntime;         // Pointer to the Corona runtime

- (void)dispatchLuaEvent:(NSDictionary *)dict;

@end

// ----------------------------------------------------------------------------

class AppsFlyerPlugin
{
public:
  typedef AppsFlyerPlugin Self;
  
public:
  static const char kName[];
		
public:
  static int Open(lua_State *L);
  static int Finalizer(lua_State *L);
  static Self *ToLibrary(lua_State *L);
  
protected:
  AppsFlyerPlugin();
  bool Initialize(void *platformContext);
		
public: // plugin API
  static int init(lua_State *L);
  static int logEvent(lua_State *L);
  static int getVersion(lua_State *L);
  static int setHasUserConsent(lua_State *L);
  static int logPurchase(lua_State *L);
  static int getAppsFlyerUID(lua_State *L);
  static int logRevenueAds(lua_State* L);

private: // internal helper functions
  static void logMsg(lua_State *L, NSString *msgType,  NSString *errorMsg);
  static bool isSDKInitialized(lua_State *L);
  static AppsFlyerAdRevenueMediationNetworkType mediationNetworkTypeFromString(NSString* mediationNetwork);
  
private:
  NSString *functionSignature;                                  // used in logMsg to identify function
  UIViewController *coronaViewController;                       // application's view controller
};

const char AppsFlyerPlugin::kName[] = PLUGIN_NAME;
AppsFlyerDelegate *appsflyerDelegate;                                     // AppsFlyer delegate

// ----------------------------------------------------------------------------
// helper functions
// ----------------------------------------------------------------------------

// log message to console
void
AppsFlyerPlugin::logMsg(lua_State *L, NSString* msgType, NSString* errorMsg)
{
  Self *context = ToLibrary(L);
  
  if (context) {
    Self& library = *context;
    
    NSString *functionID = [library.functionSignature copy];
    if (functionID.length > 0) {
      functionID = [functionID stringByAppendingString:@", "];
    }
    
    CoronaLuaLogPrefix(L, [msgType UTF8String], UTF8StringWithFormat(@"%@%@", functionID, errorMsg));
  }
}

// check if SDK calls can be made
bool
AppsFlyerPlugin::isSDKInitialized(lua_State *L)
{
  if (appsflyerDelegate == nil) {
    logMsg(L, ERROR_MSG, @"appsflyer.init() must be called before calling other API methods.");
    return false;
  }
  
  return true;
}

// Добавьте этот метод в ваш класс или в категорию (например, в .m файл)
AppsFlyerAdRevenueMediationNetworkType
AppsFlyerPlugin::mediationNetworkTypeFromString (NSString* mediationNetwork) {
    NSDictionary<NSString*, NSNumber*>* mapping = @{
        @"GOOGLE_ADMOB": @(AppsFlyerAdRevenueMediationNetworkTypeGoogleAdMob),
        @"IRONSOURCE": @(AppsFlyerAdRevenueMediationNetworkTypeIronSource),
        @"APPLOVIN_MAX": @(AppsFlyerAdRevenueMediationNetworkTypeApplovinMax),
        @"FYBER": @(AppsFlyerAdRevenueMediationNetworkTypeFyber),
        @"APPODEAL": @(AppsFlyerAdRevenueMediationNetworkTypeAppodeal),
        @"ADMOST": @(AppsFlyerAdRevenueMediationNetworkTypeAdmost),
        @"TOPON": @(AppsFlyerAdRevenueMediationNetworkTypeTopon),
        @"TRADPLUS": @(AppsFlyerAdRevenueMediationNetworkTypeTradplus),
        @"YANDEX": @(AppsFlyerAdRevenueMediationNetworkTypeYandex),
        @"CHARTBOOST": @(AppsFlyerAdRevenueMediationNetworkTypeChartBoost),
        @"UNITY": @(AppsFlyerAdRevenueMediationNetworkTypeUnity),
        @"TOPON_PTE": @(AppsFlyerAdRevenueMediationNetworkTypeToponPte),
        @"CUSTOM_MEDIATION": @(AppsFlyerAdRevenueMediationNetworkTypeCustom),
        @"DIRECT_MONETIZATION_NETWORK": @(AppsFlyerAdRevenueMediationNetworkTypeDirectMonetization)
    };

    for (NSString* key in mapping) {
        if ([key containsString: mediationNetwork]) {
            NSNumber *value = mapping[key];
            return (AppsFlyerAdRevenueMediationNetworkType)value.unsignedIntegerValue;
        }
    }

    return AppsFlyerAdRevenueMediationNetworkTypeCustom;
}

// ----------------------------------------------------------------------------
// plugin implementation
// ----------------------------------------------------------------------------

int
AppsFlyerPlugin::Open( lua_State *L )
{
  // Register __gc callback
  const char kMetatableName[] = __FILE__; // Globally unique string to prevent collision
  CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
  
  void *platformContext = CoronaLuaGetContext(L);
  
  // Set library as upvalue for each library function
  Self *library = new Self;
  
  if (library->Initialize(platformContext)) {
    // Functions in library
    static const luaL_Reg kFunctions[] = {
      {"init", init},
      {"logEvent", logEvent},
      {"getVersion", getVersion},
      {"setHasUserConsent", setHasUserConsent},
      {"logPurchase", logPurchase},
      {"getAppsFlyerUID", getAppsFlyerUID},
      {"logRevenueAds", logRevenueAds},
      {NULL, NULL}
    };
    
    // Register functions as closures, giving each access to the
    // 'library' instance via ToLibrary()
    {
      CoronaLuaPushUserdata(L, library, kMetatableName);
      luaL_openlib(L, kName, kFunctions, 1); // leave "library" on top of stack
    }
  }
  
  return 1;
}

int
AppsFlyerPlugin::Finalizer( lua_State *L )
{
  Self *library = (Self *)CoronaLuaToUserdata(L, 1);
  
  // Free the Lua listener
  CoronaLuaDeleteRef(L, appsflyerDelegate.coronaListener);
  appsflyerDelegate = nil;
  
  delete library;
  
  return 0;
}

AppsFlyerPlugin*
AppsFlyerPlugin::ToLibrary( lua_State *L )
{
  // library is pushed as part of the closure
  Self *library = (Self *)CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
  return library;
}

AppsFlyerPlugin::AppsFlyerPlugin()
: coronaViewController(nil)
{
}

bool
AppsFlyerPlugin::Initialize( void *platformContext )
{
  bool shouldInit = (! coronaViewController);
  
  if (shouldInit) {
    id<CoronaRuntime> runtime = (__bridge id<CoronaRuntime>)platformContext;
    coronaViewController = runtime.appViewController;
    
    functionSignature = @"";
    
    appsflyerDelegate = [AppsFlyerDelegate new];
    appsflyerDelegate.coronaRuntime = runtime;
  }
  
  return shouldInit;
}

// [Lua] init(listener, options)
int
AppsFlyerPlugin::init(lua_State *L)
{
  Self *context = ToLibrary(L);
  
  if (! context) { // abort if no valid context
    return 0;
  }
  
  Self& library = *context;
  
  const char *appID = NULL;
  const char *devKey = NULL;
  bool localHasUserConsent = false;
  bool debugMode = false;

  // prevent init from being called twice
  if (appsflyerDelegate.coronaListener != NULL) {
    logMsg(L, ERROR_MSG, @"init should only be called once");
    return 0;
  }
  
  library.functionSignature = @"appsflyer.init(listener, options)";
  
  // check number or args
  int nargs = lua_gettop(L);
  if (nargs != 2) {
    logMsg(L, ERROR_MSG, MsgFormat(@"Expected 2 arguments, got %d", nargs));
    return 0;
  }
  
  // Get the listener (required)
  if (CoronaLuaIsListener(L, 1, PROVIDER_NAME)) {
    appsflyerDelegate.coronaListener = CoronaLuaNewRef(L, 1);
  }
  else {
    logMsg(L, ERROR_MSG, MsgFormat(@"Listener expected, got: %s", luaL_typename(L, 1)));
    return 0;
  }
  
  // check for options table (required)
  if (lua_type(L, 2) == LUA_TTABLE) {
    // traverse and validate all the options
    for (lua_pushnil(L); lua_next(L, 2) != 0; lua_pop(L, 1)) {
      const char *key = lua_tostring(L, -2);
      
      // check for appId
      if (UTF8IsEqual(key, "appID")) {
        if (lua_type(L, -1) == LUA_TSTRING) {
          appID = lua_tostring(L, -1);
        }
        else {
          logMsg(L, ERROR_MSG, MsgFormat(@"options.appID (string) expected, got %s", luaL_typename(L, -1)));
          return 0;
        }
      }
      // check for devKey (required)
      else if (UTF8IsEqual(key, "devKey")) {
        if (lua_type(L, -1) == LUA_TSTRING) {
          devKey = lua_tostring(L, -1);
        }
        else {
          logMsg(L, ERROR_MSG, MsgFormat(@"options.devKey (string) expected, got %s", luaL_typename(L, -1)));
          return 0;
        }
      }
      // enable console logging (optional) default false
      else if (UTF8IsEqual(key, "enableDebugLogging")) {
        if (lua_type(L, -1) == LUA_TBOOLEAN) {
          debugMode = lua_toboolean(L, -1);
        }
        else {
          logMsg(L, ERROR_MSG, MsgFormat(@"options.enableDebugLogging (boolean) expected, got %s", luaL_typename(L, -1)));
          return 0;
        }
      }
      else if (UTF8IsEqual(key, "hasUserConsent")) {
          if (lua_type(L, -1) == LUA_TBOOLEAN) {
              localHasUserConsent = lua_toboolean(L, -1);
          }
          else {
              logMsg(L, ERROR_MSG, MsgFormat(@"options.hasUserConsent (boolean) expected, got %s", luaL_typename(L, -1)));
              return 0;
          }
      }
      else {
        logMsg(L, ERROR_MSG, MsgFormat(@"Invalid option '%s'", key));
        return 0;
      }
    }
  }
  else {
    logMsg(L, ERROR_MSG, MsgFormat(@"options table expected, got %s", luaL_typename(L, 2)));
    return 0;
  }
  
  // check required params
  if (appID == NULL) {
    logMsg(L, ERROR_MSG, MsgFormat(@"options.appID is required"));
    return 0;
  }
    // initialize the event tracker
    [AppsFlyerLib shared].appsFlyerDevKey = [NSString stringWithUTF8String:devKey];
    [AppsFlyerLib shared].appleAppID = [NSString stringWithUTF8String:appID];
    [AppsFlyerLib shared].delegate = appsflyerDelegate;
    [AppsFlyerLib shared].anonymizeUser = !localHasUserConsent;
    [AppsFlyerLib shared].isDebug = debugMode;
    [[AppsFlyerLib shared] waitForATTUserAuthorizationWithTimeoutInterval:60.0];
    [[AppsFlyerLib shared] start];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        // send Corona Lua event
        NSDictionary *coronaEvent = @{
                                      @(CoronaEventPhaseKey()) : PHASE_INIT
                                      };
        [appsflyerDelegate dispatchLuaEvent:coronaEvent];

        // Log plugin version to console
        NSString *version = PLUGIN_SDK_VERSION ? PLUGIN_SDK_VERSION : @"Plugin SDK version unknown";
        NSLog(@"%@", version);
    });

  return 0;
}

// [Lua] appsflyer.getVersion()
int
AppsFlyerPlugin::getVersion(lua_State *L)
{
    Self *context = ToLibrary(L);

    if (! context) { // abort if no valid context
        return 0;
    }

    Self& library = *context;

    library.functionSignature = @"appsflyer.getVersion()";

    if (! isSDKInitialized(L)) {
        return 0;
    }

    logMsg(L, @"Data received:", MsgFormat(@"%s: %s (SDK: %@)", PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_SDK_VERSION));

    // Create the reward event data
    NSDictionary *eventData = @{
                                @"pluginVersion": @PLUGIN_VERSION,
                                @"sdkVersion": PLUGIN_SDK_VERSION
                                };

    NSDictionary *coronaEvent = @{
                                  @(CoronaEventPhaseKey()): PHASE_RECEIVED,
                                  @(CoronaEventDataKey()): eventData,
                                  };
    [appsflyerDelegate dispatchLuaEvent:coronaEvent];

    return 0;
}

// [Lua] logEvent(eventName, options)
int
AppsFlyerPlugin::logEvent(lua_State *L)
{
  Self *context = ToLibrary(L);

  if (! context) { // abort if no valid context
    return 0;
  }

  Self& library = *context;

  library.functionSignature = @"appsflyer.logEvent(eventName, options)";

  if (! isSDKInitialized(L)) {
    return 0;
  }

  // check number or args
  int nargs = lua_gettop(L);
  if ((nargs < 1) || (nargs > 2)) {
    logMsg(L, ERROR_MSG, MsgFormat(@"Expected 1 or 2 arguments, got %d", nargs));
    return 0;
  }

  const char *eventName = NULL;
  NSMutableDictionary *standardParams = [NSMutableDictionary new];

  // get event param type
  if (lua_type(L, 1) == LUA_TSTRING) {
    eventName = lua_tostring(L, 1);
  }
  else {
    logMsg(L, ERROR_MSG, MsgFormat(@"eventName (string) expected, got %s", luaL_typename(L, 1)));
    return 0;
  }

  // get event param properties
  if (! lua_isnoneornil(L, 2)) {
    if (lua_type(L, 2) == LUA_TTABLE) {
      // traverse and validate all the properties
      for (lua_pushnil(L); lua_next(L, 2) != 0; lua_pop(L, 1)) {
        const char *key = lua_tostring(L, -2);
          if (lua_type(L, -1) == LUA_TSTRING) {
            standardParams[@(key)] = @(lua_tostring(L, -1));
          }
          else if (lua_type(L, -1) == LUA_TBOOLEAN) {
            standardParams[@(key)] = @(lua_toboolean(L, -1));
          }
          else if (lua_type(L, -1) == LUA_TNUMBER) {
            standardParams[@(key)] = @(lua_tonumber(L, -1));
          }
          else {
            logMsg(L, ERROR_MSG, MsgFormat(@"options.%s unhandled type (%s)", key, luaL_typename(L, -1)));
            return 0;
          }
      }
    }
    else {
      logMsg(L, ERROR_MSG, MsgFormat(@"options table expected, got %s", luaL_typename(L, 2)));
      return 0;
    }
  }

    
    [[AppsFlyerLib shared] logEventWithEventName:[NSString stringWithUTF8String:eventName] eventValues:standardParams completionHandler:^(NSDictionary<NSString *,id> * _Nullable dictionary, NSError * _Nullable error) {
        if(error){
            
            NSDictionary *coronaEvent = @{
              @(CoronaEventPhaseKey()) : PHASE_FAILED,
              @(CoronaEventDataKey()) : error.localizedDescription,
              @(CoronaEventIsErrorKey()): @YES,
            };
            [appsflyerDelegate dispatchLuaEvent:coronaEvent];
        }else{
            // send Corona Lua event
            NSDictionary *coronaEvent = @{
              @(CoronaEventPhaseKey()) : PHASE_RECORDED,
              @(CoronaEventIsErrorKey()): @NO,
            };
            [appsflyerDelegate dispatchLuaEvent:coronaEvent];
        }
    }];

  return 0;
}

// [Lua] logPurchase()
int
AppsFlyerPlugin::logPurchase(lua_State *L)
{
    Self *context = ToLibrary(L);

    if (! context) { // abort if no valid context
        return 0;
    }

    Self& library = *context;

    library.functionSignature = @"appsflyer.logPurchase()";

    if (! isSDKInitialized(L)) {
        return 0;
    }

    // check number or args
    int nargs = lua_gettop(L);
    if (nargs != 1) {
        logMsg(L, ERROR_MSG, MsgFormat(@"Expected 1 argument, got %d", nargs));
        return 0;
    }

    const char *productId = NULL;
    const char *price = NULL;
    const char *currency = NULL;
    const char *transactionId = NULL;
    NSMutableDictionary *params = [NSMutableDictionary new];

    // get event param type
    if (lua_type(L, 1) == LUA_TTABLE) {
        // traverse and validate all the properties
        for (lua_pushnil(L); lua_next(L, 1) != 0; lua_pop(L, 1)) {
            const char *key = lua_tostring(L, -2);

            if (UTF8IsEqual(key, "productId")) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    productId = lua_tostring(L, -1);
                }
                else {
                    logMsg(L, ERROR_MSG, MsgFormat(@"productData.productId (string) expected, got %s", luaL_typename(L, -1)));
                    return 0;
                }
            } else if (UTF8IsEqual(key, "price")) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    price = lua_tostring(L, -1);
                }
                else {
                    logMsg(L, ERROR_MSG, MsgFormat(@"productData.price (string) expected, got %s", luaL_typename(L, -1)));
                    return 0;
                }
            } else if (UTF8IsEqual(key, "currency")) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    currency = lua_tostring(L, -1);
                }
                else {
                    logMsg(L, ERROR_MSG, MsgFormat(@"productData.currency (string) expected, got %s", luaL_typename(L, -1)));
                    return 0;
                }
            } else if (UTF8IsEqual(key, "transactionId")) {
                if (lua_type(L, -1) == LUA_TSTRING) {
                    transactionId = lua_tostring(L, -1);
                }
                else {
                    logMsg(L, ERROR_MSG, MsgFormat(@"productData.transactionId (string) expected, got %s", luaL_typename(L, -1)));
                    return 0;
                }
            } else if (UTF8IsEqual(key, "parameters")) {
                if (lua_type(L, -1) == LUA_TTABLE) {
                    // we need gettop() here since -1 will return nil
                    // we also need to make it mutable (see below for float64 to float32 conversion)
                    params = [CoronaLuaCreateDictionary(L, lua_gettop(L)) mutableCopy];
                }
                else {
                    logMsg(L, ERROR_MSG, MsgFormat(@"productData.parameters (table) expected, got %s", luaL_typename(L, -1)));
                    return 0;
                }
            } else {
                logMsg(L, ERROR_MSG, MsgFormat(@"Invalid option '%s'", key));
                return 0;
            }
        }
    } else {
        logMsg(L, ERROR_MSG, MsgFormat(@"purchaseData (table) expected, got %s", luaL_typename(L, 1)));
        return 0;
    }

    [[AppsFlyerLib shared] validateAndLogInAppPurchase:[NSString stringWithUTF8String:productId] price:[NSString stringWithUTF8String:price] currency:[NSString stringWithUTF8String:currency] transactionId:[NSString stringWithUTF8String:transactionId] additionalParameters:params success:^(NSDictionary *response) {
        NSDictionary *coronaEvent = @{
                                      @(CoronaEventPhaseKey()): PHASE_RECORDED,
                                      @(CoronaEventDataKey()): response,
                                      };
        [appsflyerDelegate dispatchLuaEvent:coronaEvent];
    } failure:^(NSError *error, id reponse) {
        NSDictionary *coronaEvent = @{
                                      @(CoronaEventPhaseKey()): PHASE_FAILED,
                                      @(CoronaEventDataKey()): reponse,
                                      @(CoronaEventIsErrorKey()): @YES
                                      };
        [appsflyerDelegate dispatchLuaEvent:coronaEvent];
    }];

    return 0;
}
// [Lua] logPurchase()

int
AppsFlyerPlugin::getAppsFlyerUID(lua_State *L)
{
	NSString *appsflyerId = [[AppsFlyerLib shared] getAppsFlyerUID];
	lua_pushstring(L, [appsflyerId UTF8String]);
	return 1;
}

// [Lua] setHasUserConsent(boolean)
int
AppsFlyerPlugin::setHasUserConsent(lua_State *L)
{
    Self *context = ToLibrary(L);

    if (! context) { // abort if no valid context
        return 0;
    }

    Self& library = *context;

    library.functionSignature = @"appsflyer.setHasUserConsent(boolean)";

    if (! isSDKInitialized(L)) {
        return 0;
    }

    bool localHasUserConsent = false;

    // check number or args
    int nargs = lua_gettop(L);
    if (nargs != 1) {
        logMsg(L, ERROR_MSG, MsgFormat(@"Expected 1 argument, got %d", nargs));
        return 0;
    }

    // check for consent boolean (required)
    if (lua_type(L, 1) == LUA_TBOOLEAN) {
        // send user consent to AppsFlyer
        localHasUserConsent = lua_toboolean(L, -1);
        [AppsFlyerLib shared].anonymizeUser = !localHasUserConsent;
        return 0;
    }
    else {
        logMsg(L, ERROR_MSG, MsgFormat(@"Boolean expected, got %s", luaL_typename(L, 1)));
        return 0;
    }
}

int
AppsFlyerPlugin::logRevenueAds(lua_State* L)
{
    Self* context = ToLibrary(L);

    if (!context || !isSDKInitialized(L)) { // abort if no valid context
        return 0;
    }

    Self& library = *context;
    library.functionSignature = @"appsflyer.logRevenueAds()";

    // check number or args
    int nargs = lua_gettop(L);
    if (nargs != 1) {
        logMsg(L, ERROR_MSG, MsgFormat(@"Expected 1 argument, got %d", nargs));
        return 0;
    }

    NSString* revenueString = [NSString stringWithUTF8String: lua_tostring(L, -1)];
    NSLog(@"revenueString: %@", revenueString);
    NSData* data = [revenueString dataUsingEncoding: NSUTF8StringEncoding];
    NSError* error = nil;

    NSDictionary* revenueDictionary = [NSJSONSerialization JSONObjectWithData: data
                                                                      options: NSJSONReadingMutableContainers
                                                                        error: &error];
    if (error) {
        NSLog(@"Error: %@", error.localizedDescription);

        return 0;
    } else {
        NSLog(@"%@", [revenueDictionary debugDescription]);
    }

    NSString* monetizationNetwork = revenueDictionary[@"monetizationNetwork"];
    NSString* currencyIso4217Code = revenueDictionary[@"currencyIso4217Code"];
    NSNumber* revenue = revenueDictionary[@"value"]; //Ironsource naming
    NSString* countryCode = revenueDictionary[@"countryCode"];
    NSString* adUnitName = revenueDictionary[@"adUnitName"];
    NSString* medNetwork = revenueDictionary[@"adSource"]; //Ironsource naming
    NSString* adType = revenueDictionary[@"adFormat"]; //Ironsource naming
    NSString* placement = revenueDictionary[@"placement"];

    AppsFlyerAdRevenueMediationNetworkType mediationNetwork = mediationNetworkTypeFromString([medNetwork uppercaseString]);

    NSMutableDictionary* additionalParams = [NSMutableDictionary new];
    [additionalParams setObject:countryCode forKey:kAppsFlyerAdRevenueCountry];
    [additionalParams setObject:adUnitName forKey:kAppsFlyerAdRevenueAdUnit];
    [additionalParams setObject:adType forKey:kAppsFlyerAdRevenueAdType];
    [additionalParams setObject:placement forKey:kAppsFlyerAdRevenuePlacement];

    AFAdRevenueData* adRevenueData = [[AFAdRevenueData alloc] initWithMonetizationNetwork:monetizationNetwork mediationNetwork:mediationNetwork currencyIso4217Code:currencyIso4217Code eventRevenue:revenue];

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [[AppsFlyerLib shared] logAdRevenue:adRevenueData additionalParameters:additionalParams];
    }];

    return 0;
}

// ============================================================================
// delegate implementation
// ============================================================================

@implementation AppsFlyerDelegate

- (instancetype)init {
  if (self = [super init]) {
    self.coronaListener = NULL;
    self.coronaRuntime = NULL;
  }
  
  return self;
}

// dispatch a new Lua event
- (void)dispatchLuaEvent:(NSDictionary *)dict
{
  [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    lua_State *L = self.coronaRuntime.L;
    CoronaLuaRef coronaListener = self.coronaListener;
    bool hasErrorKey = false;
    
    // create new event
    CoronaLuaNewEvent(L, EVENT_NAME);
    
    for (NSString *key in dict) {
      CoronaLuaPushValue(L, [dict valueForKey:key]);
      lua_setfield(L, -2, key.UTF8String);
      
      if (! hasErrorKey) {
        hasErrorKey = [key isEqualToString:@(CoronaEventIsErrorKey())];
      }
    }
    
    // add error key if not in dict
    if (! hasErrorKey) {
      lua_pushboolean(L, false);
      lua_setfield(L, -2, CoronaEventIsErrorKey());
    }
    
    // add provider
    lua_pushstring(L, PROVIDER_NAME );
    lua_setfield(L, -2, CoronaEventProviderKey());
    
    CoronaLuaDispatchEvent(L, coronaListener, 0);
  }];
}

- (void)onConversionDataReceived:(NSDictionary *)installData {
      if (! [NSJSONSerialization isValidJSONObject:installData]) {
        NSLog(@"AppsFlyer: attribution data cannot be converted to JSON object %@", installData);
        // send Corona Lua event
        NSDictionary *coronaEvent = @{
          @(CoronaEventPhaseKey()) : PHASE_FAILED,
          @(CoronaEventTypeKey()) : TYPE_ATTRIBUTION,
          @(CoronaEventIsErrorKey()): @YES,
          @(EVENT_DATA_KEY) : [NSString stringWithFormat:@"Cannot convert to JSON: %@", installData]
        };
        [self dispatchLuaEvent:coronaEvent];
      }
      else {
        NSError *jsonError = nil;

        // convert data to json string
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:installData options:0 error:&jsonError];

        if ((jsonData == nil) || (jsonError != nil)) {
          NSLog(@"AppsFlyer JSON error %@", jsonError);
        }
        else {
          NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

          // send Corona Lua event
          NSDictionary *coronaEvent = @{
            @(CoronaEventPhaseKey()) : PHASE_RECEIVED,
            @(CoronaEventTypeKey()) : TYPE_ATTRIBUTION,
            @(EVENT_DATA_KEY) : jsonString
          };
          [self dispatchLuaEvent:coronaEvent];
        }
      }
    }

-(void)onAppOpenAttribution:(NSDictionary *)attributionData {
  if (! [NSJSONSerialization isValidJSONObject:attributionData]) {
	NSLog(@"AppsFlyer: attribution data cannot be converted to JSON object %@", attributionData);
	// send Corona Lua event
	NSDictionary *coronaEvent = @{
	  @(CoronaEventPhaseKey()) : PHASE_FAILED,
	  @(CoronaEventTypeKey()) : TYPE_ATTRIBUTION,
	  @(CoronaEventIsErrorKey()): @YES,
	  @(EVENT_DATA_KEY) : [NSString stringWithFormat:@"Cannot convert to JSON: %@", attributionData]
	};
	[self dispatchLuaEvent:coronaEvent];
  }
  else {
	NSError *jsonError = nil;

	// convert data to json string
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:attributionData options:0 error:&jsonError];

	if ((jsonData == nil) || (jsonError != nil)) {
	  NSLog(@"AppsFlyer JSON error %@", jsonError);
	}
	else {
	  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

	  // send Corona Lua event
	  NSDictionary *coronaEvent = @{
		@(CoronaEventPhaseKey()) : PHASE_RECEIVED,
		@(CoronaEventTypeKey()) : TYPE_ATTRIBUTION,
		@(EVENT_DATA_KEY) : jsonString
	  };
	  [self dispatchLuaEvent:coronaEvent];
	}
  }
}


- (void)onConversionDataFail:(nonnull NSError *)error {
//	NSDictionary *coronaEvent = @{
//	  @(CoronaEventPhaseKey()) : PHASE_FAILED,
//	  @(CoronaEventTypeKey()) : TYPE_ATTRIBUTION,
//	  @(CoronaEventIsErrorKey()): @YES,
//	  @(CoronaEventResponseKey()) : [error localizedDescription]
//	};
//	[self dispatchLuaEvent:coronaEvent];
}

- (void)onConversionDataSuccess:(nonnull NSDictionary *)conversionInfo {
	[self onConversionDataReceived:conversionInfo];
}

@end

// ----------------------------------------------------------------------------
#if PLUGIN_STRICT
CORONA_EXPORT int luaopen_plugin_appsflyer_strict(lua_State *L)
#else
CORONA_EXPORT int luaopen_plugin_appsflyer(lua_State *L)
#endif
{
  return AppsFlyerPlugin::Open(L);
}

