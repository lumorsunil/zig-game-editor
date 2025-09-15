const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const PersistentData = @import("persistent-data.zig").SoundPersistentData;

pub const SoundNonPersistentData = struct {
    sound: ?rl.Sound = null,

    pub fn init(_: Allocator) SoundNonPersistentData {
        return SoundNonPersistentData{};
    }

    pub fn deinit(self: *SoundNonPersistentData, _: Allocator) void {
        if (self.sound) |t| rl.unloadSound(t);
        self.sound = null;
    }

    pub fn load(
        self: *SoundNonPersistentData,
        _: [:0]const u8,
        persistentData: *PersistentData,
    ) void {
        const soundFilePath = persistentData.soundFilePath.getPath();
        defer soundFilePath.deinit();
        if (soundFilePath.path.len == 0) return;
        self.sound = rl.loadSound(soundFilePath.path) catch |err| brk: {
            std.log.err("Could not load sound {s}: {}", .{ soundFilePath.path, err });
            break :brk null;
        };
    }
};
