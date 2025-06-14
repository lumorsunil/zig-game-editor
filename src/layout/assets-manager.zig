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
            if (z.button("..", .{ .w = iconSize, .h = iconSize })) {
                z.setCursorPos(.{ nodeSpacing, nodeSpacing });
                const newDir = context.allocator.dupeZ(u8, std.fs.path.dirname(cd) orelse ".") catch unreachable;
                defer context.allocator.free(newDir);
                context.setCurrentDirectory(newDir);
            }
        }
    }

    z.sameLine(.{});

    if (assetsLibrary.currentFilesAndDirectories) |*cfad| {
        for (cfad.*) |*node| {
            if (assetsLibrary.enableAssetTypeFilter and node.* == .file and node.file.documentType != assetsLibrary.assetTypeFilter) {
                continue;
            }
            nodeMenu(context, node);
        }
    }

    newAssetUI(context);
}

fn nodeMenu(context: *Context, node: *Node) void {
    const id: [:0]const u8 = switch (node.*) {
        inline else => |n| n.path,
    };
    _ = id; // autofix
    const label: [:0]const u8 = switch (node.*) {
        .file => |f| Document.getTypeLabel(f.documentType),
        .directory => "Directory",
    };
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
    nodeDrawIcon(context, node);
    z.setCursorPos(selectablePos);
    if (z.selectable(label, .{ .w = iconSize, .h = iconSize, .flags = .{ .allow_double_click = true } }) and z.isMouseDoubleClicked(.left)) {
        switch (node.*) {
            .file => |file| context.openFileNode(file),
            .directory => |directory| {
                context.setCurrentDirectory(directory.path);
                z.popId();
                return;
            },
        }
    }
    z.popId();
    if (z.beginDragDropSource(.{})) {
        _ = z.setDragDropPayload("asset", std.mem.asBytes(&node), .once);
        z.endDragDropSource();
    }
    z.setCursorPos(labelPos);
    z.text("{s}", .{name});
    z.setCursorPos(nextPos);
}

const NodeIcon = struct {
    texture: *rl.Texture2D,
    source: rl.Rectangle,
};

fn nodeDrawIcon(_: *Context, node: *Node) void {
    switch (node.*) {
        .file => |_| {
            // const icon = getNodeIcon(context, file) orelse return;
            // c.rlImGuiImageRect(
            //     @ptrCast(icon.texture),
            //     iconSize,
            //     iconSize,
            //     @bitCast(icon.source),
            // );
        },
        .directory => {},
    }
}

fn getNodeIcon(context: *Context, fileNode: Node.File) ?NodeIcon {
    switch (fileNode.documentType) {
        .entityType => {
            const entityType = (context.requestDocumentType(.entityType, fileNode.path) catch return null) orelse return null;
            const textureId = entityType.getTextureId() orelse return null;
            const texture = (context.requestTextureById(textureId) catch return null) orelse return null;

            const gridPosition = entityType.getGridPosition().*;
            const cellSize = entityType.getCellSize().*;
            const rectPos: @Vector(2, f32) = @floatFromInt(gridPosition * cellSize);
            const rectSize: @Vector(2, f32) = @floatFromInt(cellSize);
            const source = rl.Rectangle.init(
                rectPos[0],
                rectPos[1],
                rectSize[0],
                rectSize[1],
            );

            return .{ .texture = texture, .source = source };
        },
        else => return null,
    }
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
