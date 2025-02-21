const std = @import("std");
const zxg = @import("zxg");
//const layout = @import("generated-layout").layout;
const Context = @import("context.zig").Context;
const layout = @import("layout.zig").layout;
const rl = @import("raylib");

const assetsRootDir = "D:/studio/My Drive/Kottefolket/";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = zxg.ZXGApp.init(1024, 800, "zxg zgui example");
    defer app.deinit();
    try app.loadFont("C:/Windows/Fonts/calibri.ttf", 20);
    var context = Context.init(allocator);
    defer context.deinit();

    // Load example tilemap
    const tilesetFileName = assetsRootDir ++ "tileset-initial.png";
    const tileset = "tileset-initial";
    const texture = rl.loadTexture(tilesetFileName);
    defer rl.unloadTexture(texture);
    try context.textures.put(tileset, texture);

    try context.restoreSession();

    try app.run(layout, &context);

    try context.storeSession();
}
