const std = @import("std");
const rl = @import("raylib");
const lib = @import("lib");
const Context = lib.Context;
const EditorSession = lib.EditorSession;
const Project = lib.Project;
const UUID = lib.UUIDSerializable;

const sessionFileName = "session.json";

fn createEditorSession(self: *Context) EditorSession {
    return EditorSession{
        .currentProject = if (self.currentProject) |p| self.allocator.dupe(u8, p.getRootDirPath()) catch unreachable else null,
        .openedEditor = self.currentEditor,
        .openedDocuments = self.allocator.dupe(UUID, self.openedEditors.map.keys()) catch unreachable,
        .camera = self.camera,
        .windowSize = .{ rl.getScreenWidth(), rl.getScreenHeight() },
        .windowPos = brk: {
            const winPos = rl.getWindowPosition();
            break :brk @intFromFloat(@Vector(2, f32){ winPos.x, winPos.y });
        },
    };
}

pub fn storeSession(self: *Context) !void {
    const file = try std.fs.cwd().createFile(sessionFileName, .{});
    defer file.close();
    const writer = file.writer();
    var session = self.createEditorSession();
    try std.json.stringify(session, .{}, writer);
    session.deinit(self.allocator);
    _ = self.saveIndex();
}

pub fn restoreSession(self: *Context) !void {
    // Read session file
    const file = std.fs.cwd().openFile(sessionFileName, .{}) catch |err| {
        switch (err) {
            error.FileNotFound => {
                return;
            },
            else => return err,
        }
    };
    defer file.close();
    const reader = file.reader();
    var jsonReader = std.json.reader(self.allocator, reader);
    defer jsonReader.deinit();
    const parsed = std.json.parseFromTokenSource(EditorSession, self.allocator, &jsonReader, .{
        .ignore_unknown_fields = true,
    }) catch |err| {
        std.log.err("Could not read session: {}", .{err});
        return err;
    };
    defer parsed.deinit();

    if (parsed.value.currentProject) |p| {
        self.setProject(Project.init(self.allocator, p));
    }

    for (parsed.value.openedDocuments) |id| {
        self.openEditorById(id);
    }

    if (parsed.value.openedEditor) |id| {
        self.openEditorById(id);
    }

    rl.setWindowSize(parsed.value.windowSize[0], parsed.value.windowSize[1]);
    rl.setWindowPosition(parsed.value.windowPos[0], parsed.value.windowPos[1]);

    self.camera = parsed.value.camera;

    const exitImage = rl.genImageColor(1, 1, rl.Color.white);
    const entranceImage = rl.genImageColor(1, 1, rl.Color.yellow);
    self.exitTexture = try rl.loadTextureFromImage(exitImage);
    self.entranceTexture = try rl.loadTextureFromImage(entranceImage);
}
