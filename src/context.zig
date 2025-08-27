const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const Vector = lib.Vector;
const VectorInt = lib.VectorInt;
const Project = lib.Project;
const ProjectOptions = lib.project.ProjectOptions;
const Editor = lib.Editor;
const EditorSession = lib.editor.session.EditorSession;
const EditorSessionDocument = lib.editor.session.EditorSessionDocument;
const Document = lib.documents.Document;
const DocumentTag = lib.documents.DocumentTag;
const DocumentContent = lib.documents.DocumentContent;
const DocumentError = lib.documents.DocumentError;
const Node = lib.assetsLibrary.Node;
const Tool = lib.tools.Tool;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const UUID = lib.UUIDSerializable;
const IdArrayHashMap = lib.IdArrayHashMap;
const SceneMap = lib.sceneMap.SceneMap;
const AssetIndex = lib.AssetIndex;
const SceneEntity = lib.scene.SceneEntity;
const SceneEntityTilemap = lib.scene.SceneEntityTilemap;
const generateThumbnail = lib.thumbnail.generateThumbnail;
const nfd = @import("nfd");

pub const PlayState = enum {
    notRunning,
    startNextFrame,
    starting,
    errorStarting,
    running,
    crash,
};

pub const ContextError = error{
    DocumentTagNotMatching,
    MissingDocumentFilePath,
    NoProject,
    NoCurrentDirectory,
};

pub const Context = struct {
    isRunning: bool = true,

    allocator: Allocator,

    openedEditors: IdArrayHashMap(Editor),
    currentEditor: ?UUID = null,
    editorToBeOpened: ?UUID = null,
    documents: IdArrayHashMap(Document),

    backgroundColor: rl.Color = rl.Color.init(125, 125, 155, 255),
    isDemoWindowOpen: bool = false,
    isDemoWindowEnabled: bool = false,

    scale: VectorInt = 4,
    scaleV: Vector = .{ 4, 4 },

    currentProject: ?Project,

    tools: [2]Tool = .{
        Tool.init("brush", .{ .brush = BrushTool.init() }),
        Tool.init("select", .{ .select = SelectTool.init() }),
    },

    tilesetId: UUID = undefined,
    exitTexture: rl.Texture2D,
    entranceTexture: rl.Texture2D,

    playState: PlayState = .notRunning,

    reusableTextBuffer: [256:0]u8 = undefined,
    errorMessageBuffer: [1024:0]u8 = undefined,
    errorMessage: [:0]const u8 = undefined,
    isErrorDialogOpen: bool = false,

    isNewDirectoryDialogOpen: bool = false,
    isNewAssetDialogOpen: ?DocumentTag = null,
    isDialogFirstRender: bool = false,
    // TODO: Whenever we close a document, check if we need to set this to null
    newAssetInputTarget: ?struct { documentId: UUID, assetInput: *?UUID } = null,

    deleteNodeTarget: ?*Node = null,
    isDeleteNodeDialogOpen: bool = false,

    updateThumbnailForCurrentDocument: bool = false,

    iconsTexture: ?rl.Texture2D = null,

    sceneMap: SceneMap = .init(),
    sceneMapWindowRenderTexture: rl.RenderTexture = undefined,
    isSceneMapWindowOpen: bool = false,
    sceneMapCamera: rl.Camera2D = .{
        .zoom = 1,
        .offset = rl.Vector2.init(0, 0),
        .target = rl.Vector2.init(0, 0),
        .rotation = 0,
    },

    pub fn init(allocator: Allocator) Context {
        const rootDir = std.fs.cwd().realpathAlloc(allocator, ".") catch unreachable;
        defer allocator.free(rootDir);

        return Context{
            .allocator = allocator,
            .openedEditors = .empty,
            .documents = .empty,
            .exitTexture = undefined,
            .entranceTexture = undefined,
            .currentProject = null,
            .iconsTexture = rl.loadTexture("assets/icons.png") catch |err| brk: {
                std.log.err("Could not load icons texture: {}", .{err});
                break :brk null;
            },
            .sceneMapWindowRenderTexture = rl.loadRenderTexture(800, 600) catch unreachable,
        };
    }

    pub fn deinit(self: *Context) void {
        self.deinitContextProject();
        self.deinitContextEditor();
        if (self.iconsTexture) |iconsTexture| rl.unloadTexture(iconsTexture);
        self.iconsTexture = null;
        self.sceneMap.deinit(self.allocator);
    }

    // Session {{{

    const sessionFileName = "session.json";

    fn createEditorSession(self: *Context) EditorSession {
        return EditorSession{
            .currentProject = if (self.currentProject) |p| self.allocator.dupe(u8, p.getRootDirPath()) catch unreachable else null,
            .openedEditor = self.currentEditor,
            .openedDocuments = self.createEditorSessionDocuments(),
            .windowSize = .{ rl.getScreenWidth(), rl.getScreenHeight() },
            .windowPos = brk: {
                const winPos = rl.getWindowPosition();
                break :brk @intFromFloat(@Vector(2, f32){ winPos.x, winPos.y });
            },
        };
    }

    fn createEditorSessionDocuments(self: *Context) []EditorSessionDocument {
        const len = self.openedEditors.map.count();
        const documents = self.allocator.alloc(EditorSessionDocument, len) catch unreachable;

        for (0..len) |i| {
            documents[i] = .{
                .id = self.openedEditors.map.keys()[i],
                .camera = self.openedEditors.map.values()[i].camera,
            };
        }

        return documents;
    }

    pub fn storeSession(self: *Context) !void {
        const file = try std.fs.cwd().createFile(sessionFileName, .{});
        defer file.close();
        var buffer: [1024 * 4]u8 = undefined;
        var writer = file.writer(&buffer);
        defer writer.interface.flush() catch |err| std.log.err("Could not flush: {}", .{err});
        var session = self.createEditorSession();
        try writer.interface.print("{f}", .{std.json.fmt(session, .{})});
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
        var fileReaderBuffer: [1024 * 4]u8 = undefined;
        var reader = file.reader(&fileReaderBuffer);
        var jsonReader = std.json.Reader.init(self.allocator, &reader.interface);
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

        for (parsed.value.openedDocuments) |document| {
            self.openEditorById(document.id);
            const editor = self.openedEditors.map.getPtr(document.id);
            if (editor) |e| e.camera = document.camera;
        }

        if (parsed.value.openedEditor) |id| {
            self.openEditorById(id);
        }

        rl.setWindowSize(parsed.value.windowSize[0], parsed.value.windowSize[1]);
        rl.setWindowPosition(parsed.value.windowPos[0], parsed.value.windowPos[1]);

        const exitImage = rl.genImageColor(1, 1, rl.Color.white);
        const entranceImage = rl.genImageColor(1, 1, rl.Color.yellow);
        self.exitTexture = try rl.loadTextureFromImage(exitImage);
        self.entranceTexture = try rl.loadTextureFromImage(entranceImage);
    }

    // }}}

    // Project {{{

    pub fn newProject(self: *Context) void {
        const folder = self.selectFolder() orelse return;
        defer self.allocator.free(folder);
        self.setProject(.init(self.allocator, folder));
    }

    pub fn openProject(self: *Context) void {
        const folder = self.selectFolder() orelse return;
        defer self.allocator.free(folder);
        self.setProject(.init(self.allocator, folder));
    }

    pub fn saveProject(self: *Context) !void {
        const p = &(self.currentProject orelse return ContextError.NoProject);
        try p.saveOptions(self.allocator);
    }

    pub fn closeProject(self: *Context) void {
        self.setProject(null);
    }

    pub fn setProject(self: *Context, project: ?Project) void {
        if (self.currentProject) |*p| {
            self.closeEditors();
            p.deinit(self.allocator);
            self.unloadDocuments();
        }

        self.currentProject = project;

        if (self.currentProject) |_| {
            self.loadProject() catch |err| {
                self.showError("Could not load project: {}", .{err});
            };
        }
    }

    /// Project needs to be set before this is called.
    fn loadProject(self: *Context) !void {
        const p = &(self.currentProject orelse return ContextError.NoProject);
        self.documents.map.ensureTotalCapacity(self.allocator, 100000) catch unreachable;
        p.loadOptions(self.allocator) catch |err| {
            std.log.err("Could not load project options: {}", .{err});
        };
        p.loadIndex(self.allocator) catch |err| {
            std.log.err("Could not load/build asset index: {}", .{err});
        };
        self.setCurrentDirectory(".");
        self.sceneMap.generate(self) catch |err| {
            std.log.err("Could not generate scene map: {}", .{err});
        };
    }

    pub fn deinitContextProject(self: *Context) void {
        self.setProject(null);
    }

    pub fn upgradeProject(self: *Context) void {
        const p = &(self.currentProject orelse return);

        for (p.assetIndex.hashMap.map.keys()) |id| {
            const document = self.requestDocumentById(id) orelse continue;
            document.save(p) catch |err| {
                self.showError("Could not upgrade document {?s}: {}", .{ self.getFilePathById(id), err });
                return;
            };
        }
    }

    const defaultTileSize: Vector = std.meta.fieldInfo(
        ProjectOptions,
        .tileSize,
    ).defaultValue() orelse .{ 16, 16 };

    pub fn getTileSize(self: *Context) Vector {
        const p = &(self.currentProject orelse return defaultTileSize);
        return p.options.tileSize;
    }

    const defaultTilesetPadding: u32 = std.meta.fieldInfo(
        ProjectOptions,
        .tilesetPadding,
    ).defaultValue() orelse 4;

    pub fn getTilesetPadding(self: *Context) u32 {
        const p = &(self.currentProject orelse return 4);
        return p.options.tilesetPadding;
    }

    // }}}

    // Editor {{{

    pub fn getCurrentEditor(self: *Context) ?*Editor {
        const id = self.currentEditor orelse return null;
        return self.openedEditors.map.getPtr(id);
    }

    pub fn closeEditorById(self: *Context, id: UUID) void {
        self.unloadDocumentById(id);
        var indexToOpen: ?usize = null;
        if (self.currentEditor) |ce| {
            if (ce.uuid == id.uuid) {
                self.currentEditor = null;

                const cei = for (self.openedEditors.map.keys(), 0..) |k, i| {
                    if (k.uuid == id.uuid) {
                        break i;
                    }
                } else unreachable;

                indexToOpen = if (cei == self.openedEditors.map.count() - 1) if (cei == 0) null else cei - 1 else cei;
            }
        }
        var entry = self.openedEditors.map.fetchOrderedRemove(id) orelse return;
        entry.value.deinit(self.allocator);
        if (indexToOpen) |i| {
            const idToOpen = self.openedEditors.map.keys()[i];
            self.openEditorById(idToOpen);
        }
    }

    pub fn closeEditorByNode(self: *Context, node: Node) void {
        switch (node) {
            .file => |file| {
                if (file.id) |id| self.closeEditorById(id);
            },
            .directory => {},
        }
    }

    pub fn closeEditorsByIds(self: *Context, ids: []const UUID) void {
        for (ids) |id| self.closeEditorById(id);
    }

    pub fn closeEditors(self: *Context) void {
        for (self.openedEditors.map.values()) |*editor| {
            self.unloadDocumentById(editor.document.getId());
            editor.deinit(self.allocator);
        }

        self.openedEditors.map.clearAndFree(self.allocator);
        self.currentEditor = null;
    }

    pub fn closeEditorsExcept(self: *Context, id: UUID) void {
        var ids = std.ArrayListUnmanaged(UUID).initCapacity(self.allocator, 100) catch unreachable;
        defer ids.deinit(self.allocator);

        for (self.openedEditors.map.values()) |*editor| {
            const eid = editor.document.getId();
            if (eid.uuid != id.uuid) {
                ids.append(self.allocator, eid) catch unreachable;
            }
        }

        for (ids.items) |eid| self.closeEditorById(eid);
    }

    pub fn openFileNode(self: *Context, file: Node.File) void {
        switch (file.documentType) {
            .scene, .tilemap, .animation, .entityType => {
                if (file.id) |id| self.openEditorById(id);
            },
            .texture, .sound, .font => {},
        }
    }

    pub fn openEditorById(self: *Context, id: UUID) void {
        const entry = self.openedEditors.map.getOrPut(self.allocator, id) catch unreachable;

        if (!entry.found_existing) {
            const result = self.requestDocumentById(id);

            if (result) |document| {
                if (document.state) |_| {
                    if (document.content == null) {
                        _ = self.openedEditors.map.orderedRemove(id);
                        return;
                    }
                    entry.value_ptr.* = Editor.init(document.*);
                    self.currentEditor = id;
                    return;
                } else |_| {
                    _ = self.openedEditors.map.orderedRemove(id);
                }
            }

            // Error loading document
            _ = self.openedEditors.map.swapRemove(id);
            self.currentEditor = null;
            return;
        } else {
            self.currentEditor = id;
        }
    }

    pub fn openEditorByIdAtEndOfFrame(self: *Context, id: UUID) void {
        self.editorToBeOpened = id;
    }

    pub fn saveEditorFile(self: *Context, editor: *Editor) void {
        editor.saveFile(&self.currentProject.?) catch |err| {
            const filePath = self.getFilePathById(editor.document.getId());
            self.showError("Could not save file {?s}: {}", .{ filePath, err });
            return;
        };
    }

    pub fn deinitContextEditor(self: *Context) void {
        for (&self.tools) |*tool| tool.deinit(self.allocator);
    }

    // }}}

    // {{{ Play

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

    // }}}

    // New Directory {{{

    pub fn newDirectory(self: *Context, name: []const u8) void {
        const p = &(self.currentProject orelse return);
        var currentDir = self.openCurrentDirectory() catch return;
        defer currentDir.close();
        const cd = p.assetsLibrary.currentDirectory orelse unreachable;

        currentDir.makeDir(name) catch |err| {
            self.showError("Could not create directory {s} in {s}: {}", .{ name, cd, err });
            return;
        };

        const relativeToRoot = std.fs.path.joinZ(self.allocator, &.{ cd, name }) catch unreachable;
        defer self.allocator.free(relativeToRoot);

        p.assetsLibrary.appendNewDirectory(self.allocator, relativeToRoot);
    }

    // }}}

    // New Asset {{{

    pub const NewAssetError = error{AlreadyExists};

    pub fn newAsset(
        self: *Context,
        name: []const u8,
        comptime documentType: DocumentTag,
    ) !struct { *Document, *std.meta.TagPayload(DocumentContent, documentType) } {
        const project, const currentDirectory = try self.getProjectAndCurrentDirectory();

        const normalized = try getNormalizedAssetPath(self, currentDirectory, name, documentType);
        defer self.allocator.free(normalized);

        try self.checkFileExists(project, normalized);

        var document = try self.createDocument(documentType, name, normalized);
        errdefer document.deinit(self.allocator);
        const documentId = document.getId();

        try self.storeDocument(project, document, normalized);

        const storedDocument = self.documents.map.getPtr(documentId) orelse unreachable;
        const content = &@field(storedDocument.content.?, @tagName(documentType));

        return .{ storedDocument, content };
    }

    fn getProjectAndCurrentDirectory(self: *Context) !struct { *Project, [:0]const u8 } {
        const project = &(self.currentProject orelse return ContextError.NoProject);
        const currentDirectory = project.assetsLibrary.currentDirectory orelse return ContextError.NoCurrentDirectory;

        return .{ project, currentDirectory };
    }

    fn getNormalizedAssetPath(
        self: *Context,
        currentDirectory: []const u8,
        assetName: []const u8,
        comptime documentType: DocumentTag,
    ) ![:0]const u8 {
        const fileExtension = Document.getFileExtension(documentType);
        const fileName = try std.mem.concat(self.allocator, u8, &.{ assetName, fileExtension });
        defer self.allocator.free(fileName);
        const relativeToRoot = try std.fs.path.joinZ(self.allocator, &.{
            currentDirectory,
            fileName,
        });
        defer self.allocator.free(relativeToRoot);
        return try self.allocator.dupeZ(u8, AssetIndex.normalizeIndex(relativeToRoot));
    }

    fn checkFileExists(self: *Context, project: *Project, filePath: []const u8) !void {
        var dir = project.assetsLibrary.openRoot();
        defer dir.close();

        if (dir.openFile(filePath, .{}) catch |err|
            switch (err) {
                error.FileNotFound => null,
                else => {
                    self.showError("Could not access file {s}: {}", .{ filePath, err });
                    return err;
                },
            }) |f|
        {
            self.showError("File already exists: {s}", .{filePath});
            f.close();
            return NewAssetError.AlreadyExists;
        }
    }

    fn createDocument(
        self: *Context,
        comptime documentType: DocumentTag,
        name: []const u8,
        filePath: [:0]const u8,
    ) !Document {
        var document = Document.init();
        errdefer document.deinit(self.allocator);
        document.newContent(self.allocator, documentType);
        document.content.?.load(filePath);
        self.onNewAsset(&document, name) catch |err| {
            self.showError("Could not create {s} asset {s}: {}", .{ @tagName(documentType), filePath, err });
            return err;
        };

        return document;
    }

    fn onNewAsset(self: *Context, document: *Document, name: []const u8) !void {
        // Special case for creating new scene documents;
        // Add a tilemap entity as the first entity.
        switch (document.content.?) {
            .scene => |*scene| {
                const entity = try self.allocator.create(SceneEntity);
                errdefer self.allocator.destroy(entity);
                entity.* = SceneEntity.init(
                    .{ 0, 0 },
                    .{ .tilemap = SceneEntityTilemap.init() },
                );
                try scene.getEntities().append(self.allocator, entity);
            },
            .entityType => |*entityType| {
                entityType.getName().setFmt("{s}", .{name});
            },
            else => {},
        }
    }

    fn storeDocument(
        self: *Context,
        project: *Project,
        document: Document,
        filePath: [:0]const u8,
    ) !void {
        const documentId = document.getId();

        self.documents.map.putAssumeCapacity(documentId, document);
        errdefer _ = self.documents.map.swapRemove(documentId);

        project.assetIndex.addIndex(self.allocator, documentId, filePath);
        errdefer _ = project.assetIndex.removeIndex(self.allocator, documentId);

        document.save(project) catch |err| {
            self.showError("Could not save document {s}: {}", .{ filePath, err });
            return err;
        };

        project.assetsLibrary.appendNewFile(self.allocator, project.assetIndex, filePath);

        _ = self.saveIndex();
    }

    // }}}

    // Document {{{

    pub fn requestDocumentById(self: *Context, id: UUID) ?*Document {
        const entry = self.documents.map.getOrPutAssumeCapacity(id);

        if (!entry.found_existing) {
            std.log.debug("Requested document {f} not found, loading", .{id});

            const path = self.getFilePathById(id) orelse {
                entry.value_ptr.* = .initWithError(DocumentError.IndexNotFound);
                self.showError("Could not find document in index with id {f}", .{id});
                return null;
            };
            entry.value_ptr.* = Document.open(self.allocator, &self.currentProject.?, path) catch |err| {
                self.showError("Could not open document {s}: {}", .{ path, err });
                return null;
            };
        } else if (if (entry.value_ptr.state) |state| state == .unloaded else |_| false) {
            std.log.debug("Requested document {f} found with no content, loading", .{id});
            const filePath = self.getFilePathById(id) orelse return null;
            std.log.debug("Loading content for document {s}", .{filePath});
            entry.value_ptr.loadContent(self.allocator, &self.currentProject.?, filePath) catch |err| {
                self.showError("Could not load document: {}", .{err});
                return null;
            };
        } else {
            _ = entry.value_ptr.state catch return null;
        }

        return entry.value_ptr;
    }

    pub fn requestDocumentTypeById(
        self: *Context,
        comptime tag: DocumentTag,
        id: UUID,
    ) !?*std.meta.TagPayload(DocumentContent, tag) {
        const document = self.requestDocumentById(id) orelse return null;

        switch (document.content.?) {
            tag => |*content| return content,
            else => return ContextError.DocumentTagNotMatching,
        }
    }

    pub fn requestTextureById(self: *Context, id: UUID) !?*rl.Texture2D {
        const content = try self.requestDocumentTypeById(.texture, id) orelse return null;
        return content.getTexture();
    }

    pub fn unloadDocumentById(self: *Context, id: UUID) void {
        var entry = self.documents.map.fetchSwapRemove(id) orelse return;
        entry.value.deinit(self.allocator);
    }

    pub fn unloadDocuments(self: *Context) void {
        for (self.documents.map.values()) |*document| {
            document.deinit(self.allocator);
        }

        self.documents.map.clearAndFree(self.allocator);
    }

    pub fn reloadDocumentById(self: *Context, id: UUID) void {
        self.unloadDocumentById(id);
        _ = self.requestDocumentById(id);
    }

    pub fn saveDocument(self: *Context, id: UUID) void {
        const p = &self.currentProject orelse return;
        const editor = self.openedEditors.map.getPtr(id) orelse return;
        editor.saveFile(p) catch |err| {
            const filePath = self.getFilePathById(id);
            self.showError("Could not save file {?s}: {}", .{ filePath, err });
            return;
        };
    }

    pub fn saveAll(self: *Context) void {
        for (self.openedEditors.map.values()) |*editor| {
            self.saveEditorFile(editor);
        }
    }

    // }}}

    // Thumbnail {{{

    pub fn requestThumbnailById(self: *Context, id: UUID) !?*rl.Texture2D {
        const p = &(self.currentProject orelse return null);
        return p.requestThumbnailById(self.allocator, id);
    }

    pub fn updateThumbnailById(self: *Context, id: UUID) void {
        const p = &(self.currentProject orelse return);
        const path = self.getFilePathById(id) orelse return;
        const document = self.requestDocumentById(id) orelse return;
        const image = generateThumbnail(self, document) catch |err| {
            self.showError("Could not update thumbnail for document {s}: {}", .{ path, err });
            return;
        } orelse return;
        defer rl.unloadImage(image);

        p.updateThumbnailById(self.allocator, id, image) catch |err| {
            self.showError("Could not update thumbnail for document {s}: {}", .{ path, err });
        };
    }

    // }}}

    // File Dialog {{{

    pub fn selectFolder(self: *Context) ?[]const u8 {
        const folder = (nfd.openFolderDialog(null) catch return null) orelse return null;
        defer nfd.freePath(folder);
        return self.allocator.dupe(u8, folder) catch unreachable;
    }

    pub fn openFileWithDialog(self: *Context, documentType: DocumentTag) ?Document {
        const fileName = (nfd.openFileDialog(Document.getFileFilter(documentType), null) catch return null) orelse return null;
        defer nfd.freePath(fileName);
        const id = self.getIdByFilePath(fileName) orelse return null;
        const document = self.requestDocumentById(id) orelse return null;
        return document.*;
    }

    pub fn getFileNameWithDialog(self: *Context, fileFilter: ?[:0]const u8) ?[:0]const u8 {
        const fileName = (nfd.openFileDialog(fileFilter, null) catch return null) orelse return null;
        defer nfd.freePath(fileName);
        return self.allocator.dupeZ(u8, fileName) catch unreachable;
    }

    // }}}

    // Assets Manager {{{

    pub fn openCurrentDirectory(self: *Context) !std.fs.Dir {
        const p = self.currentProject orelse return ContextError.NoProject;
        return p.assetsLibrary.openCurrentDirectory(self.allocator) catch |err| {
            self.showError("Could not open current directory {?s}: {}", .{ p.assetsLibrary.currentDirectory, err });
            return err;
        };
    }

    pub fn setCurrentDirectory(self: *Context, path: [:0]const u8) void {
        self.currentProject.?.setCurrentDirectory(self.allocator, path) catch |err| {
            self.showError("Could not set current directory {s}: {}", .{ path, err });
            return;
        };
    }

    pub fn getIdByFilePath(self: *Context, filePath: [:0]const u8) ?UUID {
        const p = self.currentProject orelse return null;
        return p.assetIndex.getId(filePath);
    }

    pub fn getFilePathById(self: *Context, id: UUID) ?[:0]const u8 {
        const p = self.currentProject orelse return null;
        return p.assetIndex.getIndex(id);
    }

    pub fn getIdsByDocumentType(self: *Context, comptime documentType: DocumentTag) []UUID {
        const p = &(self.currentProject orelse return &.{});
        return p.assetIndex.getIdsByDocumentType(self.allocator, documentType);
    }

    pub fn getNodeById(self: *Context, id: UUID) ?Node {
        const p = self.currentProject orelse return null;
        return p.assetsLibrary.getNodeById(id);
    }

    pub fn openNewDirectoryDialog(context: *Context) void {
        context.isNewDirectoryDialogOpen = true;
        context.isDialogFirstRender = true;
    }

    pub fn openNewAssetDialog(context: *Context, documentType: DocumentTag) void {
        context.isNewAssetDialogOpen = documentType;
        context.isDialogFirstRender = true;
    }

    pub fn closeNewAssetAndDirectoryDialog(context: *Context) void {
        context.isNewDirectoryDialogOpen = false;
        context.isNewAssetDialogOpen = null;
        context.isDialogFirstRender = false;
        context.newAssetInputTarget = null;
        context.reusableTextBuffer[0] = 0;
    }

    // }}}

    // Asset Index {{{

    // Returns true if successful
    pub fn saveIndex(self: *Context) bool {
        const p = self.currentProject orelse return false;
        std.log.debug("Updating index", .{});
        p.saveIndex() catch |err| {
            std.log.err("Could not save asset index: {}", .{err});
            return false;
        };
        return true;
    }

    pub fn getSceneReferencingTilemap(self: *Context, tilemapId: UUID) ?UUID {
        const p = self.currentProject orelse return null;
        const sceneIds = p.assetIndex.getIdsByDocumentType(self.allocator, .scene);
        defer self.allocator.free(sceneIds);

        for (sceneIds) |sceneId| {
            const document = (self.requestDocumentTypeById(.scene, sceneId) catch continue) orelse continue;
            for (document.getEntities().items) |entity| {
                switch (entity.type) {
                    .tilemap => |tilemap| {
                        if (tilemap.tilemapId) |id| if (id.uuid == tilemapId.uuid) return sceneId;
                    },
                    else => continue,
                }
            }
        }

        return null;
    }

    // }}}

    // Error {{{

    pub fn showError(self: *Context, comptime fmt: []const u8, args: anytype) void {
        std.log.err(fmt, args);
        self.errorMessage = std.fmt.bufPrintZ(&self.errorMessageBuffer, fmt, args) catch unreachable;
        self.isErrorDialogOpen = true;
    }

    // }}}
};
