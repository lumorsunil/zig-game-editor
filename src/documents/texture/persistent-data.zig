const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("root").lib;
const Tilemap = lib.Tilemap;
const History = lib.History;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;

pub const TexturePersistentData = struct {
    id: UUID,
    textureFilePath: [:0]const u8,

    pub fn init(_: Allocator) TexturePersistentData {
        return TexturePersistentData{
            .id = UUID.init(),
            .textureFilePath = &.{},
        };
    }

    pub fn deinit(self: *TexturePersistentData, allocator: Allocator) void {
        allocator.free(self.textureFilePath);
    }

    pub fn clone(self: TexturePersistentData, allocator: Allocator) TexturePersistentData {
        var cloned = self;

        cloned.textureFilePath = allocator.dupeZ(u8, self.textureFilePath) catch unreachable;

        return cloned;
    }
};
