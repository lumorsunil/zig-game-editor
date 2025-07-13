const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Animation = @import("animation.zig").Animation;
const lib = @import("root").lib;
const json = lib.json;
const UUID = lib.UUIDSerializable;
const DocumentVersion = lib.documents.DocumentVersion;
const firstDocumentVersion = lib.documents.firstDocumentVersion;
const upgrade = lib.upgrade;

pub const PersistentData = struct {
    version: DocumentVersion,
    id: UUID,
    textureId: ?UUID = null,
    animations: ArrayList(Animation),

    pub const currentVersion: DocumentVersion = firstDocumentVersion + 1;

    const initialAnimationsCapacity = 10;

    pub fn init(allocator: Allocator) PersistentData {
        return PersistentData{
            .version = currentVersion,
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

    pub const upgraders = .{
        @import("upgrades/0-1.zig"),
    };

    pub const UpgradeContainer = upgrade.Container.init(&.{});

    pub fn jsonStringify(self: *const @This(), jw: anytype) !void {
        try json.writeObject(self.*, jw);
    }
};
