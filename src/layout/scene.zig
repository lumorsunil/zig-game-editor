const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c");
const lib = @import("root").lib;
const config = @import("root").config;
const LayoutGeneric = lib.LayoutGeneric;
const Context = lib.Context;
const Editor = lib.Editor;
const SceneDocument = lib.documents.SceneDocument;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityType = lib.documents.scene.SceneEntityType;
const SceneEntityExit = lib.documents.scene.SceneEntityExit;
const SceneEntityEntrance = lib.documents.scene.SceneEntityEntrance;
const Vector = lib.Vector;
const Node = lib.Node;
const utils = @import("utils.zig");

const tileSize = config.tileSize;

pub const LayoutScene = LayoutGeneric(.scene, draw, menu, handleInput);

fn draw(context: *Context, sceneDocument: *SceneDocument) void {
    for (sceneDocument.getEntities().items) |entity| {
        sceneDocument.drawEntity(context, entity);
    }

    for (sceneDocument.getSelectedEntities().items) |selectedEntity| {
        const rect = utils.getEntityRectScaled(context, selectedEntity.*);
        rl.drawRectangleLinesEx(rect, 1 / context.camera.zoom, rl.Color.white);
    }

    if (sceneDocument.getDragPayload().*) |payload| {
        const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context) else utils.gridPositionToEntityPosition(context, utils.getMouseSceneGridPosition(context), payload);
        sceneDocument.drawEntityEx(context, payload, position);
    }
}

fn menu(context: *Context, editor: *Editor, sceneDocument: *SceneDocument) void {
    const screenSize: @Vector(2, f32) = @floatFromInt(Vector{ rl.getScreenWidth(), rl.getScreenHeight() });
    z.setNextWindowPos(.{ .x = 0, .y = config.topBarOffset });
    z.setNextWindowSize(.{ .w = 200, .h = screenSize[1] - config.topBarOffset });
    _ = z.begin("Scene Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
    } });
    defer z.end();

    utils.activeDocumentLabel(context, editor);

    if (z.button("Reset Camera", .{})) {
        utils.resetCamera(context);
    }
    z.text("{d:0.0},{d:0.0}", .{ context.camera.target.x, context.camera.target.y });

    if (z.button("Save", .{})) {
        context.saveEditorFile(editor);
        context.updateThumbnailForCurrentDocument = true;
    }
    if (z.button("Set Tilemap", .{})) {
        if (context.openFileWithDialog(.tilemap)) |document| {
            for (sceneDocument.getEntities().items) |entity| {
                if (entity.type == .tilemap) {
                    entity.type.tilemap.tilemapId = document.getId();
                }
            }
        }
    }
    if (z.button("Play", .{})) {
        context.play();
    } else if (context.playState != .notRunning) {
        z.sameLine(.{});

        switch (context.playState) {
            .starting => z.text("Starting...", .{}),
            .errorStarting => z.textColored(.{ 1, 0, 0, 1 }, "Error Starting", .{}),
            .running => z.textColored(.{ 0, 1, 0, 1 }, "Running", .{}),
            .crash => z.textColored(.{ 1, 0, 0, 1 }, "Crashed", .{}),
            .notRunning => {},
        }
    }

    if (sceneDocument.getSelectedEntities().items.len > 0) {
        const selectedEntity = sceneDocument.getSelectedEntities().items[0];

        // Entity details menu
        z.text("Entity: {s}", .{@tagName(selectedEntity.type)});
        if (selectedEntity.type == .custom) {
            const entityType = context.requestDocumentTypeById(.entityType, selectedEntity.type.custom) catch unreachable orelse unreachable;
            z.text("Custom: {}", .{entityType.getName()});
        }
        switch (selectedEntity.type) {
            .exit => |*exit| {
                utils.scaleInput(&exit.scale.?);
                sceneExitTargetInput(context, exit);

                if (exit.sceneId) |sId| {
                    if (z.button("Open Target Scene", .{})) {
                        // const targetEntranceKey = getTargetEntranceKey(exit);
                        context.openEditorById(sId);
                        // const targetEntrance = getEntranceByKey(context, targetEntranceKey);
                        // moveCameraToEntity(context, targetEntrance.*);
                        utils.resetCamera(context);
                        return;
                    }
                }
            },
            .entrance => |*entrance| {
                utils.scaleInput(&entrance.scale.?);
                _ = z.inputText("Key", .{
                    .buf = entrance.key.buffer,
                });
            },
            else => {},
        }
        z.text("Metadata:", .{});
        z.pushPtrId(&selectedEntity.metadata);
        _ = z.inputTextMultiline("", .{
            .buf = selectedEntity.metadata.buffer,
        });
        z.popId();
    }

    const entities: []const std.meta.FieldEnum(SceneEntityType) = &.{
        // .player,
        // .npc,
        // .klet,
        // .mossing,
        // .stening,
        // .barlingSpawner,
        .exit,
        .entrance,
    };

    inline for (entities) |tag| {
        switch (tag) {
            .player, .npc, .klet, .mossing, .stening, .barlingSpawner => {
                const texture = sceneDocument.getTextureFromEntityType(tag) catch continue orelse continue;
                const source = SceneDocument.getSourceRectFromEntityType(tag) catch continue orelse continue;
                const size = SceneDocument.getSizeFromEntityType(tag) catch continue orelse continue;
                const scaledSize = Vector{
                    @intFromFloat(size.x),
                    @intFromFloat(size.y),
                } * context.scaleV;
                c.rlImGuiImageRect(@ptrCast(texture), scaledSize[0], scaledSize[1], @bitCast(source));
                if (z.beginDragDropSource(.{ .source_allow_null_id = true })) {
                    sceneDocument.getDragPayload().* = tag;
                    z.endDragDropSource();
                }
            },
            .exit => {
                const pos: @Vector(2, f32) = z.getCursorPos();
                const size: @Vector(2, f32) = @floatFromInt(tileSize * context.scaleV);

                c.rlImGuiImageRect(
                    @ptrCast(&context.exitTexture),
                    @intFromFloat(size[0]),
                    @intFromFloat(size[1]),
                    .{
                        .x = pos[0],
                        .y = pos[1],
                        .width = 1,
                        .height = 1,
                    },
                );
                if (z.beginDragDropSource(.{ .source_allow_null_id = true })) {
                    sceneDocument.getDragPayload().* = .{ .exit = SceneEntityExit.init() };
                    z.endDragDropSource();
                }
            },
            .entrance => {
                const pos: @Vector(2, f32) = z.getCursorPos();
                const size: @Vector(2, f32) = @floatFromInt(tileSize * context.scaleV);

                c.rlImGuiImageRect(
                    @ptrCast(&context.entranceTexture),
                    @intFromFloat(size[0]),
                    @intFromFloat(size[1]),
                    .{
                        .x = pos[0],
                        .y = pos[1],
                        .width = 1,
                        .height = 1,
                    },
                );
                if (z.beginDragDropSource(.{ .source_allow_null_id = true })) {
                    if (sceneDocument.getDragPayload().* == null) {
                        sceneDocument.getDragPayload().* = .{ .entrance = SceneEntityEntrance.init(context.allocator) };
                    }
                    z.endDragDropSource();
                }
            },
            .tilemap, .custom => {},
        }
    }
}

fn sceneExitTargetInput(context: *Context, exit: *SceneEntityExit) void {
    const sceneId = exit.sceneId;
    const sceneFilePath = (if (sceneId) |id| context.getFilePathById(id) else null) orelse "None";
    const baseName = std.fs.path.basename(sceneFilePath);
    var it = std.mem.splitScalar(u8, baseName, '.');
    const name = it.next().?;
    z.text("{s}", .{name});
    if (z.beginDragDropTarget()) {
        if (z.getDragDropPayload()) |payload| {
            const node: *Node = @as(**Node, @ptrCast(@alignCast(payload.data.?))).*;

            switch (node.*) {
                .directory => {},
                .file => |file| {
                    if (file.documentType == .scene) {
                        if (z.acceptDragDropPayload("asset", .{})) |_| {
                            exit.sceneId = context.getIdByFilePath(file.path) orelse unreachable;
                        }
                    }
                },
            }
        }
        z.endDragDropTarget();
    }
}

fn handleInput(context: *Context, _: *Editor, sceneDocument: *SceneDocument) void {
    utils.cameraControls(context);
    sceneDocumentHandleInputCreateEntity(context, sceneDocument);
    sceneDocumentHandleInputCreateEntityFromAssetsManager(context, sceneDocument);
    sceneDocumentHandleInputSelectEntity(context, sceneDocument);
    sceneDocumentHandleInputMoveEntity(context, sceneDocument);
    sceneDocumentHandleInputDeleteEntity(context, sceneDocument);

    if (rl.isKeyPressed(.f5)) {
        context.play();
    }
}

fn sceneDocumentHandleInputCreateEntity(context: *Context, sceneDocument: *SceneDocument) void {
    const dragPayload = sceneDocument.getDragPayload();
    const payload = dragPayload.* orelse return;

    if (rl.isMouseButtonReleased(.left)) {
        const entity = context.allocator.create(SceneEntity) catch unreachable;
        const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context) else utils.gridPositionToEntityPosition(context, utils.getMouseSceneGridPosition(context), payload);
        entity.* = SceneEntity.init(context.allocator, position, payload);
        sceneDocument.getEntities().append(context.allocator, entity) catch unreachable;
        dragPayload.* = null;
    }
}

fn sceneDocumentHandleInputCreateEntityFromAssetsManager(
    context: *Context,
    sceneDocument: *SceneDocument,
) void {
    const dragPayload = z.getDragDropPayload() orelse return;
    const draggedNode: *Node = @as(**Node, @ptrCast(@alignCast(dragPayload.data.?))).*;

    if (draggedNode.* == .directory) return;
    if (draggedNode.file.documentType != .entityType) return;

    const fileNode = draggedNode.file;
    const id = fileNode.id orelse return;

    if (rl.isMouseButtonReleased(.left)) {
        const entity = context.allocator.create(SceneEntity) catch unreachable;
        const entityTypeTag = SceneEntityType{ .custom = id };
        const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context) else utils.gridPositionToEntityPosition(context, utils.getMouseSceneGridPosition(context), entityTypeTag);
        entity.* = SceneEntity.init(context.allocator, position, entityTypeTag);
        sceneDocument.getEntities().append(context.allocator, entity) catch unreachable;
    }
}

fn sceneDocumentHandleInputSelectEntity(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getDragPayload().* != null) return;

    if (rl.isMouseButtonPressed(.left)) {
        for (sceneDocument.getEntities().items) |entity| {
            if (entity.type == .tilemap) continue;

            if (utils.isMousePositionInsideEntityRect(context, entity.*)) {
                sceneDocument.selectEntity(entity, context.allocator);
                sceneDocument.setDragStartPoint(utils.getMousePosition(context));
                break;
            }
        }
    }
}

fn sceneDocumentHandleInputMoveEntity(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getDragPayload().* != null) return;
    if (sceneDocument.getSelectedEntities().items.len == 0) return;

    if (sceneDocument.getDragStartPoint()) |dragStartPoint| {
        if (sceneDocument.getIsDragging()) {
            if (rl.isMouseButtonDown(.left)) {
                const entity = sceneDocument.getSelectedEntities().items[0];
                const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context) else utils.gridPositionToEntityPosition(context, utils.getMouseSceneGridPosition(context), entity.type);
                entity.position = position;
            } else {
                sceneDocument.setIsDragging(false);
                sceneDocument.setDragStartPoint(null);
            }
        } else {
            const dsp = rl.Vector2.init(
                @floatFromInt(dragStartPoint[0]),
                @floatFromInt(dragStartPoint[1]),
            );
            const mousePosition = utils.getMousePosition(context);
            const mp = rl.Vector2.init(
                @floatFromInt(mousePosition[0]),
                @floatFromInt(mousePosition[1]),
            );

            if (dsp.distanceSqr(mp) >= 25) {
                sceneDocument.setIsDragging(true);
            }
        }
    }
}

fn sceneDocumentHandleInputDeleteEntity(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getSelectedEntities().items.len == 0) return;

    const selectedEntity = sceneDocument.getSelectedEntities().items[0];
    if (rl.isKeyPressed(.delete)) {
        sceneDocument.deleteEntity(context.allocator, selectedEntity);
    }
}
