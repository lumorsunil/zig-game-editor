const std = @import("std");
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const DocumentVersion = lib.documents.DocumentVersion;
const ProjectOptions1 = @import("1.zig").ProjectOptions1;

pub const ProjectOptions2 = lib.typeUtils.ExtendFields(ProjectOptions1, struct {
    version: DocumentVersion = 2,
    playCommandCwd: []const u8 = "",
});
