//
// LuaLoader.java
// AppsFlyer Plugin
//
// Copyright (c) 2018 Corona Labs, Inc. All rights reserved.
//

package plugin.appsflyer;

import com.ansca.corona.CoronaActivity;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaLuaEvent;
import com.ansca.corona.CoronaRuntimeTask;
import com.ansca.corona.CoronaRuntimeTaskDispatcher;
import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeListener;

import com.appsflyer.AFAdRevenueData;
import com.appsflyer.AdRevenueScheme;
import com.appsflyer.AppsFlyerInAppPurchaseValidatorListener;
import com.appsflyer.MediationNetwork;
import com.appsflyer.attribution.AppsFlyerRequestListener;
import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.naef.jnlua.JavaFunction;
import com.naef.jnlua.LuaType;
import com.naef.jnlua.NamedJavaFunction;
import com.naef.jnlua.LuaState;

import java.util.HashMap;
import java.util.Hashtable;
import java.util.Map;

import android.util.Log;

// AppsFlyer imports
import com.appsflyer.AppsFlyerLib;
import com.appsflyer.AppsFlyerConversionListener;

/**
 * Implements the Lua interface for the AppsFlyer Plugin.
 * <p>
 * Only one instance of this class will be created by Corona for the lifetime of the application.
 * This instance will be re-used for every new Corona activity that gets created.
 */
@SuppressWarnings({"unused", "RedundantSuppression"})
public class LuaLoader implements JavaFunction, CoronaRuntimeListener {
    private static final String PLUGIN_NAME = "plugin.appsflyer";
    private static final String PLUGIN_VERSION = "1.1.0";

    private static String PLUGIN_SDK_VERSION() {
        return AppsFlyerLib.getInstance().getSdkVersion();
    }

    private static final String EVENT_NAME = "analyticsRequest";
    private static final String PROVIDER_NAME = "appsflyer";

    // analytics types
    private static final String TYPE_ATTRIBUTION = "attribution";

    // event phases
    private static final String PHASE_INIT = "init";
    private static final String PHASE_RECEIVED = "received";
    private static final String PHASE_RECORDED = "recorded";
    private static final String PHASE_FAILED = "failed";

    // add missing event keys
    private static final String EVENT_PHASE_KEY = "phase";
    private static final String EVENT_DATA_KEY = "data";
    private static final String EVENT_TYPE_KEY = "type";
    private static final String EVENT_IS_ERROR_KEY = "isError";

    // message constants
    private static final String CORONA_TAG = "Corona";
    private static final String ERROR_MSG = "ERROR: ";
    private static final String WARNING_MSG = "WARNING: ";

    private static int coronaListener = CoronaLua.REFNIL;
    private static CoronaRuntimeTaskDispatcher coronaRuntimeTaskDispatcher = null;

    private static String functionSignature = "";
    private static AppsFlyerConversionListener appsflyerDelegate = null;

    // -------------------------------------------------------
    // Plugin lifecycle events
    // -------------------------------------------------------

    /**
     * <p>
     * Note that a new LuaLoader instance will not be created for every CoronaActivity instance.
     * That is, only one instance of this class will be created for the lifetime of the application process.
     * This gives a plugin the option to do operations in the background while the CoronaActivity is destroyed.
     */
    @SuppressWarnings("unused")
    public LuaLoader() {
        // Set up this plugin to listen for Corona runtime events to be received by methods
        // onLoaded(), onStarted(), onSuspended(), onResumed(), and onExiting().

        CoronaEnvironment.addRuntimeListener(this);
    }

    /**
     * Called when this plugin is being loaded via the Lua require() function.
     * <p>
     * Note that this method will be called every time a new CoronaActivity has been launched.
     * This means that you'll need to re-initialize this plugin here.
     * <p>
     * Warning! This method is not called on the main UI thread.
     *
     * @param L Reference to the Lua state that the require() function was called from.
     * @return Returns the number of values that the require() function will return.
     * <p>
     * Expected to return 1, the library that the require() function is loading.
     */
    @Override
    public int invoke(LuaState L) {
        // Register this plugin into Lua with the following functions.
        NamedJavaFunction[] luaFunctions = new NamedJavaFunction[]{
                new Init(),
                new LogEvent(),
                new GetVersion(),
                new SetHasUserConsent(),
                new GetAppsFlyerUID(),
                new LogPurchase(),
                new LogRevenueAds()
        };
        String libName = L.toString(1);
        L.register(libName, luaFunctions);

        // Returning 1 indicates that the Lua require() function will return the above Lua library
        return 1;
    }

    /**
     * Called after the Corona runtime has been created and just before executing the "main.lua" file.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that has just been loaded/initialized.
     *                Provides a LuaState object that allows the application to extend the Lua API.
     */
    @Override
    public void onLoaded(CoronaRuntime runtime) {
        // Note that this method will not be called the first time a Corona activity has been launched.
        // This is because this listener cannot be added to the CoronaEnvironment until after
        // this plugin has been required-in by Lua, which occurs after the onLoaded() event.
        // However, this method will be called when a 2nd Corona activity has been created.

        if (coronaRuntimeTaskDispatcher == null) {
            coronaRuntimeTaskDispatcher = new CoronaRuntimeTaskDispatcher(runtime);
        }
    }

    /**
     * Called just after the Corona runtime has executed the "main.lua" file.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that has just been started.
     */
    @Override
    public void onStarted(CoronaRuntime runtime) {
    }

    /**
     * Called just after the Corona runtime has been suspended which pauses all rendering, audio, timers,
     * and other Corona related operations. This can happen when another Android activity (ie: window) has
     * been displayed, when the screen has been powered off, or when the screen lock is shown.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that has just been suspended.
     */
    @Override
    public void onSuspended(CoronaRuntime runtime) {
    }

    /**
     * Called just after the Corona runtime has been resumed after a suspend.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that has just been resumed.
     */
    @Override
    public void onResumed(CoronaRuntime runtime) {
    }

    /**
     * Called just before the Corona runtime terminates.
     * <p>
     * This happens when the Corona activity is being destroyed which happens when the user presses the Back button
     * on the activity, when the native.requestExit() method is called in Lua, or when the activity's finish()
     * method is called. This does not mean that the application is exiting.
     * <p>
     * Warning! This method is not called on the main thread.
     *
     * @param runtime Reference to the CoronaRuntime object that is being terminated.
     */
    @Override
    public void onExiting(final CoronaRuntime runtime) {
        // reset class variables
        CoronaLua.deleteRef(runtime.getLuaState(), coronaListener);
        coronaListener = CoronaLua.REFNIL;

        appsflyerDelegate = null;
        coronaRuntimeTaskDispatcher = null;
        functionSignature = "";
    }

    // --------------------------------------------------------------------------
    // helper functions
    // --------------------------------------------------------------------------

    // log message to console
    @SuppressWarnings("SameParameterValue")
    private void logMsg(String msgType, String errorMsg) {
        String functionID = functionSignature;
        if (!functionID.isEmpty()) {
            functionID += ", ";
        }

        Log.i(CORONA_TAG, msgType + functionID + errorMsg);
    }

    // return true if SDK is properly initialized
    private boolean isSDKInitialized() {
        if (appsflyerDelegate == null) {
            logMsg(ERROR_MSG, "appsflyer.init() must be called before calling other API functions");
            return false;
        }

        return true;
    }

    // dispatch a Lua event to our callback (dynamic handling of properties through map)
    private void dispatchLuaEvent(final Map<String, Object> event) {
        if (coronaRuntimeTaskDispatcher != null) {
            coronaRuntimeTaskDispatcher.send(new CoronaRuntimeTask() {
                public void executeUsing(CoronaRuntime runtime) {
                    try {
                        LuaState L = runtime.getLuaState();
                        CoronaLua.newEvent(L, EVENT_NAME);
                        boolean hasErrorKey = false;

                        // add event parameters from map
                        for (String key : event.keySet()) {
                            CoronaLua.pushValue(L, event.get(key));           // push value
                            L.setField(-2, key);                              // push key

                            if (!hasErrorKey) {
                                hasErrorKey = key.equals(CoronaLuaEvent.ISERROR_KEY);
                            }
                        }

                        // add error key if not in map
                        if (!hasErrorKey) {
                            L.pushBoolean(false);
                            L.setField(-2, CoronaLuaEvent.ISERROR_KEY);
                        }

                        // add provider
                        L.pushString(PROVIDER_NAME);
                        L.setField(-2, CoronaLuaEvent.PROVIDER_KEY);

                        CoronaLua.dispatchEvent(L, coronaListener, 0);
                    } catch (Exception ex) {
                        ex.printStackTrace();
                    }
                }
            });
        }
    }

    // -------------------------------------------------------
    // plugin implementation
    // -------------------------------------------------------

    // [Lua] init(listener, params)
    private class Init implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "init";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(final LuaState luaState) {

            // Parameters
            String appID = null;
            String devKey = null;
            boolean localHasUserConsent = false;
            boolean debugMode = false;

            // prevent init from being called twice
            if (appsflyerDelegate != null) {
                return 0;
            }

            functionSignature = "appsflyer.init(listener, options)";

            // check number of args
            int nargs = luaState.getTop();
            if (nargs != 2) {
                logMsg(ERROR_MSG, "Expected 2 arguments, got " + nargs);
                return 0;
            }

            // Get the listener (required)
            if (CoronaLua.isListener(luaState, 1, PROVIDER_NAME)) {
                coronaListener = CoronaLua.newRef(luaState, 1);
            } else {
                logMsg(ERROR_MSG, "Listener expected, got: " + luaState.typeName(1));
                return 0;
            }

            // check for options table (required)
            if (luaState.type(2) == LuaType.TABLE) {
                // traverse and verify all options
                for (luaState.pushNil(); luaState.next(2); luaState.pop(1)) {
                    String key = luaState.toString(-2);

                    switch (key) {
                        case "appID":
                            if (luaState.type(-1) == LuaType.STRING) {
                                appID = luaState.toString(-1);
                            } else {
                                logMsg(ERROR_MSG, "options.appID (string) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        case "devKey":
                            if (luaState.type(-1) == LuaType.STRING) {
                                devKey = luaState.toString(-1);
                            } else {
                                logMsg(ERROR_MSG, "options.devKey (string) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        case "enableDebugLogging":
                            if (luaState.type(-1) == LuaType.BOOLEAN) {
                                debugMode = luaState.toBoolean(-1);
                            } else {
                                logMsg(ERROR_MSG, "options.enableDebugLogging (boolean) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        case "hasUserConsent":
                            if (luaState.type(-1) == LuaType.BOOLEAN) {
                                localHasUserConsent = luaState.toBoolean(-1);
                            } else {
                                logMsg(ERROR_MSG, "options.hasUserConsent (boolean) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        default:
                            logMsg(ERROR_MSG, "Invalid option '" + key + "'");
                            return 0;
                    }
                }
            } else {
                logMsg(ERROR_MSG, "options table expected, got " + luaState.typeName(2));
                return 0;
            }

            // check required params
            if (appID == null) {
                logMsg(ERROR_MSG, "options.appID is required");
                return 0;
            }

            final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();

            // make values final
            final String fAppID = appID;
            final String fDevKey = devKey;
            final boolean fLocalHasUserConsent = localHasUserConsent;
            final boolean fDebugMode = debugMode;

            if (coronaActivity != null) {
                coronaActivity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {

                        appsflyerDelegate = new AppsflyerDelegate();

                        AppsFlyerLib.getInstance().init(fDevKey, appsflyerDelegate, coronaActivity.getApplicationContext());
                        AppsFlyerLib.getInstance().start(coronaActivity.getApplication());

                        AppsFlyerLib.getInstance().registerConversionListener(coronaActivity.getApplicationContext(), appsflyerDelegate);
                        AppsFlyerLib.getInstance().setDebugLog(fDebugMode);
                        AppsFlyerLib.getInstance().anonymizeUser(!fLocalHasUserConsent);

                        // Log plugin version to device log
                        Log.i(CORONA_TAG, PLUGIN_NAME + ": " + PLUGIN_VERSION + " (SDK: " + PLUGIN_SDK_VERSION() + ")");

                        // send Corona Lua event
                        Map<String, Object> coronaEvent = new HashMap<>();
                        coronaEvent.put(EVENT_PHASE_KEY, PHASE_INIT);
                        dispatchLuaEvent(coronaEvent);

//						sendToBeacon(CoronaBeacon.IMPRESSION, null);
                    }
                });
            }

            return 0;
        }
    }

    // [Lua] appsflyer.getVersion()
    private class GetVersion implements NamedJavaFunction {
        // Gets the name of the Lua function as it would appear in the Lua script
        @Override
        public String getName() {
            return "getVersion";
        }

        // This method is executed when the Lua function is called
        @Override
        public int invoke(LuaState luaState) {
            functionSignature = "appsflyer.getVersion()";

            if (!isSDKInitialized()) {
                return 0;
            }

            // declare final vars for inner loop
            final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();

            if (coronaActivity != null) {
                coronaActivity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        Log.i(CORONA_TAG, PLUGIN_NAME + ": " + PLUGIN_VERSION + " (SDK: " + PLUGIN_SDK_VERSION() + ")");
                        // Dispatch the Lua event
                        HashMap<String, Object> event = new HashMap<>();
                        event.put("pluginVersion", PLUGIN_VERSION);
                        event.put("sdkVersion", PLUGIN_SDK_VERSION());
                        dispatchLuaEvent(event);
                    }
                });
            }

            return 0;
        }
    }

    private static class GetAppsFlyerUID implements NamedJavaFunction {
        // Gets the name of the Lua function as it would appear in the Lua script
        @Override
        public String getName() {
            return "getAppsFlyerUID";
        }

        // This method is executed when the Lua function is called
        @Override
        public int invoke(LuaState luaState) {
            final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();
            String uid = AppsFlyerLib.getInstance().getAppsFlyerUID(coronaActivity.getApplicationContext());
            luaState.pushString(uid);
            return 1;
        }
    }


    private class LogEvent implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "logEvent";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(LuaState luaState) {
            functionSignature = "appsflyer.logEvent(eventName, options)";

            if (!isSDKInitialized()) {
                return 0;
            }

            // check number or args
            int nargs = luaState.getTop();
            if ((nargs < 1) || (nargs > 2)) {
                logMsg(ERROR_MSG, "Expected 1 or 2 arguments, got " + nargs);
                return 0;
            }

            final String eventName;
            final Map<String, Object> standardParams = new HashMap<>();

            // get event param type
            if (luaState.type(1) == LuaType.STRING) {
                eventName = luaState.toString(1);
            } else {
                logMsg(ERROR_MSG, "eventName (string) expected, got " + luaState.typeName(1));
                return 0;
            }

            // get event param properties
            if (!luaState.isNoneOrNil(2)) {
                if (luaState.type(2) == LuaType.TABLE) {
                    // traverse and validate all the properties
                    for (luaState.pushNil(); luaState.next(2); luaState.pop(1)) {
                        String key = luaState.toString(-2);
                        if (luaState.type(-1) == LuaType.STRING) {
                            standardParams.put(key, luaState.toString(-1));
                        } else if (luaState.type(-1) == LuaType.BOOLEAN) {
                            standardParams.put(key, luaState.toBoolean(-1));
                        } else if (luaState.type(-1) == LuaType.NUMBER) {
                            standardParams.put(key, luaState.toNumber(-1));
                        } else {
                            logMsg(ERROR_MSG, "options." + key + " unhandled type (" + luaState.typeName(-1) + ")");
                            return 0;
                        }
                    }
                } else {
                    logMsg(ERROR_MSG, "options table expected, got " + luaState.typeName(2));
                    return 0;
                }
            }

            // declare final values for inner loop
            final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();

            if (coronaActivity != null) {
                coronaActivity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        // send parameters to AppsFlyer

                        AppsFlyerLib.getInstance().logEvent(coronaActivity.getApplicationContext(), eventName, standardParams, new AppsFlyerRequestListener() {
                            @Override
                            public void onSuccess() {
                                Map<String, Object> coronaEvent = new HashMap<>();
                                coronaEvent.put(EVENT_PHASE_KEY, PHASE_RECORDED);
                                coronaEvent.put(EVENT_IS_ERROR_KEY, false);
                                dispatchLuaEvent(coronaEvent);
                            }

                            @Override
                            public void onError(int i, String s) {
                                Map<String, Object> coronaEvent = new HashMap<>();
                                coronaEvent.put(EVENT_PHASE_KEY, PHASE_FAILED);
                                coronaEvent.put(EVENT_IS_ERROR_KEY, true);
                                coronaEvent.put(EVENT_DATA_KEY, s);
                                dispatchLuaEvent(coronaEvent);

                            }
                        });
                        // send Corona Lua event
                        Map<String, Object> coronaEvent = new HashMap<>();
                        coronaEvent.put(EVENT_PHASE_KEY, PHASE_RECORDED);
                        dispatchLuaEvent(coronaEvent);
                    }
                });
            }

            return 0;
        }
    }

    private class LogPurchase implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "logPurchase";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(LuaState luaState) {
            functionSignature = "appsflyer.logPurchase()";

            if (!isSDKInitialized()) {
                return 0;
            }

            // check number or args
            int nargs = luaState.getTop();
            if (nargs != 1) {
                logMsg(ERROR_MSG, "Expected 1 argument, got " + nargs);
                return 0;
            }

            String publicKey = null;
            String signature = null;
            String purchaseData = null;
            String price = null;
            String currency = null;
            Hashtable<Object, Object> params = new Hashtable<>();

            if (luaState.type(1) == LuaType.TABLE) {
                // traverse and validate all the properties
                for (luaState.pushNil(); luaState.next(1); luaState.pop(1)) {
                    String key = luaState.toString(-2);

                    switch (key) {
                        case "publicKey":
                            if (luaState.type(-1) == LuaType.STRING) {
                                publicKey = luaState.toString(-1);
                            } else {
                                logMsg(ERROR_MSG, "productData.publicKey (string) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        case "price":
                            if (luaState.type(-1) == LuaType.STRING) {
                                price = luaState.toString(-1);
                            } else {
                                logMsg(ERROR_MSG, "productData.price (string) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        case "currency":
                            if (luaState.type(-1) == LuaType.STRING) {
                                currency = luaState.toString(-1);
                            } else {
                                logMsg(ERROR_MSG, "productData.currency (string) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        case "signature":
                            if (luaState.type(-1) == LuaType.STRING) {
                                signature = luaState.toString(-1);
                            } else {
                                logMsg(ERROR_MSG, "productData.signature (string) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        case "purchaseData":
                            if (luaState.type(-1) == LuaType.STRING) {
                                purchaseData = luaState.toString(-1);
                            } else {
                                logMsg(ERROR_MSG, "productData.purchaseData (string) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        case "parameters":
                            if (luaState.type(-1) == LuaType.TABLE) {
                                // we need gettop() here since -1 will return nil
                                params = CoronaLua.toHashtable(luaState, luaState.getTop());
                            } else {
                                logMsg(ERROR_MSG, "productData.parameters (table) expected, got " + luaState.typeName(-1));
                                return 0;
                            }
                            break;
                        default:
                            logMsg(ERROR_MSG, "Invalid option '" + key + "'");
                            return 0;
                    }
                }
            } else {
                logMsg(ERROR_MSG, "purchaseData table expected, got " + luaState.typeName(1));
                return 0;
            }

            // declare final values for inner loop
            final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();
            final String fPublicKey = publicKey;
            final String fSignature = signature;
            final String fPurchaseData = purchaseData;
            final String fPrice = price;
            final String fCurrency = currency;
            final HashMap<String, String> fParams = getHashMapFromHashTable(params);

            if (coronaActivity != null) {
                coronaActivity.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        AppsFlyerLib.getInstance().registerValidatorListener(coronaActivity.getApplicationContext(), new
                                AppsFlyerInAppPurchaseValidatorListener() {
                                    public void onValidateInApp() {
                                        // send Corona Lua event
                                        Map<String, Object> coronaEvent = new HashMap<>();
                                        coronaEvent.put(EVENT_PHASE_KEY, PHASE_RECORDED);
                                        dispatchLuaEvent(coronaEvent);
                                    }

                                    public void onValidateInAppFailure(String error) {
                                        // send Corona Lua event
                                        Map<String, Object> coronaEvent = new HashMap<>();
                                        coronaEvent.put(EVENT_PHASE_KEY, PHASE_FAILED);
                                        coronaEvent.put(EVENT_DATA_KEY, error);
                                        coronaEvent.put(EVENT_IS_ERROR_KEY, true);
                                        dispatchLuaEvent(coronaEvent);
                                    }
                                });
                        // send parameters to AppsFlyer
                        AppsFlyerLib.getInstance().validateAndLogInAppPurchase(coronaActivity.getApplicationContext(), fPublicKey, fSignature, fPurchaseData, fPrice, fCurrency, fParams);
                    }
                });
            }

            return 0;
        }
    }

    private class LogRevenueAds implements NamedJavaFunction {

        @Override
        public String getName() {
            return "logRevenueAds";
        }

        @Override
        public int invoke(LuaState luaState) {
            functionSignature = "appsflyer.logRevenueAds()";

            if (!isSDKInitialized()) {
                return 0;
            }

            int nargs = luaState.getTop();
            if (nargs != 1) {
                logMsg(ERROR_MSG, "Expected 1 argument, got " + nargs);
                return 0;
            }

            Gson gson = new Gson();
            JsonObject revenueData = gson.fromJson(luaState.toString( -1), JsonObject.class);

            String monetizationNetwork = revenueData.get("monetizationNetwork").getAsString();
            String currencyIso4217Code = revenueData.get("currencyIso4217Code").getAsString();
            double revenue = revenueData.get("value").getAsDouble(); //'value' is IronSource style name
            String countryCode = revenueData.get("countryCode").getAsString();
            String adUnitName = revenueData.get("adUnitName").getAsString();
            String adType = revenueData.get("adFormat").getAsString(); //'adFormat' is IronSource style name

            String medNetwork = revenueData.get("adSource").getAsString().toUpperCase(); //'adSource' is IronSource style name
            MediationNetwork mediationNetwork = MediationNetwork.CUSTOM_MEDIATION;

// medNetwork must be one of: IRONSOURCE, APPLOVIN_MAX, GOOGLE_ADMOB, FYBER, APPODEAL, ADMOST, TOPON, TRADPLUS, YANDEX, CHARTBOOST, UNITY, TOPON_PTE,
            for(MediationNetwork medNet : MediationNetwork.values()) {
                if (medNet.toString().contains(medNetwork)) {
                   mediationNetwork = medNet;
               }
            }

            AFAdRevenueData adRevenueData = new AFAdRevenueData(
                    monetizationNetwork,
                    mediationNetwork,
                    currencyIso4217Code,
                    revenue
            );

            Map<String, Object> additionalParameters = new HashMap<>();
            additionalParameters.put(AdRevenueScheme.COUNTRY, countryCode);
            additionalParameters.put(AdRevenueScheme.AD_UNIT, adUnitName);
            additionalParameters.put(AdRevenueScheme.AD_TYPE, adType);

            final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();
            if (coronaActivity != null) {
                coronaActivity.runOnUiThread(() -> AppsFlyerLib.getInstance().logAdRevenue(adRevenueData, additionalParameters));
            }

            return 0;
        }
    }

    private HashMap getHashMapFromHashTable(Hashtable hashtable) {
        return new HashMap(hashtable);
    }

    // [Lua] setHasUserConsent(bool)
    private class SetHasUserConsent implements NamedJavaFunction {
        /**
         * Gets the name of the Lua function as it would appear in the Lua script.
         *
         * @return Returns the name of the custom Lua function.
         */
        @Override
        public String getName() {
            return "setHasUserConsent";
        }

        /**
         * This method is called when the Lua function is called.
         * <p>
         * Warning! This method is not called on the main UI thread.
         *
         * @param luaState Reference to the Lua state.
         *                 Needed to retrieve the Lua function's parameters and to return values back to Lua.
         * @return Returns the number of values to be returned by the Lua function.
         */
        @Override
        public int invoke(LuaState luaState) {
            functionSignature = "appsflyer.setHasUserConsent(boolean)";

            if (!isSDKInitialized()) {
                return 0;
            }

            // check number or args
            int nargs = luaState.getTop();
            if (nargs != 1) {
                logMsg(ERROR_MSG, "Expected 1 argument, got " + nargs);
                return 0;
            }

            // check for consent boolean (required)
            if (luaState.type(1) == LuaType.BOOLEAN) {
                final Boolean fLocalHasUserConsent = luaState.toBoolean(-1);
                final CoronaActivity coronaActivity = CoronaEnvironment.getCoronaActivity();
                if (coronaActivity != null) {
                    coronaActivity.runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            // send consent to AppsFlyer
                            AppsFlyerLib.getInstance().anonymizeUser(!fLocalHasUserConsent);
                        }
                    });
                }
            } else {
                logMsg(ERROR_MSG, "Boolean expected, got " + luaState.typeName(1));
            }
            return 0;
        }
    }

    // -------------------------------------------------------
    // delegate implementation
    // -------------------------------------------------------

    private class AppsflyerDelegate implements AppsFlyerConversionListener {
        @Override
        public void onAppOpenAttribution(Map<String, String> map) {
            Map<String, Object> coronaEvent = new HashMap<>();
            coronaEvent.put(EVENT_PHASE_KEY, PHASE_RECEIVED);
            coronaEvent.put(EVENT_TYPE_KEY, TYPE_ATTRIBUTION);
            coronaEvent.put(EVENT_DATA_KEY, map.toString());
            dispatchLuaEvent(coronaEvent);
        }

        @Override
        public void onConversionDataSuccess(Map<String, Object> map) {
            Map<String, Object> coronaEvent = new HashMap<>();
            coronaEvent.put(EVENT_PHASE_KEY, PHASE_RECEIVED);
            coronaEvent.put(EVENT_TYPE_KEY, TYPE_ATTRIBUTION);
            coronaEvent.put(EVENT_DATA_KEY, map.toString());
            dispatchLuaEvent(coronaEvent);
        }

        @Override
        public void onConversionDataFail(String s) {

        }

        @Override
        public void onAttributionFailure(String s) {

        }
    }
}
