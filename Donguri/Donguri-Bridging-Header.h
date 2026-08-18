//
//  Donguri-Bridging-Header.h
//  Donguri
//
//  hoshidicts' module.modulemap only exposes the C++ umbrella header, so the C
//  bindings (hoshidicts_c.h) aren't reachable via `import CHoshiDicts`. Pulling
//  the C header in here exposes them to Swift without importing the C++ API —
//  which matters because Swift can't import that API's `DictionaryQuery`.
//

#include "hoshidicts_c.h"
