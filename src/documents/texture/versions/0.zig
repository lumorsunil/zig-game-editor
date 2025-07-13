const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;

pub const Document0 = struct {
    id: UUID,
    textureFilePath: []const u8,
};
