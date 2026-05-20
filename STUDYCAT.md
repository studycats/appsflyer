# Studycat fork — `plugin.appsflyer`

Local Solar2D plugin maintained for funbox (`plugins/plugin-appsflyer`).

## One plugin identity

| Item | Value |
|------|--------|
| Lua module | `plugin.appsflyer` |
| publisherId | `com.studycat.appsflyer` |
| Install path | `~/Solar2DPlugins/com.studycat.appsflyer/` |
| fun build | `./fun plugins build appsflyer ios android` |

`build.settings`:

```lua
["plugin.appsflyer"] = {
    publisherId = "com.studycat.appsflyer"
}
```

**Strict vs non-strict** is a compile-time flag (`PLUGIN_STRICT`), not a separate Corona plugin name. Default branch builds with `PLUGIN_STRICT=1` (ATT / strict SDK behavior). A `standard` branch can set `PLUGIN_STRICT=0` for the non-strict build of the same `plugin.appsflyer`.

## Layout

- `ios/`, `android/` — native source
- `plugin/com.studycat.appsflyer/plugin.appsflyer/` — packaged `data.tgz` outputs
- `plugin/plugin_appsflyer.lua` — simulator stub
- `Sample-Project/` — sample app

## Upstream (policy C)

`upstream` → [coronalabs/com.coronalabs-plugin.appsflyer](https://github.com/coronalabs/com.coronalabs-plugin.appsflyer). No routine merges; port fixes manually from `upstream/master:src/`.

## Build

```bash
./fun plugins build appsflyer ios android
./fun plugins install
```

Manual iOS: `ios/build.sh` (target `plugin_appsflyer`).
