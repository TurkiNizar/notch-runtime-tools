# Notch Runtime Tools for Developers

Notch HUD + CLI to surface local build status in the MacBook notch.

## What it does
- macOS app shows a slim HUD around the notch during builds: running → testing → success/fail with colored progress.
- CLI wrapper (`notch-build`) wraps your build command (Maven/Gradle/npm/yarn/pnpm), streams output, and emits events to the app.

## Install (unsigned build)
> Unsigned binary: macOS may warn. Allow once via right‑click → Open, or strip quarantine with `xattr -dr com.apple.quarantine /Applications/NotchRuntimeToolsForDevs.app`.

```sh
brew tap TurkiNizar/homebrew-notch-runtime
brew install notch-build
brew install --cask notch-runtime-tools-for-developers   # add --no-quarantine if you accept Gatekeeper bypass
```

Upgrade:
```sh
brew update
brew upgrade notch-build
brew upgrade --cask notch-runtime-tools-for-developers
```

Remove:
```sh
brew uninstall notch-build
brew uninstall --cask notch-runtime-tools-for-developers
```

## Run
1) Launch the app: `/Applications/NotchRuntimeToolsForDevs.app` (keep it running). First launch: right‑click → Open if macOS warns.
2) In your project directory, run builds through the CLI:
   ```sh
   notch-build mvn clean install
   notch-build ./gradlew test
   notch-build npm run build
   ```
   The HUD will appear, update states, and auto-hide on success; stays red on failure until dismissed (click HUD to hide).

Quick sanity checks:
```sh
notch-build /bin/true    # success state
notch-build /bin/false   # failure state
```

## Defaults & config
- Listener: `127.0.0.1:34345`
- Override via `--host/--port` or env `NOTCH_BUILD_HOST/NOTCH_BUILD_PORT` in `notch-build`.

## Limitations (unsigned)
- App is unsigned/not notarized; users must allow it once.
- HUD shows coarse progress: start/test/success/fail + simple heuristics for Maven/Gradle; npm/yarn/pnpm indeterminate.

## Homebrew tap auto-update
Tags in this repo build/upload artifacts and auto-bump the tap (`TurkiNizar/homebrew-notch-runtime`) with new URLs/SHA256. Users can just `brew update` and upgrade.
