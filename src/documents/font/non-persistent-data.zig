const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const PersistentData = @import("persistent-data.zig").FontPersistentData;

pub const FontNonPersistentData = struct {
    font: ?rl.Font = null,

    pub fn init(_: Allocator) FontNonPersistentData {
        return FontNonPersistentData{};
    }

    pub fn deinit(self: *FontNonPersistentData, _: Allocator) void {
        if (self.font) |t| rl.unloadFont(t);
        self.font = null;
    }

    pub fn load(
        self: *FontNonPersistentData,
        _: [:0]const u8,
        persistentData: *PersistentData,
    ) void {
        const fontFilePath = persistentData.fontFilePath.slice();
        if (fontFilePath.len == 0) return;
        self.font = rl.loadFont(fontFilePath) catch |err| brk: {
            std.log.err("Could not load font {s}: {}", .{ fontFilePath, err });
            break :brk null;
        };
    }
};
