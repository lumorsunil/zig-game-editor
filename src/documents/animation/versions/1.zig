const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document1 = struct {
    version: DocumentVersion,
    id: UUID,
    textureId: ?UUID = null,
    animations: []const Animation1,
};

pub const Animation1 = @import("0.zig").Animation0;
pub const Frame1 = @import("0.zig").Frame0;
