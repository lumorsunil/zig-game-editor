const std = @import("std");
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document0 = struct {
    id: UUID,
    entities: []const Entity0,
};

pub const Entity0 = struct {
    id: UUID,
    position: Vector,
    type: EntityType0,
};

pub const EntityType0 = union(enum) {
    custom: struct {
        entityTypeId: UUID,
        properties: PropertyObject0,
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
};

pub const PropertyObject0 = std.json.ArrayHashMap(Property0);

pub const Property0 = struct {
    id: UUID,
    property: PropertyType0,
};

const PropertyTypeTag0 = enum {
    object,
    array,
    string,
    integer,
    float,
    boolean,
    entityReference,
    assetReference,
};

const PropertyType0 = union(PropertyTypeTag0) {
    object: PropertyObject0,
    array: PropertyArray0,
    string: PropertyString0,
    integer: PropertyInteger0,
    float: PropertyFloat0,
    boolean: PropertyBoolean0,
    entityReference: PropertyEntityReference0,
    assetReference: PropertyAssetReference0,
};

const PropertyArray0 = struct {
    subType: PropertyTypeTag0,
    items: []const Property0,
};

const PropertyString0 = struct {
    value: []const u8,
};

const PropertyInteger0 = struct {
    value: i32,
};

const PropertyFloat0 = struct {
    value: f32,
};

const PropertyBoolean0 = struct {
    value: bool,
};

const PropertyEntityReference0 = struct {
    sceneId: ?UUID,
    entityId: ?UUID,
};

const PropertyAssetReference0 = struct {
    assetId: ?UUID,
    assetType: DocumentTag0,
};

pub const DocumentTag0 = enum {
    scene,
    tilemap,
    animation,
    texture,
    entityType,
};
