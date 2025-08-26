const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c").c;
const nfd = @import("nfd");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const screenSize: @Vector(2, i32) = .{ 800, 600 };
    rl.initWindow(screenSize[0], screenSize[1], "Generate UV");
    defer rl.closeWindow();
    c.rlImGuiSetup(true);
    defer c.rlImGuiShutdown();
    z.initNoContext(allocator);
    defer z.deinitNoContext();

    const clearColor = rl.Color.init(136, 136, 176, 255);

    var size: @Vector(2, i32) = .{ 32, 32 };

    var texture: rl.Texture2D = try createUVTexture(size);
    const scale = 4;

    var camera = rl.Camera2D{
        .zoom = 1,
        .offset = .{ .x = @floatFromInt(screenSize[0] / 2), .y = @floatFromInt(screenSize[1] / 2) },
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
    };

    const cwd = try std.fmt.allocPrintSentinel(allocator, "{s}", .{try std.fs.cwd().realpathAlloc(allocator, ".")}, 0);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        rl.clearBackground(clearColor);

        rl.beginMode2D(camera);

        const w, const h = @as(@Vector(2, f32), @floatFromInt(size));
        rl.drawTexturePro(texture, rl.Rectangle.init(0, 0, w, h), rl.Rectangle.init(0, 0, w * scale, h * scale), rl.Vector2.init(w / 2 * scale, h / 2 * scale), 0, rl.Color.white);

        rl.endMode2D();

        c.rlImGuiBegin();

        _ = z.begin("Menu", .{});
        if (z.inputInt2("Size", .{ .v = &size })) {
            std.log.debug("Changed size to {}", .{size});
            rl.unloadTexture(texture);
            texture = try createUVTexture(size);
        }
        if (z.button("Export", .{})) {
            std.log.debug("Export clicked", .{});
            try exportImage(allocator, texture, cwd);
        }
        z.end();

        c.rlImGuiEnd();

        rl.endDrawing();

        if (z.io.getWantCaptureMouse()) continue;

        if (rl.isMouseButtonDown(.middle)) {
            const delta = rl.getMouseDelta();
            camera.target.x -= delta.x / camera.zoom;
            camera.target.y -= delta.y / camera.zoom;
        } else if (rl.getMouseWheelMove() != 0) {
            camera.zoom *= 1 + rl.getMouseWheelMove() / 10;
        }
    }
}

fn createUVTexture(size: @Vector(2, i32)) !rl.Texture2D {
    var image = rl.genImageColor(size[0], size[1], rl.Color.white);
    defer rl.unloadImage(image);

    const w: f32 = @floatFromInt(size[0]);
    const h: f32 = @floatFromInt(size[1]);

    for (0..@intCast(size[0])) |x| {
        for (0..@intCast(size[1])) |y| {
            const fx: f32 = @floatFromInt(x);
            const fy: f32 = @floatFromInt(y);
            const rx = fx / w;
            const ry = fy / h;
            const g: u8 = @intFromFloat(@round(rx * 255));
            const r: u8 = @intFromFloat(@round(ry * 255));
            const color = rl.Color.init(r, g, 0, 255);
            rl.imageDrawPixel(&image, @intCast(x), @intCast(y), color);
        }
    }

    return try rl.loadTextureFromImage(image);
}

fn exportImage(allocator: Allocator, texture: rl.Texture2D, dialogPath: [:0]const u8) !void {
    if (try nfd.saveFileDialog("png", dialogPath)) |saveFileName| {
        const fileName = if (!std.mem.endsWith(u8, saveFileName, ".png"))
            try std.mem.concatWithSentinel(allocator, u8, &.{ saveFileName, ".png" }, 0)
        else
            try allocator.dupeZ(u8, saveFileName);
        nfd.freePath(saveFileName);
        std.log.err("Exporting to file {s}", .{fileName});
        const image = try rl.loadImageFromTexture(texture);
        defer rl.unloadImage(image);
        if (!rl.exportImage(image, fileName)) {
            std.log.err("Error exporting image", .{});
        } else {
            std.log.debug("Exported image success", .{});
        }
    }
}
