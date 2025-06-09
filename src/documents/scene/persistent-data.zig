const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const uuid = @import("uuid");
const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const json = lib.json;
const StringZ = lib.StringZ;

pub const SceneEntity = struct {
    id: UUID,
    position: Vector,
    type: SceneEntityType,
    metadata: StringZ(1024),

    pub fn init(
        allocator: Allocator,
        position: Vector,
        entityType: SceneEntityType,
    ) SceneEntity {
        return SceneEntity{
            .id = UUID.init(),
            .position = position,
            .type = entityType,
            .metadata = .init(allocator, ""),
        };
    }

    pub fn deinit(self: *SceneEntity, allocator: Allocator) void {
        self.metadata.deinit(allocator);
        self.type.deinit(allocator);
    }

    pub fn clone(self: SceneEntity, allocator: Allocator) SceneEntity {
        return SceneEntity{
            .id = self.id,
            .position = self.position,
            .metadata = .init(allocator, self.metadata.slice()),
            .type = self.type.clone(allocator),
        };
    }
};

pub const SceneEntityType = union(enum) {
    klet,
    mossing,
    stening,
    barlingSpawner,
    player,
    npc,
    custom: [:0]const u8,
    exit: SceneEntityExit,
    entrance: SceneEntityEntrance,
    tilemap: SceneEntityTilemap,

    pub fn deinit(self: *SceneEntityType, allocator: Allocator) void {
        switch (self.*) {
            .klet, .mossing, .stening, .barlingSpawner, .player, .npc, .exit, .tilemap => {},
            .custom => |c| allocator.free(c),
            inline else => |*e| e.deinit(allocator),
        }
    }

    pub fn clone(self: SceneEntityType, allocator: Allocator) SceneEntityType {
        return switch (self) {
            .klet, .mossing, .stening, .barlingSpawner, .player, .npc, .exit, .tilemap => self,
            .custom => |c| .{ .custom = allocator.dupeZ(u8, c) catch unreachable },
            .entrance => |entrance| .{ .entrance = entrance.clone(allocator) },
        };
    }
};

pub const SceneEntityExit = struct {
    sceneId: ?UUID = null,
    scale: ?@Vector(2, f32) = .{ 1, 1 },

    pub fn init() SceneEntityExit {
        return SceneEntityExit{};
    }
};

pub const SceneEntityEntrance = struct {
    key: StringZ(64),
    scale: ?@Vector(2, f32) = .{ 1, 1 },

    pub fn init(allocator: Allocator) SceneEntityEntrance {
        return SceneEntityEntrance{
            .key = .initFmt(allocator, "{s}", .{uuid.urn.serialize(uuid.v4.new())}),
        };
    }

    pub fn deinit(self: SceneEntityEntrance, allocator: Allocator) void {
        self.key.deinit(allocator);
    }

    pub fn clone(self: SceneEntityEntrance, allocator: Allocator) SceneEntityEntrance {
        return SceneEntityEntrance{
            .key = .init(allocator, self.key.slice()),
            .scale = self.scale,
        };
    }
};

pub const SceneEntityTilemap = struct {
    tilemapId: ?UUID,

    pub fn init() SceneEntityTilemap {
        return SceneEntityTilemap{
            .tilemapId = null,
        };
    }

    pub fn deinit(self: *SceneEntityTilemap) void {
        self.tilemapId = null;
    }
};

pub const Scene = struct {
    id: UUID,
    entities: ArrayList(*SceneEntity),

    pub fn init(allocator: Allocator) Scene {
        return Scene{
            .id = UUID.init(),
            .entities = ArrayList(*SceneEntity).initCapacity(allocator, 10) catch unreachable,
        };
    }

    pub fn deinit(self: *Scene, allocator: Allocator) void {
        for (self.entities.items) |entity| {
            entity.deinit(allocator);
            allocator.destroy(entity);
        }
        self.entities.clearAndFree(allocator);
    }

    pub fn clone(self: Scene, allocator: Allocator) Scene {
        var cloned = Scene.init(allocator);

        cloned.id = self.id;

        for (self.entities.items) |entity| {
            const clonedEntity = allocator.create(SceneEntity) catch unreachable;
            clonedEntity.* = entity.clone(allocator);
            cloned.entities.append(allocator, clonedEntity) catch unreachable;
        }

        return cloned;
    }

    pub fn jsonStringify(self: *const @This(), jw: anytype) !void {
        try json.writeObject(self.*, jw);
    }

    pub fn jsonParse(
        allocator: Allocator,
        source: anytype,
        options: std.json.ParseOptions,
    ) !@This() {
        return try json.parseObject(@This(), allocator, source, options);
    }
};
