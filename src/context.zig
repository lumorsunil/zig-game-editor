const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("root").lib;
const Vector = lib.Vector;
const VectorInt = lib.VectorInt;
const Project = lib.Project;
const AssetIndex = lib.AssetIndex;
const EditorSession = lib.EditorSession;
const Editor = lib.Editor;
const AssetsLibrary = lib.AssetsLibrary;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const DocumentContent = lib.DocumentContent;
const DocumentError = lib.DocumentError;
const Node = lib.Node;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityTilemap = lib.documents.scene.SceneEntityTilemap;
const Tool = lib.Tool;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const nfd = @import("nfd");
const UUID = lib.UUIDSerializable;
const IdArrayHashMap = lib.IdArrayHashMap;
const drawTilemap = lib.drawTilemap;

pub const ContextError = error{ DocumentTagNotMatching, MissingDocumentFilePath };

pub const Context = struct {
    allocator: Allocator,

    openedEditors: IdArrayHashMap(Editor),
    currentEditor: ?UUID = null,
    documents: IdArrayHashMap(Document),

    backgroundColor: rl.Color = rl.Color.init(125, 125, 155, 255),
    isDemoWindowOpen: bool = false,
    isDemoWindowEnabled: bool = false,
    camera: rl.Camera2D,

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

    deleteNodeTarget: ?*Node = null,
    isDeleteNodeDialogOpen: bool = false,

    updateThumbnailForCurrentDocument: bool = false,

    iconsTexture: ?rl.Texture2D = null,

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
        const rootDir = std.fs.cwd().realpathAlloc(allocator, ".") catch unreachable;
        defer allocator.free(rootDir);

        return Context{
            .allocator = allocator,
            .openedEditors = .empty,
            .documents = .empty,
            .camera = rl.Camera2D{
                .target = .{ .x = 0, .y = 0 },
                .offset = .{ .x = 0, .y = 0 },
                .rotation = 0,
                .zoom = 1,
            },
            .exitTexture = undefined,
            .entranceTexture = undefined,
            .currentProject = null,
            .iconsTexture = rl.loadTexture("assets/icons.png") catch |err| brk: {
                std.log.err("Could not load icons texture: {}", .{err});
                break :brk null;
            },
        };
    }

    pub fn deinit(self: *Context) void {
        self.setProject(null);
        for (&self.tools) |*tool| tool.deinit(self.allocator);
        if (self.iconsTexture) |iconsTexture| rl.unloadTexture(iconsTexture);
        self.iconsTexture = null;
    }

    pub fn getCurrentEditor(self: *Context) ?*Editor {
        const id = self.currentEditor orelse return null;
        return self.openedEditors.map.getPtr(id);
    }

    fn createEditorSession(self: *Context) EditorSession {
        return EditorSession{
            .currentProject = if (self.currentProject) |p| self.allocator.dupe(u8, p.assetsLibrary.root) catch unreachable else null,
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

    const sessionFileName = "session.json";

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

    pub fn play(self: *Context) void {
        self.playInner() catch |err| {
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

        const zigCommand = try std.fmt.allocPrint(self.allocator, "zig build run -- --scene \"{s}\"", .{currentSceneFileName});
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

    pub fn selectFolder(self: *Context) ?[]const u8 {
        const folder = (nfd.openFolderDialog(null) catch return null) orelse return null;
        defer nfd.freePath(folder);
        return self.allocator.dupe(u8, folder) catch unreachable;
    }

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

    pub fn closeProject(self: *Context) void {
        self.setProject(null);
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

    fn closeEditors(self: *Context) void {
        for (self.openedEditors.map.values()) |*editor| {
            self.unloadDocumentById(editor.document.getId());
            editor.deinit(self.allocator);
        }

        self.openedEditors.map.clearAndFree(self.allocator);
        self.currentEditor = null;
    }

    fn setProject(self: *Context, project: ?Project) void {
        if (self.currentProject) |*p| {
            self.closeEditors();
            p.deinit(self.allocator);
            self.unloadDocuments();
        }
        self.currentProject = project;

        if (self.currentProject) |_| {
            self.loadProject();
        }
    }

    /// Project needs to be set before this is called.
    fn loadProject(self: *Context) void {
        self.documents.map.ensureTotalCapacity(self.allocator, 100000) catch unreachable;
        self.currentProject.?.loadIndex(self.allocator) catch |err| {
            std.log.err("Could not load/build asset index: {}", .{err});
        };
        self.setCurrentDirectory(".");
    }

    pub fn newDirectory(self: *Context, name: []const u8) void {
        const p = &(self.currentProject orelse return);
        const cd = p.assetsLibrary.currentDirectory orelse return;
        var rootDir = p.assetsLibrary.openRoot();
        defer rootDir.close();
        var targetDir = rootDir.openDir(cd, .{}) catch unreachable;
        defer targetDir.close();

        targetDir.makeDir(name) catch |err| {
            self.showError("Could not create directory {s} in {s}: {}", .{ name, cd, err });
            return;
        };

        const relativeToRoot = std.fs.path.joinZ(self.allocator, &.{ cd, name }) catch unreachable;
        defer self.allocator.free(relativeToRoot);

        p.assetsLibrary.appendNewDirectory(self.allocator, relativeToRoot);
    }

    pub fn newAsset(
        self: *Context,
        name: []const u8,
        comptime documentType: DocumentTag,
    ) ?*std.meta.TagPayload(DocumentContent, documentType) {
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

        const relativeToRoot = std.fs.path.joinZ(self.allocator, &.{ self.currentProject.?.assetsLibrary.currentDirectory.?, fileName }) catch unreachable;
        defer self.allocator.free(relativeToRoot);
        const normalized = AssetIndex.normalizeIndex(relativeToRoot);

        var document = Document.init();
        errdefer document.deinit(self.allocator);
        document.newContent(self.allocator, documentType);
        self.documents.map.putAssumeCapacity(document.getId(), document);

        const storedDocument = self.documents.map.getPtr(document.getId()) orelse unreachable;
        const content = &@field(storedDocument.content.?, @tagName(documentType));
        self.currentProject.?.assetIndex.addIndex(self.allocator, content.getId(), normalized);
        storedDocument.content.?.load(normalized);

        switch (storedDocument.content.?) {
            .scene => |*scene| {
                const entity = self.allocator.create(SceneEntity) catch unreachable;
                entity.* = SceneEntity.init(
                    .{ 0, 0 },
                    .{ .tilemap = SceneEntityTilemap.init() },
                );
                scene.getEntities().append(self.allocator, entity) catch unreachable;
            },
            else => {},
        }

        storedDocument.save(&self.currentProject.?) catch |err| {
            _ = self.documents.map.swapRemove(content.getId());
            storedDocument.deinit(self.allocator);
            _ = self.currentProject.?.assetIndex.removeIndex(self.allocator, content.getId());
            self.showError("Could not save document {s}: {}", .{ normalized, err });
            return null;
        };

        self.currentProject.?.assetsLibrary.appendNewFile(self.allocator, self.currentProject.?.assetIndex, normalized);

        // Update the asset index to match the new path for the node id
        _ = self.saveIndex();

        return content;
    }

    pub fn showError(self: *Context, comptime fmt: []const u8, args: anytype) void {
        std.log.err(fmt, args);
        self.errorMessage = std.fmt.bufPrintZ(&self.errorMessageBuffer, fmt, args) catch unreachable;
        self.isErrorDialogOpen = true;
    }

    pub fn openFileNode(self: *Context, file: Node.File) void {
        switch (file.documentType) {
            .scene, .tilemap, .animation, .entityType => {
                self.openEditor(file.path);
            },
            .texture => {},
        }
    }

    pub fn openEditor(self: *Context, path: [:0]const u8) void {
        const id = self.getIdByFilePath(path) orelse {
            std.log.warn("Could not open document, id not found for {s}", .{path});
            return;
        };
        self.openEditorById(id);
    }

    pub fn openEditorById(self: *Context, id: UUID) void {
        const entry = self.openedEditors.map.getOrPut(self.allocator, id) catch unreachable;

        if (!entry.found_existing) {
            if (self.requestDocumentById(id)) |document| {
                entry.value_ptr.* = Editor.init(document.*);
            } else {
                _ = self.openedEditors.map.swapRemove(id);
                self.currentEditor = null;
                return;
            }
        }

        self.currentEditor = id;
    }

    pub fn setCurrentDirectory(self: *Context, path: [:0]const u8) void {
        self.currentProject.?.setCurrentDirectory(self.allocator, path) catch |err| {
            self.showError("Could not set current directory {s}: {}", .{ path, err });
            return;
        };
    }

    pub fn saveEditorFile(self: *Context, editor: *Editor) void {
        editor.saveFile(&self.currentProject.?) catch |err| {
            const filePath = self.getFilePathById(editor.document.getId());
            self.showError("Could not save file {?s}: {}", .{ filePath, err });
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

    pub fn requestDocumentById(self: *Context, id: UUID) ?*Document {
        const entry = self.documents.map.getOrPutAssumeCapacity(id);

        if (!entry.found_existing) {
            std.log.debug("Requested document {} not found, loading", .{id});

            const path = self.getFilePathById(id) orelse {
                entry.value_ptr.* = .initWithError(DocumentError.IndexNotFound);
                self.showError("Could not find document in index with id {}", .{id});
                return null;
            };
            entry.value_ptr.* = Document.open(self.allocator, &self.currentProject.?, path) catch |err| {
                self.showError("Could not open document {s}: {}", .{ path, err });
                return null;
            };
        } else if (entry.value_ptr.state == .unloaded) {
            std.log.debug("Requested document {} found with no content, loading", .{id});
            const filePath = self.getFilePathById(id) orelse return null;
            std.log.debug("Loading content for document {?s}", .{filePath});
            entry.value_ptr.loadContent(self.allocator, &self.currentProject.?, filePath) catch |err| {
                self.showError("Could not load document: {}", .{err});
                return null;
            };
        } else if (entry.value_ptr.state == .err) {
            return null;
        }

        return entry.value_ptr;
    }

    pub fn requestDocument(self: *Context, path: [:0]const u8) ?*Document {
        const id = self.getIdByFilePath(path) orelse return null;
        return self.requestDocumentById(id);
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

    pub fn requestDocumentType(
        self: *Context,
        comptime tag: DocumentTag,
        path: [:0]const u8,
    ) !?*std.meta.TagPayload(DocumentContent, tag) {
        const id = self.getIdByFilePath(path) orelse return null;
        return try self.requestDocumentTypeById(tag, id);
    }

    pub fn requestTextureById(self: *Context, id: UUID) !?*rl.Texture2D {
        const content = try self.requestDocumentTypeById(.texture, id) orelse return null;
        return content.getTexture();
    }

    pub fn requestTexture(self: *Context, path: [:0]const u8) !?*rl.Texture2D {
        const content = try self.requestDocumentType(.texture, path) orelse return null;
        return content.getTexture();
    }

    pub fn requestThumbnail(self: *Context, path: [:0]const u8) !?*rl.Texture2D {
        const id = self.getIdByFilePath(path) orelse return null;
        return try self.requestThumbnailById(id);
    }

    pub fn requestThumbnailById(self: *Context, id: UUID) !?*rl.Texture2D {
        const p = &(self.currentProject orelse return null);
        return p.requestThumbnailById(self.allocator, id);
    }

    pub fn updateThumbnailById(self: *Context, id: UUID) void {
        const p = &(self.currentProject orelse return);
        const path = self.getFilePathById(id) orelse return;
        const document = self.requestDocumentById(id) orelse return;
        const image = self.generateThumbnail(document) catch |err| {
            self.showError("Could not update thumbnail for document {s}: {}", .{ path, err });
            return;
        } orelse return;
        defer rl.unloadImage(image);

        p.updateThumbnailById(self.allocator, id, image) catch |err| {
            self.showError("Could not update thumbnail for document {s}: {}", .{ path, err });
        };
    }

    pub fn updateThumbnail(self: *Context, path: [:0]const u8) void {
        const id = self.getIdByFilePath(path) orelse return null;
        self.updateThumbnailById(id);
    }

    // TODO: Refactor into it's own file
    fn generateThumbnail(self: *Context, document: *Document) !?rl.Image {
        const content = &(document.content orelse return null);

        switch (content.*) {
            .texture => |texture| {
                return try rl.loadImageFromTexture(texture.getTexture().?.*);
            },
            .animation => |*animationDocument| {
                const animations = animationDocument.getAnimations();
                if (animations.items.len == 0) return null;
                const textureId = animationDocument.getTextureId() orelse return null;
                const texture = (self.requestTextureById(textureId) catch return null) orelse return null;
                const animation = animations.items[0];
                if (animation.frames.items.len == 0) return null;
                const frame = animation.frames.items[0];
                const gridPosition = frame.gridPos;
                const sourceRectMin = @as(
                    @Vector(2, f32),
                    @floatFromInt(gridPosition * animation.gridSize),
                );
                const fCellSize: @Vector(2, f32) = @floatFromInt(animation.gridSize);
                const sourceRect = rl.Rectangle.init(
                    sourceRectMin[0],
                    sourceRectMin[1],
                    fCellSize[0],
                    fCellSize[1],
                );
                const dstRect = rl.Rectangle.init(0, 0, fCellSize[0], fCellSize[1]);
                var image = rl.genImageColor(animation.gridSize[0], animation.gridSize[1], rl.Color.white);
                const srcImage = try rl.loadImageFromTexture(texture.*);
                defer rl.unloadImage(srcImage);
                rl.imageDraw(&image, srcImage, sourceRect, dstRect, rl.Color.white);
                return image;
            },
            .entityType => |*entityTypeDocument| {
                const textureId = entityTypeDocument.getTextureId() orelse return null;
                const texture = (self.requestTextureById(textureId) catch return null) orelse return null;

                const gridPosition = entityTypeDocument.getGridPosition().*;
                const cellSize = entityTypeDocument.getCellSize().*;
                const srcRectMin: @Vector(2, f32) = @floatFromInt(gridPosition * cellSize);
                const fCellSize: @Vector(2, f32) = @floatFromInt(cellSize);
                const srcRect = rl.Rectangle.init(
                    srcRectMin[0],
                    srcRectMin[1],
                    fCellSize[0],
                    fCellSize[1],
                );
                const dstRect = rl.Rectangle.init(0, 0, fCellSize[0], fCellSize[1]);
                var image = rl.genImageColor(cellSize[0], cellSize[1], rl.Color.white);
                const srcImage = try rl.loadImageFromTexture(texture.*);
                defer rl.unloadImage(srcImage);
                rl.imageDraw(&image, srcImage, srcRect, dstRect, rl.Color.white);
                return image;
            },
            .tilemap => |*tilemapDocument| {
                // 1. Calculate image size and create render texture
                const tileSize = tilemapDocument.getTileSize();
                const gridSize = tilemapDocument.getGridSize();
                const tilemapSize = gridSize * tileSize;
                const renderTexture = try rl.loadRenderTexture(tilemapSize[0], tilemapSize[1]);
                defer rl.unloadRenderTexture(renderTexture);

                // 2. Call draw tilemap with render texture as target
                rl.beginTextureMode(renderTexture);
                drawTilemap(self, tilemapDocument, .{ 0, 0 }, 1, true);
                rl.endTextureMode();

                // 3. Create image from renderTexture.texture
                var image = try rl.loadImageFromTexture(renderTexture.texture);
                rl.imageFlipVertical(&image);

                return image;
            },
            .scene => |*sceneDocument| {
                const entities = sceneDocument.getEntities();
                const tilemapId = for (entities.items) |entity|
                    switch (entity.type) {
                        .tilemap => |tilemap| break tilemap.tilemapId orelse return null,
                        else => continue,
                    }
                else
                    return null;
                const tilemapDocument = (self.requestDocumentTypeById(.tilemap, tilemapId) catch return null) orelse return null;

                // 1. Calculate image size and create render texture
                const tileSize = tilemapDocument.getTileSize();
                const gridSize = tilemapDocument.getGridSize();
                const tilemapSize = gridSize * tileSize;
                const renderTexture = try rl.loadRenderTexture(tilemapSize[0], tilemapSize[1]);
                defer rl.unloadRenderTexture(renderTexture);

                // 2. Call draw tilemap with render texture as target
                rl.beginTextureMode(renderTexture);
                drawTilemap(self, tilemapDocument, .{ 0, 0 }, 1, true);
                rl.endTextureMode();

                // 3. Create image from renderTexture.texture
                var image = try rl.loadImageFromTexture(renderTexture.texture);
                rl.imageFlipVertical(&image);

                return image;
            },
        }
    }

    pub fn unloadDocumentById(self: *Context, id: UUID) void {
        var entry = self.documents.map.fetchSwapRemove(id) orelse return;
        entry.value.deinit(self.allocator);
    }

    pub fn unloadDocument(self: *Context, path: [:0]const u8) void {
        const id = self.getIdByFilePath(path) orelse return;
        self.unloadDocumentById(id);
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

    pub fn reloadDocument(self: *Context, path: [:0]const u8) void {
        const id = self.getIdByFilePath(path) orelse return;
        self.reloadDocumentById(id);
    }

    pub fn openFileWithDialog(self: *Context, documentType: DocumentTag) ?Document {
        const fileName = (nfd.openFileDialog(Document.getFileFilter(documentType), null) catch return null) orelse return null;
        defer nfd.freePath(fileName);
        const document = self.requestDocument(fileName) orelse return null;
        return document.*;
    }

    pub fn getFileNameWithDialog(self: *Context, fileFilter: ?[:0]const u8) ?[:0]const u8 {
        const fileName = (nfd.openFileDialog(fileFilter, null) catch return null) orelse return null;
        defer nfd.freePath(fileName);
        return self.allocator.dupeZ(u8, fileName) catch unreachable;
    }

    pub fn getIdsByDocumentType(self: *Context, comptime documentType: DocumentTag) []UUID {
        const p = &(self.currentProject orelse return &.{});
        return p.assetIndex.getIdsByDocumentType(self.allocator, documentType);
    }
};
