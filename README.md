# Custom HLS Hover Plugin

A custom plugin I built for the [Haskell Language Server (HLS)](https://github.com/haskell/haskell-language-server). It intercepts LSP hover requests and instead of showing the normal tooltip, it directly queries GHC's internal AST (HieAST) to show you the raw compiler data for whatever token you're hovering over.

*Why did I build this?* Purely to understand how HLS plugins work by intercepting LSP commands, traversing the GHC AST, and mapping cursor positions to specific AST nodes. It started as a simple position tracker and grew from there.

## What it does

Instead of the standard documentation tooltip, this shows the raw internal compiler data for the token under your cursor:

- *Identifier extraction*  pulls the raw GHC nodeIdentifiers from the AST node
- *Dictionary filtering*  GHC silently generates hidden dictionary variables for typeclass constraints (like $dEq). The plugin filters anything starting with $ to keep the output clean
- *Type extraction*  safely casts internal type representations out of HLS's generic HAR wrapper using Data.Typeable.cast to get concrete GHC.Core.Type objects

One interesting thing I found while building this: if you hover over a function definition (a binder), the plugin shows (No type data). But if you hover over a variable being used (an expression), GHC has the evaluated type stamped right onto that AST node. GHC deliberately doesn't attach types to definition nodes to save memory the type is only there at the use site.

## Demo

<img width="588" height="187" alt="image" src="https://github.com/user-attachments/assets/e0fea99d-4c4d-4a0c-a2d7-f4d6487b5b6f" />
<img width="854" height="319" alt="image" src="https://github.com/user-attachments/assets/2126efce-3c47-4585-bf85-cdb459a5b525" />
<img width="861" height="338" alt="image" src="https://github.com/user-attachments/assets/2810ff38-f771-4def-9b43-c82cf879d2f5" />
<img width="805" height="339" alt="image" src="https://github.com/user-attachments/assets/aebdc021-fff6-421c-9709-b797fa13e9cf" />

## How to build and install

This taps directly into HLS internals so it has to be built as part of an HLS workspace, not as a standalone package.

*1. Clone this repo next to your HLS source*
```
your-workspace/
    haskell-language-server/
    hls-hover-plugin/          
```

*2. Add it to the HLS cabal project*

In haskell-language-server/cabal.project, add it to the packages: list:

packages:
  .
  ../hls-hover-plugin


*3. Add it as a dependency*

In haskell-language-server.cabal, find the main library block and add hls-hover-plugin to build-depends.

*4. Wire it up*

In src/HlsPlugins.hs:
- Add import qualified HoverPlugin to the imports
- Add this to the top of the allPlugins list:
```
let pId = "hover" in HoverPlugin.descriptor (pluginRecorder pId) pId :
```

*5. Build*
```
cabal build exe:haskell-language-server
```

*6. Point VS Code at your build*

Get the path to your compiled binary:

```
cabal list-bin exe:haskell-language-server
```

Create .vscode/settings.json at your project root:
```
{
    "haskell.serverExecutablePath": "path-to-bin",
    "haskell.manageHLS": "PATH"
}
```



