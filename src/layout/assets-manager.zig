const std = @import("std");
const rl = @import("raylib");
const lib = @import("lib");
const Context = lib.Context;
const Vector = lib.Vector;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const AssetsLibrary = lib.AssetsLibrary;
const Node = lib.Node;
const z = @import("zgui");
const c = @import("c");
const utils = @import("utils.zig");

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
    if (deleteAssetDialog(context)) return;
}

// Returns true if nodes were invalidated
fn nodeMenu(context: *Context, node: *Node) bool {
    const name: [:0]const u8 = switch (node.*) {
        inline else => |n| n.name,
    };

    const labelHeight = z.getFontSize() * 2;
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
    utils.drawAssetIcon(context, .{ .node = node.* });
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
        if (z.setDragDropPayload("asset", std.mem.asBytes(&node), .once)) {
            std.log.debug("setting dragPayload: {any}", .{z.getDragDropPayload()});
        }
        z.endDragDropSource();
    }
    if (node.* == .directory) {
        if (moveFileDropTarget(context, node.directory.path)) return true;
    }
    if (z.isItemHovered(.{ .delay_none = true }) and rl.isKeyPressed(.delete)) {
        context.deleteNodeTarget = node;
        context.isDeleteNodeDialogOpen = true;
    }
    z.setCursorPos(labelPos);
    if (z.beginChild(name, .{ .w = iconSize, .h = labelHeight * 2 })) {
        z.textWrapped("{s}", .{name});
        if (z.isItemHovered(.{ .delay_short = true })) {
            if (z.beginTooltip()) {
                switch (node.*) {
                    .directory => |directory| z.text("{s}", .{directory.path}),
                    .file => |file| z.text("{?s} - {s}", .{ file.id, file.path }),
                }
            }
            z.endTooltip();
        }
    }
    z.endChild();
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
                        return moveNode(context, targetDirectory, file);
                    }
                },
            }
        }
        z.endDragDropTarget();
    }

    return false;
}

// Returns true if nodes are invalidated
fn moveNode(context: *Context, targetDirectory: []const u8, file: Node.File) bool {
    const dTargetDirectory = context.allocator.dupe(u8, targetDirectory) catch unreachable;
    defer context.allocator.free(dTargetDirectory);

    // Create target path
    const p = &(context.currentProject orelse return false);
    var rootDir = p.assetsLibrary.openRoot();
    defer rootDir.close();
    const basename = std.fs.path.basename(file.path);
    const targetPath = std.fs.path.joinZ(context.allocator, &.{ dTargetDirectory, basename }) catch unreachable;
    defer context.allocator.free(targetPath);

    // Check if target path exists
    const stat = rootDir.statFile(targetPath) catch |err| brk: {
        switch (err) {
            std.fs.Dir.StatFileError.FileNotFound => break :brk null,
            else => {
                context.showError("Could not move file {s} to {s}: {}", .{ file.path, targetPath, err });
                return false;
            },
        }
    };

    // File exists, show error
    if (stat) |_| {
        context.showError("Could not move file {s} to {s}: Target exists", .{ file.path, targetPath });
        return false;
    }

    // Move file in file system
    rootDir.renameZ(file.path, targetPath) catch |err| {
        context.showError("Could not move file {s} to {s}: {}", .{ file.path, targetPath, err });
        return false;
    };

    // Update the asset index to match the new path for the node id
    if (file.id) |id| p.assetIndex.updateIndex(context.allocator, id, targetPath);

    // Update the asset library to match the file system
    p.assetsLibrary.removeNode(context.allocator, file.path);

    return true;
}

// Returns true if nodes are invalidated
fn deleteNode(context: *Context, node: Node) bool {
    const p = &(context.currentProject orelse return false);
    var rootDir = p.assetsLibrary.openRoot();
    defer rootDir.close();

    // Delete node in file system
    switch (node) {
        .directory => |directory| {
            rootDir.deleteDir(directory.path) catch |err| {
                context.showError("Could not delete directory {s}: {}", .{ directory.path, err });
                return false;
            };
        },
        .file => |file| {
            rootDir.deleteFile(file.path) catch |err| {
                context.showError("Could not delete file {s}: {}", .{ file.path, err });
                return false;
            };

            // Update the asset index
            if (file.id) |id| _ = p.assetIndex.removeIndex(context.allocator, id);
        },
    }

    context.closeEditorByNode(node);

    // Update the asset library to match the file system
    p.assetsLibrary.removeNode(context.allocator, node.getPath());

    return true;
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
                .sound, .font => return,
            };
            c.rlImGuiImageSize(@ptrCast(thumbnail), iconSize, iconSize);
        },
        .directory => {},
    }
}

fn newAssetUI(context: *Context) void {
    const newAssetItemWidth = 196;

    if (z.beginPopup("new-asset", .{})) {
        defer z.endPopup();

        if (z.button("Directory", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.openNewDirectoryDialog();
        }
        if (z.button("Texture", .{ .w = newAssetItemWidth, .h = 24 })) {
            createNewTextureAsset(context);
            z.closeCurrentPopup();
        }
        if (z.button("Sound", .{ .w = newAssetItemWidth, .h = 24 })) {
            createNewSoundAsset(context);
            z.closeCurrentPopup();
        }
        if (z.button("Font", .{ .w = newAssetItemWidth, .h = 24 })) {
            createNewFontAsset(context);
            z.closeCurrentPopup();
        }
        if (z.button("Scene", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.openNewAssetDialog(.scene);
        }
        if (z.button("Tilemap", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.openNewAssetDialog(.tilemap);
        }
        if (z.button("Animation", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.openNewAssetDialog(.animation);
        }
        if (z.button("Entity Type", .{ .w = newAssetItemWidth, .h = 24 })) {
            context.openNewAssetDialog(.entityType);
        }

        if (context.isNewDirectoryDialogOpen or context.isNewAssetDialogOpen != null) {
            z.closeCurrentPopup();
        }
    }

    if (context.isNewDirectoryDialogOpen) {
        defer context.isDialogFirstRender = false;

        _ = z.begin("New Directory", .{});
        defer z.end();

        z.pushStrId("new-directory-input");
        if (context.isDialogFirstRender) z.setKeyboardFocusHere(0);
        _ = z.inputText("", .{
            .buf = &context.reusableTextBuffer,
        });
        z.popId();

        if (z.button("Create", .{})) {
            context.newDirectory(std.mem.sliceTo(&context.reusableTextBuffer, 0));
            context.closeNewAssetAndDirectoryDialog();
        }
        z.sameLine(.{ .spacing = 8 });
        if (z.button("Cancel", .{})) {
            context.closeNewAssetAndDirectoryDialog();
        }
    }

    if (context.isNewAssetDialogOpen) |documentType| {
        defer context.isDialogFirstRender = false;

        const windowLabel = switch (documentType) {
            inline else => |dt| "New " ++ comptime Document.getTypeLabel(dt),
        };

        _ = z.begin(windowLabel, .{});
        defer z.end();

        z.pushStrId("new-asset-input");
        if (context.isDialogFirstRender) z.setKeyboardFocusHere(0);
        _ = z.inputText("", .{
            .buf = &context.reusableTextBuffer,
        });
        z.popId();

        if ((z.isItemFocused() and z.isKeyPressed(.enter, false)) or z.button("Create", .{})) {
            createNewDocumentAsset(
                context,
                std.mem.sliceTo(&context.reusableTextBuffer, 0),
                documentType,
            );
            context.closeNewAssetAndDirectoryDialog();
        }
        z.sameLine(.{ .spacing = 8 });
        if (z.button("Cancel", .{})) {
            context.closeNewAssetAndDirectoryDialog();
        }
    }
}

fn createNewTextureAsset(context: *Context) void {
    if (context.getFileNameWithDialog("png")) |filePath| {
        defer context.allocator.free(filePath);
        const basename = context.allocator.dupeZ(u8, std.fs.path.basename(filePath)) catch unreachable;
        defer context.allocator.free(basename);
        const document, const textureDocument = context.newAsset(basename, .texture) catch return;
        // TODO: Fix this hack
        textureDocument.setTextureFilePath(filePath);
        textureDocument.document.nonPersistentData.load("", textureDocument.document.persistentData);
        document.save(&context.currentProject.?) catch |err| {
            context.showError(
                "Could not update texture document {?s} with texture file path {s}: {}",
                .{ context.getFilePathById(document.getId()), filePath, err },
            );
            const node = context.getNodeById(document.getId()) orelse return;
            _ = deleteNode(context, node);
            return;
        };
    }
}

fn createNewSoundAsset(context: *Context) void {
    if (context.getFileNameWithDialog("wav,mp3")) |filePath| {
        defer context.allocator.free(filePath);
        const basename = context.allocator.dupeZ(u8, std.fs.path.basename(filePath)) catch unreachable;
        defer context.allocator.free(basename);
        const document, const soundDocument = context.newAsset(basename, .sound) catch return;
        soundDocument.setSoundFilePath(filePath);
        soundDocument.document.nonPersistentData.load("", soundDocument.document.persistentData);
        document.save(&context.currentProject.?) catch |err| {
            context.showError(
                "Could not update sound document {?s} with sound file path {s}: {}",
                .{ context.getFilePathById(document.getId()), filePath, err },
            );
            const node = context.getNodeById(document.getId()) orelse return;
            _ = deleteNode(context, node);
            return;
        };
    }
}

fn createNewFontAsset(context: *Context) void {
    if (context.getFileNameWithDialog("ttf")) |filePath| {
        defer context.allocator.free(filePath);
        const basename = context.allocator.dupeZ(u8, std.fs.path.basename(filePath)) catch unreachable;
        defer context.allocator.free(basename);
        const document, const fontDocument = context.newAsset(basename, .font) catch return;
        fontDocument.setFontFilePath(filePath);
        fontDocument.document.nonPersistentData.load("", fontDocument.document.persistentData);
        document.save(&context.currentProject.?) catch |err| {
            context.showError(
                "Could not update font document {?s} with font file path {s}: {}",
                .{ context.getFilePathById(document.getId()), filePath, err },
            );
            const node = context.getNodeById(document.getId()) orelse return;
            _ = deleteNode(context, node);
            return;
        };
    }
}

fn createNewDocumentAsset(
    context: *Context,
    name: []const u8,
    documentType: DocumentTag,
) void {
    switch (documentType) {
        inline else => |dt| {
            const document, const content = context.newAsset(name, dt) catch return;
            if (context.newAssetInputTarget) |target| {
                // TODO: Check if document is not unloaded
                target.assetInput.* = document.getId();
            }
            if (dt == .tilemap) {
                content.document.persistentData.tilemap.tileSize = context.getTileSize();
            }
            context.openEditorByIdAtEndOfFrame(document.getId());
        },
    }
}

// Returns true if nodes are invalidated
fn deleteAssetDialog(context: *Context) bool {
    if (context.isDeleteNodeDialogOpen) {
        const target = context.deleteNodeTarget orelse {
            context.isDeleteNodeDialogOpen = false;
            context.showError("Delete dialog opened without a target.", .{});
            return false;
        };
        _ = z.begin("Delete Node", .{ .flags = .{ .no_collapse = true } });
        defer z.end();
        z.textColored(.{ 1, 0, 0, 1 }, "Warning! ", .{});
        z.sameLine(.{});
        z.textWrapped("Do you really want to delete the {s} \"{s}\"?\n\nThis action cannot be undone!", .{ @tagName(target.*), target.getPath() });
        if (z.button("Cancel", .{})) {
            context.isDeleteNodeDialogOpen = false;
            context.deleteNodeTarget = null;
        }
        z.sameLine(.{ .spacing = 16 });
        if (z.button("Delete", .{})) {
            context.isDeleteNodeDialogOpen = false;
            context.deleteNodeTarget = null;
            if (deleteNode(context, target.*)) return true;
        }
    }

    return false;
}
