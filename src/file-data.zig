const std = @import("std");
const Allocator = std.mem.Allocator;
const Vector = @import("vector.zig").Vector;
const Tilemap = @import("tilemap.zig").Tilemap;
const History = @import("history.zig").History;

pub const FileData = struct {
    tilemap: Tilemap,
    history: History,

    pub fn init(allocator: Allocator, size: Vector, tileSize: Vector) FileData {
        return FileData{
            .tilemap = Tilemap.init(allocator, size, tileSize),
            .history = History.init(),
        };
    }

    pub fn deinit(self: *FileData, allocator: Allocator) void {
        self.tilemap.deinit(allocator);
    }

    pub fn serialize(self: *const FileData, writer: anytype) !void {
        try std.json.stringify(self, .{}, writer);
    }

    pub fn deserialize(allocator: Allocator, reader: anytype) !*FileData {
        return try std.json.parseFromTokenSourceLeaky(*FileData, allocator, reader, .{});
    }

    pub fn undo(self: *FileData, allocator: Allocator) void {
        self.history.undo(allocator, &self.tilemap);
    }

    pub fn redo(self: *FileData, allocator: Allocator) void {
        self.history.redo(allocator, &self.tilemap);
    }
};
