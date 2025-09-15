# zig-game-editor

Asset creator for games.

Use to create assets like tilemaps and animations etc, and use those assets in your game engine.

The assets are stored as JSON files.

This is the editor I'm using when developing my game.

**Note:** This is _not_ shipping with a game engine, the idea is that this editor is only used to produce asset files, not a game executable.

## Installation

Note: Works on windows. Use at your own risk.

### Build source

1. Clone the repo
2. If you want to try it out you can change some settings in the `src/config.zig` file:

```zig
// Set these to your liking
pub const fontPath = "C:/Windows/Fonts/calibri.ttf";
```

3. Run `zig build run`.

### Releases

_Probably in the future somewhere._

## Todo

[todo](todo.md)
