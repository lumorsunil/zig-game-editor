const lib = @import("lib");
const Context = lib.Context;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;
const MapCell = lib.MapCell;

const c = @import("c");
const rl = @import("raylib");
const z = @import("zgui");

const utils = @import("utils.zig");

pub fn sceneMapUI(context: *Context) void {
    if (context.isSceneMapWindowOpen) {
        z.setNextWindowSize(.{ .cond = .first_use_ever, .w = 800, .h = 600 });
        z.setNextWindowPos(.{ .cond = .first_use_ever, .x = 100, .y = 100 });
        z.setNextWindowBgAlpha(.{ .alpha = 1 });
        _ = z.begin("Scene Map", .{ .popen = &context.isSceneMapWindowOpen, .flags = .{
            .no_scrollbar = true,
            .no_scroll_with_mouse = true,
            .no_move = false,
        } });
        defer z.end();

        if (context.sceneMap.renderTexture) |*renderTexture| {
            resizeWindowRenderTextureIfNeeded(context);

            rl.beginTextureMode(context.sceneMapWindowRenderTexture);
            rl.clearBackground(rl.Color.gray);
            context.sceneMapCamera.target.y *= -1;
            rl.beginMode2D(context.sceneMapCamera);
            rl.drawTexture(renderTexture.texture, 0, 0, rl.Color.white);
            rl.endMode2D();
            context.sceneMapCamera.target.y *= -1;
            rl.endTextureMode();

            const mapPosition = @Vector(2, f32){
                z.getCursorPosX() + z.getWindowPos()[0],
                z.getCursorPosY() + z.getWindowPos()[1],
            };
            c.rlImGuiImage(@ptrCast(&context.sceneMapWindowRenderTexture.texture));

            if (z.isItemHovered(.{ .delay_none = true })) {
                const sceneId, const highlightedCell = getHighlightedCell(context, mapPosition) orelse return;
                highlightCell(context, mapPosition, highlightedCell);
                if (rl.isMouseButtonPressed(.left)) {
                    context.openEditorByIdAtEndOfFrame(sceneId);
                    context.isSceneMapWindowOpen = false;
                }
            }
        }
    }
}

fn resizeWindowRenderTextureIfNeeded(context: *Context) void {
    const fWindowSize = z.getWindowSize();
    const windowSize = Vector{
        @intFromFloat(fWindowSize[0]),
        @intFromFloat(fWindowSize[1]),
    };
    const textureSize = Vector{
        context.sceneMapWindowRenderTexture.texture.width,
        context.sceneMapWindowRenderTexture.texture.height,
    };
    if (windowSize[0] != textureSize[0] or windowSize[1] != textureSize[1]) {
        rl.unloadRenderTexture(context.sceneMapWindowRenderTexture);
        context.sceneMapWindowRenderTexture = rl.loadRenderTexture(
            windowSize[0],
            windowSize[1],
        ) catch unreachable;
        context.sceneMapCamera.offset.x = fWindowSize[0] / 2;
        context.sceneMapCamera.offset.y = fWindowSize[1] / 2;
    }
}

fn getHighlightedCell(context: *Context, mapPosition: @Vector(2, f32)) ?struct { UUID, MapCell } {
    for (context.sceneMap.mapCells.map.values(), 0..) |cell, i| {
        const cellRect = getCellScreenRectangle(context, mapPosition, cell);

        if (rl.checkCollisionPointRec(rl.getMousePosition(), cellRect)) {
            return .{ context.sceneMap.mapCells.map.keys()[i], cell };
        }
    }

    return null;
}

fn highlightCell(context: *Context, mapPosition: @Vector(2, f32), cell: MapCell) void {
    const cellRect = getCellScreenRectangle(context, mapPosition, cell);

    z.getWindowDrawList().addRect(.{
        .pmin = .{ cellRect.x, cellRect.y },
        .pmax = .{ cellRect.x + cellRect.width, cellRect.y + cellRect.height },
        .col = z.colorConvertFloat3ToU32(.{ 1, 1, 1 }),
        .rounding = 0,
        .flags = .{},
        .thickness = 1.0,
    });
}

fn getCellScreenRectangle(context: *Context, offset: @Vector(2, f32), cell: MapCell) rl.Rectangle {
    const sceneMapMin, const sceneMapSize = context.sceneMap.calculateMapMinAndSize();
    const fSceneMapMin: @Vector(2, f32) = @floatFromInt(sceneMapMin);
    const fSceneMapSize: @Vector(2, f32) = @floatFromInt(sceneMapSize);
    const mtrx = context.sceneMapCamera.getMatrix();
    const zoom: @Vector(2, f32) = @splat(context.sceneMapCamera.zoom);
    const cellMin = cell.position - cell.size / @Vector(2, f32){ 2, 2 } - fSceneMapMin;
    const min = rl.Vector2.init(
        cellMin[0],
        cellMin[1],
    ).transform(mtrx).add(
        rl.Vector2.init(offset[0], offset[1]),
    ).subtract(rl.Vector2.init(0, (fSceneMapSize * zoom)[1]));
    const cellSize = cell.size * zoom;

    return rl.Rectangle.init(min.x, min.y, cellSize[0], cellSize[1]);
}

pub fn sceneMapUIHandleInput(context: *Context) void {
    if (context.isSceneMapWindowOpen) {
        utils.cameraControls(&context.sceneMapCamera);
    }

    if (!z.io.getWantCaptureKeyboard()) {
        if (rl.isKeyPressed(.m)) {
            context.isSceneMapWindowOpen = !context.isSceneMapWindowOpen;
        }
    }
}
