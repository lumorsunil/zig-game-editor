const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("lib");
const Vector = lib.Vector;
const Scene = @import("persistent-data.zig").Scene;
const SceneEntityType = @import("persistent-data.zig").SceneEntityType;
const SceneEntity = @import("persistent-data.zig").SceneEntity;
const UUID = lib.UUIDSerializable;
const config = @import("lib").config;
const IdArrayHashMap = lib.IdArrayHashMap;

pub const SceneTool = union(enum) {
    select,
    createPoint,
};

const SetEntityWindow = struct {
    isOpen: bool = false,
    sceneTarget: ?*?UUID = null,
    entityTarget: ?*?UUID = null,
    selectedScene: ?UUID = null,
    selectedEntity: ?UUID = null,
    renderTexture: rl.RenderTexture = undefined,
    camera: rl.Camera2D = .{
        .zoom = 1,
        .offset = .{
            .x = @floatFromInt(setEntityReferenceWindowWidth / 2),
            .y = @floatFromInt(setEntityReferenceWindowHeight / 2),
        },
        .target = .{ .x = 0, .y = 0 },
        .rotation = 0,
    },

    pub const setEntityReferenceWindowHeight = 800;
    pub const setEntityReferenceWindowWidth = 800;
};

pub const DragState = union(enum) {
    payload: SceneEntityType,
    entityTarget: DragEntityState,
};

pub const DragEntityState = struct {
    dragStartPoint: Vector,
    snapshot: []const Snapshot,
    startScale: @Vector(2, f32),
    entitySize: Vector,

    pub const Snapshot = struct {
        entity: *SceneEntity,
        startPosition: Vector,
    };

    pub fn deinit(self: DragEntityState, allocator: Allocator) void {
        allocator.free(self.snapshot);
    }

    pub fn getSnapshotById(self: DragEntityState, entityId: UUID) Snapshot {
        for (self.snapshot) |s| if (s.entity.id.uuid == entityId.uuid) return s;

        unreachable;
    }
};

pub const DragAction = union(enum) {
    move,
    resize: ResizeAction,
    select: Select,

    pub const Select = struct {
        dragStartPoint: Vector,
    };
};

pub const ResizeAction = struct {
    entityId: UUID,
    direction: Direction,

    pub const Direction = enum {
        right,
        topright,
        top,
        topleft,
        left,
        bottomleft,
        bottom,
        bottomright,
    };
};

pub const SceneNonPersistentData = struct {
    selectedEntities: ArrayList(*SceneEntity),
    hiddenEntities: IdArrayHashMap(bool),
    dragState: ?DragState = null,
    dragAction: ?DragAction = null,
    isDragging: bool = false,
    setEntityWindow: SetEntityWindow = .{},
    currentTool: SceneTool = .select,

    pub const setEntityReferenceWindowHeight = SetEntityWindow.setEntityReferenceWindowHeight;
    pub const setEntityReferenceWindowWidth = SetEntityWindow.setEntityReferenceWindowHeight;

    pub fn init(allocator: Allocator) SceneNonPersistentData {
        return SceneNonPersistentData{
            .selectedEntities = ArrayList(*SceneEntity).initCapacity(allocator, 10) catch unreachable,
            .hiddenEntities = .empty,
        };
    }

    pub fn deinit(self: *SceneNonPersistentData, allocator: Allocator) void {
        self.selectedEntities.clearAndFree(allocator);
        rl.unloadRenderTexture(self.setEntityWindow.renderTexture);
        self.setEntityWindow.renderTexture = undefined;
    }

    pub fn load(self: *SceneNonPersistentData, _: [:0]const u8, persistentData: *Scene) void {
        self.setEntityWindow.selectedScene = persistentData.id;
        self.setEntityWindow.renderTexture = rl.loadRenderTexture(setEntityReferenceWindowWidth, setEntityReferenceWindowHeight) catch unreachable;
    }
};
