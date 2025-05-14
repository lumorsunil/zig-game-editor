const std = @import("std");
const rl = @import("raylib");
const lib = @import("root").lib;
const Context = lib.Context;
const Vector = lib.Vector;
const Document = lib.Document;
const z = @import("zgui");

var isCollapsed = false;

pub fn assetsManager(context: *Context) void {
    const currentProject = context.currentProject.?;
    const assetsLibrary = currentProject.assetsLibrary;
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));
    const assetsManagerHeight = 300;
    const assetsManagerBottom: f32 = if (isCollapsed) 24 else assetsManagerHeight;

    z.setNextWindowPos(.{ .x = 0, .y = screenH - assetsManagerBottom });
    z.setNextWindowSize(.{ .w = screenW, .h = assetsManagerHeight });
    _ = z.begin("Assets Manager", .{ .flags = .{
        .no_resize = true,
        .no_move = true,
    } });
    defer z.end();
    isCollapsed = z.isWindowCollapsed();

    const iconSize = 128;
    const spacing = 8;

    if (z.button("+", .{ .w = iconSize, .h = iconSize })) {
        z.setCursorPos(.{ spacing, spacing });
        z.openPopup("new-asset", .{});
    }

    z.sameLine(.{});

    if (assetsLibrary.currentFilesAndDirectories) |cfad| {
        for (cfad) |node| {
            const id: [:0]const u8 = switch (node) {
                inline else => |n| n.path,
            };
            _ = id; // autofix
            const label: [:0]const u8 = switch (node) {
                .file => |f| Document.getTypeLabel(f.documentType),
                .directory => "Directory",
            };
            const name: [:0]const u8 = switch (node) {
                inline else => |n| n.name,
            };

            const labelHeight = z.getFontSize();
            const windowSize = z.getWindowSize();
            const pos = z.getCursorPos();
            const labelPos: @TypeOf(pos) = .{ pos[0], pos[1] + iconSize };
            const nextPos: @TypeOf(pos) = if (pos[0] + iconSize * 2 + spacing >= windowSize[0]) .{ spacing, pos[1] + iconSize + spacing + labelHeight } else .{ pos[0] + iconSize + spacing, pos[1] };

            if (z.selectable(label, .{ .w = iconSize, .h = iconSize, .flags = .{ .allow_double_click = true } }) and z.isMouseDoubleClicked(.left)) {
                switch (node) {
                    .file => |file| context.openFileNode(file),
                    .directory => |directory| context.setCurrentDirectory(directory.path),
                }
            }
            z.setCursorPos(labelPos);
            z.text("{s}", .{name});
            z.setCursorPos(nextPos);
        }
    }

    newAssetUI(context);
}

fn newAssetUI(context: *Context) void {
    const newAssetItemWidth = 196;

    if (z.beginPopup("new-asset", .{})) {
        defer z.endPopup();

        if (z.button("Tilemap", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.isNewTilemapDialogOpen = true;
        }
    }

    if (context.isNewTilemapDialogOpen) {
        _ = z.begin("New Tilemap", .{});
        defer z.end();

        z.pushStrId("new-tilemap-input");
        _ = z.inputText("", .{
            .buf = &context.reusableTextBuffer,
        });
        z.popId();

        if (z.button("Create", .{})) {
            context.isNewTilemapDialogOpen = false;
            context.newTilemap(std.mem.sliceTo(&context.reusableTextBuffer, 0));
            context.reusableTextBuffer[0] = 0;
        }
    }
}
