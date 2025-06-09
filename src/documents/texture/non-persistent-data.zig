const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const PersistentData = @import("persistent-data.zig").TexturePersistentData;

pub const TextureNonPersistentData = struct {
    texture: ?rl.Texture2D = null,

    pub fn init(_: Allocator) TextureNonPersistentData {
        return TextureNonPersistentData{};
    }

    pub fn deinit(self: *TextureNonPersistentData, _: Allocator) void {
        if (self.texture) |t| rl.unloadTexture(t);
        self.texture = null;
    }

    pub fn load(
        self: *TextureNonPersistentData,
        _: [:0]const u8,
        persistentData: *PersistentData,
    ) void {
        if (persistentData.textureFilePath.len == 0) return;
        self.texture = rl.loadTexture(persistentData.textureFilePath) catch |err| brk: {
            std.log.err("Could not load texture {s}: {}", .{ persistentData.textureFilePath, err });
            break :brk null;
        };
    }
};
