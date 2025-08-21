const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const StringZ = lib.StringZ;
const DocumentVersion = lib.documents.DocumentVersion;
const firstDocumentVersion = lib.documents.firstDocumentVersion;
const upgrade = lib.upgrade;

pub const FontPersistentData = struct {
    version: DocumentVersion,
    id: UUID,
    fontFilePath: StringZ,

    pub const currentVersion: DocumentVersion = firstDocumentVersion + 0;

    pub const upgraders = .{};

    pub const NoUpgradersDocument = @import("versions/0.zig").Document0;

    pub const UpgradeContainer = upgrade.Container.init(&.{});

    pub fn init(allocator: Allocator) FontPersistentData {
        return FontPersistentData{
            .version = currentVersion,
            .id = UUID.init(),
            .fontFilePath = .init(allocator, ""),
        };
    }

    pub fn deinit(self: *FontPersistentData, allocator: Allocator) void {
        self.fontFilePath.deinit(allocator);
    }

    pub fn clone(self: FontPersistentData, allocator: Allocator) FontPersistentData {
        var cloned = self;
        cloned.fontFilePath = self.fontFilePath.clone(allocator);
        return cloned;
    }
};
