const std = @import("std");
const Allocator = std.mem.Allocator;
const rl = @import("raylib");
const lib = @import("lib");
const Vector = lib.Vector;
const VectorInt = lib.VectorInt;
const Project = lib.Project;
const Editor = lib.Editor;
const Document = lib.Document;
const DocumentTag = lib.DocumentTag;
const Node = lib.Node;
const Tool = lib.Tool;
const BrushTool = lib.tools.BrushTool;
const SelectTool = lib.tools.SelectTool;
const UUID = lib.UUIDSerializable;
const IdArrayHashMap = lib.IdArrayHashMap;
const SceneMap = lib.SceneMap;

pub const PlayState = enum {
    notRunning,
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
    allocator: Allocator,

    openedEditors: IdArrayHashMap(Editor),
    currentEditor: ?UUID = null,
    editorToBeOpened: ?UUID = null,
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

    pub usingnamespace @import("context/session.zig");
    pub usingnamespace @import("context/project.zig");
    pub usingnamespace @import("context/editor.zig");
    pub usingnamespace @import("context/play.zig");
    pub usingnamespace @import("context/new-directory.zig");
    pub usingnamespace @import("context/new-asset.zig");
    pub usingnamespace @import("context/document.zig");
    pub usingnamespace @import("context/thumbnail.zig");
    pub usingnamespace @import("context/file-dialog.zig");
    pub usingnamespace @import("context/assets-manager.zig");
    pub usingnamespace @import("context/asset-index.zig");
    pub usingnamespace @import("context/show-error.zig");
};
