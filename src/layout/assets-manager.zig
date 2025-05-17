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

    if (assetsLibrary.currentDirectory) |cd| {
        if (!std.mem.eql(u8, cd, ".")) {
            if (z.button("..", .{ .w = iconSize, .h = iconSize })) {
                z.setCursorPos(.{ spacing, spacing });
                const newDir = context.allocator.dupeZ(u8, std.fs.path.dirname(cd) orelse ".") catch unreachable;
                defer context.allocator.free(newDir);
                context.setCurrentDirectory(newDir);
            }
        }
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

        if (z.button("Directory", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.isNewDirectoryDialogOpen = true;
        }
        if (z.button("Scene", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.isNewSceneDialogOpen = true;
        }
        if (z.button("Tilemap", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.isNewTilemapDialogOpen = true;
        }
        if (z.button("Animation", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.isNewAnimationDocumentDialogOpen = true;
        }
    }

    if (context.isNewDirectoryDialogOpen) {
        _ = z.begin("New Directory", .{});
        defer z.end();

        z.pushStrId("new-directory-input");
        _ = z.inputText("", .{
            .buf = &context.reusableTextBuffer,
        });
        z.popId();

        if (z.button("Create", .{})) {
            context.isNewDirectoryDialogOpen = false;
            context.newDirectory(std.mem.sliceTo(&context.reusableTextBuffer, 0));
            context.reusableTextBuffer[0] = 0;
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
            context.newAsset(std.mem.sliceTo(&context.reusableTextBuffer, 0), .tilemap);
            context.reusableTextBuffer[0] = 0;
        }
    }

    if (context.isNewSceneDialogOpen) {
        _ = z.begin("New Scene", .{});
        defer z.end();

        z.pushStrId("new-scene-input");
        _ = z.inputText("", .{
            .buf = &context.reusableTextBuffer,
        });
        z.popId();

        if (z.button("Create", .{})) {
            context.isNewSceneDialogOpen = false;
            context.newAsset(std.mem.sliceTo(&context.reusableTextBuffer, 0), .scene);
            context.reusableTextBuffer[0] = 0;
        }
    }

    if (context.isNewAnimationDocumentDialogOpen) {
        _ = z.begin("New Animation", .{});
        defer z.end();

        z.pushStrId("new-animation-input");
        _ = z.inputText("", .{
            .buf = &context.reusableTextBuffer,
        });
        z.popId();

        if (z.button("Create", .{})) {
            context.isNewAnimationDocumentDialogOpen = false;
            context.newAsset(std.mem.sliceTo(&context.reusableTextBuffer, 0), .animation);
            context.reusableTextBuffer[0] = 0;
        }
    }
}
