const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document2 = struct {
    version: DocumentVersion,
    id: UUID,
    name: []const u8,
    icon: EntityTypeIcon2,
    hitboxOrigin: Vector,
    hitboxSize: Vector,
    properties: @import("../../scene/versions/3.zig").PropertyObject3,
};

pub const EntityTypeIcon2 = @import("1.zig").EntityTypeIcon1;
