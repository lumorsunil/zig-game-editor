const std = @import("std");
const rl = @import("raylib");
const lib = @import("lib");
const Context = lib.Context;
const TilemapDocument = lib.documents.TilemapDocument;
const Vector = lib.Vector;
const VectorInt = lib.VectorInt;
const Tilemap = lib.tilemap.Tilemap;
const TilemapLayer = lib.tilemap.TilemapLayer;

pub fn drawTilemap(
    context: *Context,
    tilemapDocument: *TilemapDocument,
    position: Vector,
    scale: VectorInt,
    overrideFocus: bool,
) void {
    const tilemap = tilemapDocument.getTilemap();
    for (tilemap.layers.items) |layer| {
        drawLayer(context, tilemapDocument, layer, tilemap.tileSize, position, scale, overrideFocus);
    }
}

pub fn drawLayer(
    context: *Context,
    tilemapDocument: *TilemapDocument,
    layer: *TilemapLayer,
    tileSize: Vector,
    offset: Vector,
    scale: VectorInt,
    overrideFocus: bool,
) void {
    for (0..@intCast(layer.grid.size[0])) |x| {
        for (0..@intCast(layer.grid.size[1])) |y| {
            const tile = layer.getTileByXY(x, y);

            if (tile.source == null) continue;
            const tileSource = tile.source.?;

            const ux: VectorInt = @intCast(x);
            const uy: VectorInt = @intCast(y);
            const texture = context.requestTextureById(tileSource.tileset) catch continue orelse continue;
            const origin = rl.Vector2.init(0, 0);
            const gridPosition: Vector = .{ ux, uy };
            const scaleV: Vector = .{ scale, scale };

            const spacing: i32 = @intCast(context.getTilesetPadding());
            const source = tileSource.getSourceRect(spacing, tileSize);

            const destPosition = offset + gridPosition * tileSize * scaleV;
            const destSize = tileSize * scaleV;
            const fDestPositionX: f32 = @floatFromInt(destPosition[0]);
            const fDestPositionY: f32 = @floatFromInt(destPosition[1]);
            const fDestWidth: f32 = @floatFromInt(destSize[0]);
            const fDestHeight: f32 = @floatFromInt(destSize[1]);
            const dest = rl.Rectangle.init(fDestPositionX, fDestPositionY, fDestWidth, fDestHeight);

            const color = if (!overrideFocus and tilemapDocument.getFocusOnActiveLayer() and tilemapDocument.document.persistentData.tilemap.activeLayer.uuid != layer.id.uuid) rl.Color.init(255, 255, 255, 50) else rl.Color.white;

            rl.drawTexturePro(texture.*, source, dest, origin, 0, color);
        }
    }
}
