const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Animation = @import("animation.zig").Animation;

pub const PersistentData = struct {
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
    }

    pub fn clone(self: PersistentData, allocator: Allocator) PersistentData {
        var cloned = PersistentData.init(allocator);

        for (self.animations.items) |animation| {
            cloned.animations.append(allocator, animation.clone(allocator)) catch unreachable;
        }

        return cloned;
    }
};
