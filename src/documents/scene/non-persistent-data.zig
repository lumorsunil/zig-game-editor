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

pub const SceneNonPersistentData = struct {
    dragPayload: ?SceneEntityType = null,
    selectedEntities: ArrayList(*SceneEntity),
    dragStartPoint: ?Vector = null,
    isDragging: bool = false,
    setEntityWindow: SetEntityWindow = .{},

    pub const setEntityReferenceWindowHeight = SetEntityWindow.setEntityReferenceWindowHeight;
    pub const setEntityReferenceWindowWidth = SetEntityWindow.setEntityReferenceWindowHeight;

    pub fn init(allocator: Allocator) SceneNonPersistentData {
        return SceneNonPersistentData{
            .selectedEntities = ArrayList(*SceneEntity).initCapacity(allocator, 10) catch unreachable,
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
