const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Animation = @import("animation.zig").Animation;
const lib = @import("root").lib;
const json = lib.json;
const UUID = lib.UUIDSerializable;

pub const PersistentData = struct {
    id: UUID,
    textureId: ?UUID = null,
    animations: ArrayList(Animation),

    const initialAnimationsCapacity = 10;

    pub fn init(allocator: Allocator) PersistentData {
        return PersistentData{
            .id = UUID.init(),
            .animations = ArrayList(Animation).initCapacity(allocator, initialAnimationsCapacity) catch unreachable,
        };
    }

    pub fn deinit(self: *PersistentData, allocator: Allocator) void {
        for (self.animations.items) |*animation| {
            animation.deinit(allocator);
        }
        self.animations.clearAndFree(allocator);
        self.textureId = null;
    }

    pub fn clone(self: PersistentData, allocator: Allocator) PersistentData {
        var cloned = PersistentData.init(allocator);

        cloned.id = self.id;

        for (self.animations.items) |animation| {
            cloned.animations.append(allocator, animation.clone(allocator)) catch unreachable;
        }
        cloned.textureId = self.textureId;

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
