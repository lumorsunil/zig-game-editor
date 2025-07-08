const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const z = @import("zgui");
const c = @import("c");
const lib = @import("root").lib;
const config = @import("root").config;
const Context = lib.Context;
const Editor = lib.Editor;
const SceneDocument = lib.documents.SceneDocument;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityType = lib.documents.scene.SceneEntityType;
const TilemapDocument = lib.documents.TilemapDocument;
const DocumentTag = lib.DocumentTag;
const UUID = lib.UUIDSerializable;
const Node = lib.Node;
const Vector = lib.Vector;

const tileSize = config.tileSize;
const defaultEntitySize = rl.Vector2.init(@floatFromInt(tileSize[0]), @floatFromInt(tileSize[1]));

pub fn getEntityRect(context: *Context, entity: SceneEntity) rl.Rectangle {
    const entityPosition: @Vector(2, f32) = @floatFromInt(entity.position);
    const scaleVx, const scaleVy = switch (entity.type) {
        inline .exit, .entrance => |e| e.scale.?,
        else => .{ 1, 1 },
    };
    var size = SceneDocument.getSizeFromEntityType(context, entity.type) catch defaultEntitySize orelse defaultEntitySize;
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
    var rect = getEntityRect(context, entity);
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

pub fn getMousePosition(context: *Context, camera: rl.Camera2D) Vector {
    const mp = rl.getMousePosition();
    const mtrx = rl.getCameraMatrix2D(camera);
    const inv = mtrx.invert();
    const tr = mp.transform(inv);
    const ftr = @Vector(2, f32){ tr.x, tr.y };
    const scale: @Vector(2, f32) = @floatFromInt(context.scaleV);

    const fp = ftr / scale;

    return @intFromFloat(fp);
}

pub fn getMouseSceneGridPosition(context: *Context) Vector {
    const mp = getMousePosition(context, context.camera);
    const ftr: @Vector(2, f32) = @floatFromInt(mp);
    const fDivisor: @Vector(2, f32) = @floatFromInt(tileSize);

    const fp = (ftr + fDivisor / @Vector(2, f32){ -2, 2 }) / fDivisor;

    return @intFromFloat(fp);
}

pub fn getMouseGridPosition(context: *Context) Vector {
    return getMouseGridPositionWithSize(context, tileSize);
}

pub fn getMouseGridPositionWithSize(context: *Context, cellSize: Vector) Vector {
    const mp = getMousePosition(context, context.camera);
    const ftr: @Vector(2, f32) = @floatFromInt(mp);
    const fDivisor: @Vector(2, f32) = @floatFromInt(cellSize);

    const fp = ftr / fDivisor;

    return @intFromFloat(fp);
}

pub fn gridPositionToEntityPosition(
    context: *Context,
    gridPosition: Vector,
    entityType: SceneEntityType,
) Vector {
    const fTileSize: @Vector(2, f32) = @floatFromInt(tileSize);
    const rlEntitySize = SceneDocument.getSizeFromEntityType(context, entityType) catch defaultEntitySize orelse defaultEntitySize;
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
    camera: rl.Camera2D,
    entity: SceneEntity,
) bool {
    const point: @Vector(2, f32) = @floatFromInt(getMousePosition(context, camera));
    const rlPoint = rl.Vector2.init(point[0], point[1]);
    const rect = getEntityRect(context, entity);

    return rl.checkCollisionPointRec(rlPoint, rect);
}

pub fn capitalize(allocator: Allocator, s: []const u8) []const u8 {
    return std.fmt.allocPrint(allocator, "{c}{s}", .{ std.ascii.toUpper(s[0]), s[1..] }) catch unreachable;
}

pub fn documentShortName(allocator: Allocator, filePath: []const u8) [:0]const u8 {
    const baseName = std.fs.path.basename(filePath);
    const name = std.mem.sliceTo(baseName, '.');
    return allocator.dupeZ(u8, name) catch unreachable;
}

pub fn activeDocumentLabel(context: *Context, editor: *Editor) void {
    const filePath = context.getFilePathById(editor.document.getId()) orelse "null";
    const baseName = std.fs.path.basename(filePath);
    var it = std.mem.splitScalar(u8, baseName, '.');
    const name = it.next().?;
    const typeLabel = capitalize(context.allocator, @tagName(editor.documentType));
    defer context.allocator.free(typeLabel);
    z.text("{s}: {s}", .{ typeLabel, name });
    if (z.isItemHovered(.{ .delay_short = true })) {
        if (z.beginTooltip()) {
            z.text("{s}", .{filePath});
        }
        z.endTooltip();
    }
}

pub fn cameraControls(camera: *rl.Camera2D) void {
    if (rl.isMouseButtonDown(.middle)) {
        const delta = rl.getMouseDelta();
        camera.target.x -= delta.x / camera.zoom;
        camera.target.y -= delta.y / camera.zoom;
    }

    if (rl.isKeyDown(.left_control)) {
        camera.zoom *= 1 + rl.getMouseWheelMove() * 0.1;
        camera.zoom = std.math.clamp(camera.zoom, 0.1, 10);
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

pub fn assetInput(
    comptime documentType: DocumentTag,
    context: *Context,
    currentId: ?UUID,
) ?UUID {
    const emptyLabel = "None";
    const currentFileName = if (currentId) |id| context.getFilePathById(id) else null;
    const shortLabel = if (currentFileName) |cfn| assetShortName(cfn) else emptyLabel;

    const inputPosMin = z.getCursorPos();
    drawAssetIcon(context, .{ .documentType = documentType });
    const inputPosMax = z.getCursorPos();
    const inputHeightHalf = (inputPosMax[1] - inputPosMin[1]) / 2;
    z.sameLine(.{ .spacing = 8 });
    const textHeightHalf = z.getTextLineHeight() / 2;
    z.setCursorPosY(z.getCursorPosY() + inputHeightHalf - textHeightHalf);
    z.text("{s}", .{shortLabel});

    if (currentFileName) |cfn| {
        if (z.isItemClicked(.left)) {
            const assetDirectory = context.allocator.dupeZ(u8, std.fs.path.dirname(cfn) orelse ".") catch unreachable;
            defer context.allocator.free(assetDirectory);
            context.setCurrentDirectory(assetDirectory);
        }

        if (z.isItemHovered(.{ .delay_short = true })) {
            if (z.beginTooltip()) {
                z.text("{s}", .{cfn});
            }
            z.endTooltip();
        }
    }

    // Input border
    const x = inputPosMin[0] + z.getWindowPos()[0] - 2;
    const y = inputPosMin[1] + z.getWindowPos()[1] - 2;
    const w = z.getWindowContentRegionMax()[0] - 4;
    const h = inputPosMax[1] - inputPosMin[1];
    z.getWindowDrawList().addRect(.{
        .pmin = .{ x, y },
        .pmax = .{ x + w, y + h },
        .col = @bitCast(c.ColorToInt(c.WHITE)),
        .rounding = 5.0,
        .flags = .round_corners_all,
        .thickness = 1.0,
    });

    if (z.beginDragDropTarget()) {
        defer z.endDragDropTarget();
        if (z.getDragDropPayload()) |payload| {
            const node: *Node = @as(**Node, @ptrCast(@alignCast(payload.data.?))).*;

            switch (node.*) {
                .directory => {},
                .file => |file| {
                    if (file.documentType == documentType) {
                        if (z.acceptDragDropPayload("asset", .{})) |_| {
                            return file.id;
                        }
                    }
                },
            }
        }
    }

    return null;
}

pub fn assetShortName(filePath: []const u8) []const u8 {
    return std.mem.sliceTo(std.fs.path.basename(filePath), '.');
}

pub const DrawAssetIconSource = union(enum) {
    node: Node,
    documentType: DocumentTag,
};

pub fn drawAssetIcon(context: *Context, source: DrawAssetIconSource) void {
    const iconsTexture = &(context.iconsTexture orelse return);
    const cellSize: Vector = .{ 32, 32 };
    const gridPosition: Vector = switch (source) {
        .node => |node| switch (node) {
            .file => |file| getAssetIconGridPosition(file.documentType),
            .directory => .{ 5, 1 },
        },
        .documentType => |documentType| getAssetIconGridPosition(documentType),
    };
    const srcRectMin = gridPosition * cellSize;
    const srcRect = c.Rectangle{
        .x = @floatFromInt(srcRectMin[0]),
        .y = @floatFromInt(srcRectMin[1]),
        .width = @floatFromInt(cellSize[0]),
        .height = @floatFromInt(cellSize[1]),
    };
    c.rlImGuiImageRect(@ptrCast(iconsTexture), cellSize[0], cellSize[1], srcRect);
}

fn getAssetIconGridPosition(documentType: DocumentTag) Vector {
    return switch (documentType) {
        .animation => .{ 0, 1 },
        .scene => .{ 1, 1 },
        .tilemap => .{ 2, 1 },
        .entityType => .{ 3, 1 },
        .texture => .{ 4, 1 },
    };
}
