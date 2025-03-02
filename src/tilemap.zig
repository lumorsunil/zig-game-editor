const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const Vector = @import("vector.zig").Vector;
const VectorInt = @import("vector.zig").VectorInt;
const UUID = @import("uuid.zig").UUIDSerializable;

pub const Grid = struct {
    size: Vector,

    pub fn init(size: Vector) Grid {
        return Grid{
            .size = size,
        };
    }

    pub fn width(self: *const Grid) VectorInt {
        return self.size[0];
    }

    pub fn height(self: *const Grid) VectorInt {
        return self.size[1];
    }

    pub fn getIndex(self: *const Grid, x: usize, y: usize) usize {
        return x + y * @as(usize, @intCast(self.width()));
    }

    pub fn getIndexV(self: *const Grid, gridPosition: Vector) usize {
        return self.getIndex(@intCast(gridPosition[0]), @intCast(gridPosition[1]));
    }

    pub fn isOutOfBounds(self: *const Grid, gridPosition: Vector) bool {
        return gridPosition[0] < 0 or gridPosition[1] < 0 or gridPosition[0] >= self.size[0] or gridPosition[1] >= self.size[1];
    }
};

pub const TilemapLayer = struct {
    id: UUID,
    name: [:0]u8,
    grid: Grid,
    tiles: ArrayList(Tile),

    pub const MAX_LAYER_NAME_SIZE = 32;

    pub fn init(allocator: Allocator, name: [:0]const u8, size: Vector) TilemapLayer {
        var layer = TilemapLayer{
            .id = UUID.init(),
            .name = allocator.allocSentinel(u8, MAX_LAYER_NAME_SIZE, 0) catch unreachable,
            .grid = Grid.init(size),
            .tiles = initTiles(allocator, size),
        };

        layer.setName(name);

        return layer;
    }

    fn initTiles(allocator: Allocator, size: Vector) ArrayList(Tile) {
        const len: usize = @intCast(size[0] * size[1]);
        var arrayList = ArrayList(Tile).initCapacity(allocator, len) catch unreachable;
        arrayList.appendNTimes(allocator, Tile{}, len) catch unreachable;
        return arrayList;
    }

    pub fn deinit(self: *TilemapLayer, allocator: Allocator) void {
        for (self.tiles.items) |tile| {
            if (tile.source) |source| {
                allocator.free(source.tileset);
            }
        }
        self.tiles.deinit(allocator);
        allocator.free(self.name);
    }

    pub fn clone(self: *const TilemapLayer, allocator: Allocator) TilemapLayer {
        var tilemapLayer = self.*;

        tilemapLayer.name = allocator.dupeZ(u8, self.name) catch unreachable;
        tilemapLayer.tiles = self.tiles.clone(allocator) catch unreachable;

        for (tilemapLayer.tiles.items) |*tile| {
            tile.* = tile.clone(allocator);
        }

        return tilemapLayer;
    }

    pub fn getTileByIndex(self: *TilemapLayer, i: usize) *Tile {
        return &self.tiles.items[i];
    }

    pub fn getTileByV(self: *TilemapLayer, gridPosition: Vector) *Tile {
        return &self.tiles.items[self.grid.getIndexV(gridPosition)];
    }

    pub fn getTileByXY(self: *TilemapLayer, x: usize, y: usize) *Tile {
        return &self.tiles.items[self.grid.getIndex(x, y)];
    }

    pub fn getNameBuffer(self: *TilemapLayer) [:0]u8 {
        return @ptrCast(self.name.ptr[0..MAX_LAYER_NAME_SIZE]);
    }

    pub fn setName(
        self: *TilemapLayer,
        newName: []const u8,
    ) void {
        self.name = std.fmt.bufPrintZ(self.getNameBuffer(), "{s}", .{newName}) catch unreachable;
    }
};

pub const Tilemap = struct {
    grid: Grid,
    tileSize: Vector,
    layers: ArrayList(*TilemapLayer),
    activeLayer: UUID,

    pub fn init(allocator: Allocator, size: Vector, tileSize: Vector) Tilemap {
        var tilemap = Tilemap{
            .grid = Grid.init(size),
            .tileSize = tileSize,
            .layers = ArrayList(*TilemapLayer).initBuffer(&.{}),
            .activeLayer = undefined,
        };

        const layer = tilemap.addLayer(allocator, "Background");
        tilemap.activeLayer = layer.id;

        return tilemap;
    }

    pub fn deinit(self: *Tilemap, allocator: Allocator) void {
        for (self.layers.items) |layer| {
            layer.deinit(allocator);
            allocator.destroy(layer);
        }
    }

    pub fn clone(self: *const Tilemap, allocator: Allocator) Tilemap {
        var tilemap = self.*;

        tilemap.layers = self.layers.clone(allocator) catch unreachable;

        for (tilemap.layers.items) |*item| {
            const original = item.*;
            item.* = allocator.create(TilemapLayer) catch unreachable;
            item.*.* = original.clone(allocator);
        }

        return tilemap;
    }

    pub fn width(self: *const Tilemap) VectorInt {
        return self.grid.width();
    }

    pub fn height(self: *const Tilemap) VectorInt {
        return self.grid.height();
    }

    pub fn getActiveLayer(self: *Tilemap) *TilemapLayer {
        return self.getLayerById(self.activeLayer).?;
    }

    fn getLayerIndexById(self: *Tilemap, layerId: UUID) ?usize {
        for (0..self.layers.items.len) |i| {
            if (self.layers.items[i].id.uuid == layerId.uuid) return i;
        }

        return null;
    }

    pub fn getLayerById(self: *Tilemap, layerId: UUID) ?*TilemapLayer {
        const i = self.getLayerIndexById(layerId) orelse return null;
        return self.layers.items[i];
    }

    pub fn getTileByIndex(self: *Tilemap, layerId: UUID, i: usize) ?*Tile {
        const layer = self.getLayerById(layerId) orelse return null;
        return &layer.tiles.items[i];
    }

    pub fn getTileV(self: *Tilemap, layerId: UUID, gridPosition: Vector) ?*Tile {
        const layer = self.getLayerById(layerId) orelse return null;
        return &layer.tiles.items[self.getIndexV(gridPosition)];
    }

    pub fn addLayer(self: *Tilemap, allocator: Allocator, name: [:0]const u8) *TilemapLayer {
        const tilemap = allocator.create(TilemapLayer) catch unreachable;
        tilemap.* = TilemapLayer.init(allocator, name, self.grid.size);
        self.layers.append(allocator, tilemap) catch unreachable;
        return tilemap;
    }

    pub fn removeLayer(self: *Tilemap, allocator: Allocator, layerId: UUID) void {
        const i = self.getLayerIndexById(layerId) orelse return;
        const tilemap = self.layers.swapRemove(i);
        tilemap.deinit(allocator);
        allocator.destroy(tilemap);
    }

    pub fn isOutOfBounds(self: *const Tilemap, gridPosition: Vector) bool {
        return self.grid.isOutOfBounds(gridPosition);
    }
};

pub const Tile = struct {
    source: ?TileSource = null,
    isSolid: bool = false,

    pub fn clone(self: *const Tile, allocator: Allocator) Tile {
        var tile = self.*;

        tile.source = TileSource.clone(&self.source, allocator);

        return tile;
    }
};

pub const TileSource = struct {
    tileset: []const u8,
    gridPosition: Vector,

    pub fn clone(self: *const ?TileSource, allocator: Allocator) ?TileSource {
        var tileSource = self.*;

        if (tileSource) |*source| {
            source.tileset = allocator.dupe(u8, source.tileset) catch unreachable;
        }

        return tileSource;
    }

    pub fn set(dest: *?TileSource, allocator: Allocator, source: *const ?TileSource) void {
        if (dest.*) |s| {
            allocator.free(s.tileset);
        }

        dest.* = source.*;

        if (source.*) |s| {
            dest.*.?.tileset = allocator.dupe(u8, s.tileset) catch unreachable;
        }
    }

    pub fn getSourceRect(self: *const TileSource, tileSize: Vector) rl.Rectangle {
        return getSourceRectEx(self.gridPosition, tileSize);
    }

    pub fn getSourceRectEx(gridPosition: Vector, tileSize: Vector) rl.Rectangle {
        const paddingOffset: Vector = .{ 2, 2 };
        const paddingSpacing: Vector = .{ 4, 4 };
        const totalSize = paddingSpacing + tileSize;
        const sourcePosition: @Vector(2, f32) = @floatFromInt(paddingOffset + totalSize * gridPosition);
        const sourceSize: @Vector(2, f32) = @floatFromInt(tileSize);
        return rl.Rectangle.init(sourcePosition[0], sourcePosition[1], sourceSize[0], sourceSize[1]);
    }
};
