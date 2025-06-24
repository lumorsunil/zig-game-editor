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
const DocumentContent = lib.DocumentContent;
const Node = lib.Node;
const SceneEntity = lib.documents.scene.SceneEntity;
const SceneEntityTilemap = lib.documents.scene.SceneEntityTilemap;
const Tool = lib.Tool;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const nfd = @import("nfd");
const UUID = lib.UUIDSerializable;
const uuid = @import("uuid");
const IdArrayHashMap = lib.IdArrayHashMap;
const drawTilemap = lib.drawTilemap;

pub const ContextError = error{DocumentTagNotMatching};

pub const Context = struct {
    allocator: Allocator,

    openedEditors: IdArrayHashMap(Editor),
    currentEditor: ?usize = null,
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
    errorMessage: [1024:0]u8 = undefined,
    isErrorDialogOpen: bool = false,

    isNewDirectoryDialogOpen: bool = false,
    isNewTilemapDialogOpen: bool = false,
    isNewSceneDialogOpen: bool = false,
    isNewAnimationDocumentDialogOpen: bool = false,
    isNewEntityTypeDocumentDialogOpen: bool = false,

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

        var context = Context{
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

        context.documents.map.ensureTotalCapacity(allocator, 100000) catch unreachable;

        return context;
    }

    pub fn deinit(self: *Context) void {
        for (self.openedEditors.map.values()) |*editor| {
            editor.deinit(self.allocator);
        }
        self.openedEditors.map.clearAndFree(self.allocator);
        for (self.documents.map.values()) |*document| {
            document.deinit(self.allocator);
        }
        self.documents.map.clearAndFree(self.allocator);
        if (self.currentProject) |*p| p.deinit(self.allocator);
        self.currentProject = null;
        for (&self.tools) |*tool| tool.deinit(self.allocator);
        if (self.iconsTexture) |iconsTexture| rl.unloadTexture(iconsTexture);
        self.iconsTexture = null;
    }

    pub fn getCurrentEditor(self: *Context) ?*Editor {
        const i = self.currentEditor orelse return null;
        return &self.openedEditors.map.values()[i];
    }

    fn createEditorSession(self: *Context) EditorSession {
        return EditorSession{
            .currentProject = if (self.currentProject) |p| self.allocator.dupe(u8, p.assetsLibrary.root) catch unreachable else null,
            .openedEditorFilePath = if (self.getCurrentEditor()) |e| brk: {
                const p = self.currentProject orelse break :brk null;
                const relativeToRoot = std.fs.path.relative(
                    self.allocator,
                    p.assetsLibrary.root,
                    e.document.filePath,
                ) catch unreachable;
                defer self.allocator.free(relativeToRoot);
                const relativeToRootZ = self.allocator.dupeZ(u8, relativeToRoot) catch unreachable;
                break :brk relativeToRootZ;
            } else null,
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
        self.updateIndex();
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
            self.currentProject.?.loadIndex(self.allocator) catch |err| {
                std.log.err("Could not load/build asset index: {}", .{err});
            };
            self.currentProject.?.setCurrentDirectory(self.allocator, ".") catch |err| {
                std.log.err("Could not set current directory in assets manager: {}", .{err});
            };
        }

        if (parsed.value.openedEditorFilePath) |oefp| {
            self.openEditor(oefp);
        }

        rl.setWindowSize(parsed.value.windowSize[0], parsed.value.windowSize[1]);
        rl.setWindowPosition(parsed.value.windowPos[0], parsed.value.windowPos[1]);

        self.camera = parsed.value.camera;

        const exitImage = rl.genImageColor(1, 1, rl.Color.white);
        const entranceImage = rl.genImageColor(1, 1, rl.Color.yellow);
        self.exitTexture = try rl.loadTextureFromImage(exitImage);
        self.entranceTexture = try rl.loadTextureFromImage(entranceImage);
    }

    pub fn updateIndex(self: *Context) void {
        const p = self.currentProject orelse return;
        std.log.debug("Updating index", .{});
        p.saveIndex() catch |err| {
            std.log.err("Could not save asset index: {}", .{err});
        };
    }

    pub fn play(self: *Context) void {
        const editor = self.getCurrentEditor() orelse return;

        if (editor.documentType != .scene) return;

        self.playState = .starting;

        for (self.openedEditors.map.values()) |*openedEditor| {
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

    fn closeEditors(self: *Context) void {
        for (self.openedEditors.map.values()) |*editor| {
            editor.deinit(self.allocator);
        }

        self.openedEditors.map.clearAndFree(self.allocator);
        self.currentEditor = null;
    }

    fn setProject(self: *Context, project: ?Project) void {
        if (self.currentProject) |*p| {
            self.closeEditors();

            p.deinit(self.allocator);
        }
        self.currentProject = project;

        if (self.currentProject) |_| {
            self.loadProject();
        }
    }

    /// Project needs to be set before this is called.
    fn loadProject(self: *Context) void {
        self.setCurrentDirectory(".");
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

        const relativeToRootZ = std.fs.path.joinZ(self.allocator, &.{ cd, name }) catch unreachable;
        defer self.allocator.free(relativeToRootZ);

        p.assetsLibrary.appendNewDirectory(self.allocator, relativeToRootZ);
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
            return null;
        };

        self.documents.map.putAssumeCapacity(document.getId(), document);

        const rootDirAbsolutePath = rootDir.realpathAlloc(self.allocator, ".") catch unreachable;
        defer self.allocator.free(rootDirAbsolutePath);
        const relativeToRoot = std.fs.path.relative(self.allocator, rootDirAbsolutePath, absoluteFilePathZ) catch unreachable;
        defer self.allocator.free(relativeToRoot);
        const relativeToRootZ = self.allocator.dupeZ(u8, relativeToRoot) catch unreachable;
        defer self.allocator.free(relativeToRootZ);

        const storedDocument = self.documents.map.getPtr(document.getId()) orelse unreachable;
        const content = &@field(storedDocument.content.?, @tagName(documentType));
        self.currentProject.?.assetIndex.addIndex(self.allocator, content.getId(), relativeToRootZ);
        self.currentProject.?.assetsLibrary.appendNewFile(self.allocator, self.currentProject.?.assetIndex, relativeToRootZ);

        // Update the asset index to match the new path for the node id
        self.updateIndex();

        return content;
    }

    pub fn showError(self: *Context, comptime fmt: []const u8, args: anytype) void {
        std.log.err(fmt, args);
        _ = std.fmt.bufPrintZ(&self.errorMessage, fmt, args) catch unreachable;
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

        self.currentEditor = entry.index;
    }

    pub fn setCurrentDirectory(self: *Context, path: [:0]const u8) void {
        self.currentProject.?.setCurrentDirectory(self.allocator, path) catch |err| {
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

            const path = self.getFilePathById(id) orelse return null;
            var targetDir = self.currentProject.?.assetsLibrary.openRoot();
            defer targetDir.close();
            const absolutePath = toAbsolutePathZ(self.allocator, targetDir, path);
            defer self.allocator.free(absolutePath);
            const documentType = Document.getTagByFilePath(path) catch |err| {
                self.showError("Could not open document {s}: {}", .{ path, err });
                _ = self.documents.map.swapRemove(id);
                return null;
            };
            entry.value_ptr.* = Document.open(self.allocator, absolutePath, documentType) catch |err| {
                self.showError("Could not open document {s}: {}", .{ path, err });
                _ = self.documents.map.swapRemove(id);
                return null;
            };
        } else if (entry.value_ptr.content == null) {
            std.log.debug("Requested document {} found with no content, loading", .{id});

            const path = self.getFilePathById(id) orelse return null;
            const documentType = Document.getTagByFilePath(path) catch |err| {
                self.showError("Could not open document {s}: {}", .{ path, err });
                _ = self.documents.map.swapRemove(id);
                return null;
            };
            std.log.debug("Loading content for document {s}", .{path});
            entry.value_ptr.loadContent(self.allocator, documentType) catch |err| {
                self.showError("Could not load document {s}: {}", .{ path, err });
                return null;
            };
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
        var entry = self.documents.map.fetchSwapRemove(id) orelse return;
        entry.value.deinit(self.allocator);
    }

    pub fn reloadDocumentById(self: *Context, id: UUID) void {
        self.unloadDocumentById(id);
        _ = self.requestDocumentById(id);
    }

    pub fn reloadDocument(self: *Context, path: [:0]const u8) void {
        self.unloadDocument(path);
        _ = self.requestDocument(path);
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
};
