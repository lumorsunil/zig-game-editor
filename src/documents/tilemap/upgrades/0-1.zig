const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const upgrade = lib.upgrade;

// Breaking change: Old version had tiles in a flat array, now it's a 2D-array.

const Document0 = @import("../versions/0.zig").Document0;
const Document1 = @import("../versions/1.zig").Document1;

pub const DocumentPrev = Document0;
pub const DocumentNext = Document1;

pub fn upgrader(
    allocator: Allocator,
    prev: DocumentPrev,
    container: upgrade.Container,
) DocumentNext {
    const upgradeContainer = container.add(LayerUpgrader);

    return DocumentNext{
        .version = 1,
        .id = prev.id,
        .tilemap = upgrade.upgradeValue(
            std.meta.FieldType(DocumentNext, .tilemap),
            allocator,
            prev.tilemap,
            upgradeContainer,
        ),
    };
}

const TilemapLayer0 = @import("../versions/0.zig").TilemapLayer0;
const TilemapLayer1 = @import("../versions/1.zig").TilemapLayer1;
const Tile1 = @import("../versions/1.zig").Tile1;

const LayerUpgrader = struct {
    pub fn upgradeLayer(
        allocator: Allocator,
        from: TilemapLayer0,
        _: upgrade.Container,
    ) TilemapLayer1 {
        defer allocator.free(from.tiles);

        const w, const h = @as(@Vector(2, usize), @intCast(from.grid.size));
        const tiles = allocator.alloc([]Tile1, h) catch unreachable;

        for (tiles, 0..) |*row, y| {
            row.* = allocator.alloc(Tile1, w) catch unreachable;

            for (0..w) |x| {
                const i = w * y + x;
                row.*[x] = from.tiles[i];
            }
        }

        return TilemapLayer1{
            .id = from.id,
            .name = from.name,
            .grid = from.grid,
            .tiles = tiles,
        };
    }
};
