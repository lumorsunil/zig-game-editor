const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Vector = @import("vector.zig").Vector;
const VectorInt = @import("vector.zig").VectorInt;
const rl = @import("raylib");
const JsonArrayList = @import("json-array-list.zig").JsonArrayList;

pub const FileData = struct {
    tilemap: Tilemap,

    pub fn init(allocator: Allocator, size: Vector, tileSize: Vector) FileData {
        return FileData{
            .tilemap = Tilemap.init(allocator, size, tileSize),
        };
    }

    pub fn deinit(self: *FileData, allocator: Allocator) void {
        self.tilemap.deinit(allocator);
    }

    pub fn serialize(self: *const FileData, writer: anytype) !void {
        try writer.print("{}", .{std.json.fmt(self, .{})});
    }

    pub fn deserialize(allocator: Allocator, reader: anytype) !*FileData {
        return try std.json.parseFromTokenSourceLeaky(*FileData, allocator, reader, .{});
    }
};

pub const Tilemap = struct {
    size: Vector,
    tileSize: Vector,
    tiles: JsonArrayList(Tile),

    pub fn init(allocator: Allocator, size: Vector, tileSize: Vector) Tilemap {
        return Tilemap{
            .size = size,
            .tileSize = tileSize,
            .tiles = JsonArrayList(Tile).initWith(allocator, Tile{}, @intCast(size[0] * size[1])),
        };
    }

    pub fn deinit(self: *Tilemap, allocator: Allocator) void {
        for (self.tiles.slice()) |tile| {
            if (tile.source) |source| {
                allocator.free(source.tileset);
            }
        }
        self.tiles.deinit(allocator);
    }

    pub fn width(self: *const Tilemap) VectorInt {
        return self.size[0];
    }

    pub fn height(self: *const Tilemap) VectorInt {
        return self.size[1];
    }

    pub fn getIndex(self: *const Tilemap, x: usize, y: usize) usize {
        return x + y * @as(usize, @intCast(self.width()));
    }

    pub fn getIndexV(self: *const Tilemap, gridPosition: Vector) usize {
        return self.getIndex(@intCast(gridPosition[0]), @intCast(gridPosition[1]));
    }

    pub fn getTileByIndex(self: *Tilemap, i: usize) *Tile {
        return &self.tiles.arrayList.items[i];
    }

    pub fn getTileV(self: *Tilemap, gridPosition: Vector) *Tile {
        return &self.tiles.arrayList.items[self.getIndexV(gridPosition)];
    }

    pub fn isOutOfBounds(self: *const Tilemap, gridPosition: Vector) bool {
        return gridPosition[0] < 0 or gridPosition[1] < 0 or gridPosition[0] >= self.size[0] or gridPosition[1] >= self.size[1];
    }
};

pub const Tile = struct {
    source: ?TileSource = null,
    isSolid: bool = false,
};

pub const TileSource = struct {
    tileset: []const u8,
    gridPosition: Vector,

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
