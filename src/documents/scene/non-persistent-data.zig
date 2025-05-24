const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("root").lib;
const Vector = lib.Vector;
const Scene = @import("persistent-data.zig").Scene;
const SceneEntityType = @import("persistent-data.zig").SceneEntityType;
const SceneEntity = @import("persistent-data.zig").SceneEntity;
const config = @import("root").config;

pub const SceneNonPersistentData = struct {
    kletTexture: rl.Texture2D = undefined,
    mossingTexture: rl.Texture2D = undefined,
    steningTexture: rl.Texture2D = undefined,
    barlingTexture: rl.Texture2D = undefined,
    playerTexture: rl.Texture2D = undefined,
    npcTexture: rl.Texture2D = undefined,

    dragPayload: ?SceneEntityType = null,
    selectedEntities: ArrayList(*SceneEntity),
    dragStartPoint: ?Vector = null,
    isDragging: bool = false,

    pub fn init(allocator: Allocator) SceneNonPersistentData {
        return SceneNonPersistentData{
            .selectedEntities = ArrayList(*SceneEntity).initCapacity(allocator, 10) catch unreachable,
        };
    }

    pub fn deinit(self: *SceneNonPersistentData, allocator: Allocator) void {
        rl.unloadTexture(self.kletTexture);
        rl.unloadTexture(self.mossingTexture);
        rl.unloadTexture(self.steningTexture);
        rl.unloadTexture(self.barlingTexture);
        rl.unloadTexture(self.playerTexture);
        rl.unloadTexture(self.npcTexture);
        self.selectedEntities.clearAndFree(allocator);
    }

    pub fn load(self: *SceneNonPersistentData, _: [:0]const u8, _: *Scene) void {
        self.kletTexture = rl.loadTexture(config.assetsRootDir ++ "klet.png") catch unreachable;
        self.mossingTexture = rl.loadTexture(config.assetsRootDir ++ "mossing.png") catch unreachable;
        self.steningTexture = rl.loadTexture(config.assetsRootDir ++ "stening.png") catch unreachable;
        self.barlingTexture = rl.loadTexture(config.assetsRootDir ++ "barling.png") catch unreachable;
        self.playerTexture = rl.loadTexture(config.assetsRootDir ++ "pyssling.png") catch unreachable;
        self.npcTexture = rl.loadTexture(config.assetsRootDir ++ "kottekarl.png") catch unreachable;
    }
};
