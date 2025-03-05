const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const Tilemap = lib.Tilemap;
const History = lib.History;
const Vector = lib.Vector;

pub const TilemapDocument = struct {
    tilemap: Tilemap,
    history: History,

    pub fn init(allocator: Allocator, size: Vector, tileSize: Vector) TilemapDocument {
        return TilemapDocument{
            .tilemap = Tilemap.init(allocator, size, tileSize),
            .history = History.init(),
        };
    }

    pub fn deinit(self: *TilemapDocument, allocator: Allocator) void {
        self.tilemap.deinit(allocator);
    }

    pub fn serialize(self: *const TilemapDocument, writer: anytype) !void {
        try std.json.stringify(self, .{}, writer);
    }

    pub fn deserialize(allocator: Allocator, reader: anytype) !*TilemapDocument {
        return try std.json.parseFromTokenSourceLeaky(*TilemapDocument, allocator, reader, .{});
    }

    pub fn undo(self: *TilemapDocument, allocator: Allocator) void {
        self.history.undo(allocator, &self.tilemap);
    }

    pub fn redo(self: *TilemapDocument, allocator: Allocator) void {
        self.history.redo(allocator, &self.tilemap);
    }
};
