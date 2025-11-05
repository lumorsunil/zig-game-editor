const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const StringZ = lib.StringZ;
const DocumentVersion = lib.documents.DocumentVersion;
const firstDocumentVersion = lib.documents.firstDocumentVersion;
const upgrade = lib.upgrade;

pub const MusicPersistentData = struct {
    version: DocumentVersion,
    id: UUID,
    musicFilePath: StringZ,

    pub const currentVersion: DocumentVersion = firstDocumentVersion + 0;

    pub const upgraders = .{};

    pub const NoUpgradersDocument = @import("versions/0.zig").Document0;

    pub const UpgradeContainer = upgrade.Container.init(&.{});

    pub fn init(allocator: Allocator) MusicPersistentData {
        return MusicPersistentData{
            .version = currentVersion,
            .id = UUID.init(),
            .musicFilePath = .init(allocator, ""),
        };
    }

    pub fn deinit(self: *MusicPersistentData, allocator: Allocator) void {
        self.musicFilePath.deinit(allocator);
    }

    pub fn clone(self: MusicPersistentData, allocator: Allocator) MusicPersistentData {
        var cloned = self;
        cloned.musicFilePath = self.musicFilePath.clone(allocator);
        return cloned;
    }
};
