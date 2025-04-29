const std = @import("std");
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
const SceneEntity = lib.documents.SceneEntity;
const SceneEntityType = lib.documents.SceneEntityType;
const SceneEntityExit = lib.documents.SceneEntityExit;
const SceneEntityEntrance = lib.documents.SceneEntityEntrance;

pub fn layout(context: *Context) !void {
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));
    context.camera.offset.x = screenW / 2;
    context.camera.offset.y = screenH / 2;

    rl.clearBackground(context.backgroundColor);
    rl.beginMode2D(context.camera);

    switch (context.mode) {
        .scene => drawSceneDocument(context),
        .tilemap => drawTilemapDocument(context),
    }

    rl.endMode2D();

    c.rlImGuiBegin();

    try switch (context.mode) {
        .scene => sceneDocumentMenu(context),
        .tilemap => tilemapDocumentMenu(context),
    };

    c.rlImGuiEnd();

    if (!z.io.getWantCaptureMouse()) {
        try switch (context.mode) {
            .scene => sceneDocumentHandleInput(context),
            .tilemap => tilemapDocumentHandleInput(context),
        };
    }
}

fn sceneDocumentMenu(context: *Context) !void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 200, .h = 800 });
    _ = z.begin("Scene Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
    } });
    defer z.end();

    activeDocumentLabel(context);

    if (z.button("Reset Camera", .{})) {
        resetCamera(context);
    }
    z.text("{d:0.0},{d:0.0}", .{ context.camera.target.x, context.camera.target.y });

    if (z.button("Tilemap Editor", .{})) {
        context.mode = .tilemap;
        return;
    }
    if (z.button("New", .{})) {
        try context.newFileScene();
    }
    if (z.button("Save", .{})) {
        try context.saveFileScene();
    }
    if (z.button("Open", .{})) {
        try context.openFileScene();
    }
    if (z.button("Set Tilemap", .{})) {
        try context.openFileTilemap();
        if (context.currentTilemapFileName) |cfn| {
            for (context.sceneDocument.scene.entities.items) |entity| {
                if (entity.type == .tilemap) {
                    entity.type.tilemap.setSceneFileName(context.allocator, cfn);
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

    if (context.sceneDocument.selectedEntities.items.len > 0) {
        const selectedEntity = context.sceneDocument.selectedEntities.items[0];

        // Entity details menu
        switch (selectedEntity.type) {
            .exit => |*exit| {
                if (z.button("Set Target", .{})) {
                    const maybeFileName = try nfd.openFileDialog(Context.sceneFileFilter, context.defaultPath);

                    if (maybeFileName) |fileName| {
                        defer nfd.freePath(fileName);
                        exit.setSceneFileName(context.allocator, fileName);
                    }
                }

                if (exit.sceneFileName) |scf| {
                    const baseName = std.fs.path.basename(scf);
                    var it = std.mem.splitScalar(u8, baseName, '.');
                    const name = it.next().?;
                    z.text("{s}", .{name});
                    if (z.button("Open Target Scene", .{})) {
                        // const targetEntranceKey = getTargetEntranceKey(exit);
                        try context.openFileSceneEx(scf);
                        // const targetEntrance = getEntranceByKey(context, targetEntranceKey);
                        // moveCameraToEntity(context, targetEntrance.*);
                        resetCamera(context);
                        return;
                    }
                }
            },
            .entrance => |*entrance| {
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
                const texture = context.sceneDocument.getTextureFromEntityType(tag);
                const source = context.sceneDocument.getSourceRectFromEntityType(tag);
                const size = context.sceneDocument.getSizeFromEntityType(tag);
                const scaledSize = Vector{
                    @intFromFloat(size.x),
                    @intFromFloat(size.y),
                } * context.scaleV;
                c.rlImGuiImageRect(@ptrCast(texture), scaledSize[0], scaledSize[1], @bitCast(source));
                if (z.beginDragDropSource(.{ .source_allow_null_id = true })) {
                    context.sceneDocument.dragPayload = tag;
                    z.endDragDropSource();
                }
            },
            .exit => {
                const pos: @Vector(2, f32) = z.getCursorPos();
                const size: @Vector(2, f32) = @floatFromInt(context.tilemapDocument.tilemap.tileSize * context.scaleV);

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
                    context.sceneDocument.dragPayload = .{ .exit = SceneEntityExit.init() };
                    z.endDragDropSource();
                }
            },
            .entrance => {
                const pos: @Vector(2, f32) = z.getCursorPos();
                const size: @Vector(2, f32) = @floatFromInt(context.tilemapDocument.tilemap.tileSize * context.scaleV);

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
                    context.sceneDocument.dragPayload = .{ .entrance = SceneEntityEntrance.init(context.allocator) };
                    z.endDragDropSource();
                }
            },
            .tilemap => {},
        }
    }
}

fn tilemapDocumentMenu(context: *Context) !void {
    if (context.currentTool != null and context.currentTool.?.impl == .brush and context.currentTool.?.impl.brush.isSelectingTileSource) {
        const brush = &context.currentTool.?.impl.brush;
        try selectTileSourceMenu(context, brush);
    } else {
        if (context.isDemoWindowEnabled) {
            z.showDemoWindow(&context.isDemoWindowOpen);
        }

        try mainMenu(context);
    }
}

fn drawTilemapDocument(context: *Context) void {
    const size = context.tilemapDocument.tilemap.grid.size * context.tilemapDocument.tilemap.tileSize * context.scaleV;
    const thickness = 2;
    const rect = rl.Rectangle.init(
        -thickness,
        -thickness,
        @floatFromInt(size[0] + thickness * 2),
        @floatFromInt(size[1] + thickness * 2),
    );
    rl.drawRectangleLinesEx(rect, thickness / context.camera.zoom, rl.Color.black);
    drawTilemap(context, .{ 0, 0 }, false);

    if (context.currentTool) |currentTool| {
        switch (currentTool.impl) {
            .select => |*select| select.draw(context),
            else => {},
        }
    }
}

fn drawSceneDocument(context: *Context) void {
    for (context.sceneDocument.scene.entities.items) |entity| {
        context.sceneDocument.drawEntity(context, entity.*);
    }

    for (context.sceneDocument.selectedEntities.items) |selectedEntity| {
        const rect = getEntityRectScaled(context, selectedEntity.*);
        rl.drawRectangleLinesEx(rect, 1 / context.camera.zoom, rl.Color.white);
    }

    if (context.sceneDocument.dragPayload) |payload| {
        const position = if (rl.isKeyDown(.key_left_shift)) getMousePosition(context) else gridPositionToEntityPosition(context, getMouseSceneGridPosition(context), payload);
        context.sceneDocument.drawEntity(context, SceneEntity.init(context.allocator, position, payload));
    }
}

fn sceneDocumentHandleInput(context: *Context) void {
    cameraControls(context);
    sceneDocumentHandleInputCreateEntity(context);
    sceneDocumentHandleInputSelectEntity(context);
    sceneDocumentHandleInputMoveEntity(context);
    sceneDocumentHandleInputDeleteEntity(context);

    if (rl.isKeyPressed(.key_f5)) {
        context.play();
    }
}

fn sceneDocumentHandleInputCreateEntity(context: *Context) void {
    if (context.sceneDocument.dragPayload) |payload| {
        if (rl.isMouseButtonReleased(.mouse_button_left)) {
            const entity = context.allocator.create(SceneEntity) catch unreachable;
            const position = if (rl.isKeyDown(.key_left_shift)) getMousePosition(context) else gridPositionToEntityPosition(context, getMouseSceneGridPosition(context), payload);
            entity.* = SceneEntity.init(context.allocator, position, payload);
            context.sceneDocument.scene.entities.append(context.allocator, entity) catch unreachable;
            context.sceneDocument.dragPayload = null;
        }
    }
}

fn sceneDocumentHandleInputSelectEntity(context: *Context) void {
    if (context.sceneDocument.dragPayload != null) return;

    if (rl.isMouseButtonPressed(.mouse_button_left)) {
        for (context.sceneDocument.scene.entities.items) |entity| {
            if (entity.type == .tilemap) continue;

            if (isMousePositionInsideEntityRect(context, entity.*)) {
                context.sceneDocument.selectEntity(entity, context.allocator);
                context.sceneDocument.dragStartPoint = getMousePosition(context);
                break;
            }
        }
    }
}

fn sceneDocumentHandleInputMoveEntity(context: *Context) void {
    if (context.sceneDocument.dragPayload != null) return;
    if (context.sceneDocument.selectedEntities.items.len == 0) return;

    if (context.sceneDocument.dragStartPoint) |dragStartPoint| {
        if (context.sceneDocument.isDragging) {
            if (rl.isMouseButtonDown(.mouse_button_left)) {
                const entity = context.sceneDocument.selectedEntities.items[0];
                const position = if (rl.isKeyDown(.key_left_shift)) getMousePosition(context) else gridPositionToEntityPosition(context, getMouseSceneGridPosition(context), entity.type);
                entity.position = position;
            } else {
                context.sceneDocument.isDragging = false;
                context.sceneDocument.dragStartPoint = null;
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
                context.sceneDocument.isDragging = true;
            }
        }
    }
}

fn sceneDocumentHandleInputDeleteEntity(context: *Context) void {
    if (context.sceneDocument.selectedEntities.items.len == 0) return;

    const selectedEntity = context.sceneDocument.selectedEntities.items[0];
    if (rl.isKeyPressed(.key_delete)) {
        context.sceneDocument.deleteEntity(selectedEntity);
    }
}

fn tilemapDocumentHandleInput(context: *Context) !void {
    cameraControls(context);

    if (context.currentTool) |tool| {
        switch (tool.impl) {
            .brush => |*brush| handleBrush(context, brush),
            .select => |*select| handleSelect(context, select),
        }
    }

    try handleShortcuts(context);
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

fn handleShortcuts(context: *Context) !void {
    if (rl.isKeyDown(.key_left_control)) {
        if (rl.isKeyDown(.key_s)) return try context.saveFileTilemap();
        if (rl.isKeyDown(.key_o)) return try context.openFileTilemap();
        if (rl.isKeyDown(.key_n)) return try context.newFileTilemap();
        if (rl.isKeyPressed(.key_z)) {
            if (rl.isKeyDown(.key_left_shift)) {
                return context.redo();
            } else {
                return context.undo();
            }
        }
        if (rl.isKeyPressed(.key_y)) return context.redo();
        if (rl.isKeyPressed(.key_f)) {
            context.focusOnActiveLayer = !context.focusOnActiveLayer;
            return;
        }
    } else if (rl.isKeyPressed(.key_n)) {
        context.setTool(.brush);
    } else if (rl.isKeyPressed(.key_r)) {
        context.setTool(.select);
    }
}

fn mainMenu(context: *Context) !void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 200, .h = 800 });
    _ = z.begin("Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
    } });
    defer z.end();

    activeDocumentLabel(context);

    if (z.button("Scene Editor", .{})) {
        context.mode = .scene;
        return;
    }
    z.separatorText("File");
    try fileMenu(context);
    z.separatorText("Edit");
    try editMenu(context);
    z.separatorText("Tilemap");
    try tilemapMenu(context);
    z.separatorText("Tools");
    try toolPickerMenu(context);
    if (context.currentTool != null) {
        z.separatorText("Tool details");
        try toolDetailsMenu(context);
    }
    z.separatorText("Tilesets");
    z.separatorText("Layers");
    try layersMenu(context);
    z.separatorText("History");
    try historyMenu(context);
}

fn activeDocumentLabel(context: *Context) void {
    if (context.currentTilemapFileName) |cfn| {
        const baseName = std.fs.path.basename(cfn);
        var it = std.mem.splitScalar(u8, baseName, '.');
        const name = it.next().?;
        z.text("Tilemap: {s}", .{name});
        if (z.isItemHovered(.{ .delay_short = true })) {
            if (z.beginTooltip()) {
                z.text("{s}", .{cfn});
            }
            z.endTooltip();
        }
    }
    if (context.currentSceneFileName) |cfn| {
        const baseName = std.fs.path.basename(cfn);
        var it = std.mem.splitScalar(u8, baseName, '.');
        const name = it.next().?;
        z.text("Scene: {s}", .{name});
        if (z.isItemHovered(.{ .delay_short = true })) {
            if (z.beginTooltip()) {
                z.text("{s}", .{cfn});
            }
            z.endTooltip();
        }
    }
}

fn fileMenu(context: *Context) !void {
    if (z.button("New", .{})) {
        try context.newFileTilemap();
    }
    z.sameLine(.{});
    if (z.button("Open", .{})) {
        try context.openFileTilemap();
    }
    z.sameLine(.{});
    if (z.button("Save", .{})) {
        try context.saveFileTilemap();
    }
    if (z.button("Squash History", .{})) {
        context.squashHistory();
    }
}

fn editMenu(context: *Context) !void {
    z.beginDisabled(.{ .disabled = !context.canUndo() });
    if (z.button("Undo", .{})) {
        context.undo();
    }
    z.endDisabled();
    z.sameLine(.{});
    z.beginDisabled(.{ .disabled = !context.canRedo() });
    if (z.button("Redo", .{})) {
        context.redo();
    }
    z.endDisabled();
}

fn tilemapMenu(context: *Context) !void {
    if (z.inputInt2("Size", .{
        .v = &context.inputTilemapSize,
        .flags = .{
            .enter_returns_true = true,
        },
    })) {
        context.startGenericAction(Action.ResizeTilemap);
        context.tilemapDocument.tilemap.resize(context.tilemapArena.allocator(), context.inputTilemapSize);
        context.endGenericAction(Action.ResizeTilemap);
    }
}

fn toolPickerMenu(context: *Context) !void {
    for (context.tools, 0..) |*tool, i| {
        if (i > 0) z.sameLine(.{});
        if (z.button(tool.name, .{})) {
            context.currentTool = tool;
        }
    }
}

fn toolDetailsMenu(context: *Context) !void {
    const tool = context.currentTool.?;

    switch (tool.impl) {
        .brush => |*brush| try brushToolDetailsMenu(context, brush),
        .select => |*select| try selectToolDetailsMenu(context, select),
    }
}

fn brushToolDetailsMenu(context: *Context, brush: *BrushTool) !void {
    if (z.button("Set Tile", .{})) {
        brush.isSelectingTileSource = true;
    }
    if (brush.source) |source| {
        const texture = context.textures.getPtr(source.tileset).?;
        const sourceRect = source.getSourceRect(context.tilemapDocument.tilemap.tileSize);
        c.rlImGuiImageRect(@ptrCast(texture), 64, 64, @bitCast(sourceRect));
    }
}

fn selectToolDetailsMenu(context: *Context, select: *SelectTool) !void {
    _ = select; // autofix
    _ = context; // autofix
}

fn layersMenu(context: *Context) !void {
    const buttonSize = 24;
    _ = z.checkbox("Focus", .{ .v = &context.focusOnActiveLayer });
    if (z.button("+", .{ .w = buttonSize, .h = buttonSize })) {
        context.startGenericAction(Action.AddLayer);
        _ = context.tilemapDocument.tilemap.addLayer(context.tilemapArena.allocator(), "Layer");
        context.endGenericAction(Action.AddLayer);
    }

    for (context.tilemapDocument.tilemap.layers.items, 0..) |*layer_ptr, i| {
        const layer = layer_ptr.*;
        const isActiveLayer = layer.id.uuid == context.tilemapDocument.tilemap.activeLayer.uuid;

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
            if (z.inputText("", .{
                .buf = layer.getNameBuffer(),
                .flags = .{
                    .enter_returns_true = true,
                    .callback_edit = true,
                },
                .callback = layerNameInputCallback,
                .user_data = context,
            })) {
                context.endGenericAction(Action.RenameLayer);
            }
            z.popId();
        }

        if (z.isItemClicked(.left)) {
            context.tilemapDocument.tilemap.activeLayer = layer.id;
        }

        // Remove layer button
        if (i > 0) {
            z.sameLine(.{ .offset_from_start_x = z.getWindowWidth() - buttonSize });
            z.pushIntId(@intCast(i));
            if (z.button("-", .{ .w = buttonSize, .h = buttonSize })) {
                context.startGenericAction(Action.RemoveLayer);
                context.tilemapDocument.tilemap.removeLayer(context.tilemapArena.allocator(), layer.id);
                context.endGenericAction(Action.RemoveLayer);
            }
            z.popId();
        }
    }
}

fn layerNameInputCallback(data: *z.InputTextCallbackData) i32 {
    const context: *Context = @ptrCast(@alignCast(data.user_data.?));
    const layer = context.tilemapDocument.tilemap.getActiveLayer();

    context.startGenericAction(Action.RenameLayer);
    layer.setName(data.buf[0..@intCast(data.buf_text_len)]);

    return 0;
}

fn getMouseGridPositionSafe(context: *Context) ?Vector {
    const gridPosition = getMouseGridPosition(context);
    if (context.tilemapDocument.tilemap.isOutOfBounds(gridPosition)) return null;
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
    const tilemap = context.tilemapDocument.tilemap;
    const fDivisor: @Vector(2, f32) = @floatFromInt(tilemap.tileSize);

    const fp = (ftr + fDivisor / @Vector(2, f32){ -2, 2 }) / fDivisor;

    return @intFromFloat(fp);
}

fn getMouseGridPosition(context: *Context) Vector {
    const mp = getMousePosition(context);
    const ftr: @Vector(2, f32) = @floatFromInt(mp);
    const tilemap = context.tilemapDocument.tilemap;
    const fDivisor: @Vector(2, f32) = @floatFromInt(tilemap.tileSize);

    const fp = ftr / fDivisor;

    return @intFromFloat(fp);
}

fn gridPositionToEntityPosition(context: *Context, gridPosition: Vector, entityType: SceneEntityType) Vector {
    const tileSize: @Vector(2, f32) = @floatFromInt(context.tilemapDocument.tilemap.tileSize);
    const rlEntitySize = context.sceneDocument.getSizeFromEntityType(entityType);
    const entitySize = @Vector(2, f32){ rlEntitySize.x, rlEntitySize.y };
    const half = @Vector(2, f32){ 0.5, 0.5 };
    return @intFromFloat(tileSize * @as(@Vector(2, f32), @floatFromInt(gridPosition)) - tileSize * half + entitySize * half);
}

fn gridPositionToCenterOfTile(context: *Context, gridPosition: Vector) Vector {
    const tileSize: @Vector(2, f32) = @floatFromInt(context.tilemapDocument.tilemap.tileSize);
    const half = @Vector(2, f32){ 0.5, 0.5 };
    return @intFromFloat(tileSize * @as(@Vector(2, f32), @floatFromInt(gridPosition)) + tileSize * half);
}

fn getEntityRect(context: *Context, entity: SceneEntity) rl.Rectangle {
    const entityPosition: @Vector(2, f32) = @floatFromInt(entity.position);
    const size = context.sceneDocument.getSizeFromEntityType(entity.type);
    var rect = rl.Rectangle.init(entityPosition[0], entityPosition[1], size.x, size.y);
    rect.x -= rect.width / 2;
    rect.y -= rect.height / 2;

    return rect;
}

fn getEntityRectScaled(context: *Context, entity: SceneEntity) rl.Rectangle {
    var rect = getEntityRect(context, entity);
    const scale: f32 = @floatFromInt(context.scale);
    rect.width *= scale;
    rect.height *= scale;
    rect.x *= scale;
    rect.y *= scale;

    return rect;
}

fn isMousePositionInsideEntityRect(context: *Context, entity: SceneEntity) bool {
    const point: @Vector(2, f32) = @floatFromInt(getMousePosition(context));
    const rlPoint = rl.Vector2.init(point[0], point[1]);
    const rect = getEntityRect(context, entity);

    return rl.checkCollisionPointRec(rlPoint, rect);
}

fn handleBrush(context: *Context, brush: *BrushTool) void {
    highlightHoveredCell(context);

    if (rl.isMouseButtonDown(.mouse_button_left)) {
        context.startGenericAction(Action.BrushPaint);

        const gridPosition = getMouseGridPositionSafe(context);

        if (gridPosition == null) return;

        brush.onUse(context, &context.tilemapDocument.tilemap, gridPosition.?);
    } else {
        brush.onUseEnd();
        context.endGenericAction(Action.BrushPaint);
    }

    if (rl.isMouseButtonDown(.mouse_button_right)) {
        context.startGenericAction(Action.BrushDelete);

        const gridPosition = getMouseGridPositionSafe(context);

        if (gridPosition == null) return;

        brush.onAlternateUse(context, &context.tilemapDocument.tilemap, gridPosition.?);
    } else {
        context.endGenericAction(Action.BrushDelete);
    }
}

fn handleSelect(context: *Context, select: *SelectTool) void {
    highlightHoveredCell(context);

    if (rl.isMouseButtonDown(.mouse_button_left)) {
        const gridPosition = getMouseGridPositionSafe(context);
        if (gridPosition == null) return;
        select.onUse(context, &context.tilemapDocument.tilemap, gridPosition.?);
    } else if (select.pendingSelection) |selectionType| {
        switch (selectionType) {
            .select => context.startGenericAction(Action.Select),
            .add => context.startGenericAction(Action.SelectAdd),
            .subtract => context.startGenericAction(Action.SelectSubtract),
            .floatingMove => context.startGenericAction(Action.CreateFloatingSelection),
            .mergeFloating => context.startGenericAction(Action.MergeFloatingSelection),
        }
        select.onUseEnd(context);
        switch (selectionType) {
            .select => context.endGenericAction(Action.Select),
            .add => context.endGenericAction(Action.SelectAdd),
            .subtract => context.endGenericAction(Action.SelectSubtract),
            .floatingMove => context.endGenericAction(Action.CreateFloatingSelection),
            .mergeFloating => context.endGenericAction(Action.MergeFloatingSelection),
        }
    } else if (rl.isKeyDown(.key_left_control)) {
        if (rl.isKeyPressed(.key_c)) {
            select.copy(context);
        } else if (rl.isKeyPressed(.key_v)) {
            select.paste(context);
        }
    } else if (rl.isKeyPressed(.key_delete)) {
        select.delete(context);
    }
}

fn highlightHoveredCell(context: *Context) void {
    const gridPosition = getMouseGridPositionSafe(context);

    if (gridPosition == null) return;

    const tileSizeScaled = context.tilemapDocument.tilemap.tileSize * context.scaleV;
    const x, const y = gridPosition.? * tileSizeScaled;
    const w, const h = tileSizeScaled;

    rl.beginMode2D(context.camera);
    rl.drawRectangleLines(x, y, w, h, rl.Color.yellow);
    rl.endMode2D();
}

fn selectTileSourceMenu(context: *Context, brush: *BrushTool) !void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 1024, .h = 800 });
    _ = z.begin("Select Tile Source", .{ .popen = &context.currentTool.?.impl.brush.isSelectingTileSource, .flags = .{ .no_scrollbar = true } });

    const texture = context.textures.getPtr(brush.tileset).?;
    const spacing = 4;
    const tileWidth = context.tilemapDocument.tilemap.tileSize[0];
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
            const sourceRect = TileSource.getSourceRectEx(gridPosition, context.tilemapDocument.tilemap.tileSize);

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

fn historyMenu(context: *Context) !void {
    const items = context.tilemapDocument.history.actions.items;
    const nextActionIndex = context.tilemapDocument.history.nextActionIndex;

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
