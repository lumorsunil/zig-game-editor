const std = @import("std");
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c").c;
const lib = @import("lib");
const config = @import("lib").config;
const LayoutGeneric = lib.layouts.LayoutGeneric;
const Context = lib.Context;
const Editor = lib.Editor;
const SceneDocument = lib.documents.SceneDocument;
const SceneEntity = lib.scene.SceneEntity;
const SceneEntityType = lib.scene.SceneEntityType;
const SceneEntityExit = lib.scene.SceneEntityExit;
const SceneEntityEntrance = lib.scene.SceneEntityEntrance;
const DragEntityState = lib.scene.DragEntityState;
const DragAction = lib.scene.DragAction;
const ResizeAction = lib.scene.ResizeAction;
const SceneMapError = lib.sceneMap.SceneMapError;
const propertyEditor = @import("property.zig").propertyEditor;
const drawIconMenu = @import("entity-type.zig").drawIconMenu;
const Vector = lib.Vector;
const Node = lib.assetsLibrary.Node;
const UUID = lib.UUIDSerializable;
const utils = @import("utils.zig");

const distanceToStartDrag = 2;

pub const LayoutScene = LayoutGeneric(.scene, draw, menu, handleInput);

const DrawOptions = struct {};

fn draw(context: *Context, sceneDocument: *SceneDocument) void {
    z.setMouseCursor(.arrow);
    drawEntities(context, sceneDocument);
    drawHighlights(context, sceneDocument);
    drawSelectionBoxes(context, sceneDocument);
    drawDragPayload(context, sceneDocument);
    drawDragAction(context, sceneDocument);
}

fn drawEntities(context: *Context, sceneDocument: *SceneDocument) void {
    for (sceneDocument.getEntities().items) |entity| {
        sceneDocument.drawEntity(context, entity);
    }
}

fn drawHighlights(context: *Context, sceneDocument: *SceneDocument) void {
    const editor = context.getCurrentEditor().?;

    drawMouseoverHighlight(context, editor.camera, sceneDocument, rl.Vector2.init(0, 0));
    drawReferencedEntitiesHighlights(context, editor.camera, sceneDocument, sceneDocument);
}

fn drawMouseoverHighlight(
    context: *Context,
    camera: rl.Camera2D,
    sceneDocument: *SceneDocument,
    offset: rl.Vector2,
) void {
    if (getHoveredEntity(context, camera, sceneDocument, offset)) |entity| {
        drawEntityBox(context, camera, entity.*, rl.Color.yellow);
        z.setMouseCursor(.hand);
    }
}

fn drawReferencedEntitiesHighlights(
    context: *Context,
    camera: rl.Camera2D,
    sceneDocument: *SceneDocument,
    sceneDocumentToBeDrawn: *SceneDocument,
) void {
    for (sceneDocument.getSelectedEntities().items) |selectedEntity| {
        const referencedEntities = sceneDocumentToBeDrawn.getReferencedEntities(context.allocator, selectedEntity);
        defer context.allocator.free(referencedEntities);
        for (referencedEntities) |entity| {
            drawEntityBox(context, camera, entity.*, rl.Color.green);
        }
    }
}

fn drawEntityBox(
    context: *Context,
    camera: rl.Camera2D,
    entity: SceneEntity,
    color: rl.Color,
) void {
    const rect = utils.getEntityRectScaled(context, entity);
    rl.drawRectangleLinesEx(rect, 1 / camera.zoom, color);
}

const ResizeAnchorPoint = struct {
    point: rl.Vector2,
    cursor: z.Cursor,
    resize: ResizeAction.Direction,

    pub fn toDragAction(self: ResizeAnchorPoint, entityId: UUID) DragAction {
        return .{ .resize = .{
            .entityId = entityId,
            .direction = self.resize,
        } };
    }
};

const resizeAnchorPoints = [_]ResizeAnchorPoint{
    .{ .point = rl.Vector2.init(0, 0), .cursor = z.Cursor.resize_nwse, .resize = .topleft },
    .{ .point = rl.Vector2.init(0.5, 0), .cursor = z.Cursor.resize_ns, .resize = .top },
    .{ .point = rl.Vector2.init(1, 0), .cursor = z.Cursor.resize_nesw, .resize = .topright },
    .{ .point = rl.Vector2.init(1, 0.5), .cursor = z.Cursor.resize_ew, .resize = .right },
    .{ .point = rl.Vector2.init(1, 1), .cursor = z.Cursor.resize_nwse, .resize = .bottomright },
    .{ .point = rl.Vector2.init(0.5, 1), .cursor = z.Cursor.resize_ns, .resize = .bottom },
    .{ .point = rl.Vector2.init(0, 1), .cursor = z.Cursor.resize_nesw, .resize = .bottomleft },
    .{ .point = rl.Vector2.init(0, 0.5), .cursor = z.Cursor.resize_ew, .resize = .left },
};

fn getRectWithCenter(center: rl.Vector2, size: rl.Vector2) rl.Rectangle {
    const halfWidth = size.x / 2;
    const halfHeight = size.y / 2;
    return rl.Rectangle.init(center.x - halfWidth, center.y - halfHeight, size.x, size.y);
}

fn getResizeAnchorMouseCollisionRect(
    rect: rl.Rectangle,
    anchorPoint: ResizeAnchorPoint,
) rl.Rectangle {
    const center = anchorPoint.point.multiply(.init(rect.width, rect.height)).add(.init(rect.x, rect.y));
    return getRectWithCenter(center, .init(24, 24));
}

fn drawEntityAnchorPoints(
    context: *Context,
    editor: *Editor,
    _: *SceneDocument,
    entity: SceneEntity,
    dragAction: *?DragAction,
) void {
    const rect = utils.getEntityRectScaled(context, entity);
    const rectPos = rl.Vector2.init(rect.x, rect.y);
    const rectSize = rl.Vector2.init(rect.width, rect.height);
    const size = 6 / editor.camera.zoom;

    for (resizeAnchorPoints) |s| {
        const pointRectCenter = s.point.multiply(rectSize).add(rectPos);
        const pointRect = getRectWithCenter(pointRectCenter, .init(size, size));

        rl.drawRectangleRec(pointRect, rl.Color.white);

        const mouseCollisionRect = getResizeAnchorMouseCollisionRect(rect, s);

        if (utils.isMousePositionInsideRect(editor.camera, mouseCollisionRect)) {
            z.setMouseCursor(s.cursor);

            dragAction.* = s.toDragAction(entity.id);
        }
    }
}

fn drawSelectionBoxes(context: *Context, sceneDocument: *SceneDocument) void {
    var dragAction: ?DragAction = null;

    for (sceneDocument.getSelectedEntities().items) |selectedEntity| {
        const editor = context.getCurrentEditor().?;
        drawEntityBox(context, editor.camera, selectedEntity.*, rl.Color.white);
        drawEntityAnchorPoints(context, editor, sceneDocument, selectedEntity.*, &dragAction);
    }

    if (sceneDocument.getDragAction() == null and sceneDocument.getDragEntityState() == null) {
        sceneDocument.setDragAction(dragAction);
    }
}

fn drawDragPayload(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getDragPayload()) |payload| {
        const editor = context.getCurrentEditor().?;
        const position = if (isShiftDown()) utils.getMousePosition(
            context,
            editor.camera,
        ) else utils.gridPositionToEntityPosition(
            context,
            utils.getMouseSceneGridPosition(context),
            payload,
        );
        sceneDocument.drawEntityEx(context, payload, position);
    }
}

fn menu(context: *Context, editor: *Editor, sceneDocument: *SceneDocument) void {
    const tileSize = context.getTileSize();
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
    z.text("{d:0.0},{d:0.0}", .{ editor.camera.target.x, editor.camera.target.y });

    if (z.button("Save", .{})) {
        save(context, editor);
    }

    if (sceneDocument.getTilemapId()) |tilemapId| _ = utils.assetInput(.tilemap, context, tilemapId);

    if (z.button("Play", .{})) {
        startPlayCommand(context);
    }

    if (context.playState != .notRunning) {
        z.sameLine(.{});

        switch (context.playState) {
            .starting, .startNextFrame => z.text("Starting...", .{}),
            .errorStarting => z.textColored(.{ 1, 0, 0, 1 }, "Error Starting", .{}),
            .running => z.textColored(.{ 0, 1, 0, 1 }, "Running", .{}),
            .crash => z.textColored(.{ 1, 0, 0, 1 }, "Crashed", .{}),
            .notRunning => {},
        }
    }

    z.separatorText("Entities");
    entityListMenu(context, editor, sceneDocument);
    z.separator();

    entityDetailsMenu(context, editor, sceneDocument);

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
                    if (sceneDocument.getDragPayload() == null) {
                        sceneDocument.setDragPayload(.{ .exit = SceneEntityExit.init(context.allocator) });
                    }

                    z.endDragDropSource();
                }
                if (z.isItemHovered(.{ .delay_short = true })) {
                    if (z.beginTooltip()) {
                        z.text("Exit", .{});
                    }
                    z.endTooltip();
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
                    if (sceneDocument.getDragPayload() == null) {
                        sceneDocument.setDragPayload(.{ .entrance = SceneEntityEntrance.init(context.allocator) });
                    }
                    z.endDragDropSource();
                }
                if (z.isItemHovered(.{ .delay_short = true })) {
                    if (z.beginTooltip()) {
                        z.text("Entrance", .{});
                    }
                    z.endTooltip();
                }
            },
            .tilemap, .custom, .point => unreachable,
        }
    }

    z.separatorText("Tools");
    z.beginDisabled(.{ .disabled = sceneDocument.getTool() == .select });
    if (z.button("Select", .{})) {
        sceneDocument.setTool(.select);
    }
    z.endDisabled();
    z.beginDisabled(.{ .disabled = sceneDocument.getTool() == .createPoint });
    if (z.button("Create Point", .{})) {
        sceneDocument.setTool(.createPoint);
    }
    z.endDisabled();

    setEntityReferenceWindow(context, sceneDocument);
}

fn startPlayCommand(context: *Context) void {
    if (context.currentProject) |*project| {
        if (project.options.hasPlayCommand()) {
            context.playState = .startNextFrame;
        } else {
            project.isProjectOptionsOpen = true;
            project.focusSetProjectCommand = true;
        }
    }
}

fn entityDetailsMenu(context: *Context, _: *Editor, sceneDocument: *SceneDocument) void {
    // TODO: Add support for editing properties of multiple entities
    if (sceneDocument.getSelectedEntities().items.len == 1) {
        const selectedEntity = sceneDocument.getSelectedEntities().items[0];

        // Entity details menu
        z.text("Entity: {s}", .{@tagName(selectedEntity.type)});
        var idAsString = selectedEntity.id.serializeZ();
        _ = z.inputText("Entity Id:", .{
            .buf = &idAsString,
        });
        if (selectedEntity.type == .custom) {
            const entityType = context.requestDocumentTypeById(.entityType, selectedEntity.type.custom.entityTypeId) catch unreachable;
            if (entityType) |et| {
                z.text("Custom: {f}", .{et.getName()});
            } else {
                z.text("Custom: Not found", .{});
            }
        }

        switch (selectedEntity.type) {
            .exit => |*exit| utils.scaleInput(&exit.scale.?),
            .entrance => |*entrance| utils.scaleInput(&entrance.scale.?),
            else => utils.scaleInput(&selectedEntity.scale),
        }

        switch (selectedEntity.type) {
            .exit => |*exit| {
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
                _ = z.inputText("Key", .{
                    .buf = entrance.key.buffer,
                });
            },
            .point => |*p| {
                _ = z.inputText("Key", .{
                    .buf = p.key.buffer,
                });
            },
            else => {},
        }
        switch (selectedEntity.type) {
            .custom => |*custom| propertyEditor(context, .{ .entityInstance = custom }),
            else => {},
        }
    }
}

fn save(context: *Context, editor: *Editor) void {
    context.saveEditorFile(editor);
    context.updateThumbnailForCurrentDocument = true;
    context.sceneMap.generate(context) catch |err| {
        switch (err) {
            SceneMapError.NoValidScenesFound => {},
            else => context.showError("Could not generate scene map: {}", .{err}),
        }
    };
}

fn entityListMenu(
    context: *Context,
    _: *Editor,
    sceneDocument: *SceneDocument,
) void {
    const winWidth = z.getWindowWidth();
    z.pushStrId("Entities");
    _ = z.beginListBox("", .{ .w = winWidth - 12 });
    defer {
        z.endListBox();
        z.popId();
    }

    for (sceneDocument.getEntities().items) |entity| {
        switch (entity.type) {
            .tilemap => continue,
            else => {},
        }

        const isSelected = for (sceneDocument.getSelectedEntities().items) |selectedEntity| {
            if (selectedEntity.id.uuid == entity.id.uuid) break true;
        } else false;

        var buttonId: [UUID.zero.serialize().len + 1]u8 = undefined;
        _ = std.fmt.bufPrint(&buttonId, "{f}h", .{entity.id}) catch unreachable;
        z.pushStrId(&buttonId);
        if (sceneDocument.isEntityHidden(entity.id)) {
            if (z.button("S", .{})) {
                sceneDocument.showEntity(context.allocator, entity.id);
            }
        } else {
            if (z.button("H", .{})) {
                sceneDocument.hideEntity(context.allocator, entity.id);
            }
        }
        z.popId();

        z.sameLine(.{ .spacing = 2 });

        z.pushStrId(&entity.id.serialize());

        const entityLabel = if (entity.type == .custom) brk: {
            const entityTypeDocument: *lib.documents.EntityTypeDocument = (context.requestDocumentTypeById(
                .entityType,
                entity.type.custom.entityTypeId,
                // TODO: Bug: says loading even though there was an error while requesting the document
            ) catch break :brk "Error!") orelse break :brk "Loading...";
            break :brk entityTypeDocument.getName().slice();
        } else @tagName(entity.type);

        if (z.selectable(entityLabel, .{
            .selected = isSelected,
        })) {
            if (isShiftDown()) {
                sceneDocument.toggleSelectEntity(entity, context.allocator);
            } else {
                sceneDocument.selectOnlyEntity(entity, context.allocator);
            }
        }
        z.popId();
    }
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
                            z.text("{f} - {f}", .{
                                entityTypeDocument.getName(),
                                entity.id,
                            });
                        }
                    },
                    .entrance => |entrance| z.text("Entrance - {f}", .{entrance.key}),
                    .exit => |exit| z.text("Exit - {f}", .{exit.entranceKey}),
                    else => {},
                }
            }
        } else {
            z.text("Not selected", .{});
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
    const windowPos: @Vector(2, f32) = z.getWindowPos();
    const cursorPos: @Vector(2, f32) = z.getCursorPos();
    const offsetV = windowPos + cursorPos;
    const offset = rl.Vector2.init(offsetV[0], offsetV[1]);
    const texture = sceneDocumentToBeDrawn.getSetEntityWindowRenderTexture();
    const camera = sceneDocumentToBeDrawn.getSetEntityWindowCamera();
    rl.beginTextureMode(texture);
    rl.clearBackground(rl.Color.white);
    rl.beginMode2D(camera.*);
    drawEntities(context, sceneDocumentToBeDrawn);
    drawSetEntityReferenceHighlights(context, sceneDocument, sceneDocumentToBeDrawn, camera.*, offset);
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
                cameraTemp.target.x -= sceneTexturePos[0] / camera.zoom;
                cameraTemp.target.y -= sceneTexturePos[1] / camera.zoom;

                if (utils.isMousePositionInsideEntityRect(context, cameraTemp, entity.*)) {
                    sceneDocument.setSetEntityReferenceEntity(entity.id);
                    break;
                }
            }
        }
    }
}

fn drawSetEntityReferenceHighlights(
    context: *Context,
    sceneDocument: *SceneDocument,
    sceneDocumentToBeDrawn: *SceneDocument,
    camera: rl.Camera2D,
    offset: rl.Vector2,
) void {
    drawSetEntityReferenceSelectionBox(context, sceneDocument, sceneDocumentToBeDrawn, camera);
    drawSetEntityReferenceHoverHighlights(context, camera, sceneDocument, offset);
    drawReferencedEntitiesHighlights(context, camera, sceneDocument, sceneDocumentToBeDrawn);
}

fn drawSetEntityReferenceSelectionBox(
    context: *Context,
    sceneDocument: *SceneDocument,
    sceneDocumentToBeDrawn: *SceneDocument,
    camera: rl.Camera2D,
) void {
    const selectedTargetId = sceneDocument.getSetEntityReferenceEntity() orelse return;
    const selectedTarget = sceneDocumentToBeDrawn.getEntityByInstanceId(selectedTargetId) orelse return;
    const rect = utils.getEntityRectScaled(context, selectedTarget.*);
    rl.drawRectangleLinesEx(rect, 1 / camera.zoom, rl.Color.green);
}

fn drawSetEntityReferenceHoverHighlights(
    context: *Context,
    camera: rl.Camera2D,
    sceneDocument: *SceneDocument,
    offset: rl.Vector2,
) void {
    drawMouseoverHighlight(context, camera, sceneDocument, offset);
}

fn getEntitiesUnderDragSelectionBox(
    context: *Context,
    camera: rl.Camera2D,
    sceneDocument: *SceneDocument,
    select: DragAction.Select,
) []const *SceneEntity {
    const rect = getDragSelectionBoxRect(context, camera, select);

    var entities = std.ArrayList(*SceneEntity).initCapacity(context.allocator, sceneDocument.getEntities().items.len) catch unreachable;

    for (sceneDocument.getEntities().items) |entity| {
        if (!canSelectEntity(sceneDocument, entity)) continue;
        const entityRect = utils.getEntityRectScaled(context, entity.*);
        if (entityRect.checkCollision(rect)) {
            entities.appendAssumeCapacity(entity);
        }
    }

    return entities.toOwnedSlice(context.allocator) catch unreachable;
}

fn getDragSelectionBoxRect(
    context: *Context,
    camera: rl.Camera2D,
    select: DragAction.Select,
) rl.Rectangle {
    const mp = utils.getMousePosition(context, camera);
    const min: @Vector(2, f32) = @floatFromInt(@min(select.dragStartPoint, mp) * context.scaleV);
    const max: @Vector(2, f32) = @floatFromInt(@max(select.dragStartPoint, mp) * context.scaleV);
    const size = max - min;
    const rect = rl.Rectangle.init(min[0], min[1], size[0], size[1]);

    return rect;
}

fn drawDragAction(
    context: *Context,
    sceneDocument: *SceneDocument,
) void {
    const editor = context.getCurrentEditor().?;
    const camera = editor.camera;

    if (sceneDocument.getDragAction()) |dragAction| {
        switch (dragAction) {
            .select => |select| {
                const rect = getDragSelectionBoxRect(context, camera, select);

                rl.drawRectangleLinesEx(rect, 1 / camera.zoom, rl.Color.white);

                const entities = getEntitiesUnderDragSelectionBox(
                    context,
                    camera,
                    sceneDocument,
                    select,
                );
                defer context.allocator.free(entities);

                for (entities) |entity| drawEntityBox(
                    context,
                    camera,
                    entity.*,
                    rl.Color.yellow,
                );
            },
            .move, .resize => {},
        }
    }
}

fn handleInput(context: *Context, editor: *Editor, sceneDocument: *SceneDocument) void {
    utils.cameraControls(&editor.camera);

    sceneDocumentHandleInputCreateEntity(context, editor, sceneDocument);
    sceneDocumentHandleInputCreateEntityFromAssetsManager(context, editor, sceneDocument);

    switch (sceneDocument.getTool()) {
        .select => handleInputToolSelect(context, editor, sceneDocument),
        .createPoint => handleInputToolCreatePoint(context, editor, sceneDocument),
    }

    if (rl.isKeyPressed(.f5)) {
        startPlayCommand(context);
    } else if (isControlDown()) {
        if (rl.isKeyPressed(.s)) {
            save(context, editor);
        }
    }
}

fn handleInputToolSelect(
    context: *Context,
    editor: *Editor,
    sceneDocument: *SceneDocument,
) void {
    sceneDocumentHandleInputSelectEntity(context, editor, sceneDocument);
    sceneDocumentHandleInputDragging(context, editor, sceneDocument);
    sceneDocumentHandleInputDeleteEntity(context, sceneDocument);
}

fn handleInputToolCreatePoint(
    context: *Context,
    editor: *Editor,
    sceneDocument: *SceneDocument,
) void {
    handleInputCreatePoint(context, editor, sceneDocument);
}

fn handleInputCreatePoint(
    context: *Context,
    editor: *Editor,
    sceneDocument: *SceneDocument,
) void {
    if (!rl.isMouseButtonPressed(.left)) return;
    const position = utils.getMousePosition(context, editor.camera);
    _ = sceneDocument.addEntity(context.allocator, position, .{ .point = .init(context.allocator) });
}

fn sceneDocumentHandleInputCreateEntity(
    context: *Context,
    editor: *Editor,
    sceneDocument: *SceneDocument,
) void {
    const payload = sceneDocument.getDragPayload() orelse return;

    if (rl.isMouseButtonReleased(.left)) {
        const position = if (isShiftDown()) utils.getMousePosition(
            context,
            editor.camera,
        ) else utils.gridPositionToEntityPosition(
            context,
            utils.getMouseSceneGridPosition(context),
            payload,
        );
        const entity = sceneDocument.addEntity(context.allocator, position, payload);
        sceneDocument.setDragPayload(null);
        sceneDocument.setTool(.select);
        sceneDocument.selectOnlyEntity(entity, context.allocator);
    }
}

fn sceneDocumentHandleInputCreateEntityFromAssetsManager(
    context: *Context,
    editor: *Editor,
    sceneDocument: *SceneDocument,
) void {
    const dragPayload = z.getDragDropPayload() orelse return;
    const draggedNode: *Node = @as(**Node, @ptrCast(@alignCast(dragPayload.data.?))).*;

    if (draggedNode.* == .directory) return;
    if (draggedNode.file.documentType != .entityType) return;

    const fileNode = draggedNode.file;
    const id = fileNode.id orelse return;

    if (rl.isMouseButtonReleased(.left)) {
        const entityTypeTag = SceneEntityType{ .custom = .init(context, id) };
        const position = if (isShiftDown()) utils.getMousePosition(
            context,
            editor.camera,
        ) else utils.gridPositionToEntityPosition(
            context,
            utils.getMouseSceneGridPosition(context),
            entityTypeTag,
        );
        const entity = sceneDocument.addEntity(context.allocator, position, entityTypeTag);
        sceneDocument.setTool(.select);
        sceneDocument.selectOnlyEntity(entity, context.allocator);
    }
}

fn sceneDocumentHandleInputSelectEntity(
    context: *Context,
    editor: *Editor,
    sceneDocument: *SceneDocument,
) void {
    if (sceneDocument.getDragPayload() != null) return;

    if (rl.isMouseButtonPressed(.left)) {
        if (sceneDocument.getDragAction()) |dragAction| {
            const draggedEntities = switch (dragAction) {
                .move => sceneDocument.getSelectedEntities().items,
                .resize => |resize| &.{sceneDocument.getEntityByInstanceId(resize.entityId).?},
                .select => return,
            };
            setDragEntityState(context, editor, sceneDocument, draggedEntities);
        } else for (sceneDocument.getEntities().items) |entity| {
            if (!canSelectEntity(sceneDocument, entity)) continue;

            if (utils.isMousePositionInsideEntityRect(context, editor.camera, entity.*)) {
                if (isShiftDown()) {
                    sceneDocument.toggleSelectEntity(entity, context.allocator);
                } else if (!sceneDocument.isEntitySelected(entity)) {
                    sceneDocument.selectOnlyEntity(entity, context.allocator);
                }
                if (sceneDocument.getSelectedEntities().items.len > 0) {
                    setDragEntityState(
                        context,
                        editor,
                        sceneDocument,
                        sceneDocument.getSelectedEntities().items,
                    );
                }
                break;
            }
        } else {
            if (!isShiftDown()) {
                sceneDocument.deselectAllEntities();
            }

            sceneDocument.setDragAction(.{ .select = .{
                .dragStartPoint = utils.getMousePosition(context, editor.camera),
            } });
        }
    }
}

fn isControlDown() bool {
    return rl.isKeyDown(.left_control) or rl.isKeyDown(.right_control);
}

fn isShiftDown() bool {
    return rl.isKeyDown(.left_shift) or rl.isKeyDown(.right_shift);
}

fn canSelectEntity(sceneDocument: *SceneDocument, entity: *SceneEntity) bool {
    if (entity.type == .tilemap) return false;
    if (sceneDocument.isEntityHidden(entity.id)) return false;

    return true;
}

fn setDragEntityState(
    context: *Context,
    editor: *Editor,
    sceneDocument: *SceneDocument,
    entities: []const *SceneEntity,
) void {
    const firstEntity = entities[0];
    const entitySize = utils.getEntitySizeNotScaled(context, firstEntity.*);
    const snapshot = context.allocator.alloc(DragEntityState.Snapshot, entities.len) catch unreachable;
    for (entities, 0..) |entity, i| snapshot[i] = .{
        .entity = entity,
        .startPosition = entity.position,
    };
    sceneDocument.setDragEntityState(.{
        .dragStartPoint = utils.getMousePosition(context, editor.camera),
        .snapshot = snapshot,
        .startScale = firstEntity.scale,
        .entitySize = .{ @intFromFloat(entitySize.x), @intFromFloat(entitySize.y) },
    });
}

fn getDragAction(sceneDocument: *SceneDocument) DragAction {
    if (sceneDocument.getDragAction()) |action| return action;
    return .move;
}

fn handleDragActionEnd(
    context: *Context,
    camera: rl.Camera2D,
    sceneDocument: *SceneDocument,
) void {
    if (sceneDocument.getDragAction()) |dragAction| {
        if (!rl.isMouseButtonDown(.left)) {
            switch (dragAction) {
                .select => |select| {
                    const entities = getEntitiesUnderDragSelectionBox(
                        context,
                        camera,
                        sceneDocument,
                        select,
                    );
                    defer context.allocator.free(entities);

                    if (isShiftDown()) {
                        sceneDocument.selectAppendEntities(entities, context.allocator);
                    } else {
                        sceneDocument.selectOnlyEntities(entities, context.allocator);
                    }
                },
                .resize, .move => {},
            }

            sceneDocument.setDragAction(null);
        }
    }
}

fn sceneDocumentHandleInputDragging(
    context: *Context,
    editor: *Editor,
    sceneDocument: *SceneDocument,
) void {
    if (sceneDocument.getDragPayload() != null) return;

    handleDragActionEnd(context, editor.camera, sceneDocument);

    if (sceneDocument.getSelectedEntities().items.len == 0) return;

    if (!rl.isMouseButtonDown(.left)) {
        sceneDocument.setIsDragging(false);
        sceneDocument.setDragEntityState(null);
    }

    if (sceneDocument.getDragEntityState()) |dragEntityState| {
        if (sceneDocument.getIsDragging()) {
            const mousePosition = utils.getMousePosition(context, editor.camera);
            const dragAction = getDragAction(sceneDocument);
            applyDragAction(context, sceneDocument, dragEntityState, mousePosition, dragAction);
        } else {
            const dsp = rl.Vector2.init(
                @floatFromInt(dragEntityState.dragStartPoint[0]),
                @floatFromInt(dragEntityState.dragStartPoint[1]),
            );
            const mousePosition = utils.getMousePosition(context, editor.camera);
            const mp = rl.Vector2.init(
                @floatFromInt(mousePosition[0]),
                @floatFromInt(mousePosition[1]),
            );

            if (dsp.distanceSqr(mp) >= distanceToStartDrag * distanceToStartDrag) {
                sceneDocument.setIsDragging(true);
            }
        }
    }
}

fn applyDragAction(
    context: *Context,
    sceneDocument: *SceneDocument,
    dragEntityState: DragEntityState,
    mousePosition: Vector,
    dragAction: DragAction,
) void {
    switch (dragAction) {
        .move => applyMoveEntity(context, dragEntityState, mousePosition),
        .resize => |resize| applyResizeEntity(
            context,
            sceneDocument,
            dragEntityState,
            mousePosition,
            resize,
        ),
        .select => {},
    }
}

fn applyMoveEntity(
    context: *Context,
    dragEntityState: DragEntityState,
    mousePosition: Vector,
) void {
    const deltaPosition = mousePosition - dragEntityState.dragStartPoint;

    for (dragEntityState.snapshot) |s| {
        const precisionPosition = deltaPosition + s.startPosition;
        const gridSnapPosition = snapPositionToGridPosition(context, precisionPosition);

        const newPosition = if (isShiftDown()) gridSnapPosition else precisionPosition;
        s.entity.position = newPosition;
    }
}

fn snapPositionToGridPosition(
    context: *Context,
    position: Vector,
) Vector {
    const cellSize = @divFloor(context.getTileSize(), Vector{ 2, 2 });
    return utils.snapPositionToGridPosition(cellSize, position);
}

fn applyResizeEntity(
    context: *Context,
    sceneDocument: *SceneDocument,
    dragEntityState: DragEntityState,
    mousePosition: Vector,
    resizeAction: ResizeAction,
) void {
    const gridSnapStartPosition = snapPositionToGridPosition(context, dragEntityState.dragStartPoint);
    const gridSnapPosition = snapPositionToGridPosition(context, mousePosition);
    const dragStartPoint = if (isShiftDown()) gridSnapStartPosition else dragEntityState.dragStartPoint;
    const inputPosition = if (isShiftDown()) gridSnapPosition else mousePosition;

    var unit: @Vector(2, f32) = .{ 0, 0 };

    switch (resizeAction.direction) {
        .right => unit = .{ 1, 0 },
        .topright => unit = .{ 1, -1 },
        .top => unit = .{ 0, -1 },
        .topleft => unit = .{ -1, -1 },
        .left => unit = .{ -1, 0 },
        .bottomleft => unit = .{ -1, 1 },
        .bottom => unit = .{ 0, 1 },
        .bottomright => unit = .{ 1, 1 },
    }

    const size: @Vector(2, f32) = @floatFromInt(dragEntityState.entitySize);
    const deltaMouse: @Vector(2, f32) = @floatFromInt(inputPosition - dragStartPoint);

    const delta = deltaMouse * unit;
    const deltaLimit = (-dragEntityState.startScale * size) * @abs(unit);
    const actualDelta = @max(deltaLimit, delta);

    const deltaScale = actualDelta / size;
    const deltaPos: Vector = @intFromFloat(actualDelta * unit / @Vector(2, f32){ 2, 2 });

    const entity = sceneDocument.getEntityByInstanceId(resizeAction.entityId).?;

    entity.scale = dragEntityState.startScale + deltaScale;
    entity.position = dragEntityState.getSnapshotById(entity.id).startPosition + deltaPos;
}

fn sceneDocumentHandleInputDeleteEntity(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getSelectedEntities().items.len == 0) return;

    if (rl.isKeyPressed(.delete)) {
        sceneDocument.deleteEntities(
            context.allocator,
            sceneDocument.getSelectedEntities().items,
        );
    }
}

fn getHoveredEntity(
    context: *Context,
    camera: rl.Camera2D,
    sceneDocument: *SceneDocument,
    offset: rl.Vector2,
) ?*SceneEntity {
    for (sceneDocument.getEntities().items) |entity| {
        if (entity.type == .tilemap) continue;
        if (sceneDocument.isEntityHidden(entity.id)) continue;

        const entityRect = utils.getEntityRectScaled(context, entity.*);
        const worldMousePosition = rl.getScreenToWorld2D(
            rl.getMousePosition().subtract(offset),
            camera,
        );

        if (rl.checkCollisionPointRec(worldMousePosition, entityRect) or entity.isPointInEntityRect(.{ worldMousePosition.x, worldMousePosition.y })) {
            return entity;
        }
    }

    return null;
}
