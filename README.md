

# Custom HLS Hover Plugin (AST Radar) 🎯

Hey! This is a custom plugin I built for the [Haskell Language Server (HLS)](https://github.com/haskell/haskell-language-server). It intercepts standard LSP hover requests and bypasses the normal IDE response to directly query GHC's internal memory (the `HieAST`).

**Why did I build this?** I built this just to get an understanding of how to develop plugins , the standard LSP commands and the traversing the GHC AST to get the specific nodeInfo.

## 🧠 The Learning Curve (Why the code looks like that)

If you look at `HoverPlugin.hs`, you'll notice some commented-out code that just prints the cursor's Line and Column numbers. I deliberately left this old code in to show the learning progression!

This project started as a simple test with the LSP protocol (`HoverParams`). Once I could intercept the coordinates, I moved on to using GHC's `RealSrcSpan` coordinate math to recursively traverse the AST and find the deepest, most specific sub-node under the cursor.

## 🛠️ What it actually does

Instead of showing the standard documentation tooltip, this plugin shows the raw internal compiler data for the exact token you are hovering over:

* **Identifier Extraction:** It pulls the raw GHC `nodeIdentifiers`.
* **Dictionary Filtering:** It intercepts GHC's desugaring process. If you write a typeclass constraint, GHC silently generates hidden dictionary variables (like `$dEq`). My plugin filters out anything starting with `$` to keep the output clean.
* **Existential Type Casting:** It safely extracts internal type representations from HLS's generic `HAR` wrapper using `Data.Typeable.cast` to map them back to concrete `GHC.Core.Type` objects.

## 🔬 Edge Cases Discovered 

While building this, I stumbled into a fascinating quirk about how GHC structures its Abstract Syntax Tree: **Binders vs. Expressions**.

If you hover over a function *definition* (a Binder), my plugin will say `(No type data)`. Why? Because GHC doesn't attach types to definition nodes in the AST to save memory .
**BUT**, if you hover over a variable/function being *used* (an Expression), GHC physically stamps the evaluated `Type` onto that AST node. My plugin catches this perfectly


## Demo



## 🚀 How to Build & Install

Because this taps directly into HLS internals, you have to build it as an integrated library inside an HLS workspace.

1. **Clone it:** Clone this repository right next to your local `haskell-language-server` source code.
2. **Link the Cabal Project:** Add `../hls-hover-plugin` (or whatever you named the folder) to the `packages:` list in the HLS `cabal.project` file.
3. **Un-hide the Package:** Open `haskell-language-server.cabal`, find the main `library` block, and add `hls-hover-plugin` to the `build-depends` list.
4. **Wire it to the Switchboard:** Open `src/HlsPlugins.hs` in the HLS repo.
* Add `import qualified HoverPlugin` to the global imports.
* Add `let pId = "hover" in HoverPlugin.descriptor (pluginRecorder pId) pId :` unconditionally to the top of the `allPlugins` cons list.


5. **Compile:**
```bash
cabal build exe:haskell-language-server

```
To use your clone hls for a project ,
run : cabal list-bin exe:haskell-language-server
copy the path to the exe folder
create a .vscode folder inside the project at the root position 
create a settings.json file inside the .vscode folder containing the path
{
    "haskell.serverExecutablePath": "copied-path",
    "haskell.manageHLS": "PATH"
}

