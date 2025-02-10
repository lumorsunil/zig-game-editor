const rl = @import("raylib");
const Vector = @import("vector.zig").Vector;
const VectorInt = @import("vector.zig").VectorInt;
const Context = @import("context.zig").Context;

pub fn drawTilemap(position: Vector, context: *const Context) void {
    const tilemap = context.fileData.tilemap;

    for (0..@intCast(tilemap.size[0])) |x| {
        for (0..@intCast(tilemap.size[1])) |y| {
            const i = tilemap.getIndex(x, y);
            const tile = tilemap.tiles.items[i];

            if (tile.source == null) continue;
            const tileSource = tile.source.?;

            const ux: VectorInt = @intCast(x);
            const uy: VectorInt = @intCast(y);
            const texture = context.textures.get(tileSource.tileset).?;
            const origin = rl.Vector2.init(0, 0);
            const tileSize = tilemap.tileSize;
            const gridPosition: Vector = .{ ux, uy };
            const scaleV: Vector = .{ context.scale, context.scale };

            const source = tileSource.getSourceRect(tileSize);

            const destPosition = position + gridPosition * tileSize * scaleV;
            const destSize = tileSize * scaleV;
            const fDestPositionX: f32 = @floatFromInt(destPosition[0]);
            const fDestPositionY: f32 = @floatFromInt(destPosition[1]);
            const fDestWidth: f32 = @floatFromInt(destSize[0]);
            const fDestHeight: f32 = @floatFromInt(destSize[1]);
            const dest = rl.Rectangle.init(fDestPositionX, fDestPositionY, fDestWidth, fDestHeight);

            rl.drawTexturePro(texture, source, dest, origin, 0, rl.Color.white);
        }
    }
}
