const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const DocumentVersion = lib.documents.DocumentVersion;

pub const Document0 = struct {
    version: DocumentVersion,
    id: UUID,
    soundFilePath: []const u8,
};
