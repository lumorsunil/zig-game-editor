const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const StringZ = lib.StringZ;
const DocumentVersion = lib.documents.DocumentVersion;
const firstDocumentVersion = lib.documents.firstDocumentVersion;
const upgrade = lib.upgrade;

pub const SoundPersistentData = struct {
    version: DocumentVersion,
    id: UUID,
    soundFilePath: StringZ,

    pub const currentVersion: DocumentVersion = firstDocumentVersion + 0;

    pub const upgraders = .{};

    pub const NoUpgradersDocument = @import("versions/0.zig").Document0;

    pub const UpgradeContainer = upgrade.Container.init(&.{});

    pub fn init(allocator: Allocator) SoundPersistentData {
        return SoundPersistentData{
            .version = currentVersion,
            .id = UUID.init(),
            .soundFilePath = .init(allocator, ""),
        };
    }

    pub fn deinit(self: *SoundPersistentData, allocator: Allocator) void {
        self.soundFilePath.deinit(allocator);
    }

    pub fn clone(self: SoundPersistentData, allocator: Allocator) SoundPersistentData {
        var cloned = self;
        cloned.soundFilePath = self.soundFilePath.clone(allocator);
        return cloned;
    }
};
