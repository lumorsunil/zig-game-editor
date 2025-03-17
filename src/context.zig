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

const SceneDocument = @import("documents/scene/document.zig").SceneDocument;
const SceneEntity = @import("documents/scene/document.zig").SceneEntity;
const TilemapDocument = @import("documents/tilemap/document.zig").TilemapDocument;

var __tools = [_]Tool{
    Tool.init("brush", .{ .brush = BrushTool.init() }),
    Tool.init("select", .{ .select = SelectTool.init() }),
};

pub const Context = struct {
    allocator: Allocator,
    tilemapArena: ArenaAllocator,

    defaultPath: [:0]const u8,
    currentFileName: ?[:0]const u8 = null,

    backgroundColor: rl.Color = rl.Color.init(125, 125, 155, 255),
    isDemoWindowOpen: bool = false,
    isDemoWindowEnabled: bool = false,
    camera: rl.Camera2D,

    currentTool: ?*Tool = &__tools[0],

    tools: []Tool = &__tools,

    textures: std.StringHashMap(rl.Texture2D),
    tilemapDocument: *TilemapDocument,
    sceneDocument: SceneDocument,
    scale: VectorInt = 4,
    scaleV: Vector = .{ 4, 4 },

    materializingAction: ?Action,

    focusOnActiveLayer: bool = true,

    currentProject: Project,

    inputTilemapSize: Vector = .{ 0, 0 },

    mode: EditorMode = .scene,

    pub const EditorMode = enum {
        scene,
        tilemap,
    };

    const defaultSize: Vector = .{ 35, 17 };
    const defaultTileSize: Vector = .{ 16, 16 };

    pub fn init(allocator: Allocator) Context {
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
            .sceneDocument = SceneDocument.init(),
            .materializingAction = null,
            .currentProject = Project.init(allocator),
        };
    }

    pub fn deinit(self: *Context) void {
        self.textures.deinit();
        self.freeFileData();
        self.allocator.free(self.defaultPath);
        if (self.currentFileName) |fileName| {
            self.allocator.free(fileName);
        }
        if (self.currentTool) |ct| ct.deinit(self.allocator);
        self.sceneDocument.deinit();
    }

    fn createFileData(self: *Context, size: Vector, tileSize: Vector) *TilemapDocument {
        const allocator = self.tilemapArena.allocator();
        const ptr = allocator.create(TilemapDocument) catch unreachable;
        ptr.* = TilemapDocument.init(allocator, size, tileSize);
        return ptr;
    }

    fn createDefaultFileData(self: *Context) *TilemapDocument {
        return self.createFileData(defaultSize, defaultTileSize);
    }

    fn freeFileData(self: *Context) void {
        _ = self.tilemapArena.reset(.free_all);
    }

    inline fn getDefaultPath(allocator: Allocator) ![:0]const u8 {
        var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const cwd = try std.fmt.allocPrintZ(allocator, "{s}", .{try std.fs.cwd().realpath(".", &buf)});
        return cwd;
    }

    /// fileName will be duplicated
    fn setCurrentFileName(self: *Context, fileName: ?[]const u8) !void {
        if (self.currentFileName) |cfn| {
            self.allocator.free(cfn);
            self.currentFileName = null;
        }

        if (fileName) |cfn| {
            self.currentFileName = try self.allocator.dupeZ(u8, cfn);
        }
    }

    const fileFilter = "tilemap.json";

    pub fn saveFile(self: *Context) !void {
        if (self.currentFileName) |fileName| {
            try self.saveFileTo(fileName);
            return;
        }

        const fileName = try nfd.saveFileDialog(fileFilter, self.defaultPath) orelse return;
        defer nfd.freePath(fileName);

        if (!std.mem.endsWith(u8, fileName, ".tilemap.json")) {
            self.currentFileName = try std.fmt.allocPrintZ(self.allocator, "{s}.tilemap.json", .{fileName});
        } else {
            self.currentFileName = try std.fmt.allocPrintZ(self.allocator, "{s}", .{fileName});
        }

        try self.saveFileTo(self.currentFileName.?);
    }

    fn saveFileTo(self: *Context, fileName: [:0]const u8) !void {
        std.log.debug("Saving to file: {s}", .{fileName});
        const file = try std.fs.createFileAbsolute(fileName, .{});
        defer file.close();
        const writer = file.writer();
        try self.tilemapDocument.serialize(writer);
    }

    pub fn openFile(self: *Context) !void {
        const maybeFileName = try nfd.openFileDialog(fileFilter, self.defaultPath);

        if (maybeFileName) |fileName| {
            defer nfd.freePath(fileName);
            try self.openFileEx(fileName);
        }
    }

    fn openFileEx(self: *Context, fileName: []const u8) !void {
        const file = std.fs.openFileAbsolute(fileName, .{}) catch |err| {
            switch (err) {
                error{FileNotFound}.FileNotFound => {
                    try self.newFile();
                    return;
                },
                else => return err,
            }
        };
        defer file.close();
        const fileReader = file.reader();
        var reader = std.json.reader(self.allocator, fileReader);
        defer reader.deinit();
        self.freeFileData();
        self.tilemapDocument = TilemapDocument.deserialize(self.tilemapArena.allocator(), &reader) catch |err| {
            std.log.err("Error reading file: {s} {}", .{ fileName, err });
            return self.newFile();
        };
        self.inputTilemapSize = self.tilemapDocument.tilemap.grid.size;
        try self.setCurrentFileName(fileName);
    }

    pub fn newFile(self: *Context) !void {
        try self.setCurrentFileName(null);
        self.freeFileData();
        self.tilemapDocument = self.createDefaultFileData();
        self.inputTilemapSize = self.tilemapDocument.tilemap.grid.size;
    }

    fn createEditorSession(self: *Context) EditorSession {
        return EditorSession{
            .currentFileName = self.currentFileName,
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
        self.sceneDocument.load();
        const entity = self.allocator.create(SceneEntity) catch unreachable;
        entity.* = .{
            .id = UUID.init(),
            .position = .{ 0, 0 },
            .type = .tilemap,
        };
        self.sceneDocument.scene.entities.append(self.allocator, entity) catch unreachable;
        const player = self.allocator.create(SceneEntity) catch unreachable;
        player.* = .{
            .id = UUID.init(),
            .position = .{ 0, 0 },
            .type = .player,
        };
        self.sceneDocument.scene.entities.append(self.allocator, player) catch unreachable;
        const klet = self.allocator.create(SceneEntity) catch unreachable;
        klet.* = .{
            .id = UUID.init(),
            .position = .{ 16 * 8, 16 * 4 },
            .type = .klet,
        };
        self.sceneDocument.scene.entities.append(self.allocator, klet) catch unreachable;

        const file = std.fs.cwd().openFile(sessionFileName, .{}) catch |err| {
            switch (err) {
                error{FileNotFound}.FileNotFound => {
                    try self.newFile();
                    return;
                },
                else => return err,
            }
        };
        defer file.close();
        const reader = file.reader();
        var jsonReader = std.json.reader(self.allocator, reader);
        defer jsonReader.deinit();
        const parsed = try std.json.parseFromTokenSource(EditorSession, self.allocator, &jsonReader, .{
            .ignore_unknown_fields = true,
        });
        defer parsed.deinit();

        if (parsed.value.currentFileName) |cfn| {
            try self.openFileEx(cfn);
        } else {
            try self.newFile();
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
};
