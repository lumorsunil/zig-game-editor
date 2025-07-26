const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("lib");
const Vector = lib.Vector;
const VectorInt = lib.VectorInt;
const UUID = lib.UUIDSerializable;
const StringZ = lib.StringZ;
const json = lib.json;
const SelectGrid = lib.SelectGrid;

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
    name: StringZ,
    grid: Grid,
    tiles: ArrayList(ArrayList(Tile)),

    pub fn init(allocator: Allocator, name: [:0]const u8, size: Vector) TilemapLayer {
        return TilemapLayer{
            .id = .init(),
            .name = .init(allocator, name),
            .grid = .init(size),
            .tiles = initTiles(allocator, size),
        };
    }

    fn initTiles(allocator: Allocator, size: Vector) ArrayList(ArrayList(Tile)) {
        const usizeSize: @Vector(2, usize) = @intCast(size);
        var arrayList = ArrayList(ArrayList(Tile)).initCapacity(allocator, usizeSize[1]) catch unreachable;
        for (0..usizeSize[1]) |_| {
            var row = ArrayList(Tile).initCapacity(allocator, usizeSize[0]) catch unreachable;
            row.appendNTimesAssumeCapacity(.empty, usizeSize[0]);
            arrayList.appendAssumeCapacity(row);
        }
        return arrayList;
    }

    pub fn deinit(self: *TilemapLayer, allocator: Allocator) void {
        for (self.tiles.items) |*row| {
            row.deinit(allocator);
        }
        self.tiles.deinit(allocator);
        self.name.deinit(allocator);
    }

    pub fn clone(self: *const TilemapLayer, allocator: Allocator) TilemapLayer {
        var tilemapLayer = self.*;

        tilemapLayer.name = self.name.clone(allocator);
        tilemapLayer.tiles = self.tiles.clone(allocator) catch unreachable;

        for (tilemapLayer.tiles.items) |*row| {
            row.* = row.clone(allocator) catch unreachable;

            for (row.items) |*tile| {
                tile.* = tile.clone();
            }
        }

        return tilemapLayer;
    }

    pub fn jsonStringify(self: *const @This(), jw: anytype) !void {
        try json.writeObject(self.*, jw);
    }

    pub fn getTileByV(self: *TilemapLayer, gridPosition: Vector) *Tile {
        const usizeGp: @Vector(2, usize) = @intCast(gridPosition);
        return &self.tiles.items[usizeGp[1]].items[usizeGp[0]];
    }

    pub fn getTileByXY(self: *TilemapLayer, x: usize, y: usize) *Tile {
        return self.getTileByV(@intCast(@Vector(2, usize){ x, y }));
    }

    pub fn setSize(self: *TilemapLayer, allocator: Allocator, newSize: Vector) void {
        std.debug.assert(newSize[0] >= 0 and newSize[1] >= 0);
        const usizeNewSize: @Vector(2, usize) = @intCast(newSize);
        const usizeGridSize: @Vector(2, usize) = @intCast(self.grid.size);

        self.tiles.ensureTotalCapacity(allocator, usizeNewSize[1]) catch unreachable;

        if (usizeNewSize[1] > usizeGridSize[1]) {
            const newRows = usizeNewSize[1] - usizeGridSize[1];
            self.tiles.appendNTimesAssumeCapacity(.empty, newRows);
            for (usizeGridSize[1]..usizeGridSize[1] + newRows) |i| {
                initRow(allocator, &self.tiles.items[i], usizeNewSize[0]);
            }
        } else if (usizeNewSize[1] < usizeGridSize[1]) {
            for (usizeNewSize[1]..usizeGridSize[1]) |i| {
                self.tiles.items[i].deinit(allocator);
            }
            self.tiles.shrinkAndFree(allocator, usizeNewSize[1]);
        }

        for (self.tiles.items) |*row| {
            row.ensureTotalCapacity(allocator, usizeNewSize[0]) catch unreachable;
            const prevLen = row.items.len;

            if (usizeNewSize[0] > prevLen) {
                const newColumns = usizeNewSize[0] - prevLen;
                row.appendNTimesAssumeCapacity(.empty, newColumns);
            } else if (usizeNewSize[0] < prevLen) {
                row.shrinkAndFree(allocator, usizeNewSize[0]);
            }
        }

        self.grid.size = newSize;
    }

    fn initRow(allocator: Allocator, row: *ArrayList(Tile), size: usize) void {
        row.ensureTotalCapacity(allocator, size) catch unreachable;
        row.appendNTimesAssumeCapacity(.empty, size);
    }

    pub fn cloneTiles(
        self: *TilemapLayer,
        allocator: Allocator,
        selectGrid: SelectGrid,
        clearSource: bool,
    ) TilemapLayer {
        const start: @Vector(2, usize) = @intCast(selectGrid.offset);
        const startX, const startY = start;
        const size: @Vector(2, usize) = @intCast(selectGrid.size);
        const sizeX, const sizeY = size;

        var newLayer = TilemapLayer.init(allocator, "Floating Selection", selectGrid.size);

        for (0..sizeX) |rx| {
            for (0..sizeY) |ry| {
                const x = startX + rx;
                const y = startY + ry;
                const rv: Vector = @intCast(@Vector(2, usize){ rx, ry });
                const v: Vector = @intCast(@Vector(2, usize){ x, y });

                if (selectGrid.isSelected(v)) {
                    const tile = self.getTileByV(v);
                    const newTile = newLayer.getTileByV(rv);
                    TileSource.set(&newTile.source, &tile.source);
                    if (clearSource) TileSource.clear(&tile.source);
                }
            }
        }

        return newLayer;
    }

    pub fn pasteLayer(self: *TilemapLayer, source: *TilemapLayer, selectGrid: SelectGrid) void {
        const size: @Vector(2, usize) = @intCast(selectGrid.size);
        const sizeX, const sizeY = size;

        for (0..sizeX) |rx| {
            for (0..sizeY) |ry| {
                const rv: Vector = @intCast(@Vector(2, usize){ rx, ry });
                const v = rv + selectGrid.offset;
                if (self.grid.isOutOfBounds(v)) continue;

                const sourceTile = source.getTileByV(rv);

                if (selectGrid.isSelected(v) and sourceTile.source != null) {
                    const destTile = self.getTileByV(v);
                    TileSource.set(&destTile.source, &sourceTile.source);
                }
            }
        }
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
        self.layers.clearAndFree(allocator);
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

    pub fn jsonStringify(self: *const @This(), jw: anytype) !void {
        try json.writeObject(self.*, jw);
    }

    pub fn resize(self: *Tilemap, allocator: Allocator, newSize: Vector) void {
        const zero: Vector = @splat(0);
        std.debug.assert(@reduce(.And, newSize > zero));

        var newTilemap = Tilemap.init(allocator, newSize, self.tileSize);

        for (self.layers.items, 0..) |layer, i| {
            if (i == 0) continue;
            _ = newTilemap.addLayer(allocator, layer.name.slice());
        }

        newTilemap.copyArea(self, .{ 0, 0 }, self.grid.size, .{ 0, 0 });

        self.deinit(allocator);
        self.* = newTilemap;
    }

    fn copyArea(
        dst: *Tilemap,
        src: *Tilemap,
        srcPos: Vector,
        srcSize: Vector,
        dstPos: Vector,
    ) void {
        const zero: Vector = @splat(0);
        std.debug.assert(@reduce(.And, srcSize > zero));
        std.debug.assert(@reduce(.And, srcPos >= zero));
        std.debug.assert(@reduce(.And, (srcSize + srcPos) <= src.grid.size));
        std.debug.assert(@reduce(.And, dstPos >= zero));
        std.debug.assert(@reduce(.And, dstPos < dst.grid.size));

        const maxDstSize = dst.grid.size - dstPos;
        const minWidth, const minHeight = @as(@Vector(2, usize), @intCast(@min(maxDstSize, srcSize)));

        for (0..minWidth) |x| {
            for (0..minHeight) |y| {
                for (0..dst.layers.items.len) |i| {
                    const dstX = x + @as(usize, @intCast(dstPos[0]));
                    const dstY = y + @as(usize, @intCast(dstPos[1]));
                    const srcX = x + @as(usize, @intCast(srcPos[0]));
                    const srcY = y + @as(usize, @intCast(srcPos[1]));

                    const srcLayer = src.layers.items[i];
                    const srcTile = srcLayer.getTileByXY(srcX, srcY);
                    const dstLayer = dst.layers.items[i];
                    const dstTile = dstLayer.getTileByXY(dstX, dstY);

                    dstTile.* = srcTile.clone();
                }
            }
        }
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
        if (self.getLayerIndexById(self.activeLayer) == null) {
            self.activeLayer = self.layers.items[0].id;
        }
    }

    pub fn isOutOfBounds(self: *const Tilemap, gridPosition: Vector) bool {
        return self.grid.isOutOfBounds(gridPosition);
    }

    pub fn setSize(self: *Tilemap, allocator: Allocator, newSize: Vector) void {
        std.debug.assert(newSize[0] >= 0 and newSize[1] >= 0);

        self.grid.size = newSize;

        for (self.layers.items) |layer| {
            layer.setSize(allocator, newSize);
        }
    }
};

pub const Tile = struct {
    source: ?TileSource = null,
    isSolid: bool = false,

    pub const empty: Tile = .{};

    pub fn clone(self: *const Tile) Tile {
        var tile = self.*;

        tile.source = TileSource.clone(&self.source);

        return tile;
    }
};

pub const TileSource = struct {
    tileset: UUID,
    gridPosition: Vector,

    pub fn init(tileset: UUID, gridPosition: Vector) TileSource {
        return TileSource{
            .tileset = tileset,
            .gridPosition = gridPosition,
        };
    }

    pub fn clone(self: *const ?TileSource) ?TileSource {
        return self.*;
    }

    pub fn set(dest: *?TileSource, source: *const ?TileSource) void {
        dest.* = clone(source);
    }

    pub fn clear(dest: *?TileSource) void {
        dest.* = null;
    }

    pub fn eql(a: ?TileSource, b: ?TileSource) bool {
        if (a == null and b == null) return true;
        if (a == null or b == null) return false;
        return a.?.tileset.uuid == b.?.tileset.uuid and @reduce(.And, a.?.gridPosition == b.?.gridPosition);
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
