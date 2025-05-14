const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("root").lib;
const Tilemap = lib.Tilemap;
const History = lib.History;
const Vector = lib.Vector;

pub const TexturePersistentData = struct {
    pub fn init(_: Allocator) TexturePersistentData {
        return TexturePersistentData{};
    }

    pub fn deinit(_: *TexturePersistentData, _: Allocator) void {}

    pub fn clone(self: TexturePersistentData, _: Allocator) TexturePersistentData {
        return self;
    }
};
