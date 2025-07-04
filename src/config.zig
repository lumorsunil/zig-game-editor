const lib = @import("root").lib;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;

pub const screenSize = .{ 1024, 800 };
pub const assetsRootDir = "D:/studio/My Drive/Kottefolket/";
pub const tilesetPath = "tileset-initial.png";
pub const tilesetName = "tileset-initial";
pub const fontPath = "C:/Windows/Fonts/calibri.ttf";
pub const fontSize = 20;
pub const topBarHeight = 26;
pub const documentTabsHeight = 42;
pub const editorContentOffset = topBarHeight + documentTabsHeight;
pub const tileSize = Vector{ 16, 16 };
