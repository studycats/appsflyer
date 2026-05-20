# Studycat fork — `plugin.appsflyer`

Local Solar2D plugin for funbox (`plugins/plugin-appsflyer`).

## One plugin identity

| Item | Value |
|------|--------|
| Lua module | `plugin.appsflyer` |
| publisherId | `com.studycat.appsflyer` |
| Install path | `~/Solar2DPlugins/com.studycat.appsflyer/plugin.appsflyer/` |
| fun build | `./fun plugins build appsflyer ios android` |

App `build.settings`:

```lua
["plugin.appsflyer"] = {
    publisherId = "com.studycat.appsflyer"
}
```

Strict vs non-strict is compile-time (`PLUGIN_STRICT`), not a separate Corona plugin name. Default `master` builds with `PLUGIN_STRICT=1` (iOS ATT wait in `init`). Branch `standard` can set `PLUGIN_STRICT=0`.

## getVersion

`appsflyer.getVersion()` dispatches `analyticsRequest` with `phase == "received"` and `data`:

- `pluginVersion` — plugin release string
- `sdkVersion` — AppsFlyer SDK version
- `isStrict` — boolean, matches compile-time `PLUGIN_STRICT`

## Layout (vs official Corona)

| Studycat (this repo) | Official coronalabs |
|----------------------|---------------------|
| `ios/`, `android/` | `src/ios/`, `src/android/` |
| `plugin/com.studycat.appsflyer/plugin.appsflyer/` | `plugins/2020.3569/` prebuilt only |
| `plugin/plugin_appsflyer.lua` | marketplace sim stubs |

Removed from this fork (do not restore): `plugins/2018.3326/`, `plugins/2020.3569/`, `plugin.appsflyer.strict` module, `plugin_appsflyerStrict` Xcode target.

## Upstream (policy C)

`upstream` → [coronalabs/com.coronalabs-plugin.appsflyer](https://github.com/coronalabs/com.coronalabs-plugin.appsflyer). No routine merges; port fixes manually from `upstream/master:src/`.

## Build

```bash
./fun plugins build appsflyer ios android
./fun plugins install
```

Manual iOS: `ios/build.sh` (target `plugin_appsflyer`).
