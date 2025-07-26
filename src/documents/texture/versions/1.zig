const lib = @import("lib");
const DocumentVersion = lib.documents.DocumentVersion;
const UUID = lib.UUIDSerializable;

pub const Document1 = struct {
    version: DocumentVersion,
    id: UUID,
    textureFilePath: []const u8,
};
