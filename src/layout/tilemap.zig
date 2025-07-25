const std = @import("std");
const z = @import("zgui");
const c = @import("c");
const rl = @import("raylib");
const lib = @import("lib");
const LayoutGeneric = lib.LayoutGeneric;
const Context = lib.Context;
const Editor = lib.Editor;
const TilemapDocument = lib.documents.TilemapDocument;
const TileSource = lib.TileSource;
const Action = lib.Action;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const Vector = lib.Vector;
const utils = lib.layouts.utils;
const drawTilemap = lib.drawTilemap;
const config = lib.config;

pub const LayoutTilemap = LayoutGeneric(.tilemap, draw, menu, handleInput);

fn draw(context: *Context, document: *TilemapDocument) void {
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
    drawTilemap(context, document, .{ 0, 0 }, context.scale, false);

    if (document.getCurrentTool()) |currentTool| {
        switch (currentTool.impl) {
            .select => |*select| select.draw(context, document),
            else => {},
        }
    }
}

fn menu(
    context: *Context,
    editor: *Editor,
    tilemapDocument: *TilemapDocument,
) void {
    if (tilemapDocument.isCurrentTool(.brush) and tilemapDocument.getCurrentTool().?.impl.brush.isSelectingTileSource) {
        try selectTileSourceMenu(context, tilemapDocument, &tilemapDocument.getCurrentTool().?.impl.brush);
    } else {
        mainMenu(context, editor, tilemapDocument);
    }
}

fn mainMenu(context: *Context, editor: *Editor, tilemapDocument: *TilemapDocument) void {
    const screenSize: @Vector(2, f32) = @floatFromInt(Vector{ rl.getScreenWidth(), rl.getScreenHeight() });
    z.setNextWindowPos(.{ .x = 0, .y = config.editorContentOffset });
    z.setNextWindowSize(.{ .w = 200, .h = screenSize[1] - config.editorContentOffset });
    _ = z.begin("Menu", .{ .flags = .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
        .no_bring_to_front_on_focus = true,
    } });
    defer z.end();

    utils.activeDocumentLabel(context, editor);

    z.separatorText("File");
    fileMenu(context, editor, tilemapDocument);
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

fn fileMenu(context: *Context, editor: *Editor, tilemapDocument: *TilemapDocument) void {
    if (z.button("Save", .{})) {
        save(context, editor, tilemapDocument);
    }
    if (z.button("Squash History", .{})) {
        tilemapDocument.squashHistory(context.allocator);
    }
}

fn save(context: *Context, editor: *Editor, tilemapDocument: *TilemapDocument) void {
    // TODO: Remove when history is more optimized
    tilemapDocument.squashHistory(context.allocator);
    context.saveEditorFile(editor);
    context.updateThumbnailForCurrentDocument = true;
    context.sceneMap.generate(context) catch |err| {
        context.showError("Could not generate scene map: {}", .{err});
    };
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
            // TODO: Fix this later
            .enter_returns_true = false,
        },
    })) {
        tilemapDocument.startGenericAction(Action.ResizeTilemap, context.allocator);
        tilemapDocument.document.persistentData.tilemap.resize(context.allocator, inputTilemapSize.*);
        tilemapDocument.endGenericAction(Action.ResizeTilemap, context.allocator);
    }
    _ = z.checkbox("Auto Expand", .{ .v = tilemapDocument.getAutoExpand() });
}

fn toolPickerMenu(context: *Context, tilemapDocument: *TilemapDocument) void {
    for (tilemapDocument.getTools(context), 0..) |*tool, i| {
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

fn brushToolDetailsMenu(
    context: *Context,
    tilemapDocument: *TilemapDocument,
    brush: *BrushTool,
) void {
    initializeBrushTileset(context, brush);
    z.text("Tileset:", .{});
    _ = utils.assetInput(.texture, context, &brush.tileset);
    if (brush.tileset != null and z.button("Set Tile", .{})) {
        brush.isSelectingTileSource = true;
    }
    if (brush.source) |source| {
        const texture = context.requestTextureById(source.tileset) catch return orelse return;
        const sourceRect = source.getSourceRect(tilemapDocument.getTileSize());
        c.rlImGuiImageRect(@ptrCast(texture), 64, 64, @bitCast(sourceRect));
    }
}

fn initializeBrushTileset(
    context: *Context,
    brush: *BrushTool,
) void {
    if (brush.tileset == null) {
        const p = context.currentProject orelse return;
        brush.tileset = p.options.defaultTileset orelse return;
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

        // Layer name
        if (i == 0 or !isActiveLayer) {
            z.text("{s}", .{layer.name});
        } else {
            z.pushPtrId(layer);
            _ = z.inputText("", .{ .buf = layer.name.buffer });
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
    layer.name.setFmt("{s}", .{data.buf[0..@intCast(data.buf_text_len)]});

    return 0;
}

fn handleBrush(context: *Context, tilemapDocument: *TilemapDocument, brush: *BrushTool) void {
    const isAutoExpandEnabled = tilemapDocument.getAutoExpand().*;
    utils.highlightHoveredCell(
        context,
        tilemapDocument.getTileSize(),
        tilemapDocument.getGridSize(),
        isAutoExpandEnabled,
    );

    if (rl.isMouseButtonDown(.left)) {
        tilemapDocument.startGenericAction(Action.BrushPaint, context.allocator);

        const gridPosition = if (isAutoExpandEnabled) utils.getMouseGridPosition(context) else utils.getMouseGridPositionSafe(context, tilemapDocument);

        if (gridPosition == null) return;

        brush.onUse(context, tilemapDocument, gridPosition.?);
    } else {
        brush.onUseEnd();
        tilemapDocument.endGenericAction(Action.BrushPaint, context.allocator);
    }

    if (rl.isMouseButtonDown(.right)) {
        tilemapDocument.startGenericAction(Action.BrushDelete, context.allocator);

        const gridPosition = utils.getMouseGridPositionSafe(context, tilemapDocument);

        if (gridPosition == null) return;

        brush.onAlternateUse(tilemapDocument.getTilemap(), gridPosition.?);
    } else {
        tilemapDocument.endGenericAction(Action.BrushDelete, context.allocator);
    }
}

fn handleSelect(context: *Context, tilemapDocument: *TilemapDocument, select: *SelectTool) void {
    const isAutoExpandEnabled = tilemapDocument.getAutoExpand().*;
    utils.highlightHoveredCell(
        context,
        tilemapDocument.getTileSize(),
        tilemapDocument.getGridSize(),
        isAutoExpandEnabled,
    );

    if (rl.isMouseButtonDown(.left)) {
        const gridPosition = utils.getMouseGridPositionSafe(context, tilemapDocument);
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
    } else if (rl.isKeyDown(.left_control)) {
        if (rl.isKeyPressed(.c)) {
            select.copy(context, tilemapDocument);
        } else if (rl.isKeyPressed(.v)) {
            select.paste(context);
        }
    } else if (rl.isKeyPressed(.delete)) {
        select.delete(context, tilemapDocument);
    }
}

fn selectTileSourceMenu(
    context: *Context,
    tilemapDocument: *TilemapDocument,
    brush: *BrushTool,
) !void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 1024, .h = 800 });
    _ = z.begin("Select Tile Source", .{ .popen = &brush.isSelectingTileSource, .flags = .{ .no_scrollbar = true } });

    const texture = context.requestTextureById(brush.tileset orelse unreachable) catch return orelse return;
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

    if (rl.isMouseButtonDown(.middle)) {
        const delta = rl.getMouseDelta();
        z.setScrollX(scrollPos[0] - delta.x);
        z.setScrollY(scrollPos[1] - delta.y);
    }

    for (0..gridWidth) |y| {
        for (0..gridWidth) |x| {
            const gridPosition: Vector = @intCast(@Vector(2, usize){ x, y });
            const sourceRect = TileSource.getSourceRectEx(gridPosition, tilemapDocument.getTileSize());

            var idBuffer: [16:0]u8 = undefined;
            const id = std.fmt.bufPrintZ(&idBuffer, "{d:0.0},{d:0.0}", .{ x, y }) catch unreachable;

            z.pushStrId(id);
            _ = z.selectable(" ", .{
                .selected = brush.selectedSourceTiles.isSelected(gridPosition),
                .w = @floatFromInt(scaledWidth),
                .h = @floatFromInt(scaledWidth),
                .flags = .{ .allow_overlap = true },
            });
            z.popId();
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

            if (rl.isMouseButtonPressed(.left) and isMouseWithinCursor) {
                if (rl.isKeyDown(.left_shift)) {
                    brush.selectedSourceTiles.togglePoint(context.allocator, gridPosition);
                } else {
                    TileSource.set(&brush.source, &TileSource{
                        .tileset = brush.tileset orelse unreachable,
                        .gridPosition = gridPosition,
                    });
                    brush.isSelectingTileSource = false;
                }
            }
            z.sameLine(.{});
        }
        z.newLine();
    }

    if (rl.isKeyDown(.enter)) brush.isSelectingTileSource = false;

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

fn handleInput(context: *Context, editor: *Editor, tilemapDocument: *TilemapDocument) void {
    utils.cameraControls(&context.camera);

    if (tilemapDocument.getCurrentTool()) |tool| {
        switch (tool.impl) {
            .brush => |*brush| handleBrush(context, tilemapDocument, brush),
            .select => |*select| handleSelect(context, tilemapDocument, select),
        }
    }

    handleShortcuts(context, editor, tilemapDocument);
}

fn handleShortcuts(context: *Context, editor: *Editor, tilemapDocument: *TilemapDocument) void {
    if (rl.isKeyDown(.left_control)) {
        if (rl.isKeyDown(.s)) return save(context, editor, tilemapDocument);
        if (rl.isKeyPressed(.z)) {
            if (rl.isKeyDown(.left_shift)) {
                return tilemapDocument.redo(context.allocator);
            } else {
                return tilemapDocument.undo(context.allocator);
            }
        }
        if (rl.isKeyPressed(.y)) {
            return tilemapDocument.redo(context.allocator);
        }
    } else if (rl.isKeyPressed(.n)) {
        tilemapDocument.setToolByType(.brush, context);
    } else if (rl.isKeyPressed(.r)) {
        tilemapDocument.setToolByType(.select, context);
    }
}
