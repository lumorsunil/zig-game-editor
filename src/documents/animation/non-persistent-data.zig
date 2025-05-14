const std = @import("std");
const Allocator = std.mem.Allocator;
const PersistentData = @import("persistent-data.zig").PersistentData;

pub const NonPersistentData = struct {
    selectedAnimation: ?usize = null,
    selectedFrame: ?usize = null,

    pub fn init(_: Allocator) NonPersistentData {
        return NonPersistentData{};
    }

    pub fn deinit(_: NonPersistentData, _: Allocator) void {}

    pub fn load(_: *NonPersistentData, _: [:0]const u8, _: *PersistentData) void {}
};
