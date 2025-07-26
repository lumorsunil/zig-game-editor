const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document1 = struct {
    version: DocumentVersion,
    id: UUID,
    name: []const u8,
    icon: EntityTypeIcon1,
    properties: @import("../../scene/versions/1.zig").PropertyObject1,
};

pub const EntityTypeIcon1 = @import("0.zig").EntityTypeIcon0;
