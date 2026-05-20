# Studycat fork — `plugin.appsflyer.strict`

This repository is maintained by Studycat for local Solar2D plugin builds via funbox (`plugins/plugin-appsflyer`).

## Layout (matches `plugin-revenuecat`)

- `ios/`, `android/` — native plugin source (formerly under `src/`)
- `plugin/com.studycat.appsflyerStrict/` — self-hosted plugin package for builds
- `plugin/plugin_appsflyer_strict.lua` — simulator stub
- `Sample-Project/` — Corona sample app

## Strict variant only

We ship **`plugin.appsflyer.strict`** (`PLUGIN_STRICT=1`, Xcode target `plugin_appsflyerStrict`).

App `build.settings`:

```lua
["plugin.appsflyer.strict"] = {
    publisherId = "com.studycat.appsflyerStrict"
}
```

## Upstream (policy C)

`upstream` remote points to [coronalabs/com.coronalabs-plugin.appsflyer](https://github.com/coronalabs/com.coronalabs-plugin.appsflyer).

We do **not** routinely `git merge upstream/master`. Corona still commits under `src/`; this fork uses root-level `ios/` and `android/`. Merges cause path conflicts.

When you need an upstream fix:

1. `git fetch upstream`
2. Read commits under `upstream/master:src/ios` and `src/android`
3. Port changes manually into `ios/` and `android/`
4. Prefer AppsFlyer release notes for SDK bumps

## Build (funbox)

```bash
./fun plugins build appsflyer ios android
./fun plugins install
```

Manual iOS: `ios/build.sh` (builds `plugin_appsflyerStrict`).
