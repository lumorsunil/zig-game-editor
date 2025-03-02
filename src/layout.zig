const std = @import("std");
const z = @import("zgui");
const c = @import("c");
const rl = @import("raylib");
const nfd = @import("nfd");
const Context = @import("context.zig").Context;
const BrushTool = @import("tools/brush.zig").BrushTool;
const drawTilemap = @import("draw-tilemap.zig").drawTilemap;
const Vector = @import("vector.zig").Vector;
const TileSource = @import("file-data.zig").TileSource;
const TilemapLayer = @import("file-data.zig").TilemapLayer;

pub fn layout(context: *Context) !void {
    const screenSize: Vector = .{ rl.getScreenWidth(), rl.getScreenHeight() };
    const screenW, const screenH = @as(@Vector(2, f32), @floatFromInt(screenSize));
    context.camera.offset.x = screenW / 2;
    context.camera.offset.y = screenH / 2;

    rl.clearBackground(context.backgroundColor);
    rl.beginMode2D(context.camera);

    const size = context.fileData.tilemap.grid.size * context.fileData.tilemap.tileSize * context.scaleV;
    const rect = rl.Rectangle.init(0, 0, @floatFromInt(size[0]), @floatFromInt(size[1]));
    rl.drawRectangleLinesEx(rect, 4, rl.Color.black);
    drawTilemap(.{ 0, 0 }, context);

    rl.endMode2D();

    c.rlImGuiBegin();

    if (context.currentTool != null and context.currentTool.?.impl == .brush and context.currentTool.?.impl.brush.isSelectingTileSource) {
        const brush = &context.currentTool.?.impl.brush;
        try selectTileSourceMenu(context, brush);
    } else {
        if (context.isDemoWindowEnabled) {
            z.showDemoWindow(&context.isDemoWindowOpen);
        }

        try mainMenu(context);
    }

    c.rlImGuiEnd();

    if (!z.io.getWantCaptureMouse()) {
        try handleInput(context);
    }
}

fn handleInput(context: *Context) !void {
    if (rl.isMouseButtonDown(.mouse_button_middle)) {
        const delta = rl.getMouseDelta();
        context.camera.target.x -= delta.x / context.camera.zoom;
        context.camera.target.y -= delta.y / context.camera.zoom;
    }

    if (rl.isKeyDown(.key_left_control)) {
        context.camera.zoom *= 1 + rl.getMouseWheelMove() * 0.1;
        context.camera.zoom = std.math.clamp(context.camera.zoom, 0.1, 10);
    }

    if (context.currentTool) |tool| {
        switch (tool.impl) {
            .brush => |*brush| handleBrush(context, brush),
        }
    }

    try handleShortcuts(context);
}

fn handleShortcuts(context: *Context) !void {
    if (rl.isKeyDown(.key_left_control)) {
        if (rl.isKeyDown(.key_s)) return try context.saveFile();
        if (rl.isKeyDown(.key_o)) return try context.openFile();
        if (rl.isKeyDown(.key_n)) return try context.newFile();
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

    if (context.currentFileName) |cfn| {
        const baseName = std.fs.path.basename(cfn);
        var it = std.mem.splitScalar(u8, baseName, '.');
        const name = it.next().?;
        z.text("{s}", .{name});
        if (z.isItemHovered(.{ .delay_short = true })) {
            if (z.beginTooltip()) {
                z.text("{s}", .{cfn});
            }
            z.endTooltip();
        }
    }

    z.separatorText("File");
    try fileMenu(context);
    z.separatorText("Tools");
    try toolPickerMenu(context);
    if (context.currentTool != null) {
        z.separatorText("Tool details");
        try toolDetailsMenu(context);
    }
    z.separatorText("Tilesets");
    z.separatorText("Layers");
    try layersMenu(context);
}

fn fileMenu(context: *Context) !void {
    if (z.button("Open", .{})) {
        try context.openFile();
    }
    z.sameLine(.{});
    if (z.button("Save", .{})) {
        try context.saveFile();
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
    }
}

fn brushToolDetailsMenu(context: *Context, brush: *BrushTool) !void {
    if (z.button("Set Tile", .{})) {
        brush.isSelectingTileSource = true;
    }
    if (brush.source) |source| {
        const texture = context.textures.getPtr(source.tileset).?;
        const sourceRect = source.getSourceRect(context.fileData.tilemap.tileSize);
        c.rlImGuiImageRect(@ptrCast(texture), 64, 64, @bitCast(sourceRect));
    }
}

fn layersMenu(context: *Context) !void {
    const buttonSize = 24;
    if (z.button("+", .{ .w = buttonSize, .h = buttonSize })) {
        _ = context.fileData.tilemap.addLayer(context.tilemapArena.allocator(), "Layer");
    }

    for (context.fileData.tilemap.layers.items, 0..) |*layer_ptr, i| {
        const layer = layer_ptr.*;
        const isActiveLayer = layer.id.uuid == context.fileData.tilemap.activeLayer.uuid;

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
            _ = z.inputText("", .{
                .buf = layer.getNameBuffer(),
                .flags = .{
                    .callback_edit = true,
                },
                .callback = layerNameInputCallback,
                .user_data = context,
            });
            z.popId();
        }

        if (z.isItemClicked(.left)) {
            context.fileData.tilemap.activeLayer = layer.id;
        }

        // Remove layer button
        if (i > 0) {
            z.sameLine(.{ .offset_from_start_x = z.getWindowWidth() - buttonSize });
            z.pushIntId(@intCast(i));
            if (z.button("-", .{ .w = buttonSize, .h = buttonSize })) {
                context.fileData.tilemap.removeLayer(context.tilemapArena.allocator(), layer.id);
            }
            z.popId();
        }
    }
}

fn layerNameInputCallback(data: *z.InputTextCallbackData) i32 {
    const context: *Context = @ptrCast(@alignCast(data.user_data.?));
    const layer = context.fileData.tilemap.getActiveLayer();

    std.log.debug("data.buf[0..{d}]({d}): {s}", .{ data.buf_text_len, data.buf_size, data.buf[0..@intCast(data.buf_text_len)] });
    std.log.debug("{d}", .{data.buf[0..@intCast(data.buf_size)]});

    layer.setName(data.buf[0..@intCast(data.buf_text_len)]);

    return 0;
}

fn getMouseGridPosition(context: *Context) ?Vector {
    const mp = rl.getMousePosition();
    const mtrx = rl.getCameraMatrix2D(context.camera);
    const inv = mtrx.invert();
    const tr = mp.transform(inv);
    const ftr = @Vector(2, f32){ tr.x, tr.y };
    const tilemap = context.fileData.tilemap;

    const divisor = tilemap.tileSize * context.scaleV;
    const fDivisor: @Vector(2, f32) = .{
        @floatFromInt(divisor[0]),
        @floatFromInt(divisor[1]),
    };

    const fp = ftr / fDivisor;
    const p = Vector{
        @intFromFloat(fp[0]),
        @intFromFloat(fp[1]),
    };

    if (tilemap.isOutOfBounds(p)) return null;
    return p;
}

fn handleBrush(context: *Context, brush: *BrushTool) void {
    if (rl.isMouseButtonDown(.mouse_button_left)) {
        const gridPosition = getMouseGridPosition(context);

        if (gridPosition == null) return;

        brush.onUse(context, &context.fileData.tilemap, gridPosition.?);
    } else if (rl.isMouseButtonDown(.mouse_button_right)) {
        const gridPosition = getMouseGridPosition(context);

        if (gridPosition == null) return;

        brush.onAlternateUse(context, &context.fileData.tilemap, gridPosition.?);
    }
}

fn selectTileSourceMenu(context: *Context, brush: *BrushTool) !void {
    z.setNextWindowPos(.{ .x = 0, .y = 0 });
    z.setNextWindowSize(.{ .w = 1024, .h = 800 });
    _ = z.begin("Select Tile Source", .{ .popen = &context.currentTool.?.impl.brush.isSelectingTileSource, .flags = .{ .no_scrollbar = true } });

    const texture = context.textures.getPtr(brush.tileset).?;
    const spacing = 4;
    const tileWidth = context.fileData.tilemap.tileSize[0];
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
            const sourceRect = TileSource.getSourceRectEx(gridPosition, context.fileData.tilemap.tileSize);

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
