const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const rl = @import("raylib");
const Context = lib.Context;
const config = @import("lib").config;
const StringZ = lib.StringZ;
const PropertyObject = @import("property.zig").PropertyObject;
const DocumentVersion = lib.documents.DocumentVersion;
const firstDocumentVersion = lib.documents.firstDocumentVersion;
const upgrade = lib.upgrade;

const tileSize = config.tileSize;

pub const EntityTypeIcon = struct {
    textureId: ?UUID,
    gridPosition: Vector,
    cellSize: Vector,

    pub const empty = EntityTypeIcon{
        .textureId = null,
        .gridPosition = .{ 0, 0 },
        .cellSize = .{ 0, 0 },
    };

    pub fn init(
        textureId: ?UUID,
        gridPosition: Vector,
        cellSize: Vector,
    ) EntityTypeIcon {
        return EntityTypeIcon{
            .textureId = textureId,
            .gridPosition = gridPosition,
            .cellSize = cellSize,
        };
    }

    pub fn draw(self: EntityTypeIcon, context: *Context, position: Vector) void {
        const textureId = self.textureId orelse return;

        if (context.requestTextureById(textureId)) |texture| {
            const scale = context.scale;
            const sourcePosition: @Vector(2, f32) = @floatFromInt(self.gridPosition * self.cellSize);
            const source = rl.Rectangle.init(
                sourcePosition[0],
                sourcePosition[1],
                @floatFromInt(self.cellSize[0]),
                @floatFromInt(self.cellSize[1]),
            );
            const fPosition: @Vector(2, f32) = @floatFromInt(position);
            const dest = rl.Rectangle.init(
                fPosition[0] * scale,
                fPosition[1] * scale,
                source.width * scale,
                source.height * scale,
            );
            const origin = rl.Vector2.init(source.width / 2 * scale, source.height / 2 * scale);

            rl.drawTexturePro(texture, source, dest, origin, 0, rl.Color.white);
        }
    }
};

pub const EntityType = struct {
    version: DocumentVersion,
    id: UUID,
    name: StringZ,
    icon: EntityTypeIcon,
    properties: PropertyObject,

    pub const currentVersion: DocumentVersion = firstDocumentVersion + 1;

    pub fn init(allocator: Allocator) EntityType {
        return EntityType{
            .version = currentVersion,
            .id = UUID.init(),
            .name = .init(allocator, "new-entity-type"),
            .icon = .empty,
            .properties = .empty,
        };
    }

    pub fn deinit(self: *EntityType, allocator: Allocator) void {
        self.name.deinit(allocator);
        self.properties.deinit(allocator);
    }

    pub fn clone(self: EntityType, allocator: Allocator) EntityType {
        var cloned: EntityType = undefined;
        cloned.id = self.id;
        cloned.name = .init(allocator, self.name.buffer);
        cloned.icon = self.icon;
        cloned.properties = self.properties.clone(allocator);
        return cloned;
    }

    pub const upgraders = .{
        @import("upgrades/0-1.zig"),
    };

    pub const UpgradeContainer = upgrade.Container.init(&.{});
};
