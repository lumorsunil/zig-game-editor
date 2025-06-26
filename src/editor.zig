const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("root").lib;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const Project = lib.Project;

pub const Editor = struct {
    documentType: DocumentTag,
    document: Document,

    pub fn init(document: Document) Editor {
        return Editor{
            .documentType = document.content.?,
            .document = document,
        };
    }

    pub fn deinit(_: *Editor, _: Allocator) void {}

    pub fn saveFile(self: *Editor, project: *Project) !void {
        try self.document.save(project);
    }
};
