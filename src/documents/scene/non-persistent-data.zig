const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("root").lib;
const Vector = lib.Vector;
const Scene = @import("persistent-data.zig").Scene;
const SceneEntityType = @import("persistent-data.zig").SceneEntityType;
const SceneEntity = @import("persistent-data.zig").SceneEntity;
const UUID = lib.UUIDSerializable;
const config = @import("root").config;

pub const SceneNonPersistentData = struct {
    dragPayload: ?SceneEntityType = null,
    selectedEntities: ArrayList(*SceneEntity),
    dragStartPoint: ?Vector = null,
    isDragging: bool = false,
    isSetEntityWindowOpen: bool = false,
    setEntityWindowSceneTarget: ?*?UUID = null,
    setEntityWindowEntityTarget: ?*?UUID = null,
    setEntityWindowScene: ?UUID = null,
    setEntityWindowEntity: ?UUID = null,
    setEntityWindowRenderTexture: rl.RenderTexture = undefined,
    setEntityWindowCamera: rl.Camera2D = .{
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

    pub fn init(allocator: Allocator) SceneNonPersistentData {
        return SceneNonPersistentData{
            .selectedEntities = ArrayList(*SceneEntity).initCapacity(allocator, 10) catch unreachable,
        };
    }

    pub fn deinit(self: *SceneNonPersistentData, allocator: Allocator) void {
        self.selectedEntities.clearAndFree(allocator);
        rl.unloadRenderTexture(self.setEntityWindowRenderTexture);
        self.setEntityWindowRenderTexture = undefined;
    }

    pub fn load(self: *SceneNonPersistentData, _: [:0]const u8, persistentData: *Scene) void {
        self.setEntityWindowScene = persistentData.id;
        self.setEntityWindowRenderTexture = rl.loadRenderTexture(setEntityReferenceWindowWidth, setEntityReferenceWindowHeight) catch unreachable;
    }
};
