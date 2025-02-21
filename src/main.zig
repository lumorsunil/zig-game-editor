const std = @import("std");
const zxg = @import("zxg");
const Context = @import("context.zig").Context;
const layout = @import("layout.zig").layout;
const rl = @import("raylib");

const screenSize = .{ 1024, 800 };
const assetsRootDir = "D:/studio/My Drive/Kottefolket/";
const tilesetPath = "tileset-initial.png";
const tilesetName = "tileset-initial";
const fontPath = "C:/Windows/Fonts/calibri.ttf";
const fontSize = 20;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = zxg.ZXGApp.init(screenSize[0], screenSize[1], "Zig Game Editor");
    defer app.deinit();
    try app.loadFont(fontPath, fontSize);
    var context = Context.init(allocator);
    defer context.deinit();

    // Load example tilemap
    const tilesetFileName = assetsRootDir ++ tilesetPath;
    const texture = rl.loadTexture(tilesetFileName);
    defer rl.unloadTexture(texture);
    try context.textures.put(tilesetName, texture);

    try context.restoreSession();

    try app.run(layout, &context);

    try context.storeSession();
}
