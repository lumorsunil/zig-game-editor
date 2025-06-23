const std = @import("std");
const rl = @import("raylib");
const lib = @import("root").lib;
const Context = lib.Context;
const Vector = lib.Vector;
const Document = lib.Document;
const AssetsLibrary = lib.AssetsLibrary;
const Node = lib.Node;
const z = @import("zgui");
const c = @import("c");

var isCollapsed = false;
const iconSize = 128;
const nodeSpacing = 8;

pub fn assetsManager(context: *Context) void {
    const currentProject = &context.currentProject.?;
    const assetsLibrary = &currentProject.assetsLibrary;
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));
    const assetsManagerHeight = 300;
    const assetsManagerBottom: f32 = if (isCollapsed) 24 else assetsManagerHeight;

    z.setNextWindowPos(.{ .x = 0, .y = screenH - assetsManagerBottom });
    z.setNextWindowSize(.{ .w = screenW, .h = assetsManagerHeight });
    _ = z.begin("Assets Manager", .{ .flags = .{
        .no_resize = true,
        .no_move = true,
        .menu_bar = true,
    } });
    defer z.end();
    isCollapsed = z.isWindowCollapsed();

    if (z.beginMenuBar()) {
        _ = z.checkbox("enable-asset-type-filter", .{ .v = &assetsLibrary.enableAssetTypeFilter });
        if (assetsLibrary.enableAssetTypeFilter) {
            _ = z.comboFromEnum("asset-type-filter", &assetsLibrary.assetTypeFilter);
        }
        z.endMenuBar();
    }

    if (z.button("+", .{ .w = iconSize, .h = iconSize })) {
        z.setCursorPos(.{ nodeSpacing, nodeSpacing });
        z.openPopup("new-asset", .{});
    }

    if (assetsLibrary.currentDirectory) |cd| {
        if (!std.mem.eql(u8, cd, ".")) {
            z.sameLine(.{});
            if (z.button("..", .{ .w = iconSize, .h = iconSize })) {
                z.setCursorPos(.{ nodeSpacing, nodeSpacing });
                const newDir = context.allocator.dupeZ(u8, std.fs.path.dirname(cd) orelse ".") catch unreachable;
                defer context.allocator.free(newDir);
                context.setCurrentDirectory(newDir);
                return;
            }
            const targetDirectory = std.fs.path.dirname(cd) orelse ".";
            if (moveFileDropTarget(context, targetDirectory)) return;
        }
    }

    z.sameLine(.{});

    if (assetsLibrary.currentFilesAndDirectories) |*cfad| {
        for (cfad.*) |*node| {
            if (node.* == .directory and std.mem.eql(u8, node.directory.path, "cache")) continue;
            if (assetsLibrary.enableAssetTypeFilter and node.* == .file and node.file.documentType != assetsLibrary.assetTypeFilter) {
                continue;
            }
            if (nodeMenu(context, node)) return;
        }
    }

    newAssetUI(context);
}

// Returns true if nodes were invalidated
fn nodeMenu(context: *Context, node: *Node) bool {
    const name: [:0]const u8 = switch (node.*) {
        inline else => |n| n.name,
    };

    const labelHeight = z.getFontSize();
    const windowSize = z.getWindowSize();
    const pos = z.getCursorPos();
    const labelPos: @TypeOf(pos) = .{ pos[0], pos[1] + iconSize };
    const nextPos: @TypeOf(pos) = if (pos[0] + iconSize * 2 + nodeSpacing >= windowSize[0]) .{ nodeSpacing, pos[1] + iconSize + nodeSpacing + labelHeight } else .{ pos[0] + iconSize + nodeSpacing, pos[1] };

    z.pushPtrId(node);
    const selectablePos = z.getCursorPos();
    nodeDrawThumbnail(context, node);
    var iconPos = selectablePos;
    iconPos[0] -= 5;
    iconPos[1] -= 5;
    z.setCursorPos(iconPos);
    nodeDrawIcon(context, node);
    z.setCursorPos(selectablePos);
    if (z.selectable("", .{ .w = iconSize, .h = iconSize, .flags = .{ .allow_double_click = true } }) and z.isMouseDoubleClicked(.left)) {
        switch (node.*) {
            .file => |file| context.openFileNode(file),
            .directory => |directory| {
                context.setCurrentDirectory(directory.path);
                z.popId();
                return true;
            },
        }
    }
    z.popId();
    if (z.beginDragDropSource(.{})) {
        _ = z.setDragDropPayload("asset", std.mem.asBytes(&node), .once);
        z.endDragDropSource();
    }
    if (node.* == .directory) {
        if (moveFileDropTarget(context, node.directory.path)) return true;
    }
    z.setCursorPos(labelPos);
    z.text("{s}", .{name});
    z.setCursorPos(nextPos);

    return false;
}

// Returns true if nodes are invalidated
fn moveFileDropTarget(context: *Context, targetDirectory: []const u8) bool {
    if (z.beginDragDropTarget()) {
        if (z.getDragDropPayload()) |payload| {
            const draggedNode: *Node = @as(**Node, @ptrCast(@alignCast(payload.data.?))).*;

            switch (draggedNode.*) {
                .directory => {},
                .file => |file| {
                    if (z.acceptDragDropPayload("asset", .{})) |_| {
                        const dTargetDirectory = context.allocator.dupe(u8, targetDirectory) catch unreachable;
                        defer context.allocator.free(dTargetDirectory);
                        // Move the file in the file system
                        const p = &(context.currentProject orelse return false);
                        var rootDir = p.assetsLibrary.openRoot();
                        defer rootDir.close();
                        const basename = std.fs.path.basename(file.path);
                        const targetPath = std.fs.path.joinZ(context.allocator, &.{ dTargetDirectory, basename }) catch unreachable;
                        defer context.allocator.free(targetPath);
                        rootDir.renameZ(file.path, targetPath) catch |err| {
                            context.showError("Could not move file {s} to {s}: {}", .{ file.path, targetPath, err });
                            return false;
                        };

                        // Update the asset index to match the new path for the node id
                        p.updateIndex(context.allocator) catch |err| {
                            context.showError("Could not update index when moving file {s} to {s}: {}", .{ file.path, targetPath, err });
                            return false;
                        };

                        // Update the asset library to match the file system
                        p.assetsLibrary.removeNode(context.allocator, file.path);

                        return true;
                    }
                },
            }
        }
        z.endDragDropTarget();
    }

    return false;
}

const NodeIcon = struct {
    texture: *rl.Texture2D,
    source: rl.Rectangle,
};

fn nodeDrawThumbnail(context: *Context, node: *Node) void {
    switch (node.*) {
        .file => |file| {
            const id = file.id orelse return;
            const thumbnail = switch (file.documentType) {
                .texture => context.requestThumbnailById(id) catch {
                    context.updateThumbnailById(id);
                    return;
                },
                .animation, .entityType, .tilemap, .scene => context.requestThumbnailById(id) catch return,
            };
            c.rlImGuiImageSize(@ptrCast(thumbnail), iconSize, iconSize);
        },
        .directory => {},
    }
}

fn nodeDrawIcon(context: *Context, node: *Node) void {
    const iconsTexture = &(context.iconsTexture orelse return);
    const cellSize: Vector = .{ 32, 32 };
    const gridPosition: Vector = switch (node.*) {
        .file => |file| switch (file.documentType) {
            .animation => .{ 0, 1 },
            .scene => .{ 1, 1 },
            .tilemap => .{ 2, 1 },
            .entityType => .{ 3, 1 },
            .texture => .{ 4, 1 },
        },
        .directory => .{ 5, 1 },
    };
    const srcRectMin = gridPosition * cellSize;
    const srcRect = c.Rectangle{
        .x = @floatFromInt(srcRectMin[0]),
        .y = @floatFromInt(srcRectMin[1]),
        .width = @floatFromInt(cellSize[0]),
        .height = @floatFromInt(cellSize[1]),
    };
    c.rlImGuiImageRect(@ptrCast(iconsTexture), cellSize[0], cellSize[1], srcRect);
}

fn newAssetUI(context: *Context) void {
    const newAssetItemWidth = 196;

    if (z.beginPopup("new-asset", .{})) {
        defer z.endPopup();

        if (z.button("Directory", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.isNewDirectoryDialogOpen = true;
        }
        if (z.button("Texture", .{ .w = newAssetItemWidth, .h = 24 })) {
            if (context.getFileNameWithDialog("png")) |filePath| {
                defer context.allocator.free(filePath);
                const basename = context.allocator.dupeZ(u8, std.fs.path.basename(filePath)) catch unreachable;
                defer context.allocator.free(basename);
                const textureDocument = context.newAsset(basename, .texture) orelse return;
                // TODO: Fix this hack
                textureDocument.setTextureFilePath(context.allocator, filePath);
                textureDocument.document.nonPersistentData.load("", textureDocument.document.persistentData);
                const document = context.requestDocumentById(textureDocument.getId()) orelse unreachable;
                document.save() catch unreachable;
            }
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
        if (z.button("Entity Type", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.isNewEntityTypeDocumentDialogOpen = true;
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
            _ = context.newAsset(std.mem.sliceTo(&context.reusableTextBuffer, 0), .tilemap);
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
            _ = context.newAsset(std.mem.sliceTo(&context.reusableTextBuffer, 0), .scene);
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
            _ = context.newAsset(std.mem.sliceTo(&context.reusableTextBuffer, 0), .animation);
            context.reusableTextBuffer[0] = 0;
        }
    }

    if (context.isNewEntityTypeDocumentDialogOpen) {
        _ = z.begin("New Entity Type", .{});
        defer z.end();

        z.pushStrId("new-entity-type-input");
        _ = z.inputText("", .{
            .buf = &context.reusableTextBuffer,
        });
        z.popId();

        if (z.button("Create", .{})) {
            context.isNewEntityTypeDocumentDialogOpen = false;
            _ = context.newAsset(std.mem.sliceTo(&context.reusableTextBuffer, 0), .entityType);
            context.reusableTextBuffer[0] = 0;
        }
    }
}
