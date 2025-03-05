const std = @import("std");
const Allocator = std.mem.Allocator;
const Tilemap = @import("tilemap.zig").Tilemap;

pub const Action = union(enum) {
    brushPaint: BrushPaint,
    brushDelete: BrushDelete,
    resize: ResizeTilemap,

    pub fn deinit(self: *Action, allocator: Allocator) void {
        switch (self.*) {
            inline else => |*action| action.deinit(allocator),
        }
    }

    pub fn undo(self: Action, allocator: Allocator, tilemap: *Tilemap) void {
        switch (self) {
            inline else => |action| action.undo(allocator, tilemap),
        }
    }

    pub fn redo(self: Action, allocator: Allocator, tilemap: *Tilemap) void {
        switch (self) {
            inline else => |action| action.redo(allocator, tilemap),
        }
    }

    pub fn Generic(comptime name: []const u8) type {
        return struct {
            snapshotBefore: Tilemap,
            snapshotAfter: Tilemap,

            pub const label = name;

            const Self = @This();

            pub fn init(snapshotBefore: Tilemap, allocator: Allocator) Self {
                return Self{
                    .snapshotBefore = snapshotBefore.clone(allocator),
                    .snapshotAfter = undefined,
                };
            }

            pub fn materialize(self: *Self, allocator: Allocator, snapshotAfter: Tilemap) void {
                self.snapshotAfter = snapshotAfter.clone(allocator);
            }

            pub fn deinit(self: *Self, allocator: Allocator) void {
                self.snapshotAfter.deinit(allocator);
                self.snapshotBefore.deinit(allocator);
            }

            pub fn undo(self: Self, allocator: Allocator, tilemap: *Tilemap) void {
                tilemap.deinit(allocator);
                allocator.destroy(tilemap);
                tilemap.* = self.snapshotBefore.clone(allocator);
            }

            pub fn redo(self: Self, allocator: Allocator, tilemap: *Tilemap) void {
                tilemap.deinit(allocator);
                allocator.destroy(tilemap);
                tilemap.* = self.snapshotAfter.clone(allocator);
            }
        };
    }

    pub const BrushPaint = Generic("Paint");
    pub const BrushDelete = Generic("Delete");
    pub const ResizeTilemap = Generic("Resize");
};
