const std = @import("std");
const Allocator = std.mem.Allocator;

const EntityType = @import("persistent-data.zig").EntityType;

pub const EntityTypeNonPersistentData = struct {
    pub fn init(_: Allocator) EntityTypeNonPersistentData {
        return EntityTypeNonPersistentData{};
    }

    pub fn deinit(_: *EntityTypeNonPersistentData, _: Allocator) void {}

    pub fn load(_: *EntityTypeNonPersistentData, _: [:0]const u8, _: *EntityType) void {}
};
