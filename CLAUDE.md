# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Build for the simulator:

```bash
xcodebuild -project Donguri.xcodeproj -scheme Donguri -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

Install and launch on a booted simulator:

```bash
xcrun simctl install booted "$(find ~/Library/Developer/Xcode/DerivedData/Donguri-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name 'Donguri.app' | head -1)" && xcrun simctl launch booted world.wumbo.Donguri
```

Re-resolve Swift package dependencies (after touching package refs in `project.pbxproj`):

```bash
xcodebuild -project Donguri.xcodeproj -scheme Donguri -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -resolvePackageDependencies
```

There is **no test target** and no lint config — the only target is the `Donguri` app.

If `xcodebuild` reports "requires Xcode, but active developer directory is a command line tools instance", prefix commands with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` or run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

## Architecture

Two distinct layers live in this app, and they meet in exactly one place.

**1. The 5ch reader** (original code). A plain SwiftUI + `URLSession` stack, no third-party deps:

- `Service/BBSMenuService` fetches the board list from `menu.5ch.io/bbsmenu.json`.
- `Service/ThreadService` parses `{boardURL}/subject.txt`.
- `Service/PostService` parses `{boardURL}/dat/{id}.dat`, and on 404 (dat落ち — the thread aged out) falls back to scraping the server's `read.cgi` HTML archive. **Both sources are Shift-JIS**, not UTF-8.
- `Extensions/String+HtmlDecoding` normalises the raw dat/HTML into markdown-ish text; `>>N` reply anchors become `[>>N](donguri://res/N)` links, which `ThreadView` intercepts to drive reply previews.
- Screens are `BBSMenuView → BoardView → ThreadView`. `ThreadView` also owns reply-preview popups, ID/trip highlighting, and read-position tracking (`Service/ReadStateStore`, `UserDefaults`-backed).

**2. The dictionary + Anki stack** (ported from [Hoshi Reader](https://github.com/Manhhao/Hoshi-Reader), GPL-3.0). `README.md` has a file-by-file table of what came from where. Ported files keep their original SPDX/copyright headers — preserve them.

- `Service/LookupEngine` wraps the `hoshidicts` Swift package. **It drives the package's C API (`hoshidicts_c.h`), not the C++ API that Hoshi Reader uses** — Swift's C++ interop cannot import the engine's `DictionaryQuery` (it holds a `std::vector` of a move-only, `unique_ptr`-owning type, and the importer fails synthesising a copy constructor). The C API hands out opaque handles, so that layout is never needed. `LookupEngine` copies all results into Swift value types because the C results are freed as soon as the call returns.
- `Service/DictionaryManager` handles Yomitan dictionary import/update/ordering; `Service/AnkiManager` handles mining via AnkiMobile (`x-callback-url`) or AnkiConnect (HTTP), with handlebar field templates in `Model/Anki`.
- `Service/UserConfig` is a trimmed version of Hoshi Reader's — deliberately keeps the same class name and property names so ported views' `@Environment(UserConfig.self)` code needed no rewriting.

**Where they meet — the webview bridge.** SwiftUI `Text` has no per-character hit testing, so tap-to-lookup is impossible on it. Post text therefore renders in a `WKWebView`:

`PostView` → `View/Popup/PostTextWebView` (injects `selection.js`) → tap → `selection.js` finds the word and sentence → `textSelected` message → `ThreadView.handleTextSelection` → `LookupEngine.lookup` → `View/Popup/PopupView` → `PopupWebView` (renders entries with `popup.js`/`popup.css`) → `+` button → `AnkiManager.addNote`.

`popup.js`, `popup.css` and `selection.js` are copied verbatim from Hoshi Reader and are the real rendering/selection engines — prefer configuring them via the `window.*` globals that `PopupView.buildContent` sets over editing them.

## Project and dependency setup

- The Xcode project uses a **`PBXFileSystemSynchronizedRootGroup`**: any file added under `Donguri/` is picked up automatically. Do not hand-edit `project.pbxproj` to add source files or resources. `.js`/`.css` files land in the bundle root, which is what `Bundle.main.resourceURL` loading depends on.
- `project.pbxproj` edits *are* needed for package dependencies. Current deps: `hoshidicts` (branch `main`) and `ZIPFoundation`; `libzstd` comes in transitively.
- `SWIFT_OBJC_INTEROP_MODE = objcxx` is required (hoshidicts' modulemap declares `requires cplusplus`). Because that modulemap only exposes the C++ umbrella header, the C API is reached via `Donguri/Donguri-Bridging-Header.h` (`SWIFT_OBJC_BRIDGING_HEADER`).
- Deployment target is iOS 18.0 (lowered from 26.0 to run on an iPhone 13 mini), so the `if #available(iOS 26, *)` branches the ported code carries from Hoshi Reader are load-bearing — `glassEffect` and the other Liquid Glass APIs are *not* unconditionally available. `translationPresentation` (iOS 17.4+) is.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — anything called from `Task.detached` (e.g. `DictionaryImporter.import`) needs explicit `nonisolated`.

## Gotchas that have already caused bugs

- **Do not pin `hoshidicts` to the revision Hoshi Reader uses.** That revision embeds a data file via `#embed` inside `std::to_array`, which miscompiles on Apple clang 17 ("excess elements in array initializer") — Hoshi Reader itself does not build here. `main` fixed it.
- **`Model/Dictionary.DictionaryIndex` decodes two different shapes** and must stay lenient: a Yomitan `index.json` (uses `format`, carries update URLs) and the summary hoshidicts writes after import (uses `version`, omits those URLs). A strict decode silently *deletes* every imported dictionary, because `DictionaryManager.getDictionariesFromStorage` prunes directories whose index it can't read.
- **`PopupView` caches its rendered content in `@State` at init**, so it must get a fresh identity per lookup — `ThreadView` bumps `popupGeneration` and applies `.id(popupGeneration)`. Without it the popup renders empty forever.
- **`DictionaryManager.shared` must be instantiated at launch** (it is, from `DonguriApp`). It is what loads dictionaries into `LookupEngine`; if it is only touched lazily by the settings screen, lookups silently return nothing until the user visits that screen.
- **Post rows must not be sized from the webview's reported height alone.** `PostTextWebView` has no intrinsic content size, so its height only arrives asynchronously over the `contentHeight` bridge. Rows used to start at 1pt and jump; SwiftUI clips neither a frame overflow nor a `List` cell, so a burst of those resizes left the List drawing rows at stale offsets and **posts visibly overlapped each other on device**. `Extensions/PostTextHeight` now estimates the height natively up front (TextKit, pinned to the stylesheet's `line-height: 1.5`), and `ThreadView` caches each measured height in `postHeights` so a recycled row never replays the cycle. If you touch either, keep the estimate biased *tall* — too tall costs a moment's whitespace, too short is what put text over the next post. The estimate must also track `PostTextWebView`'s CSS: font, line-height, `overflow-wrap: anywhere` (measured as the max of word- and char-wrapping) and the trailing `<br>` that a trailing newline produces.
- **UI strings live in two String Catalogs, and one Japanese literal in `PostService` must never join them.** `Donguri/Localizable.xcstrings` (the app's own UI) and `Donguri/Dictionaries.xcstrings` (the ported settings screens, which pass `tableName: "Dictionaries"` — that table exists in Hoshi Reader and had to be ported too, which is why those screens showed English keys before). Source language is `en`; both `en` and `ja` ship. Keys are the literals as written, so many keys are Japanese and carry an explicit `en` value — do not "fix" that by rewriting the literals. Anything that is a plain `String` rather than a `Text`/`Label` literal is invisible to the extractor and needs `String(localized:)` (see `NGRule.Kind.label`, and the `errorMessage` assignments in `BBSMenuView`/`BoardView`/`ThreadView`). **`PostService`'s `abornMarker = "あぼーん"` is dat *data*, not UI** — it matches text 5ch puts in the post body, so localizing it would break NG detection in English. Verify a change with `xcodebuild -exportLocalizations`, which is what actually runs the extractor; a plain `xcodebuild build` compiles the catalogs but never reports missing keys.
- `PostTextWebView` converts selection rects with `webView.convert(rect, to: nil)`. Each post is its own small webview inside a scrolling `List`, unlike Hoshi Reader's single full-screen reader webview — window coordinates are what make `PopupLayout`'s positioning maths work unchanged.
- Post text is escaped and re-linkified in `Extensions/String+PostHTML` before going into the webview. It is untrusted 5ch content; keep the escape-first ordering.
- When inspecting the app's container during debugging, re-query `xcrun simctl get_app_container booted world.wumbo.Donguri data` after every reinstall — the container UUID changes, and stale paths look like "nothing was written".
