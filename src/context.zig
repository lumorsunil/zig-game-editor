const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const rl = @import("raylib");
const nfd = @import("nfd");
const lib = @import("root").lib;
const Vector = lib.Vector;
const VectorInt = lib.VectorInt;
const Action = lib.Action;
const Project = lib.Project;
const Tool = lib.Tool;
const ImplTool = lib.ImplTool;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const EditorSession = lib.EditorSession;
const History = lib.History;
const UUID = lib.UUIDSerializable;
const uuid = @import("uuid");

const SceneDocument = @import("documents/scene/document.zig").SceneDocument;
const SceneEntity = @import("documents/scene/document.zig").SceneEntity;
const SceneEntityTilemap = @import("documents/scene/document.zig").SceneEntityTilemap;
const TilemapDocument = @import("documents/tilemap/document.zig").TilemapDocument;

var __tools = [_]Tool{
    Tool.init("brush", .{ .brush = BrushTool.init() }),
    Tool.init("select", .{ .select = SelectTool.init() }),
};

pub const Context = struct {
    allocator: Allocator,
    tilemapArena: ArenaAllocator,

    defaultPath: [:0]const u8,
    currentTilemapFileName: ?[:0]const u8 = null,
    currentSceneFileName: ?[:0]const u8 = null,

    backgroundColor: rl.Color = rl.Color.init(125, 125, 155, 255),
    isDemoWindowOpen: bool = false,
    isDemoWindowEnabled: bool = false,
    camera: rl.Camera2D,

    currentTool: ?*Tool = &__tools[0],

    tools: []Tool = &__tools,

    textures: std.StringHashMap(rl.Texture2D),
    tilemapDocument: *TilemapDocument,
    tilemapDocumentInitialized: bool = false,
    sceneDocument: *SceneDocument,
    sceneDocumentInitialized: bool = false,
    scale: VectorInt = 4,
    scaleV: Vector = .{ 4, 4 },

    materializingAction: ?Action,

    focusOnActiveLayer: bool = true,

    currentProject: Project,

    inputTilemapSize: Vector = .{ 0, 0 },

    exitTexture: rl.Texture2D,
    entranceTexture: rl.Texture2D,

    mode: EditorMode = .scene,

    playState: PlayState = .notRunning,

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
    };

    const defaultSize: Vector = .{ 35, 17 };
    const defaultTileSize: Vector = .{ 16, 16 };

    pub fn init(allocator: Allocator) Context {
        const exitImage = rl.genImageColor(1, 1, rl.Color.white);
        const entranceImage = rl.genImageColor(1, 1, rl.Color.yellow);

        const mode: EditorMode = .tilemap;
        const focusOnActiveLayer: bool = mode == .tilemap;

        return Context{
            .allocator = allocator,
            .tilemapArena = ArenaAllocator.init(allocator),
            .defaultPath = getDefaultPath(allocator) catch unreachable,
            .camera = rl.Camera2D{
                .target = .{ .x = 0, .y = 0 },
                .offset = .{ .x = 0, .y = 0 },
                .rotation = 0,
                .zoom = 1,
            },
            .textures = std.StringHashMap(rl.Texture2D).init(allocator),
            .tilemapDocument = undefined,
            .sceneDocument = undefined,
            .materializingAction = null,
            .currentProject = Project.init(allocator),
            .exitTexture = rl.loadTextureFromImage(exitImage),
            .entranceTexture = rl.loadTextureFromImage(entranceImage),
            .mode = mode,
            .focusOnActiveLayer = focusOnActiveLayer,
        };
    }

    pub fn deinit(self: *Context) void {
        self.textures.deinit();
        self.freeFileTilemapData();
        self.allocator.free(self.defaultPath);
        if (self.currentTilemapFileName) |fileName| {
            self.allocator.free(fileName);
            self.currentTilemapFileName = null;
        }
        if (self.currentSceneFileName) |fileName| {
            self.allocator.free(fileName);
            self.currentSceneFileName = null;
        }
        if (self.currentTool) |ct| ct.deinit(self.allocator);
        self.freeFileSceneData();
    }

    fn createFileTilemapData(self: *Context, size: Vector, tileSize: Vector) *TilemapDocument {
        const allocator = self.tilemapArena.allocator();
        const ptr = allocator.create(TilemapDocument) catch unreachable;
        ptr.* = TilemapDocument.init(allocator, size, tileSize);
        return ptr;
    }

    fn createDefaultFileTilemapData(self: *Context) *TilemapDocument {
        return self.createFileTilemapData(defaultSize, defaultTileSize);
    }

    fn freeFileTilemapData(self: *Context) void {
        if (!self.tilemapDocumentInitialized) return;
        _ = self.tilemapArena.reset(.free_all);
        self.tilemapDocumentInitialized = false;
    }

    fn createFileSceneData(self: *Context) *SceneDocument {
        const allocator = self.allocator;
        const ptr = allocator.create(SceneDocument) catch unreachable;
        ptr.* = SceneDocument.init(self.allocator);
        ptr.load();
        const entity = self.allocator.create(SceneEntity) catch unreachable;
        entity.* = SceneEntity.init(self.allocator, .{ 0, 0 }, .{ .tilemap = SceneEntityTilemap.init() });
        ptr.scene.entities.append(self.allocator, entity) catch unreachable;
        return ptr;
    }

    fn createDefaultFileSceneData(self: *Context) *SceneDocument {
        return self.createFileSceneData();
    }

    fn freeFileSceneData(self: *Context) void {
        if (!self.sceneDocumentInitialized) return;
        self.sceneDocument.deinit(self.allocator);
        self.allocator.destroy(self.sceneDocument);
        self.sceneDocumentInitialized = false;
    }

    inline fn getDefaultPath(allocator: Allocator) ![:0]const u8 {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const cwd = try std.fmt.allocPrintZ(allocator, "{s}", .{try std.fs.cwd().realpath(".", &buf)});
        return cwd;
    }

    /// fileName will be duplicated
    fn setCurrentTilemapFileName(self: *Context, fileName: ?[]const u8) !void {
        if (self.currentTilemapFileName) |cfn| {
            self.allocator.free(cfn);
            self.currentTilemapFileName = null;
        }

        if (fileName) |cfn| {
            self.currentTilemapFileName = try self.allocator.dupeZ(u8, cfn);
        }
    }

    fn setCurrentSceneFileName(self: *Context, fileName: ?[]const u8) !void {
        if (self.currentSceneFileName) |cfn| {
            self.allocator.free(cfn);
            self.currentSceneFileName = null;
        }

        if (fileName) |cfn| {
            self.currentSceneFileName = try self.allocator.dupeZ(u8, cfn);
        }
    }

    pub const sceneFileFilter = "scene.json";
    pub const tilemapFileFilter = "tilemap.json";

    pub fn saveFileTilemap(self: *Context) !void {
        if (self.currentTilemapFileName) |fileName| {
            try self.saveFileTilemapTo(fileName);
            return;
        }

        const fileName = try nfd.saveFileDialog(tilemapFileFilter, self.defaultPath) orelse return;
        defer nfd.freePath(fileName);

        if (!std.mem.endsWith(u8, fileName, ".tilemap.json")) {
            self.currentTilemapFileName = try std.fmt.allocPrintZ(self.allocator, "{s}.tilemap.json", .{fileName});
        } else {
            self.currentTilemapFileName = try std.fmt.allocPrintZ(self.allocator, "{s}", .{fileName});
        }

        try self.saveFileTilemapTo(self.currentTilemapFileName.?);
    }

    pub fn saveFileScene(self: *Context) !void {
        if (self.currentSceneFileName) |fileName| {
            try self.saveFileSceneTo(fileName);
            return;
        }

        const fileName = try nfd.saveFileDialog(sceneFileFilter, self.defaultPath) orelse return;
        defer nfd.freePath(fileName);

        if (!std.mem.endsWith(u8, fileName, ".scene.json")) {
            self.currentSceneFileName = try std.fmt.allocPrintZ(self.allocator, "{s}.scene.json", .{fileName});
        } else {
            self.currentSceneFileName = try std.fmt.allocPrintZ(self.allocator, "{s}", .{fileName});
        }

        try self.saveFileSceneTo(self.currentSceneFileName.?);
    }

    fn saveFileSceneTo(self: *Context, fileName: [:0]const u8) !void {
        std.log.debug("Saving to file: {s}", .{fileName});
        const file = try std.fs.createFileAbsolute(fileName, .{});
        defer file.close();
        const writer = file.writer();
        try self.sceneDocument.serialize(writer);
    }

    fn saveFileTilemapTo(self: *Context, fileName: [:0]const u8) !void {
        std.log.debug("Saving to file: {s}", .{fileName});
        const file = try std.fs.createFileAbsolute(fileName, .{});
        defer file.close();
        const writer = file.writer();
        try self.tilemapDocument.serialize(writer);
    }

    pub fn openFileTilemap(self: *Context) !void {
        const maybeFileName = try nfd.openFileDialog(tilemapFileFilter, self.defaultPath);

        if (maybeFileName) |fileName| {
            defer nfd.freePath(fileName);
            try self.openFileTilemapEx(fileName);
        }
    }

    pub fn openFileScene(self: *Context) !void {
        const maybeFileName = try nfd.openFileDialog(sceneFileFilter, self.defaultPath);

        if (maybeFileName) |fileName| {
            defer nfd.freePath(fileName);
            try self.openFileSceneEx(fileName);
        }
    }

    pub fn openFileSceneEx(self: *Context, sceneFileName: []const u8) !void {
        const fileName = self.allocator.dupe(u8, sceneFileName) catch unreachable;
        defer self.allocator.free(fileName);
        const file = std.fs.cwd().openFile(fileName, .{}) catch |err| {
            std.log.err("Could not open file {s}: {}", .{ fileName, err });
            try self.newFileScene();
            return;
        };
        defer file.close();
        const fileReader = file.reader();
        var reader = std.json.reader(self.allocator, fileReader);
        defer reader.deinit();
        self.freeFileSceneData();
        self.sceneDocument = SceneDocument.deserialize(self.allocator, &reader) catch |err| {
            std.log.err("Error reading file: {s} {}", .{ fileName, err });
            return self.newFileScene();
        };
        try self.setCurrentSceneFileName(fileName);
        self.sceneDocumentInitialized = true;

        if (self.mode == .scene) {
            if (self.sceneDocument.getTilemapFileName()) |tilemapFileName| {
                try self.openFileTilemapEx(tilemapFileName);
            }
        }
    }

    fn openFileTilemapEx(self: *Context, fileName: []const u8) !void {
        const file = std.fs.openFileAbsolute(fileName, .{}) catch |err| {
            std.log.err("Could not open file {s}: {}", .{ fileName, err });
            try self.newFileTilemap();
            return;
        };
        defer file.close();
        const fileReader = file.reader();
        var reader = std.json.reader(self.allocator, fileReader);
        defer reader.deinit();
        self.freeFileTilemapData();
        self.tilemapDocument = TilemapDocument.deserialize(self.tilemapArena.allocator(), &reader) catch |err| {
            std.log.err("Error reading file: {s} {}", .{ fileName, err });
            return self.newFileTilemap();
        };
        self.inputTilemapSize = self.tilemapDocument.tilemap.grid.size;
        try self.setCurrentTilemapFileName(fileName);
        self.tilemapDocumentInitialized = true;
    }

    pub fn newFileTilemap(self: *Context) !void {
        try self.setCurrentTilemapFileName(null);
        self.freeFileTilemapData();
        self.tilemapDocument = self.createDefaultFileTilemapData();
        self.inputTilemapSize = self.tilemapDocument.tilemap.grid.size;
        self.tilemapDocumentInitialized = true;
    }

    pub fn newFileScene(self: *Context) !void {
        try self.setCurrentSceneFileName(null);
        self.freeFileSceneData();
        self.sceneDocument = self.createDefaultFileSceneData();
        self.sceneDocumentInitialized = true;

        if (self.mode == .scene) {
            try self.newFileTilemap();
        }
    }

    fn createEditorSession(self: *Context) EditorSession {
        return EditorSession{
            .currentTilemapFileName = self.currentTilemapFileName,
            .currentSceneFileName = self.currentSceneFileName,
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
        try std.json.stringify(self.createEditorSession(), .{}, writer);
    }

    pub fn restoreSession(self: *Context) !void {
        // Read session file
        const file = std.fs.cwd().openFile(sessionFileName, .{}) catch |err| {
            switch (err) {
                error{FileNotFound}.FileNotFound => {
                    try self.newFileTilemap();
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
            try self.newFileTilemap();
            try self.newFileScene();
            return;
        };
        defer parsed.deinit();

        if (parsed.value.currentTilemapFileName) |cfn| {
            try self.openFileTilemapEx(cfn);
        } else {
            try self.newFileTilemap();
        }
        if (parsed.value.currentSceneFileName) |cfn| {
            try self.openFileSceneEx(cfn);
        } else {
            try self.newFileScene();
        }
        // TODO: need to properly clone the tool
        //self.currentTool = parsed.value.currentTool;
        rl.setWindowSize(parsed.value.windowSize[0], parsed.value.windowSize[1]);
        rl.setWindowPosition(parsed.value.windowPos[0], parsed.value.windowPos[1]);

        self.camera = parsed.value.camera;
    }

    pub fn startAction(self: *Context, action: Action) void {
        self.materializingAction = action;
    }

    pub fn endAction(self: *Context) void {
        self.tilemapDocument.history.push(self.tilemapArena.allocator(), self.materializingAction.?);
        self.materializingAction = null;
        self.inputTilemapSize = self.tilemapDocument.tilemap.grid.size;
    }

    pub fn undo(self: *Context) void {
        if (!self.canUndo()) return;
        self.tilemapDocument.undo(self.tilemapArena.allocator());
        self.inputTilemapSize = self.tilemapDocument.tilemap.grid.size;
    }

    pub fn redo(self: *Context) void {
        if (!self.canRedo()) return;
        self.tilemapDocument.redo(self.tilemapArena.allocator());
        self.inputTilemapSize = self.tilemapDocument.tilemap.grid.size;
    }

    pub fn canUndo(self: *Context) bool {
        return self.tilemapDocument.history.canUndo();
    }

    pub fn canRedo(self: *Context) bool {
        return self.tilemapDocument.history.canRedo();
    }

    pub fn startGenericAction(self: *Context, comptime GenericActionType: type) void {
        if (self.materializingAction) |_| return;

        const snapshotBefore = self.tilemapDocument.tilemap;
        const fieldName = comptime brk: {
            for (std.meta.fields(Action)) |field| {
                if (field.type == GenericActionType) break :brk field.name;
            } else {
                @compileError("Type " ++ @typeName(GenericActionType) ++ " not a valid Action");
            }
        };

        const action = @unionInit(
            Action,
            fieldName,
            GenericActionType.init(snapshotBefore, self.tilemapArena.allocator()),
        );

        self.startAction(action);
    }

    pub fn endGenericAction(self: *Context, comptime GenericActionType: type) void {
        if (self.materializingAction) |*action| switch (action.*) {
            inline else => |*generic| if (GenericActionType == @TypeOf(generic.*)) {
                generic.materialize(self.tilemapArena.allocator(), self.tilemapDocument.tilemap);
                self.endAction();
            },
        };
    }

    pub fn squashHistory(context: *Context) void {
        context.tilemapDocument.history.deinit(context.tilemapArena.allocator());
        context.tilemapDocument.history = History.init();
    }

    pub fn getTool(
        self: *const Context,
        comptime toolType: std.meta.FieldEnum(ImplTool),
    ) *Tool {
        for (self.tools) |*tool| {
            switch (tool.impl) {
                toolType => return tool,
                else => {},
            }
        }

        unreachable;
    }

    pub fn setTool(
        self: *Context,
        comptime toolType: std.meta.FieldEnum(ImplTool),
    ) void {
        self.currentTool = self.getTool(toolType);
    }

    pub fn play(self: *Context) void {
        if (self.currentTilemapFileName == null or self.currentSceneFileName == null) {
            self.playState = .errorStarting;
            return;
        }

        self.playState = .starting;

        self.saveFileTilemapTo(self.currentTilemapFileName.?) catch |err| {
            std.log.err("Error saving tilemap: {}", .{err});
            self.playState = .errorStarting;
            return;
        };

        self.saveFileSceneTo(self.currentSceneFileName.?) catch |err| {
            std.log.err("Error saving scene: {}", .{err});
            self.playState = .errorStarting;
            return;
        };

        const zigCommand = std.fmt.allocPrint(self.allocator, "zig build run -- --scene \"{s}\"", .{self.currentSceneFileName.?}) catch unreachable;
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
};
