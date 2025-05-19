const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const uuid = @import("uuid");
const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const json = lib.json;

pub const SceneEntity = struct {
    id: UUID,
    position: Vector,
    type: SceneEntityType,
    metadata: [:0]u8,

    pub const MAX_METADATA_LENGTH = 1024;

    pub fn init(
        allocator: Allocator,
        position: Vector,
        entityType: SceneEntityType,
    ) SceneEntity {
        const metadata = allocator.allocSentinel(u8, MAX_METADATA_LENGTH, 0) catch unreachable;
        metadata[0] = 0;

        return SceneEntity{
            .id = UUID.init(),
            .position = position,
            .type = entityType,
            .metadata = metadata[0..0 :0],
        };
    }

    pub fn deinit(self: *SceneEntity, allocator: Allocator) void {
        allocator.free(self.metadataBuffer());
        self.type.deinit(allocator);
    }

    pub fn clone(self: SceneEntity, allocator: Allocator) SceneEntity {
        const metadata = allocator.allocSentinel(u8, MAX_METADATA_LENGTH, 0) catch unreachable;
        std.mem.copyForwards(u8, metadata, self.metadata);
        metadata[self.metadata.len] = 0;

        return SceneEntity{
            .id = self.id,
            .position = self.position,
            .metadata = std.mem.span(metadata.ptr),
            .type = self.type.clone(allocator),
        };
    }

    pub fn metadataBuffer(self: *SceneEntity) [:0]u8 {
        return @ptrCast(self.metadata.ptr[0..MAX_METADATA_LENGTH]);
    }

    pub fn imguiCommit(self: *SceneEntity) void {
        self.metadata = std.mem.span(self.metadata.ptr);
    }
};

pub const SceneEntityType = union(enum) {
    klet,
    mossing,
    stening,
    barlingSpawner,
    player,
    npc,
    exit: SceneEntityExit,
    entrance: SceneEntityEntrance,
    tilemap: SceneEntityTilemap,

    pub fn deinit(self: SceneEntityType, allocator: Allocator) void {
        switch (self) {
            .klet, .mossing, .stening, .barlingSpawner, .player, .npc => {},
            inline else => |e| e.deinit(allocator),
        }
    }

    pub fn clone(self: SceneEntityType, allocator: Allocator) SceneEntityType {
        return switch (self) {
            .klet, .mossing, .stening, .barlingSpawner, .player, .npc => self,
            .exit => |exit| .{ .exit = exit.clone(allocator) },
            .entrance => |entrance| .{ .entrance = entrance.clone(allocator) },
            .tilemap => |tilemap| .{ .tilemap = tilemap.clone(allocator) },
        };
    }
};

pub const SceneEntityExit = struct {
    sceneFileName: ?[:0]const u8 = null,
    scale: ?@Vector(2, f32) = .{ 1, 1 },

    pub fn init() SceneEntityExit {
        return SceneEntityExit{};
    }

    pub fn deinit(self: SceneEntityExit, allocator: Allocator) void {
        if (self.sceneFileName) |scf| {
            allocator.free(scf);
        }
    }

    pub fn clone(self: SceneEntityExit, allocator: Allocator) SceneEntityExit {
        return SceneEntityExit{
            .sceneFileName = if (self.sceneFileName) |scf| allocator.dupeZ(u8, scf) catch unreachable else null,
            .scale = self.scale,
        };
    }

    pub fn setSceneFileName(
        self: *SceneEntityExit,
        allocator: Allocator,
        sceneFileName: []const u8,
    ) void {
        if (self.sceneFileName) |scf| {
            if (sceneFileName.ptr != scf.ptr) {
                allocator.free(scf);
            }
        }

        self.sceneFileName = allocator.dupeZ(u8, sceneFileName) catch unreachable;
    }
};

pub const SceneEntityEntrance = struct {
    key: [:0]u8,
    scale: ?@Vector(2, f32) = .{ 1, 1 },

    pub const KEY_MAX_LENGTH = 37;

    pub fn init(allocator: Allocator) SceneEntityEntrance {
        const key = allocator.allocSentinel(u8, KEY_MAX_LENGTH, 0) catch unreachable;
        _ = std.fmt.bufPrintZ(key, "{s}", .{uuid.urn.serialize(uuid.v4.new())}) catch unreachable;

        return SceneEntityEntrance{
            .key = key,
        };
    }

    pub fn deinit(self: SceneEntityEntrance, allocator: Allocator) void {
        allocator.free(self.key);
    }

    pub fn clone(self: SceneEntityEntrance, allocator: Allocator) SceneEntityEntrance {
        return SceneEntityEntrance{
            .key = allocator.dupeZ(u8, self.key) catch unreachable,
            .scale = self.scale,
        };
    }

    pub fn keyImguiBuffer(self: *SceneEntityEntrance) [:0]u8 {
        return @ptrCast(self.key.ptr[0..KEY_MAX_LENGTH]);
    }

    pub fn imguiCommit(self: *SceneEntityEntrance) void {
        self.key = std.mem.span(self.key.ptr);
    }
};

pub const SceneEntityTilemap = struct {
    fileName: ?[:0]const u8,

    pub fn init() SceneEntityTilemap {
        return SceneEntityTilemap{
            .fileName = null,
        };
    }

    pub fn deinit(self: SceneEntityTilemap, allocator: Allocator) void {
        if (self.fileName) |fileName| {
            allocator.free(fileName);
        }
    }

    pub fn clone(self: SceneEntityTilemap, allocator: Allocator) SceneEntityTilemap {
        return SceneEntityTilemap{
            .fileName = if (self.fileName) |fileName| allocator.dupeZ(u8, fileName) catch unreachable else null,
        };
    }

    pub fn setFileName(
        self: *SceneEntityTilemap,
        allocator: Allocator,
        fileName: [:0]const u8,
    ) void {
        if (self.fileName) |f| {
            allocator.free(f);
        }

        self.fileName = allocator.dupeZ(u8, fileName) catch unreachable;
    }
};

pub const Scene = struct {
    entities: ArrayList(*SceneEntity),

    pub fn init(allocator: Allocator) Scene {
        return Scene{
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
