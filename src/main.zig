const std = @import("std");
const zxg = @import("zxg");
const Context = @import("context.zig").Context;
const layout = @import("layout.zig").layout;
const rl = @import("raylib");
const z = @import("zgui");
const UUID = lib.UUIDSerializable;
const setImguiStyle = @import("imgui-style.zig").setImguiStyle;

pub const lib = @import("lib.zig");
pub const config = @import("config.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = zxg.ZXGApp.init(config.screenSize[0], config.screenSize[1], "Zig Game Editor");
    defer app.deinit();
    try app.loadFont(config.fontPath, config.fontSize);
    var context = Context.init(allocator);
    defer context.deinit();

    setImguiStyle();

    context.restoreSession() catch |err| {
        std.log.err("Could not restore session: {}", .{err});
    };

    try app.run(layout, &context);

    try context.storeSession();
}
