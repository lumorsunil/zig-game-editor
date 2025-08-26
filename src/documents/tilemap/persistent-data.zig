const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const Tilemap = lib.tilemap.Tilemap;
const History = lib.history.History;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;
const DocumentVersion = lib.documents.DocumentVersion;
const firstDocumentVersion = lib.documents.firstDocumentVersion;
const json = lib.json;
const upgrade = lib.upgrade;

pub const TilemapData = struct {
    version: DocumentVersion,
    id: UUID,
    tilemap: Tilemap,
    history: History,

    pub const currentVersion: DocumentVersion = firstDocumentVersion + 1;

    pub const upgraders = .{
        @import("upgrades/0-1.zig"),
    };

    pub const UpgradeContainer = upgrade.Container.init(&.{
        struct {
            pub fn upgradeAddHistory(
                allocator: Allocator,
                from: @import("versions/1.zig").Document1,
                container: upgrade.Container,
            ) TilemapData {
                return TilemapData{
                    .version = currentVersion,
                    .id = from.id,
                    .tilemap = upgrade.upgradeValue(Tilemap, allocator, from.tilemap, container),
                    .history = .init(),
                };
            }
        },
    });

    const defaultSize: Vector = .{ 35, 17 };
    const defaultTileSize: Vector = .{ 16, 16 };

    pub fn init(allocator: Allocator) TilemapData {
        return TilemapData{
            .version = currentVersion,
            .id = UUID.init(),
            .tilemap = Tilemap.init(allocator, defaultSize, defaultTileSize),
            .history = History.init(),
        };
    }

    pub fn deinit(self: *TilemapData, allocator: Allocator) void {
        self.tilemap.deinit(allocator);
        self.history.deinit(allocator);
    }

    pub fn clone(self: TilemapData, allocator: Allocator) TilemapData {
        var cloned = self;

        cloned.id = self.id;
        cloned.tilemap = self.tilemap.clone(allocator);
        cloned.history = self.history.clone(allocator);

        return cloned;
    }
};
