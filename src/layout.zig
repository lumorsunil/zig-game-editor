const std = @import("std");
const Allocator = std.mem.Allocator;
const z = @import("zgui");
const c = @import("c");
const rl = @import("raylib");
const nfd = @import("nfd");
const lib = @import("root").lib;
const Context = lib.Context;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const drawTilemap = lib.drawTilemap;
const Vector = lib.Vector;
const TileSource = lib.TileSource;
const TilemapLayer = lib.TilemapLayer;
const Action = lib.Action;
const Editor = lib.Editor;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityType = lib.documents.scene.SceneEntityType;
const SceneEntityExit = lib.documents.scene.SceneEntityExit;
const SceneEntityEntrance = lib.documents.scene.SceneEntityEntrance;
const SceneDocument = lib.documents.SceneDocument;
const TilemapDocument = lib.documents.TilemapDocument;
const AnimationDocument = lib.documents.AnimationDocument;
const assetsManager = @import("layout/assets-manager.zig").assetsManager;

const tileSize = Vector{ 16, 16 };

pub fn layout(context: *Context) !void {
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));
    context.camera.offset.x = screenW / 2;
    context.camera.offset.y = screenH / 2;

    rl.clearBackground(context.backgroundColor);
    rl.beginMode2D(context.camera);

    if (context.getCurrentEditor()) |editor| {
        drawEditor(context, editor);
    }

    rl.endMode2D();

    c.rlImGuiBegin();

    if (context.currentProject) |_| {
        if (context.getCurrentEditor()) |editor| {
            editorMenu(context, editor);
        }

        assetsManager(context);
    } else {
        noProjectOpenedMenu(context);
    }

    if (context.isErrorDialogOpen) {
        _ = z.begin("Error Message", .{});
        z.textColored(.{ 1, 0, 0, 1 }, "{s}", .{context.errorMessage});
        z.end();
    }

    c.rlImGuiEnd();

    if (context.getCurrentEditor()) |editor| {
        if (!z.io.getWantCaptureMouse()) {
            editorHandleInput(context, editor);
        }
    }
}

fn noProjectOpenedMenu(context: *Context) void {
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));

    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = screenW, .h = screenH });
    _ = z.begin("No Project Opened Menu", .{ .flags = .{ .no_title_bar = true, .no_resize = true, .no_collapse = true, .no_background = true, .no_move = true } });
    defer z.end();

    const buttonSize = 256;
    const buttonSpacing = 64;

    z.setCursorPos(.{ screenW / 2 - buttonSize - buttonSpacing, screenH / 2 - buttonSize / 2 });

    if (z.button("New Project", .{ .w = buttonSize, .h = buttonSize })) {
        context.newProject();
    }
    z.sameLine(.{ .spacing = buttonSpacing });
    if (z.button("Open Project", .{ .w = buttonSize, .h = buttonSize })) {
        context.openProject();
    }
}

fn drawEditor(context: *Context, editor: *Editor) void {
    switch (editor.document.content.?) {
        .scene => |*scene| drawSceneDocument(context, scene),
        .tilemap => |*tilemap| drawTilemapDocument(context, tilemap),
        // .animation => |animation| drawAnimationDocument(context, animation),
        else => {},
    }
}

fn editorMenu(context: *Context, editor: *Editor) void {
    switch (editor.document.content.?) {
        .scene => |*scene| sceneDocumentMenu(context, editor, scene),
        .tilemap => |*tilemap| tilemapDocumentMenu(context, editor, tilemap),
        else => {},
    }
}

fn editorHandleInput(context: *Context, editor: *Editor) void {
    switch (editor.document.content.?) {
        .scene => |*scene| sceneDocumentHandleInput(context, scene),
        .tilemap => |*tilemap| tilemapDocumentHandleInput(context, editor, tilemap),
        else => {},
    }
}

fn sceneDocumentMenu(context: *Context, editor: *Editor, sceneDocument: *SceneDocument) void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 200, .h = 800 });
    _ = z.begin("Scene Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
    } });
    defer z.end();

    activeDocumentLabel(context, editor);

    if (z.button("Reset Camera", .{})) {
        resetCamera(context);
    }
    z.text("{d:0.0},{d:0.0}", .{ context.camera.target.x, context.camera.target.y });

    if (z.button("Save", .{})) {
        context.saveEditorFile(editor);
    }
    if (z.button("Set Tilemap", .{})) {
        if (context.openFileWithDialog(.tilemap)) |document| {
            for (sceneDocument.getEntities().items) |entity| {
                if (entity.type == .tilemap) {
                    // TODO: Check if there's an issue with this path being relative to root
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
                scaleInput(&exit.scale.?);
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
                        resetCamera(context);
                        return;
                    }
                }
            },
            .entrance => |*entrance| {
                scaleInput(&entrance.scale.?);
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
                const source = sceneDocument.getSourceRectFromEntityType(tag);
                const size = sceneDocument.getSizeFromEntityType(tag);
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
                    sceneDocument.getDragPayload().* = .{ .entrance = SceneEntityEntrance.init(context.allocator) };
                    z.endDragDropSource();
                }
            },
            .tilemap => {},
        }
    }
}

fn scaleInput(scale: *@Vector(2, f32)) void {
    _ = z.inputFloat2("Scale", .{ .v = scale });
}

fn tilemapDocumentMenu(
    context: *Context,
    editor: *Editor,
    tilemapDocument: *TilemapDocument,
) void {
    if (tilemapDocument.isCurrentTool(.brush) and tilemapDocument.getCurrentTool().?.impl.brush.isSelectingTileSource) {
        try selectTileSourceMenu(context, tilemapDocument, &tilemapDocument.getCurrentTool().?.impl.brush);
    } else {
        if (context.isDemoWindowEnabled) {
            z.showDemoWindow(&context.isDemoWindowOpen);
        }

        mainMenu(context, editor, tilemapDocument);
    }
}

fn drawTilemapDocument(context: *Context, document: *TilemapDocument) void {
    const tilemap = document.getTilemap();
    const size = tilemap.grid.size * tilemap.tileSize * context.scaleV;
    const thickness = 2;
    const rect = rl.Rectangle.init(
        -thickness,
        -thickness,
        @floatFromInt(size[0] + thickness * 2),
        @floatFromInt(size[1] + thickness * 2),
    );
    rl.drawRectangleLinesEx(rect, thickness / context.camera.zoom, rl.Color.black);
    drawTilemap(context, document, .{ 0, 0 }, false);

    if (document.getCurrentTool()) |currentTool| {
        switch (currentTool.impl) {
            .select => |*select| select.draw(context, document),
            else => {},
        }
    }
}

fn drawAnimationDocument(_: *Context, _: *AnimationDocument) void {}

fn drawSceneDocument(context: *Context, sceneDocument: *SceneDocument) void {
    for (sceneDocument.getEntities().items) |entity| {
        sceneDocument.drawEntity(context, entity.*);
    }

    for (sceneDocument.getSelectedEntities().items) |selectedEntity| {
        const rect = getEntityRectScaled(context, sceneDocument, selectedEntity.*);
        rl.drawRectangleLinesEx(rect, 1 / context.camera.zoom, rl.Color.white);
    }

    if (sceneDocument.getDragPayload().*) |payload| {
        const position = if (rl.isKeyDown(.key_left_shift)) getMousePosition(context) else gridPositionToEntityPosition(context, sceneDocument, getMouseSceneGridPosition(context), payload);
        sceneDocument.drawEntity(context, SceneEntity.init(context.allocator, position, payload));
    }
}

fn sceneDocumentHandleInput(context: *Context, sceneDocument: *SceneDocument) void {
    cameraControls(context);
    sceneDocumentHandleInputCreateEntity(context, sceneDocument);
    sceneDocumentHandleInputSelectEntity(context, sceneDocument);
    sceneDocumentHandleInputMoveEntity(context, sceneDocument);
    sceneDocumentHandleInputDeleteEntity(context, sceneDocument);

    if (rl.isKeyPressed(.key_f5)) {
        context.play();
    }
}

fn sceneDocumentHandleInputCreateEntity(context: *Context, sceneDocument: *SceneDocument) void {
    const dragPayload = sceneDocument.getDragPayload();
    if (dragPayload.*) |payload| {
        if (rl.isMouseButtonReleased(.mouse_button_left)) {
            const entity = context.allocator.create(SceneEntity) catch unreachable;
            const position = if (rl.isKeyDown(.key_left_shift)) getMousePosition(context) else gridPositionToEntityPosition(context, sceneDocument, getMouseSceneGridPosition(context), payload);
            entity.* = SceneEntity.init(context.allocator, position, payload);
            sceneDocument.getEntities().append(context.allocator, entity) catch unreachable;
            dragPayload.* = null;
        }
    }
}

fn sceneDocumentHandleInputSelectEntity(context: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getDragPayload().* != null) return;

    if (rl.isMouseButtonPressed(.mouse_button_left)) {
        for (sceneDocument.getEntities().items) |entity| {
            if (entity.type == .tilemap) continue;

            if (isMousePositionInsideEntityRect(context, sceneDocument, entity.*)) {
                sceneDocument.selectEntity(entity, context.allocator);
                sceneDocument.setDragStartPoint(getMousePosition(context));
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
            if (rl.isMouseButtonDown(.mouse_button_left)) {
                const entity = sceneDocument.getSelectedEntities().items[0];
                const position = if (rl.isKeyDown(.key_left_shift)) getMousePosition(context) else gridPositionToEntityPosition(context, sceneDocument, getMouseSceneGridPosition(context), entity.type);
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
            const mousePosition = getMousePosition(context);
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

fn sceneDocumentHandleInputDeleteEntity(_: *Context, sceneDocument: *SceneDocument) void {
    if (sceneDocument.getSelectedEntities().items.len == 0) return;

    const selectedEntity = sceneDocument.getSelectedEntities().items[0];
    if (rl.isKeyPressed(.key_delete)) {
        sceneDocument.deleteEntity(selectedEntity);
    }
}

fn tilemapDocumentHandleInput(context: *Context, editor: *Editor, tilemapDocument: *TilemapDocument) void {
    cameraControls(context);

    if (tilemapDocument.getCurrentTool()) |tool| {
        switch (tool.impl) {
            .brush => |*brush| handleBrush(context, tilemapDocument, brush),
            .select => |*select| handleSelect(context, tilemapDocument, select),
        }
    }

    handleShortcuts(context, editor);
}

fn cameraControls(context: *Context) void {
    if (rl.isMouseButtonDown(.mouse_button_middle)) {
        const delta = rl.getMouseDelta();
        context.camera.target.x -= delta.x / context.camera.zoom;
        context.camera.target.y -= delta.y / context.camera.zoom;
    }

    if (rl.isKeyDown(.key_left_control)) {
        context.camera.zoom *= 1 + rl.getMouseWheelMove() * 0.1;
        context.camera.zoom = std.math.clamp(context.camera.zoom, 0.1, 10);
    }
}

fn handleShortcuts(context: *Context, editor: *Editor) void {
    if (rl.isKeyDown(.key_left_control)) {
        if (rl.isKeyDown(.key_s)) return context.saveEditorFile(editor);
        if (rl.isKeyPressed(.key_z)) {
            if (rl.isKeyDown(.key_left_shift)) {
                if (editor.document.content.? == .tilemap) {
                    return editor.document.content.?.tilemap.redo(context.allocator);
                }
            } else {
                if (editor.document.content.? == .tilemap) {
                    return editor.document.content.?.tilemap.undo(context.allocator);
                }
            }
        }
        if (rl.isKeyPressed(.key_y)) {
            if (editor.document.content.? == .tilemap) {
                return editor.document.content.?.tilemap.redo(context.allocator);
            }
        }
    } else if (rl.isKeyPressed(.key_n)) {
        if (editor.document.content.? == .tilemap) {
            editor.document.content.?.tilemap.setToolByType(.brush);
        }
    } else if (rl.isKeyPressed(.key_r)) {
        if (editor.document.content.? == .tilemap) {
            editor.document.content.?.tilemap.setToolByType(.select);
        }
    }
}

fn mainMenu(context: *Context, editor: *Editor, tilemapDocument: *TilemapDocument) void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 200, .h = 800 });
    _ = z.begin("Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
    } });
    defer z.end();

    activeDocumentLabel(context, editor);

    z.separatorText("File");
    fileMenu(context, editor);
    z.separatorText("Edit");
    editMenu(context, tilemapDocument);
    z.separatorText("Tilemap");
    tilemapMenu(context, tilemapDocument);
    z.separatorText("Tools");
    toolPickerMenu(context, tilemapDocument);
    if (tilemapDocument.hasTool()) {
        z.separatorText("Tool details");
        toolDetailsMenu(context, tilemapDocument);
    }
    z.separatorText("Tilesets");
    z.separatorText("Layers");
    layersMenu(context, tilemapDocument);
    z.separatorText("History");
    historyMenu(context, tilemapDocument);
}

fn capitalize(allocator: Allocator, s: []const u8) []const u8 {
    return std.fmt.allocPrint(allocator, "{c}{s}", .{ std.ascii.toUpper(s[0]), s[1..] }) catch unreachable;
}

fn activeDocumentLabel(context: *Context, editor: *Editor) void {
    const baseName = std.fs.path.basename(editor.document.filePath);
    var it = std.mem.splitScalar(u8, baseName, '.');
    const name = it.next().?;
    const typeLabel = capitalize(context.allocator, @tagName(editor.documentType));
    defer context.allocator.free(typeLabel);
    z.text("{s}: {s}", .{ typeLabel, name });
    if (z.isItemHovered(.{ .delay_short = true })) {
        if (z.beginTooltip()) {
            z.text("{s}", .{editor.document.filePath});
        }
        z.endTooltip();
    }
}

fn fileMenu(context: *Context, editor: *Editor) void {
    if (z.button("Save", .{})) {
        context.saveEditorFile(editor);
    }
    switch (editor.document.content.?) {
        .tilemap => |tilemap| {
            if (z.button("Squash History", .{})) {
                tilemap.squashHistory(context.allocator);
            }
        },
        else => {},
    }
}

fn editMenu(context: *Context, tilemapDocument: *TilemapDocument) void {
    z.beginDisabled(.{ .disabled = !tilemapDocument.canUndo() });
    if (z.button("Undo", .{})) {
        tilemapDocument.undo(context.allocator);
    }
    z.endDisabled();
    z.sameLine(.{});
    z.beginDisabled(.{ .disabled = !tilemapDocument.canRedo() });
    if (z.button("Redo", .{})) {
        tilemapDocument.redo(context.allocator);
    }
    z.endDisabled();
}

fn tilemapMenu(context: *Context, tilemapDocument: *TilemapDocument) void {
    const inputTilemapSize = &tilemapDocument.document.nonPersistentData.inputTilemapSize;
    if (z.inputInt2("Size", .{
        .v = inputTilemapSize,
        .flags = .{
            .enter_returns_true = true,
        },
    })) {
        tilemapDocument.startGenericAction(Action.ResizeTilemap, context.allocator);
        tilemapDocument.document.persistentData.tilemap.resize(context.allocator, inputTilemapSize.*);
        tilemapDocument.endGenericAction(Action.ResizeTilemap, context.allocator);
    }
}

fn toolPickerMenu(_: *Context, tilemapDocument: *TilemapDocument) void {
    for (tilemapDocument.getTools(), 0..) |*tool, i| {
        if (i > 0) z.sameLine(.{});
        if (z.button(tool.name, .{})) {
            tilemapDocument.setTool(tool);
        }
    }
}

fn toolDetailsMenu(context: *Context, tilemapDocument: *TilemapDocument) void {
    const tool = tilemapDocument.getCurrentTool();

    switch (tool.?.impl) {
        .brush => |*brush| brushToolDetailsMenu(context, tilemapDocument, brush),
        .select => |*select| selectToolDetailsMenu(context, select),
    }
}

fn brushToolDetailsMenu(context: *Context, tilemapDocument: *TilemapDocument, brush: *BrushTool) void {
    if (z.button("Set Tile", .{})) {
        brush.isSelectingTileSource = true;
    }
    if (brush.source) |source| {
        const texture = context.textures.getPtr(source.tileset).?;
        const sourceRect = source.getSourceRect(tilemapDocument.getTileSize());
        c.rlImGuiImageRect(@ptrCast(texture), 64, 64, @bitCast(sourceRect));
    }
}

fn selectToolDetailsMenu(context: *Context, select: *SelectTool) void {
    _ = select; // autofix
    _ = context; // autofix
}

fn layersMenu(context: *Context, tilemapDocument: *TilemapDocument) void {
    const buttonSize = 24;
    _ = z.checkbox("Focus", .{ .v = tilemapDocument.getFocusOnActiveLayerPtr() });
    if (z.button("+", .{ .w = buttonSize, .h = buttonSize })) {
        tilemapDocument.startGenericAction(Action.AddLayer, context.allocator);
        _ = tilemapDocument.addLayer(context.allocator, "Layer");
        tilemapDocument.endGenericAction(Action.AddLayer, context.allocator);
    }

    const tilemap = tilemapDocument.getTilemap();

    for (tilemap.layers.items, 0..) |*layer_ptr, i| {
        const layer = layer_ptr.*;
        const isActiveLayer = layer.id.uuid == tilemap.activeLayer.uuid;

        // Active layer highlighting
        if (isActiveLayer) {
            const x = z.getWindowContentRegionMin()[0] - 2;
            const y = z.getCursorPosY() - 2;
            const w = z.getWindowContentRegionMax()[0] - 2;
            const h = 20 + 4;
            z.getWindowDrawList().addRect(.{
                .pmin = .{ x, y },
                .pmax = .{ x + w, y + h },
                .col = @bitCast(c.ColorToInt(c.WHITE)),
                .rounding = 0.0,
                .flags = .{ .closed = true },
                .thickness = 1.0,
            });
        }

        // Layer name
        if (i == 0 or !isActiveLayer) {
            z.text("{s}", .{layer.name});
        } else {
            z.pushPtrId(layer);
            const ctx = context.allocator.create(LayerNameInputCallbackContext) catch unreachable;
            defer context.allocator.destroy(ctx);
            ctx.* = .{
                .context = context,
                .tilemapDocument = tilemapDocument,
            };
            if (z.inputText("", .{
                .buf = layer.getNameBuffer(),
                .flags = .{
                    .enter_returns_true = true,
                    .callback_edit = true,
                },
                .callback = layerNameInputCallback,
                .user_data = ctx,
            })) {
                tilemapDocument.endGenericAction(Action.RenameLayer, context.allocator);
            }
            z.popId();
        }

        if (z.isItemClicked(.left)) {
            tilemap.activeLayer = layer.id;
        }

        // Remove layer button
        if (i > 0) {
            z.sameLine(.{ .offset_from_start_x = z.getWindowWidth() - buttonSize });
            z.pushIntId(@intCast(i));
            if (z.button("-", .{ .w = buttonSize, .h = buttonSize })) {
                tilemapDocument.startGenericAction(Action.RemoveLayer, context.allocator);
                tilemap.removeLayer(context.allocator, layer.id);
                tilemapDocument.endGenericAction(Action.RemoveLayer, context.allocator);
            }
            z.popId();
        }
    }
}

const LayerNameInputCallbackContext = struct {
    context: *Context,
    tilemapDocument: *TilemapDocument,
};

fn layerNameInputCallback(data: *z.InputTextCallbackData) i32 {
    const ctx: *LayerNameInputCallbackContext = @ptrCast(@alignCast(data.user_data.?));
    const layer = ctx.tilemapDocument.getTilemap().getActiveLayer();

    ctx.tilemapDocument.startGenericAction(Action.RenameLayer, ctx.context.allocator);
    layer.setName(data.buf[0..@intCast(data.buf_text_len)]);

    return 0;
}

fn getMouseGridPositionSafe(context: *Context, tilemapDocument: *TilemapDocument) ?Vector {
    const gridPosition = getMouseGridPosition(context, tilemapDocument);
    if (tilemapDocument.isOutOfBounds(gridPosition)) return null;
    return gridPosition;
}

fn getMousePosition(context: *Context) Vector {
    const mp = rl.getMousePosition();
    const mtrx = rl.getCameraMatrix2D(context.camera);
    const inv = mtrx.invert();
    const tr = mp.transform(inv);
    const ftr = @Vector(2, f32){ tr.x, tr.y };
    const scale: @Vector(2, f32) = @floatFromInt(context.scaleV);

    const fp = ftr / scale;

    return @intFromFloat(fp);
}

fn getMouseSceneGridPosition(context: *Context) Vector {
    const mp = getMousePosition(context);
    const ftr: @Vector(2, f32) = @floatFromInt(mp);
    const fDivisor: @Vector(2, f32) = @floatFromInt(tileSize);

    const fp = (ftr + fDivisor / @Vector(2, f32){ -2, 2 }) / fDivisor;

    return @intFromFloat(fp);
}

fn getMouseGridPosition(context: *Context, tilemapDocument: *TilemapDocument) Vector {
    const mp = getMousePosition(context);
    const ftr: @Vector(2, f32) = @floatFromInt(mp);
    const tilemap = tilemapDocument.getTilemap();
    const fDivisor: @Vector(2, f32) = @floatFromInt(tilemap.tileSize);

    const fp = ftr / fDivisor;

    return @intFromFloat(fp);
}

fn gridPositionToEntityPosition(
    _: *Context,
    sceneDocument: *SceneDocument,
    gridPosition: Vector,
    entityType: SceneEntityType,
) Vector {
    const fTileSize: @Vector(2, f32) = @floatFromInt(tileSize);
    const rlEntitySize = sceneDocument.getSizeFromEntityType(entityType);
    const entitySize = @Vector(2, f32){ rlEntitySize.x, rlEntitySize.y };
    const half = @Vector(2, f32){ 0.5, 0.5 };
    return @intFromFloat(fTileSize * @as(@Vector(2, f32), @floatFromInt(gridPosition)) - fTileSize * half + entitySize * half);
}

fn gridPositionToCenterOfTile(_: *Context, gridPosition: Vector) Vector {
    const fTileSize: @Vector(2, f32) = @floatFromInt(tileSize);
    const half = @Vector(2, f32){ 0.5, 0.5 };
    return @intFromFloat(fTileSize * @as(@Vector(2, f32), @floatFromInt(gridPosition)) + fTileSize * half);
}

fn getEntityRect(_: *Context, sceneDocument: *SceneDocument, entity: SceneEntity) rl.Rectangle {
    const entityPosition: @Vector(2, f32) = @floatFromInt(entity.position);
    const scaleVx, const scaleVy = switch (entity.type) {
        inline .exit, .entrance => |e| e.scale.?,
        else => .{ 1, 1 },
    };
    var size = sceneDocument.getSizeFromEntityType(entity.type);
    size.x *= scaleVx;
    size.y *= scaleVy;
    var rect = rl.Rectangle.init(entityPosition[0], entityPosition[1], size.x, size.y);
    rect.x -= rect.width / 2;
    rect.y -= rect.height / 2;

    return rect;
}

fn getEntityRectScaled(
    context: *Context,
    sceneDocument: *SceneDocument,
    entity: SceneEntity,
) rl.Rectangle {
    var rect = getEntityRect(context, sceneDocument, entity);
    const scale: f32 = @floatFromInt(context.scale);
    rect.width *= scale;
    rect.height *= scale;
    rect.x *= scale;
    rect.y *= scale;

    return rect;
}

fn isMousePositionInsideEntityRect(
    context: *Context,
    sceneDocument: *SceneDocument,
    entity: SceneEntity,
) bool {
    const point: @Vector(2, f32) = @floatFromInt(getMousePosition(context));
    const rlPoint = rl.Vector2.init(point[0], point[1]);
    const rect = getEntityRect(context, sceneDocument, entity);

    return rl.checkCollisionPointRec(rlPoint, rect);
}

fn handleBrush(context: *Context, tilemapDocument: *TilemapDocument, brush: *BrushTool) void {
    highlightHoveredCell(context, tilemapDocument);

    if (rl.isMouseButtonDown(.mouse_button_left)) {
        tilemapDocument.startGenericAction(Action.BrushPaint, context.allocator);

        const gridPosition = getMouseGridPositionSafe(context, tilemapDocument);

        if (gridPosition == null) return;

        brush.onUse(context, tilemapDocument, gridPosition.?);
    } else {
        brush.onUseEnd();
        tilemapDocument.endGenericAction(Action.BrushPaint, context.allocator);
    }

    if (rl.isMouseButtonDown(.mouse_button_right)) {
        tilemapDocument.startGenericAction(Action.BrushDelete, context.allocator);

        const gridPosition = getMouseGridPositionSafe(context, tilemapDocument);

        if (gridPosition == null) return;

        brush.onAlternateUse(context, tilemapDocument.getTilemap(), gridPosition.?);
    } else {
        tilemapDocument.endGenericAction(Action.BrushDelete, context.allocator);
    }
}

fn handleSelect(context: *Context, tilemapDocument: *TilemapDocument, select: *SelectTool) void {
    highlightHoveredCell(context, tilemapDocument);

    if (rl.isMouseButtonDown(.mouse_button_left)) {
        const gridPosition = getMouseGridPositionSafe(context, tilemapDocument);
        if (gridPosition == null) return;
        select.onUse(context, tilemapDocument.getTilemap(), gridPosition.?);
    } else if (select.pendingSelection) |selectionType| {
        switch (selectionType) {
            .select => tilemapDocument.startGenericAction(Action.Select, context.allocator),
            .add => tilemapDocument.startGenericAction(Action.SelectAdd, context.allocator),
            .subtract => tilemapDocument.startGenericAction(Action.SelectSubtract, context.allocator),
            .floatingMove => tilemapDocument.startGenericAction(Action.CreateFloatingSelection, context.allocator),
            .mergeFloating => tilemapDocument.startGenericAction(Action.MergeFloatingSelection, context.allocator),
        }
        select.onUseEnd(context, tilemapDocument);
        switch (selectionType) {
            .select => tilemapDocument.endGenericAction(Action.Select, context.allocator),
            .add => tilemapDocument.endGenericAction(Action.SelectAdd, context.allocator),
            .subtract => tilemapDocument.endGenericAction(Action.SelectSubtract, context.allocator),
            .floatingMove => tilemapDocument.endGenericAction(Action.CreateFloatingSelection, context.allocator),
            .mergeFloating => tilemapDocument.endGenericAction(Action.MergeFloatingSelection, context.allocator),
        }
    } else if (rl.isKeyDown(.key_left_control)) {
        if (rl.isKeyPressed(.key_c)) {
            select.copy(context, tilemapDocument);
        } else if (rl.isKeyPressed(.key_v)) {
            select.paste(context);
        }
    } else if (rl.isKeyPressed(.key_delete)) {
        select.delete(context, tilemapDocument);
    }
}

fn highlightHoveredCell(context: *Context, tilemapDocument: *TilemapDocument) void {
    const gridPosition = getMouseGridPositionSafe(context, tilemapDocument);

    if (gridPosition == null) return;

    const tileSizeScaled = tilemapDocument.getTileSize() * context.scaleV;
    const x, const y = gridPosition.? * tileSizeScaled;
    const w, const h = tileSizeScaled;

    rl.beginMode2D(context.camera);
    rl.drawRectangleLines(x, y, w, h, rl.Color.yellow);
    rl.endMode2D();
}

fn selectTileSourceMenu(
    context: *Context,
    tilemapDocument: *TilemapDocument,
    brush: *BrushTool,
) !void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 1024, .h = 800 });
    _ = z.begin("Select Tile Source", .{ .popen = &brush.isSelectingTileSource, .flags = .{ .no_scrollbar = true } });

    const texture = context.textures.getPtr(brush.tileset).?;
    const spacing = 4;
    const tileWidth = tilemapDocument.getTileSize()[0];
    const totalTileWidth = tileWidth + spacing;
    const gridWidth: usize = @intCast(@divFloor(texture.width, totalTileWidth));
    const mousePos: @Vector(2, f32) = z.getMousePos();
    const scrollPos: @Vector(2, f32) = .{ z.getScrollX(), z.getScrollY() };
    const mouseWindowPos: @Vector(2, f32) = mousePos + scrollPos;
    const scaledWidth = tileWidth * context.scale;
    //const fScaledWidth: f32 = @floatFromInt(scaledWidth);
    //const fScaledSize: @Vector(2, f32) = .{ fScaledWidth, fScaledWidth };

    if (rl.isMouseButtonDown(.mouse_button_middle)) {
        const delta = rl.getMouseDelta();
        z.setScrollX(scrollPos[0] - delta.x);
        z.setScrollY(scrollPos[1] - delta.y);
    }

    for (0..gridWidth) |y| {
        for (0..gridWidth) |x| {
            const gridPosition: Vector = @intCast(@Vector(2, usize){ x, y });
            const sourceRect = TileSource.getSourceRectEx(gridPosition, tilemapDocument.getTileSize());

            _ = z.selectable(" ", .{
                .selected = brush.selectedSourceTiles.isSelected(gridPosition),
                .w = @floatFromInt(scaledWidth),
                .h = @floatFromInt(scaledWidth),
                .flags = .{ .allow_overlap = true },
            });
            const zmin: @Vector(2, f32) = z.getWindowContentRegionMin();
            const min: @Vector(2, i32) = @intFromFloat(zmin);
            const scaledSize: Vector = @splat(scaledWidth + 8);
            const cursorPos = min + gridPosition * scaledSize;
            const cursorEnd = cursorPos + scaledSize;
            const fCursorPos: @Vector(2, f32) = @floatFromInt(cursorPos);
            const fCursorEnd: @Vector(2, f32) = @floatFromInt(cursorEnd);
            z.setCursorPos(fCursorPos);
            c.rlImGuiImageRect(@ptrCast(texture), scaledWidth, scaledWidth, @bitCast(sourceRect));

            const isMouseWithinCursor = @reduce(.And, mouseWindowPos >= fCursorPos) and @reduce(.And, mouseWindowPos <= fCursorEnd);

            if (rl.isMouseButtonPressed(.mouse_button_left) and isMouseWithinCursor) {
                if (rl.isKeyDown(.key_left_shift)) {
                    brush.selectedSourceTiles.togglePoint(context.allocator, gridPosition);
                } else {
                    TileSource.set(&brush.source, context.allocator, &TileSource{
                        .tileset = brush.tileset,
                        .gridPosition = gridPosition,
                    });
                    brush.isSelectingTileSource = false;
                }
            }
            z.sameLine(.{});
        }
        z.newLine();
    }

    if (rl.isKeyDown(.key_enter)) brush.isSelectingTileSource = false;

    z.end();
}

fn historyMenu(_: *Context, tilemapDocument: *TilemapDocument) void {
    const history = tilemapDocument.getHistory();
    const items = history.actions.items;
    const nextActionIndex = history.nextActionIndex;

    for (items[0..nextActionIndex]) |item| {
        switch (item) {
            inline else => |action| z.text(@TypeOf(action).label, .{}),
        }
    }
}

fn moveCameraToEntity(context: *Context, entity: SceneEntity) void {
    context.camera.target.x = @floatFromInt(-entity.position[0]);
    context.camera.target.y = @floatFromInt(-entity.position[1]);
}

fn moveCameraToGridPosition(context: *Context, gridPosition: Vector) void {
    const centerOfTile = gridPositionToCenterOfTile(context, gridPosition);
    context.camera.target.x = @floatFromInt(centerOfTile[0]);
    context.camera.target.y = @floatFromInt(centerOfTile[1]);
}

fn resetCamera(context: *Context) void {
    context.camera.target.x = 0;
    context.camera.target.y = 0;
    context.camera.zoom = 1;
}
