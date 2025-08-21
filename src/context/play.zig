const std = @import("std");
const lib = @import("lib");
const Context = lib.Context;

pub fn play(self: *Context) void {
    playInner(self) catch |err| {
        std.log.err("Error calling play: {}", .{err});
    };
}

fn playInner(self: *Context) !void {
    const editor = self.getCurrentEditor() orelse return;
    var focusedEditor = editor;

    if (editor.documentType != .scene) return;

    self.playState = .starting;

    errdefer |err| {
        const filePath = self.getFilePathById(focusedEditor.document.getId());
        self.showError("Error starting scene {?s}: {}", .{ filePath, err });
        self.playState = .errorStarting;
    }

    for (self.openedEditors.map.values()) |*openedEditor| {
        focusedEditor = openedEditor;
        try openedEditor.saveFile(&self.currentProject.?);
    }

    focusedEditor = editor;

    const currentSceneFileName = self.getFilePathById(editor.document.getId()) orelse return error.MissingDocumentFilePath;

    const zigCommand = try std.fmt.allocPrint(self.allocator, "zig build run -- --scene {s}", .{currentSceneFileName});
    defer self.allocator.free(zigCommand);
    const command = &.{
        "cmd.exe",
        "/C",
        zigCommand,
    };
    var child = std.process.Child.init(command, self.allocator);
    child.cwd = try std.fs.cwd().realpathAlloc(self.allocator, "../kottefolket");
    defer self.allocator.free(child.cwd.?);

    const term = try child.spawnAndWait();

    switch (term) {
        .Exited => |exitCode| {
            if (exitCode != 0) {
                self.playState = .crash;
            } else {
                self.playState = .notRunning;
            }
        },
        else => self.playState = .crash,
    }
}
