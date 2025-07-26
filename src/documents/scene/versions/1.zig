const std = @import("std");
const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document1 = struct {
    version: DocumentVersion,
    id: UUID,
    entities: []const @import("0.zig").Entities0,
};

pub const PropertyObject1 = @import("0.zig").PropertyObject0;
pub const DocumentTag1 = @import("0.zig").DocumentTag0;
