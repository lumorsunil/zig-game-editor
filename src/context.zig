const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("root").lib;
const Vector = lib.Vector;
const VectorInt = lib.VectorInt;
const Project = lib.Project;
const EditorSession = lib.EditorSession;
const Editor = lib.Editor;
const AssetsLibrary = lib.AssetsLibrary;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const Node = lib.Node;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityTilemap = lib.documents.scene.SceneEntityTilemap;
const nfd = @import("nfd");

pub const Context = struct {
    allocator: Allocator,

    openedEditors: std.StringArrayHashMapUnmanaged(Editor),
    currentEditor: ?usize = null,
    documents: std.StringArrayHashMapUnmanaged(Document),

    backgroundColor: rl.Color = rl.Color.init(125, 125, 155, 255),
    isDemoWindowOpen: bool = false,
    isDemoWindowEnabled: bool = false,
    camera: rl.Camera2D,

    textures: std.StringHashMap(rl.Texture2D),
    scale: VectorInt = 4,
    scaleV: Vector = .{ 4, 4 },

    currentProject: ?Project,

    exitTexture: rl.Texture2D,
    entranceTexture: rl.Texture2D,

    mode: EditorMode = .scene,

    playState: PlayState = .notRunning,

    reusableTextBuffer: [256:0]u8 = undefined,
    errorMessage: [1024:0]u8 = undefined,
    isErrorDialogOpen: bool = false,

    isNewDirectoryDialogOpen: bool = false,
    isNewTilemapDialogOpen: bool = false,
    isNewSceneDialogOpen: bool = false,
    isNewAnimationDialogOpen: bool = false,

    pub const PlayState = enum {
        notRunning,
        starting,
        errorStarting,
        running,
        crash,
    };

    pub const EditorMode = enum {
        scene,
        tilemap,
        animation,
    };

    const defaultSize: Vector = .{ 35, 17 };
    const defaultTileSize: Vector = .{ 16, 16 };

    pub fn init(allocator: Allocator) Context {
        const exitImage = rl.genImageColor(1, 1, rl.Color.white);
        const entranceImage = rl.genImageColor(1, 1, rl.Color.yellow);

        const mode: EditorMode = .tilemap;
        const rootDir = std.fs.cwd().realpathAlloc(allocator, ".") catch unreachable;
        defer allocator.free(rootDir);

        return Context{
            .allocator = allocator,
            .openedEditors = std.StringArrayHashMapUnmanaged(Editor){},
            .documents = std.StringArrayHashMapUnmanaged(Document){},
            .camera = rl.Camera2D{
                .target = .{ .x = 0, .y = 0 },
                .offset = .{ .x = 0, .y = 0 },
                .rotation = 0,
                .zoom = 1,
            },
            .textures = std.StringHashMap(rl.Texture2D).init(allocator),
            .exitTexture = rl.loadTextureFromImage(exitImage),
            .entranceTexture = rl.loadTextureFromImage(entranceImage),
            .currentProject = null,
            .mode = mode,
        };
    }

    pub fn deinit(self: *Context) void {
        self.textures.deinit();
        for (self.openedEditors.values()) |*editor| {
            editor.deinit(self.allocator);
        }
        for (self.openedEditors.keys()) |key| {
            self.allocator.free(key);
        }
        self.openedEditors.clearAndFree(self.allocator);
        for (self.documents.values()) |*document| {
            document.deinit(self.allocator);
        }
        for (self.documents.keys()) |key| {
            self.allocator.free(key);
        }
        self.documents.clearAndFree(self.allocator);
        if (self.currentProject) |*p| p.deinit(self.allocator);
        self.currentProject = null;
    }

    pub fn getCurrentEditor(self: *Context) ?*Editor {
        const i = self.currentEditor orelse return null;
        return &self.openedEditors.values()[i];
    }

    fn createEditorSession(self: *Context) EditorSession {
        return EditorSession{
            .currentProject = if (self.currentProject) |p| p.assetsLibrary.root else null,
            .openedEditorFilePath = if (self.getCurrentEditor()) |e| e.document.filePath else null,
            .camera = self.camera,
            .windowSize = .{ rl.getScreenWidth(), rl.getScreenHeight() },
            .windowPos = brk: {
                const winPos = rl.getWindowPosition();
                break :brk @intFromFloat(@Vector(2, f32){ winPos.x, winPos.y });
            },
            .editorMode = self.mode,
        };
    }

    const sessionFileName = "session.json";

    pub fn storeSession(self: *Context) !void {
        const file = try std.fs.cwd().createFile(sessionFileName, .{});
        defer file.close();
        const writer = file.writer();
        try std.json.stringify(self.createEditorSession(), .{}, writer);
    }

    pub fn restoreSession(self: *Context) !void {
        // Read session file
        const file = std.fs.cwd().openFile(sessionFileName, .{}) catch |err| {
            switch (err) {
                error{FileNotFound}.FileNotFound => {
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
            self.currentProject = Project.init(self.allocator, p);
            self.currentProject.?.assetsLibrary.setCurrentDirectory(self.allocator, ".") catch |err| {
                std.log.err("Could not set current directory in assets manager: {}", .{err});
            };
        }

        // if (parsed.value.openedEditorFilePath) |oefp| {
        //     const editor = Editor.openFileEx(self.allocator, oefp) catch |err| {
        //         std.log.err("Could not open file {s}: {}", .{ oefp, err });
        //         return err;
        //     };
        //     self.openedEditors.putAssumeCapacity(oefp, editor);
        //     self.currentEditor = 0;
        // }

        rl.setWindowSize(parsed.value.windowSize[0], parsed.value.windowSize[1]);
        rl.setWindowPosition(parsed.value.windowPos[0], parsed.value.windowPos[1]);

        self.camera = parsed.value.camera;
        self.mode = parsed.value.editorMode;
    }

    pub fn play(self: *Context) void {
        const editor = self.getCurrentEditor() orelse return;

        if (editor.documentType != .scene) return;

        self.playState = .starting;

        for (self.openedEditors.values()) |*openedEditor| {
            openedEditor.saveFile() catch |err| {
                std.log.err("Error saving {s}: {}", .{ openedEditor.document.filePath, err });
                self.playState = .errorStarting;
                return;
            };
        }

        const currentSceneFileName = editor.document.filePath;

        const zigCommand = std.fmt.allocPrint(self.allocator, "zig build run -- --scene \"{s}\"", .{currentSceneFileName}) catch unreachable;
        defer self.allocator.free(zigCommand);
        const command = &.{
            "cmd.exe",
            "/C",
            zigCommand,
        };
        var child = std.process.Child.init(command, self.allocator);
        child.cwd = std.fs.cwd().realpathAlloc(self.allocator, "../kottefolket") catch unreachable;
        defer self.allocator.free(child.cwd.?);

        const term = child.spawnAndWait() catch |err| {
            std.log.err("Error spawning game: {}", .{err});
            self.playState = .errorStarting;
            return;
        };

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

    pub fn selectFolder(self: *Context) ?[]const u8 {
        const folder = (nfd.openFolderDialog(null) catch return null) orelse return null;
        defer nfd.freePath(folder);
        return self.allocator.dupe(u8, folder) catch unreachable;
    }

    pub fn newProject(self: *Context) void {
        const folder = self.selectFolder() orelse return;
        defer self.allocator.free(folder);
        self.currentProject = Project.init(self.allocator, folder);
    }

    pub fn openProject(self: *Context) void {
        const folder = self.selectFolder() orelse return;
        defer self.allocator.free(folder);
        self.currentProject = Project.init(self.allocator, folder);
    }

    pub fn toAbsolutePathZ(
        allocator: Allocator,
        dir: std.fs.Dir,
        path: []const u8,
    ) [:0]const u8 {
        if (std.fs.path.isAbsolute(path)) return allocator.dupeZ(u8, path) catch unreachable;
        const dirPath = dir.realpathAlloc(allocator, ".") catch unreachable;
        defer allocator.free(dirPath);
        const absoluteFilePath = std.fs.path.joinZ(allocator, &.{ dirPath, path }) catch unreachable;
        return absoluteFilePath;
    }

    pub fn newDirectory(self: *Context, name: []const u8) void {
        var rootDir = self.currentProject.?.assetsLibrary.openRoot();
        defer rootDir.close();
        var targetDir = rootDir.openDir(
            self.currentProject.?.assetsLibrary.currentDirectory.?,
            .{},
        ) catch unreachable;
        defer targetDir.close();

        targetDir.makeDir(name) catch |err| {
            self.showError("Could not create directory {s} in {s}: {}", .{ name, self.currentProject.?.assetsLibrary.currentDirectory.?, err });
            return;
        };
    }

    pub fn newAsset(self: *Context, name: []const u8, comptime documentType: DocumentTag) void {
        const fileExtension = Document.getFileExtension(documentType);
        const fileName = std.mem.concat(self.allocator, u8, &.{ name, fileExtension }) catch unreachable;
        defer self.allocator.free(fileName);

        var rootDir = self.currentProject.?.assetsLibrary.openRoot();
        defer rootDir.close();
        var targetDir = rootDir.openDir(
            self.currentProject.?.assetsLibrary.currentDirectory.?,
            .{},
        ) catch unreachable;
        defer targetDir.close();

        // TODO: Catch file already exists

        const absoluteFilePathZ = toAbsolutePathZ(self.allocator, targetDir, fileName);
        defer self.allocator.free(absoluteFilePathZ);
        var document = Document.init(self.allocator, absoluteFilePathZ);
        errdefer document.deinit(self.allocator);

        document.newContent(self.allocator, documentType);
        document.content.?.load(absoluteFilePathZ);

        switch (document.content.?) {
            .scene => |*scene| {
                const entity = self.allocator.create(SceneEntity) catch unreachable;
                entity.* = SceneEntity.init(
                    self.allocator,
                    .{ 0, 0 },
                    .{ .tilemap = SceneEntityTilemap.init() },
                );
                scene.getEntities().append(self.allocator, entity) catch unreachable;
            },
            else => {},
        }

        document.save() catch |err| {
            self.showError("Could not save document {s}: {}", .{ absoluteFilePathZ, err });
            return;
        };

        self.documents.put(self.allocator, self.allocator.dupe(u8, absoluteFilePathZ) catch unreachable, document) catch |err| {
            self.showError("Could not store document in hash map {s}: {}", .{ absoluteFilePathZ, err });
            return;
        };

        const rootDirAbsolutePath = rootDir.realpathAlloc(self.allocator, ".") catch unreachable;
        defer self.allocator.free(rootDirAbsolutePath);
        const relativeToRoot = std.fs.path.relative(self.allocator, rootDirAbsolutePath, absoluteFilePathZ) catch unreachable;
        defer self.allocator.free(relativeToRoot);
        self.currentProject.?.assetsLibrary.appendNewFile(self.allocator, relativeToRoot);
    }

    pub fn showError(self: *Context, comptime fmt: []const u8, args: anytype) void {
        std.log.err(fmt, args);
        _ = std.fmt.bufPrintZ(&self.errorMessage, fmt, args) catch unreachable;
        self.isErrorDialogOpen = true;
    }

    pub fn openFileNode(self: *Context, file: Node.File) void {
        switch (file.documentType) {
            .scene, .tilemap, .animation => {
                var targetDir = self.currentProject.?.assetsLibrary.openRoot();
                defer targetDir.close();
                const absolutePath = toAbsolutePathZ(self.allocator, targetDir, file.path);
                defer self.allocator.free(absolutePath);
                self.openEditor(absolutePath);
            },
            .texture => {},
        }
    }

    pub fn openEditor(self: *Context, path: [:0]const u8) void {
        const entry = self.openedEditors.getOrPut(self.allocator, path) catch unreachable;

        if (!entry.found_existing) {
            if (self.requestDocument(path)) |document| {
                entry.value_ptr.* = Editor.init(document.*);
                entry.key_ptr.* = self.allocator.dupe(u8, path) catch unreachable;
                return;
            }

            // const existingDocument = self.documents.get(path);
            //
            // entry.key_ptr.* = self.allocator.dupe(u8, path) catch unreachable;
            //
            // if (existingDocument) |document| {
            //     entry.value_ptr.* = Editor.init(document);
            //     _ = self.requestDocument(document.filePath);
            //     return;
            // }
            //
            // entry.value_ptr.* = Editor.openFileEx(self.allocator, path) catch |err| {
            //     self.showError("Could not open editor with file {s}: {}", .{ path, err });
            //     _ = self.openedEditors.swapRemove(path);
            //     return;
            // };
            //
            // const document = entry.value_ptr.document;
            // self.documents.put(self.allocator, self.allocator.dupe(u8, path) catch unreachable, document) catch unreachable;
        }

        self.currentEditor = entry.index;
    }

    pub fn setCurrentDirectory(self: *Context, path: [:0]const u8) void {
        self.currentProject.?.assetsLibrary.setCurrentDirectory(self.allocator, path) catch |err| {
            self.showError("Could not set current directory {s}: {}", .{ path, err });
            return;
        };
    }

    pub fn saveEditorFile(self: *Context, editor: *Editor) void {
        editor.saveFile() catch |err| {
            self.showError("Could not save file {s}: {}", .{ editor.document.filePath, err });
            return;
        };
    }

    pub fn requestDocument(self: *Context, path: [:0]const u8) ?*Document {
        var targetDir = self.currentProject.?.assetsLibrary.openRoot();
        defer targetDir.close();
        const absolutePath = toAbsolutePathZ(self.allocator, targetDir, path);
        defer self.allocator.free(absolutePath);
        const entry = self.documents.getOrPut(self.allocator, absolutePath) catch unreachable;
        const documentType = Document.getTagByFilePath(path);

        if (!entry.found_existing) {
            entry.key_ptr.* = self.allocator.dupe(u8, absolutePath) catch unreachable;
            entry.value_ptr.* = Document.open(self.allocator, absolutePath, documentType) catch |err| {
                self.showError("Could not open document {s}: {}", .{ path, err });
                _ = self.documents.swapRemove(absolutePath);
                return null;
            };
        } else if (entry.value_ptr.content == null) {
            std.log.debug("Loading content for document {s}", .{path});
            entry.value_ptr.loadContent(self.allocator, documentType) catch |err| {
                self.showError("Could not load document {s}: {}", .{ path, err });
                return null;
            };
        }

        return entry.value_ptr;
    }

    pub fn requestTexture(self: *Context, path: [:0]const u8) ?rl.Texture2D {
        if (self.requestDocument(path)) |textureDocument| {
            return textureDocument.content.?.texture.getTexture();
        }

        return null;
    }

    pub fn openFileWithDialog(self: *Context, documentType: DocumentTag) ?Document {
        const fileName = (nfd.openFileDialog(Document.getFileFilter(documentType), null) catch return null) orelse return null;
        defer nfd.freePath(fileName);
        const document = self.requestDocument(fileName) orelse return null;
        return document.*;
    }
};
