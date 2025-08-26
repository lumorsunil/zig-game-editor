const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const Document = lib.documents.Document;
const DocumentTag = lib.documents.DocumentTag;
const Project = lib.Project;

pub const session = @import("editor-session.zig");

pub const Editor = struct {
    documentType: DocumentTag,
    document: Document,
    camera: rl.Camera2D,

    pub fn init(document: Document) Editor {
        return Editor{
            .documentType = document.content.?,
            .document = document,
            .camera = .{
                .offset = .{ .x = 0, .y = 0 },
                .target = .{ .x = 0, .y = 0 },
                .rotation = 0,
                .zoom = 1,
            },
        };
    }

    pub fn deinit(_: *Editor, _: Allocator) void {}

    pub fn saveFile(self: *Editor, project: *Project) !void {
        try self.document.save(project);
    }
};
