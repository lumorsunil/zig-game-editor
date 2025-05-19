const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Animation = @import("animation.zig").Animation;
const lib = @import("root").lib;
const json = lib.json;

pub const PersistentData = struct {
    texturePath: ?[:0]const u8 = null,
    animations: ArrayList(Animation),

    const initialAnimationsCapacity = 10;

    pub fn init(allocator: Allocator) PersistentData {
        return PersistentData{
            .animations = ArrayList(Animation).initCapacity(allocator, initialAnimationsCapacity) catch unreachable,
        };
    }

    pub fn deinit(self: *PersistentData, allocator: Allocator) void {
        for (self.animations.items) |*animation| {
            animation.deinit(allocator);
        }
        self.animations.clearAndFree(allocator);
        if (self.texturePath) |tp| allocator.free(tp);
        self.texturePath = null;
    }

    pub fn clone(self: PersistentData, allocator: Allocator) PersistentData {
        var cloned = PersistentData.init(allocator);

        for (self.animations.items) |animation| {
            cloned.animations.append(allocator, animation.clone(allocator)) catch unreachable;
        }
        if (self.texturePath) |tp| cloned.texturePath = allocator.dupeZ(u8, tp) catch unreachable;

        return cloned;
    }

    pub fn jsonStringify(self: *const @This(), jw: anytype) !void {
        try json.writeObject(self.*, jw);
    }

    pub fn jsonParse(
        allocator: Allocator,
        source: anytype,
        options: std.json.ParseOptions,
    ) !@This() {
        return try json.parseObject(@This(), allocator, source, options);
    }
};
