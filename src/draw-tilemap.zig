const std = @import("std");
const rl = @import("raylib");
const Vector = @import("vector.zig").Vector;
const VectorInt = @import("vector.zig").VectorInt;
const Context = @import("context.zig").Context;
const Tilemap = @import("tilemap.zig").Tilemap;
const TilemapLayer = @import("tilemap.zig").TilemapLayer;

pub fn drawTilemap(context: *const Context, position: Vector) void {
    const tilemap = context.fileData.tilemap;

    for (tilemap.layers.items) |layer| {
        drawLayer(context, layer, tilemap.tileSize, position, false);
    }
}

pub fn drawLayer(
    context: *const Context,
    layer: *TilemapLayer,
    tileSize: Vector,
    offset: Vector,
    overrideFocus: bool,
) void {
    for (0..@intCast(layer.grid.size[0])) |x| {
        for (0..@intCast(layer.grid.size[1])) |y| {
            const tile = layer.getTileByXY(x, y);

            if (tile.source == null) continue;
            const tileSource = tile.source.?;

            const ux: VectorInt = @intCast(x);
            const uy: VectorInt = @intCast(y);
            const texture = context.textures.get(tileSource.tileset).?;
            const origin = rl.Vector2.init(0, 0);
            const gridPosition: Vector = .{ ux, uy };
            const scaleV: Vector = .{ context.scale, context.scale };

            const source = tileSource.getSourceRect(tileSize);

            const destPosition = offset + gridPosition * tileSize * scaleV;
            const destSize = tileSize * scaleV;
            const fDestPositionX: f32 = @floatFromInt(destPosition[0]);
            const fDestPositionY: f32 = @floatFromInt(destPosition[1]);
            const fDestWidth: f32 = @floatFromInt(destSize[0]);
            const fDestHeight: f32 = @floatFromInt(destSize[1]);
            const dest = rl.Rectangle.init(fDestPositionX, fDestPositionY, fDestWidth, fDestHeight);

            const color = if (!overrideFocus and context.focusOnActiveLayer and context.fileData.tilemap.activeLayer.uuid != layer.id.uuid) rl.Color.init(255, 255, 255, 50) else rl.Color.white;

            rl.drawTexturePro(texture, source, dest, origin, 0, color);
        }
    }
}
