const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const z = @import("zgui");
const lib = @import("root").lib;
const Context = lib.Context;
const Editor = lib.Editor;
const SceneDocument = lib.documents.SceneDocument;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityType = lib.documents.scene.SceneEntityType;
const TilemapDocument = lib.documents.TilemapDocument;
const Vector = lib.Vector;

pub const tileSize = Vector{ 16, 16 };

pub fn getEntityRect(entity: SceneEntity) rl.Rectangle {
    const entityPosition: @Vector(2, f32) = @floatFromInt(entity.position);
    const scaleVx, const scaleVy = switch (entity.type) {
        inline .exit, .entrance => |e| e.scale.?,
        else => .{ 1, 1 },
    };
    var size = SceneDocument.getSizeFromEntityType(entity.type);
    size.x *= scaleVx;
    size.y *= scaleVy;
    var rect = rl.Rectangle.init(entityPosition[0], entityPosition[1], size.x, size.y);
    rect.x -= rect.width / 2;
    rect.y -= rect.height / 2;

    return rect;
}

pub fn getEntityRectScaled(
    context: *Context,
    entity: SceneEntity,
) rl.Rectangle {
    var rect = getEntityRect(entity);
    const scale: f32 = @floatFromInt(context.scale);
    rect.width *= scale;
    rect.height *= scale;
    rect.x *= scale;
    rect.y *= scale;

    return rect;
}

pub fn getMouseGridPositionSafe(context: *Context, tilemapDocument: *TilemapDocument) ?Vector {
    const gridPosition = getMouseGridPosition(context);
    if (tilemapDocument.isOutOfBounds(gridPosition)) return null;
    return gridPosition;
}

pub fn getMousePosition(context: *Context) Vector {
    const mp = rl.getMousePosition();
    const mtrx = rl.getCameraMatrix2D(context.camera);
    const inv = mtrx.invert();
    const tr = mp.transform(inv);
    const ftr = @Vector(2, f32){ tr.x, tr.y };
    const scale: @Vector(2, f32) = @floatFromInt(context.scaleV);

    const fp = ftr / scale;

    return @intFromFloat(fp);
}

pub fn getMouseSceneGridPosition(context: *Context) Vector {
    const mp = getMousePosition(context);
    const ftr: @Vector(2, f32) = @floatFromInt(mp);
    const fDivisor: @Vector(2, f32) = @floatFromInt(tileSize);

    const fp = (ftr + fDivisor / @Vector(2, f32){ -2, 2 }) / fDivisor;

    return @intFromFloat(fp);
}

pub fn getMouseGridPosition(context: *Context) Vector {
    return getMouseGridPositionWithSize(context, tileSize);
}

pub fn getMouseGridPositionWithSize(context: *Context, cellSize: Vector) Vector {
    const mp = getMousePosition(context);
    const ftr: @Vector(2, f32) = @floatFromInt(mp);
    const fDivisor: @Vector(2, f32) = @floatFromInt(cellSize);

    const fp = ftr / fDivisor;

    return @intFromFloat(fp);
}

pub fn gridPositionToEntityPosition(
    gridPosition: Vector,
    entityType: SceneEntityType,
) Vector {
    const fTileSize: @Vector(2, f32) = @floatFromInt(tileSize);
    const rlEntitySize = SceneDocument.getSizeFromEntityType(entityType);
    const entitySize = @Vector(2, f32){ rlEntitySize.x, rlEntitySize.y };
    const half = @Vector(2, f32){ 0.5, 0.5 };
    return @intFromFloat(fTileSize * @as(@Vector(2, f32), @floatFromInt(gridPosition)) - fTileSize * half + entitySize * half);
}

pub fn gridPositionToCenterOfTile(gridPosition: Vector) Vector {
    const fTileSize: @Vector(2, f32) = @floatFromInt(tileSize);
    const half = @Vector(2, f32){ 0.5, 0.5 };
    return @intFromFloat(fTileSize * @as(@Vector(2, f32), @floatFromInt(gridPosition)) + fTileSize * half);
}

pub fn isMousePositionInsideEntityRect(
    context: *Context,
    entity: SceneEntity,
) bool {
    const point: @Vector(2, f32) = @floatFromInt(getMousePosition(context));
    const rlPoint = rl.Vector2.init(point[0], point[1]);
    const rect = getEntityRect(entity);

    return rl.checkCollisionPointRec(rlPoint, rect);
}

pub fn capitalize(allocator: Allocator, s: []const u8) []const u8 {
    return std.fmt.allocPrint(allocator, "{c}{s}", .{ std.ascii.toUpper(s[0]), s[1..] }) catch unreachable;
}

pub fn activeDocumentLabel(context: *Context, editor: *Editor) void {
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

pub fn cameraControls(context: *Context) void {
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

pub fn moveCameraToEntity(context: *Context, entity: SceneEntity) void {
    context.camera.target.x = @floatFromInt(-entity.position[0]);
    context.camera.target.y = @floatFromInt(-entity.position[1]);
}

pub fn moveCameraToGridPosition(context: *Context, gridPosition: Vector) void {
    const centerOfTile = gridPositionToCenterOfTile(context, gridPosition);
    context.camera.target.x = @floatFromInt(centerOfTile[0]);
    context.camera.target.y = @floatFromInt(centerOfTile[1]);
}

pub fn resetCamera(context: *Context) void {
    context.camera.target.x = 0;
    context.camera.target.y = 0;
    context.camera.zoom = 1;
}

pub fn scaleInput(scale: *@Vector(2, f32)) void {
    _ = z.inputFloat2("Scale", .{ .v = scale });
}

pub fn isOutOfBounds(gridPosition: Vector, gridSize: Vector) bool {
    return gridPosition[0] < 0 or gridPosition[1] < 0 or gridPosition[0] >= gridSize[0] or gridPosition[1] >= gridSize[1];
}

pub fn highlightHoveredCell(context: *Context, cellSize: Vector, gridSize: Vector) void {
    const gridPosition = getMouseGridPositionWithSize(context, cellSize);

    if (isOutOfBounds(gridPosition, gridSize)) return;

    const cellSizeScaled = cellSize * context.scaleV;
    const x, const y = gridPosition * cellSizeScaled;
    const w, const h = cellSizeScaled;

    rl.beginMode2D(context.camera);
    rl.drawRectangleLines(x, y, w, h, rl.Color.white);
    rl.endMode2D();
}
