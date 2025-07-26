const lib = @import("lib");
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;

// Set these to your liking
pub const fontPath = "C:/Windows/Fonts/calibri.ttf";
pub const tileSize = Vector{ 16, 16 };

// UI stuff
pub const screenSize = .{ 1024, 800 };
pub const fontSize = 20;
pub const topBarHeight = 26;
pub const documentTabsHeight = 42;
pub const editorContentOffset = topBarHeight + documentTabsHeight;
