const std = @import("std");
const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document3 = struct {
    version: DocumentVersion,
    id: UUID,
    entities: []const Entity3,
};

pub const Entity3 = struct {
    id: UUID,
    position: Vector,
    scale: @Vector(2, f32),
    type: EntityType3,
};

pub const EntityType3 = union(enum) {
    custom: struct {
        entityTypeId: UUID,
        properties: PropertyObject3,
    },
    exit: struct {
        sceneId: ?UUID = null,
        scale: ?@Vector(2, f32) = .{ 1, 1 },
        entranceKey: []const u8,
        isVertical: bool = false,
    },
    entrance: struct {
        key: []const u8,
        scale: ?@Vector(2, f32) = .{ 1, 1 },
    },
    tilemap: struct {
        tilemapId: ?UUID,
    },
    point: struct {
        key: []const u8,
    },
};

pub const PropertyObject3 = @import("2.zig").PropertyObject2;
pub const DocumentTag3 = @import("2.zig").DocumentTag2;
