const std = @import("std");
const zxg = @import("zxg");
const Context = @import("context.zig").Context;
const layout = @import("layout.zig").layout;
const rl = @import("raylib");
const z = @import("zgui");
const UUID = lib.UUIDSerializable;

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

    // Hardcoded stuff
    const style = z.getStyle();
    style.setColorsDark();
    style.setColor(.window_bg, .{ 0, 0, 0, 0.6 });
    style.setColor(.title_bg_active, .{ 0.3, 0.4, 0.3, 1 });
    style.setColor(.frame_bg, .{ 0.3, 0.4, 0.3, 1 });
    style.setColor(.header, .{ 0.4, 0.7, 0.4, 0.6 });
    style.setColor(.button, .{ 0.3, 0.4, 0.3, 1 });
    style.setColor(.button_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.separator_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.tab_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.frame_bg_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.plot_lines_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.resize_grip_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.scrollbar_grab_hovered, .{ 0.4, 0.7, 0.4, 1 });
    style.setColor(.header_hovered, .{ 0.4, 0.7, 0.4, 0.6 });
    style.setColor(.check_mark, .{ 1, 1, 1, 1 });
    style.frame_rounding = 5;
    style.window_rounding = 5;
    style.scrollbar_rounding = 5;
    style.child_rounding = 5;
    style.grab_rounding = 5;
    style.popup_rounding = 5;

    // End of hardcoded stuff

    context.restoreSession() catch |err| {
        std.log.err("Could not restore session: {}", .{err});
    };

    // Tileset hardcoded

    if (context.currentProject) |_| {
        const id = UUID.deserialize("1e5874c6-0090-4017-ac61-ba85afe94b63") catch unreachable;
        context.tilesetId = id;
        context.tools[0].impl.brush.tileset = id;
    }

    // End of hardcoded stuff again

    try app.run(layout, &context);

    try context.storeSession();
}
