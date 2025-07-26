const std = @import("std");
const zxg = @import("zxg");
const layout = @import("layout.zig").layout;
const rl = @import("raylib");
const z = @import("zgui");
const lib = @import("lib");
const Context = lib.Context;
const UUID = lib.UUIDSerializable;
const setImguiStyle = @import("imgui-style.zig").setImguiStyle;
const config = lib.config;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = initApp();
    defer app.deinit();

    var context = Context.init(allocator);
    defer cleanupContext(&context);

    context.restoreSession() catch |err| {
        std.log.err("Could not restore session: {}", .{err});
    };

    app.run(layout, &context) catch |err| {
        std.log.err("Error while running app: {}", .{err});
    };
}

fn initApp() zxg.ZXGApp {
    var app = zxg.ZXGApp.init(
        config.screenSize[0],
        config.screenSize[1],
        "Zig Game Editor",
    );
    app.loadFont(config.fontPath, config.fontSize) catch |err| {
        std.log.err("Could not load font {s} ({d:0.0}): {}", .{
            config.fontPath,
            config.fontSize,
            err,
        });
    };

    setImguiStyle();

    return app;
}

fn cleanupContext(context: *Context) void {
    context.storeSession() catch |err| {
        std.log.err("Could not store session: {}", .{err});
    };
    context.saveProject() catch |err| {
        std.log.err("Could not save project: {}", .{err});
    };
    context.deinit();
}

test {
    _ = @import("tests.zig");
}
