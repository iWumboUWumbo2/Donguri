<div align="center">

# Donguri

![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)

Donguri is a 5ちゃんねる (5channel) reader for iOS with a Yomitan-style pop-up
dictionary and Anki integration — essentially [Hoshi Reader](https://github.com/Manhhao/Hoshi-Reader)
for 5ch instead of EPUBs.

</div>

## Features

- Browse the 5ch board menu, boards, and threads
- **Yomitan-like pop-up dictionary with deinflection** — tap any word in a post
  to look it up
- Support for **all** Yomitan term, frequency and pitch dictionaries
- **Audio support** for Yomitan online audio sources
- **Anki integration** with one-click mining, via AnkiMobile or AnkiConnect
- Support for the core handlebars used by [Lapis](https://github.com/donkuri/lapis)
- Standalone dictionary search
- Reply previews, read-position tracking, and per-thread unread counts
- Inline image thumbnails with a fullscreen viewer
- Support for `dat` threads and `read.cgi` archives (dat落ち)

## Credits

Donguri's dictionary and Anki functionality is **ported from
[Hoshi Reader](https://github.com/Manhhao/Hoshi-Reader)** by
[Manhhao](https://github.com/Manhhao), which is licensed under GPL-3.0-or-later.

The following are copied or adapted from Hoshi Reader, and retain their original
copyright and SPDX headers:

| Donguri | Origin in Hoshi Reader |
| --- | --- |
| `View/Popup/popup.js`, `popup.css` | `Features/Popup/` (copied verbatim) |
| `View/Popup/selection.js` | `Features/Reader/ReaderWebView/selection.js` (copied verbatim) |
| `View/Popup/PopupView.swift`, `PopupWebView.swift` | `Features/Popup/` |
| `View/Popup/WordAudioPlayer.swift` | `Features/Popup/` (© HuangAntimony) |
| `View/Dictionary/` | `Features/Dictionary/` |
| `View/Settings/AnkiView.swift`, `AnkiConnectView.swift`, `CSSEditorView.swift`, `DictionaryView.swift` | `Features/Settings/` |
| `Service/AnkiManager.swift`, `DictionaryManager.swift`, `LookupEngine.swift`, `UserConfig.swift` | `Core/` |
| `Service/AppFileStorage.swift` | `Core/BookStorage.swift` (trimmed to the generic file helpers) |
| `Model/Anki.swift`, `Model/Dictionary.swift` | `Models/` |
| `Extensions/CSSSanitizer.swift`, `Popup+Extensions.swift` | `Util/` |

The dictionary engine itself is [hoshidicts](https://github.com/Manhhao/hoshidicts),
also by Manhhao, consumed here as a Swift package. Donguri drives its **C API**
(`hoshidicts_c.h`) rather than the C++ API that Hoshi Reader uses, since Swift's
C++ interop cannot import the engine's move-only `DictionaryQuery` type.

Notable pieces that are *not* ported, being EPUB-specific: the reader itself,
pagination and vertical writing, fonts, highlights, statistics, ッツ Reader/Google
Drive sync, and Sasayaki.

`View/Popup/PostTextWebView.swift` is new to Donguri: 5ch posts are rendered in a
`WKWebView` so that Hoshi Reader's `selection.js` can do tap-to-lookup on them,
which SwiftUI's `Text` cannot support.

## Licence

GPL-3.0-or-later — see [LICENSE](LICENSE). Donguri is a derivative work of Hoshi
Reader and is therefore distributed under the same licence.
