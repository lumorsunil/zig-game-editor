const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const Tilemap = lib.Tilemap;
const History = lib.History;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;
const StringZ = lib.StringZ;
const DocumentVersion = lib.documents.DocumentVersion;
const firstDocumentVersion = lib.documents.firstDocumentVersion;
const upgrade = lib.upgrade;

pub const TexturePersistentData = struct {
    version: DocumentVersion,
    id: UUID,
    textureFilePath: StringZ,

    pub const currentVersion: DocumentVersion = firstDocumentVersion + 1;

    pub fn init(allocator: Allocator) TexturePersistentData {
        return TexturePersistentData{
            .version = currentVersion,
            .id = UUID.init(),
            .textureFilePath = .init(allocator, ""),
        };
    }

    pub fn deinit(self: *TexturePersistentData, allocator: Allocator) void {
        self.textureFilePath.deinit(allocator);
    }

    pub fn clone(self: TexturePersistentData, allocator: Allocator) TexturePersistentData {
        var cloned = self;
        cloned.textureFilePath = self.textureFilePath.clone(allocator);
        return cloned;
    }

    pub const upgraders = .{
        @import("upgrades/0-1.zig"),
    };

    pub const UpgradeContainer = upgrade.Container.init(&.{});
};
