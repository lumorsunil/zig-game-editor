const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;

pub const EditorSession = struct {
    currentProject: ?[]const u8,
    openedEditor: ?UUID,
    openedDocuments: []EditorSessionDocument,
    windowSize: Vector,
    windowPos: Vector,

    pub fn deinit(self: *EditorSession, allocator: Allocator) void {
        if (self.currentProject) |p| allocator.free(p);
        self.currentProject = null;
        allocator.free(self.openedDocuments);
        self.openedEditor = null;
    }
};

pub const EditorSessionDocument = struct {
    id: UUID,
    camera: rl.Camera2D,
};
