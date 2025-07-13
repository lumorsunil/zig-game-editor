const lib = @import("root").lib;
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;

pub const Document1 = struct {
    version: DocumentVersion,
    id: UUID,
    textureId: ?UUID = null,
    animations: []const Animation1,
};

const Animation1 = @import("0.zig").Animation0;
const Frame1 = @import("0.zig").Frame0;
