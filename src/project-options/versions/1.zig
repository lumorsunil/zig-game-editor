const std = @import("std");
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const DocumentVersion = lib.documents.DocumentVersion;
const ProjectOptions0 = @import("0.zig").ProjectOptions0;

pub const ProjectOptions1 = lib.typeUtils.ExtendFields(ProjectOptions0, struct {
    version: DocumentVersion = 1,
    playCommand: []const u8 = "",
});
