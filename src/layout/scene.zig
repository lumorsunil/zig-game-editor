const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c");
const lib = @import("root").lib;
const LayoutGeneric = lib.LayoutGeneric;
const Context = lib.Context;
const Editor = lib.Editor;
const SceneDocument = lib.documents.SceneDocument;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityType = lib.documents.scene.SceneEntityType;
const SceneEntityExit = lib.documents.scene.SceneEntityExit;
const SceneEntityEntrance = lib.documents.scene.SceneEntityEntrance;
const Vector = lib.Vector;
const utils = @import("utils.zig");

pub const LayoutScene = LayoutGeneric(.scene, draw, menu, handleInput);

fn draw(context: *Context, sceneDocument: *SceneDocument) void {
    for (sceneDocument.getEntities().items) |entity| {
        sceneDocument.drawEntity(context, entity.*);
    }

    for (sceneDocument.getSelectedEntities().items) |selectedEntity| {
        const rect = utils.getEntityRectScaled(context, selectedEntity.*);
        rl.drawRectangleLinesEx(rect, 1 / context.camera.zoom, rl.Color.white);
    }

    if (sceneDocument.getDragPayload().*) |payload| {
        const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context) else utils.gridPositionToEntityPosition(utils.getMouseSceneGridPosition(context), payload);
        var entity: SceneEntity = .init(context.allocator, position, payload);
        defer entity.deinit(context.allocator);
        sceneDocument.drawEntity(context, entity);
    }
}

fn menu(context: *Context, editor: *Editor, sceneDocument: *SceneDocument) void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 200, .h = 800 });
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
    }
    if (z.button("Set Tilemap", .{})) {
        if (context.openFileWithDialog(.tilemap)) |document| {
            std.log.debug("opened tilemap {s}", .{document.filePath});
            for (sceneDocument.getEntities().items) |entity| {
                if (entity.type == .tilemap) {
                    entity.type.tilemap.setFileName(context.allocator, document.filePath);
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
        switch (selectedEntity.type) {
            .exit => |*exit| {
                utils.scaleInput(&exit.scale.?);
                if (z.button("Set Target", .{})) {
                    if (context.openFileWithDialog(.scene)) |document| {
                        // TODO: Check if there's an issue with this path being relative to root
                        exit.setSceneFileName(context.allocator, document.filePath);
                    }
                }

                if (exit.sceneFileName) |scf| {
                    const baseName = std.fs.path.basename(scf);
                    var it = std.mem.splitScalar(u8, baseName, '.');
                    const name = it.next().?;
                    z.text("{s}", .{name});
                    if (z.button("Open Target Scene", .{})) {
                        // const targetEntranceKey = getTargetEntranceKey(exit);
                        context.openEditor(scf);
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
                    .buf = entrance.keyImguiBuffer(),
                });
                entrance.imguiCommit();
            },
            else => {},
        }
        z.text("Metadata:", .{});
        z.pushPtrId(selectedEntity.metadata.ptr);
        _ = z.inputTextMultiline("", .{
            .buf = selectedEntity.metadataBuffer(),
        });
        selectedEntity.imguiCommit();
        z.popId();
    }

    const entities: []const std.meta.FieldEnum(SceneEntityType) = &.{
        .player,
        .npc,
        .klet,
        .mossing,
        .stening,
        .barlingSpawner,
        .exit,
        .entrance,
    };

    inline for (entities) |tag| {
        switch (tag) {
            .player, .npc, .klet, .mossing, .stening, .barlingSpawner => {
                const texture = sceneDocument.getTextureFromEntityType(tag);
                const source = SceneDocument.getSourceRectFromEntityType(tag);
                const size = SceneDocument.getSizeFromEntityType(tag);
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
                const size: @Vector(2, f32) = @floatFromInt(utils.tileSize * context.scaleV);

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
                const size: @Vector(2, f32) = @floatFromInt(utils.tileSize * context.scaleV);

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
                    sceneDocument.getDragPayload().* = .{ .entrance = SceneEntityEntrance.init(context.allocator) };
                    z.endDragDropSource();
                }
            },
            .tilemap => {},
        }
    }
}

fn handleInput(context: *Context, _: *Editor, sceneDocument: *SceneDocument) void {
    utils.cameraControls(context);
    sceneDocumentHandleInputCreateEntity(context, sceneDocument);
    sceneDocumentHandleInputSelectEntity(context, sceneDocument);
    sceneDocumentHandleInputMoveEntity(context, sceneDocument);
    sceneDocumentHandleInputDeleteEntity(context, sceneDocument);

    if (rl.isKeyPressed(.f5)) {
        context.play();
    }
}

fn sceneDocumentHandleInputCreateEntity(context: *Context, sceneDocument: *SceneDocument) void {
    const dragPayload = sceneDocument.getDragPayload();
    if (dragPayload.*) |payload| {
        if (rl.isMouseButtonReleased(.left)) {
            const entity = context.allocator.create(SceneEntity) catch unreachable;
            const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context) else utils.gridPositionToEntityPosition(utils.getMouseSceneGridPosition(context), payload);
            entity.* = SceneEntity.init(context.allocator, position, payload);
            sceneDocument.getEntities().append(context.allocator, entity) catch unreachable;
            dragPayload.* = null;
        }
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
                const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context) else utils.gridPositionToEntityPosition(utils.getMouseSceneGridPosition(context), entity.type);
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
