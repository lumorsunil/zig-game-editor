const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;

pub const ProjectOptions = struct {
    defaultTileset: ?UUID = null,

    pub const empty: ProjectOptions = .{};
};
