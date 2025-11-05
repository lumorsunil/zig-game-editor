const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const PersistentData = @import("persistent-data.zig").MusicPersistentData;

pub const MusicNonPersistentData = struct {
    music: ?rl.Music = null,

    pub fn init(_: Allocator) MusicNonPersistentData {
        return MusicNonPersistentData{};
    }

    pub fn deinit(self: *MusicNonPersistentData, _: Allocator) void {
        if (self.music) |t| rl.unloadMusicStream(t);
        self.music = null;
    }

    pub fn load(
        self: *MusicNonPersistentData,
        _: [:0]const u8,
        persistentData: *PersistentData,
    ) void {
        const musicFilePath = persistentData.musicFilePath.getPath();
        defer musicFilePath.deinit();
        if (musicFilePath.path.len == 0) return;
        self.music = rl.loadMusicStream(musicFilePath.path) catch |err| brk: {
            std.log.err("Could not load music {s}: {}", .{ musicFilePath.path, err });
            break :brk null;
        };
    }
};
