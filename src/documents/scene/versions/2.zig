const std = @import("std");
const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document2 = struct {
    version: DocumentVersion,
    id: UUID,
    entities: []const Entity2,
};

pub const Entity2 = struct {
    id: UUID,
    position: Vector,
    scale: @Vector(2, f32),
    type: EntityType2,
};

pub const EntityType2 = @import("1.zig").EntityType1;
pub const PropertyObject2 = @import("1.zig").PropertyObject1;
pub const DocumentTag2 = @import("1.zig").DocumentTag1;
