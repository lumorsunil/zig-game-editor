const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c");
const lib = @import("lib");
const config = @import("lib").config;
const LayoutGeneric = lib.LayoutGeneric;
const Context = lib.Context;
const Editor = lib.Editor;
const SceneDocument = lib.documents.SceneDocument;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityType = lib.documents.scene.SceneEntityType;
const SceneEntityExit = lib.documents.scene.SceneEntityExit;
const SceneEntityEntrance = lib.documents.scene.SceneEntityEntrance;
const propertyEditor = @import("property.zig").propertyEditor;
const drawIconMenu = @import("entity-type.zig").drawIconMenu;
const Vector = lib.Vector;
const Node = lib.Node;
const UUID = lib.UUIDSerializable;
const utils = @import("utils.zig");

const tileSize = config.tileSize;

pub const LayoutScene = LayoutGeneric(.scene, draw, menu, handleInput);

const DrawOptions = struct {};

fn draw(context: *Context, sceneDocument: *SceneDocument) void {
    drawEntities(context, sceneDocument);
    drawSelectionBoxes(context, sceneDocument);
    drawDragPayload(context, sceneDocument);
}

fn drawEntities(context: *Context, sceneDocument: *SceneDocument) void {
    for (sceneDocument.getEntities().items) |entity| {
        sceneDocument.drawEntity(context, entity);
    }
}

fn drawSelectionBoxes(context: *Context, sceneDocument: *SceneDocument) void {
    for (sceneDocument.getSelectedEntities().items) |selectedEntity| {
        const rect = utils.getEntityRectScaled(context, selectedEntity.*);
        rl.drawRectangleLinesEx(rect, 1 / context.camera.zoom, rl.Color.white);
    }
}

fn drawDragPayload(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getDragPayload().*) |payload| {
        const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context, context.camera) else utils.gridPositionToEntityPosition(context, utils.getMouseSceneGridPosition(context), payload);
        sceneDocument.drawEntityEx(context, payload, position);
    }
}

fn menu(context: *Context, editor: *Editor, sceneDocument: *SceneDocument) void {
    const screenSize: @Vector(2, f32) = @floatFromInt(Vector{ rl.getScreenWidth(), rl.getScreenHeight() });
    z.setNextWindowPos(.{ .x = 0, .y = config.editorContentOffset });
    z.setNextWindowSize(.{ .w = 200, .h = screenSize[1] - config.editorContentOffset });
    _ = z.begin("Scene Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
        .no_bring_to_front_on_focus = true,
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
        context.sceneMap.generate(context) catch |err| {
            context.showError("Could not generate scene map: {}", .{err});
        };
    }

    if (sceneDocument.getTilemapId()) |tilemapId| _ = utils.assetInput(.tilemap, context, tilemapId);

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
            const entityType = context.requestDocumentTypeById(.entityType, selectedEntity.type.custom.entityTypeId) catch unreachable orelse unreachable;
            z.text("Custom: {}", .{entityType.getName()});
        }
        switch (selectedEntity.type) {
            .exit => |*exit| {
                utils.scaleInput(&exit.scale.?);
                _ = utils.assetInput(.scene, context, &exit.sceneId);

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
                _ = z.inputText("Entrance Key", .{
                    .buf = exit.entranceKey.buffer,
                });
                _ = z.checkbox("Vertical", .{ .v = &exit.isVertical });
            },
            .entrance => |*entrance| {
                utils.scaleInput(&entrance.scale.?);
                _ = z.inputText("Key", .{
                    .buf = entrance.key.buffer,
                });
            },
            else => {},
        }
        switch (selectedEntity.type) {
            .custom => |*custom| propertyEditor(context, .{ .entityInstance = custom }),
            else => {},
        }
    }

    const entities: []const std.meta.FieldEnum(SceneEntityType) = &.{
        .exit,
        .entrance,
    };

    inline for (entities) |tag| {
        switch (tag) {
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
                    if (sceneDocument.getDragPayload().* == null) {
                        sceneDocument.getDragPayload().* = .{ .exit = SceneEntityExit.init(context.allocator) };
                    }

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

    setEntityReferenceWindow(context, sceneDocument);
}

fn setEntityReferenceWindow(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.isSetEntityWindowOpen()) {
        z.setNextWindowSize(.{
            .w = SceneDocument.setEntityReferenceWindowWidth,
            .h = SceneDocument.setEntityReferenceWindowHeight,
            .cond = .first_use_ever,
        });
        z.setNextWindowPos(.{ .x = 100, .y = 100, .cond = .first_use_ever });
        var popen = true;
        _ = z.begin("Set Entity Reference", .{ .flags = .{}, .popen = &popen });
        defer z.end();
        if (!popen) sceneDocument.closeSetEntityWindow();

        const scenes = context.getIdsByDocumentType(.scene);
        defer context.allocator.free(scenes);

        const previewValue = brk: {
            const currentSceneId = sceneDocument.getSetEntityReferenceScene() orelse break :brk context.allocator.dupeZ(u8, "None") catch unreachable;
            const sceneFilePath = context.getFilePathById(currentSceneId) orelse unreachable;
            break :brk utils.documentShortName(context.allocator, sceneFilePath);
        };
        defer context.allocator.free(previewValue);

        if (z.beginCombo("Scene", .{ .preview_value = previewValue })) {
            defer z.endCombo();

            for (scenes) |sceneId| {
                const sceneFilePath = context.getFilePathById(sceneId) orelse continue;
                const sceneName = utils.documentShortName(context.allocator, sceneFilePath);
                defer context.allocator.free(sceneName);
                const isSelected = if (sceneDocument.getSetEntityReferenceScene()) |currentId| currentId.uuid == sceneId.uuid else false;
                if (z.selectable(sceneName, .{ .selected = isSelected })) {
                    sceneDocument.setSetEntityReferenceScene(sceneId);
                }
            }
        }

        const selectedSceneId = sceneDocument.getSetEntityReferenceScene() orelse return;
        const sceneDocumentToBeDrawn: *SceneDocument = context.requestDocumentTypeById(.scene, selectedSceneId) catch return orelse return;

        if (sceneDocument.getSetEntityReferenceEntity()) |entityId| {
            if (sceneDocumentToBeDrawn.getEntityByInstanceId(entityId)) |entity| {
                switch (entity.type) {
                    .custom => |custom| {
                        if (context.requestDocumentTypeById(.entityType, custom.entityTypeId) catch return) |entityTypeDocument| {
                            z.text("{s} - {}", .{
                                entityTypeDocument.getName(),
                                entity.id,
                            });
                            drawIconMenu(context, entityTypeDocument);
                        }
                    },
                    .entrance => |entrance| z.text("Entrance - {}", .{entrance.key}),
                    .exit => |exit| z.text("Exit - {}", .{exit.entranceKey}),
                    else => {},
                }
            }
        }

        setEntityReferenceWindowRenderScene(context, sceneDocument, sceneDocumentToBeDrawn);

        z.sameLine(.{ .spacing = 8 });
        if (sceneDocument.getSetEntityReferenceEntity()) |_| {
            if (z.button("Accept", .{})) {
                sceneDocument.commitSetEntityTarget();
                sceneDocument.clearSetEntityTarget();
                sceneDocument.closeSetEntityWindow();
            }
        }
    }
}

fn setEntityReferenceWindowRenderScene(
    context: *Context,
    sceneDocument: *SceneDocument,
    sceneDocumentToBeDrawn: *SceneDocument,
) void {
    const texture = sceneDocumentToBeDrawn.getSetEntityWindowRenderTexture();
    const camera = sceneDocumentToBeDrawn.getSetEntityWindowCamera();
    rl.beginTextureMode(texture);
    rl.clearBackground(rl.Color.white);
    rl.beginMode2D(camera.*);
    drawEntities(context, sceneDocumentToBeDrawn);
    rl.endMode2D();
    rl.endTextureMode();
    c.rlImGuiImageRenderTexture(@ptrCast(&texture));
    const sceneTexturePos = z.getItemRectMin();
    if (z.isItemHovered(.{ .delay_none = true })) {
        utils.cameraControls(camera);

        if (rl.isMouseButtonPressed(.left)) {
            for (sceneDocumentToBeDrawn.getEntities().items) |entity| {
                if (entity.type == .tilemap) continue;

                var cameraTemp = camera.*;
                cameraTemp.target.x -= sceneTexturePos[0];
                cameraTemp.target.y -= sceneTexturePos[1];

                if (utils.isMousePositionInsideEntityRect(context, cameraTemp, entity.*)) {
                    sceneDocument.setSetEntityReferenceEntity(entity.id);
                    break;
                }
            }
        }
    }
}

fn handleInput(context: *Context, _: *Editor, sceneDocument: *SceneDocument) void {
    utils.cameraControls(&context.camera);
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
        const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context, context.camera) else utils.gridPositionToEntityPosition(context, utils.getMouseSceneGridPosition(context), payload);
        entity.* = SceneEntity.init(position, payload);
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
        const entityTypeTag = SceneEntityType{ .custom = .init(context, id) };
        const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context, context.camera) else utils.gridPositionToEntityPosition(context, utils.getMouseSceneGridPosition(context), entityTypeTag);
        entity.* = SceneEntity.init(position, entityTypeTag);
        sceneDocument.getEntities().append(context.allocator, entity) catch unreachable;
        std.log.debug("created entity {}", .{entity.id});
    }
}

fn sceneDocumentHandleInputSelectEntity(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getDragPayload().* != null) return;

    if (rl.isMouseButtonPressed(.left)) {
        for (sceneDocument.getEntities().items) |entity| {
            if (entity.type == .tilemap) continue;

            if (utils.isMousePositionInsideEntityRect(context, context.camera, entity.*)) {
                sceneDocument.selectEntity(entity, context.allocator);
                sceneDocument.setDragStartPoint(utils.getMousePosition(context, context.camera));
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
                const position = if (rl.isKeyDown(.left_shift)) utils.getMousePosition(context, context.camera) else utils.gridPositionToEntityPosition(context, utils.getMouseSceneGridPosition(context), entity.type);
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
            const mousePosition = utils.getMousePosition(context, context.camera);
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
