const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const json = lib.json;
const StringZ = lib.StringZ;
const PropertyObject = lib.PropertyObject;
const Context = lib.Context;

pub const SceneEntity = struct {
    id: UUID,
    position: Vector,
    type: SceneEntityType,

    pub fn init(
        position: Vector,
        entityType: SceneEntityType,
    ) SceneEntity {
        return SceneEntity{
            .id = UUID.init(),
            .position = position,
            .type = entityType,
        };
    }

    pub fn deinit(self: *SceneEntity, allocator: Allocator) void {
        self.type.deinit(allocator);
    }

    pub fn clone(self: SceneEntity, allocator: Allocator) SceneEntity {
        return SceneEntity{
            .id = self.id,
            .position = self.position,
            .type = self.type.clone(allocator),
        };
    }
};

pub const SceneEntityType = union(enum) {
    custom: SceneEntityCustom,
    exit: SceneEntityExit,
    entrance: SceneEntityEntrance,
    tilemap: SceneEntityTilemap,

    pub fn deinit(self: *SceneEntityType, allocator: Allocator) void {
        switch (self.*) {
            .tilemap => {},
            inline else => |*e| e.deinit(allocator),
        }
    }

    pub fn clone(self: SceneEntityType, allocator: Allocator) SceneEntityType {
        return switch (self) {
            .tilemap => self,
            inline .exit, .entrance, .custom => |e, t| @unionInit(SceneEntityType, @tagName(t), e.clone(allocator)),
        };
    }
};

pub const SceneEntityCustom = struct {
    entityTypeId: UUID,
    properties: PropertyObject,

    pub fn init(context: *Context, id: UUID) SceneEntityCustom {
        const properties: PropertyObject = brk: {
            const entityTypeDocument = (context.requestDocumentTypeById(.entityType, id) catch break :brk .empty) orelse break :brk .empty;
            break :brk entityTypeDocument.getProperties().clone(context.allocator);
        };

        return SceneEntityCustom{
            .entityTypeId = id,
            .properties = properties,
        };
    }

    pub fn deinit(self: *SceneEntityCustom, allocator: Allocator) void {
        self.properties.deinit(allocator);
    }

    pub fn clone(self: SceneEntityCustom, allocator: Allocator) SceneEntityCustom {
        return SceneEntityCustom{
            .entityTypeId = self.entityTypeId,
            .properties = self.properties.clone(allocator),
        };
    }
};

pub const SceneEntityExit = struct {
    sceneId: ?UUID = null,
    scale: ?@Vector(2, f32) = .{ 1, 1 },
    entranceKey: StringZ(64),
    isVertical: bool = false,

    pub fn init(allocator: Allocator) SceneEntityExit {
        return SceneEntityExit{
            .entranceKey = .init(allocator, ""),
        };
    }

    pub fn deinit(self: SceneEntityExit, allocator: Allocator) void {
        self.entranceKey.deinit(allocator);
    }

    pub fn clone(self: SceneEntityExit, allocator: Allocator) SceneEntityExit {
        return SceneEntityExit{
            .sceneId = self.sceneId,
            .scale = self.scale,
            .entranceKey = self.entranceKey.clone(allocator),
            .isVertical = self.isVertical,
        };
    }
};

pub const SceneEntityEntrance = struct {
    key: StringZ(64),
    scale: ?@Vector(2, f32) = .{ 1, 1 },

    pub fn init(allocator: Allocator) SceneEntityEntrance {
        return SceneEntityEntrance{
            .key = .initFmt(allocator, "{s}", .{UUID.init().serialize()}),
        };
    }

    pub fn deinit(self: SceneEntityEntrance, allocator: Allocator) void {
        self.key.deinit(allocator);
    }

    pub fn clone(self: SceneEntityEntrance, allocator: Allocator) SceneEntityEntrance {
        return SceneEntityEntrance{
            .key = self.key.clone(allocator),
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
