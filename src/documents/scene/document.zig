const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("root").lib;
const config = @import("root").config;
const Context = lib.Context;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;
const uuid = @import("uuid");
const drawTilemap = lib.drawTilemap;

pub const SceneEntity = struct {
    id: UUID,
    position: Vector,
    type: SceneEntityType,
    metadata: [:0]u8,

    pub fn init(
        allocator: Allocator,
        position: Vector,
        entityType: SceneEntityType,
    ) SceneEntity {
        const metadata = allocator.allocSentinel(u8, 1024, 0) catch unreachable;
        @memset(metadata, ' ');
        metadata[0] = 0;

        return SceneEntity{
            .id = UUID.init(),
            .position = position,
            .type = entityType,
            .metadata = metadata,
        };
    }

    pub fn clone(self: SceneEntity, allocator: Allocator) SceneEntity {
        const metadata = allocator.allocSentinel(u8, 1024, 0) catch unreachable;
        @memset(metadata, ' ');
        std.mem.copyForwards(u8, metadata, self.metadata);
        metadata[self.metadata.len] = 0;

        return SceneEntity{
            .id = self.id,
            .position = self.position,
            .metadata = metadata,
            .type = self.type.clone(allocator),
        };
    }

    pub fn deinit(self: SceneEntity, allocator: Allocator) void {
        allocator.free(self.metadata);
        switch (self.type) {
            .exit => |exit| exit.deinit(allocator),
            .tilemap => |tilemap| tilemap.deinit(allocator),
            else => {},
        }
    }

    pub fn jsonStringify(self: *const SceneEntity, jw: anytype) !void {
        try jw.beginObject();
        inline for (std.meta.fields(SceneEntity)) |field| {
            try jw.objectField(field.name);

            if (std.mem.eql(u8, field.name, "metadata")) {
                try jw.write(@as([*:0]u8, @ptrCast(self.metadata)));
            } else {
                try jw.write(@field(self, field.name));
            }
        }
        try jw.endObject();
    }
};

pub const SceneEntityType = union(enum) {
    klet,
    player,
    npc,
    exit: SceneEntityExit,
    entrance: SceneEntityEntrance,
    tilemap: SceneEntityTilemap,

    pub fn clone(self: SceneEntityType, allocator: Allocator) SceneEntityType {
        return switch (self) {
            .klet, .player, .npc => self,
            .exit => |exit| .{ .exit = exit.clone(allocator) },
            .entrance => |entrance| .{ .entrance = entrance.clone(allocator) },
            .tilemap => |tilemap| .{ .tilemap = tilemap.clone(allocator) },
        };
    }
};

pub const SceneEntityExit = struct {
    sceneFileName: ?[]const u8,

    pub fn init() SceneEntityExit {
        return SceneEntityExit{
            .sceneFileName = null,
        };
    }

    pub fn clone(self: SceneEntityExit, allocator: Allocator) SceneEntityExit {
        return SceneEntityExit{
            .sceneFileName = if (self.sceneFileName) |scf| allocator.dupe(u8, scf) catch unreachable else null,
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

        self.sceneFileName = allocator.dupe(u8, sceneFileName) catch unreachable;
    }

    pub fn deinit(self: SceneEntityExit, allocator: Allocator) void {
        if (self.sceneFileName) |scf| {
            allocator.free(scf);
        }
    }
};

pub const SceneEntityEntrance = struct {
    key: [:0]u8,

    pub fn init(allocator: Allocator) SceneEntityEntrance {
        const key = allocator.allocSentinel(u8, 37, 0) catch unreachable;
        _ = std.fmt.bufPrintZ(key, "{s}", .{uuid.urn.serialize(uuid.v4.new())}) catch unreachable;

        return SceneEntityEntrance{
            .key = key,
        };
    }

    pub fn clone(self: SceneEntityEntrance, allocator: Allocator) SceneEntityEntrance {
        return SceneEntityEntrance{
            .key = allocator.dupeZ(u8, self.key) catch unreachable,
        };
    }
};

pub const SceneEntityTilemap = struct {
    fileName: ?[]const u8,

    pub fn init() SceneEntityTilemap {
        return SceneEntityTilemap{
            .fileName = null,
        };
    }

    pub fn clone(self: SceneEntityTilemap, allocator: Allocator) SceneEntityTilemap {
        return SceneEntityTilemap{
            .fileName = if (self.fileName) |fileName| allocator.dupe(u8, fileName) catch unreachable else null,
        };
    }

    pub fn setSceneFileName(
        self: *SceneEntityTilemap,
        allocator: Allocator,
        fileName: []const u8,
    ) void {
        if (self.fileName) |f| {
            allocator.free(f);
        }

        self.fileName = allocator.dupe(u8, fileName) catch unreachable;
    }

    pub fn deinit(self: SceneEntityTilemap, allocator: Allocator) void {
        if (self.fileName) |fileName| {
            allocator.free(fileName);
        }
    }
};

pub const Scene = struct {
    entities: ArrayList(*SceneEntity),

    pub fn init(allocator: Allocator) Scene {
        return Scene{
            .entities = ArrayList(*SceneEntity).initCapacity(allocator, 10) catch unreachable,
        };
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

    pub fn deinit(self: *Scene, allocator: Allocator) void {
        for (self.entities.items) |entity| {
            entity.deinit(allocator);
            allocator.destroy(entity);
        }
        self.entities.clearAndFree(allocator);
    }
};

pub const SceneDocument = struct {
    scene: Scene,
    sceneArena: ?std.heap.ArenaAllocator = null,

    kletTexture: rl.Texture2D = undefined,
    playerTexture: rl.Texture2D = undefined,
    npcTexture: rl.Texture2D = undefined,

    dragPayload: ?SceneEntityType = null,
    selectedEntities: ArrayList(*SceneEntity),
    dragStartPoint: ?Vector = null,
    isDragging: bool = false,

    pub fn init(allocator: Allocator) SceneDocument {
        return SceneDocument{
            .scene = Scene.init(allocator),
            .selectedEntities = ArrayList(*SceneEntity).initCapacity(allocator, 10) catch unreachable,
        };
    }

    pub fn deinit(self: *SceneDocument, allocator: Allocator) void {
        rl.unloadTexture(self.kletTexture);
        rl.unloadTexture(self.playerTexture);
        rl.unloadTexture(self.npcTexture);
        self.scene.deinit(allocator);
        self.selectedEntities.clearAndFree(allocator);
    }

    pub fn load(self: *SceneDocument) void {
        self.kletTexture = rl.loadTexture(config.assetsRootDir ++ "klet.png");
        self.playerTexture = rl.loadTexture(config.assetsRootDir ++ "pyssling.png");
        self.npcTexture = rl.loadTexture(config.assetsRootDir ++ "kottekarl.png");
    }

    pub fn getTextureFromEntityType(self: *SceneDocument, entityType: SceneEntityType) *rl.Texture2D {
        return switch (entityType) {
            .klet => &self.kletTexture,
            .player => &self.playerTexture,
            .npc => &self.npcTexture,
            else => unreachable,
        };
    }

    pub fn getSourceRectFromEntityType(
        self: *SceneDocument,
        entityType: SceneEntityType,
    ) rl.Rectangle {
        _ = self; // autofix
        return switch (entityType) {
            .klet => rl.Rectangle.init(0, 0, 32, 32),
            .player => rl.Rectangle.init(0, 0, 16, 32),
            .npc => rl.Rectangle.init(0, 0, 32, 32),
            else => unreachable,
        };
    }

    pub fn getSizeFromEntityType(
        self: *SceneDocument,
        entityType: SceneEntityType,
    ) rl.Vector2 {
        _ = self; // autofix
        return switch (entityType) {
            .klet => rl.Vector2.init(32, 32),
            .player => rl.Vector2.init(16, 32),
            .npc => rl.Vector2.init(32, 32),
            .exit => rl.Vector2.init(16, 16),
            .entrance => rl.Vector2.init(16, 16),
            .tilemap => unreachable,
        };
    }

    pub fn drawEntity(self: *SceneDocument, context: *Context, entity: SceneEntity) void {
        const scale: f32 = @floatFromInt(context.scale);
        switch (entity.type) {
            .klet => {
                const source = rl.Rectangle.init(0, 0, 32, 32);
                const position: @Vector(2, f32) = @floatFromInt(entity.position);
                const dest = rl.Rectangle.init(
                    position[0] * scale,
                    position[1] * scale,
                    32 * scale,
                    32 * scale,
                );
                const origin = rl.Vector2.init(16 * scale, 16 * scale);

                rl.drawTexturePro(self.kletTexture, source, dest, origin, 0, rl.Color.white);
            },
            .player => {
                const source = rl.Rectangle.init(0, 0, 16, 32);
                const position: @Vector(2, f32) = @floatFromInt(entity.position);
                const dest = rl.Rectangle.init(
                    position[0] * scale,
                    position[1] * scale,
                    16 * scale,
                    32 * scale,
                );
                const origin = rl.Vector2.init(8 * scale, 16 * scale);

                rl.drawTexturePro(self.playerTexture, source, dest, origin, 0, rl.Color.white);
            },
            .npc => {
                const source = rl.Rectangle.init(0, 0, 32, 32);
                const position: @Vector(2, f32) = @floatFromInt(entity.position);
                const dest = rl.Rectangle.init(
                    position[0] * scale,
                    position[1] * scale,
                    32 * scale,
                    32 * scale,
                );
                const origin = rl.Vector2.init(24 * scale, 16 * scale);

                rl.drawTexturePro(self.npcTexture, source, dest, origin, 0, rl.Color.white);
            },
            .tilemap => {
                const tilemapSizeHalf = context.tilemapDocument.tilemap.grid.size * context.tilemapDocument.tilemap.tileSize * context.scaleV / Vector{ 2, 2 };
                const position = entity.position - tilemapSizeHalf;
                drawTilemap(context, position);
            },
            .exit => {
                const sizeInt = context.tilemapDocument.tilemap.tileSize * context.scaleV;
                const size: @Vector(2, f32) = @floatFromInt(sizeInt);
                const position: @Vector(2, f32) = @floatFromInt(entity.position * context.scaleV - sizeInt / Vector{ 2, 2 });

                const rec = rl.Rectangle.init(
                    position[0],
                    position[1],
                    size[0],
                    size[1],
                );

                rl.drawRectanglePro(rec, rl.Vector2.zero(), 0, rl.Color.white.alpha(0.5));
            },
            .entrance => {
                const sizeInt = context.tilemapDocument.tilemap.tileSize * context.scaleV;
                const size: @Vector(2, f32) = @floatFromInt(sizeInt);
                const position: @Vector(2, f32) = @floatFromInt(entity.position * context.scaleV - sizeInt / Vector{ 2, 2 });

                const rec = rl.Rectangle.init(
                    position[0],
                    position[1],
                    size[0],
                    size[1],
                );

                rl.drawRectanglePro(rec, rl.Vector2.zero(), 0, rl.Color.yellow.alpha(0.5));
            },
        }
    }

    pub fn selectEntity(self: *SceneDocument, entity: *SceneEntity, allocator: Allocator) void {
        self.selectedEntities.clearRetainingCapacity();
        self.selectedEntities.append(allocator, entity) catch unreachable;
    }

    pub fn deleteEntity(self: *SceneDocument, entity: *SceneEntity) void {
        const entitiesIndex = std.mem.indexOfScalar(*SceneEntity, self.scene.entities.items, entity) orelse unreachable;
        _ = self.scene.entities.swapRemove(entitiesIndex);
        const selectedEntitiesIndex = std.mem.indexOfScalar(*SceneEntity, self.selectedEntities.items, entity) orelse unreachable;
        _ = self.selectedEntities.swapRemove(selectedEntitiesIndex);
    }

    pub fn getTilemapFileName(self: *SceneDocument) ?[]const u8 {
        for (self.scene.entities.items) |entity| {
            switch (entity.type) {
                .tilemap => |tilemap| return tilemap.fileName,
                else => continue,
            }
        }

        return null;
    }

    pub fn serialize(self: *const SceneDocument, writer: anytype) !void {
        try std.json.stringify(self.scene, .{}, writer);
    }

    pub fn deserialize(allocator: Allocator, reader: anytype) !*SceneDocument {
        const parsed = try std.json.parseFromTokenSource(Scene, allocator, reader, .{});
        const scene = parsed.value.clone(allocator);
        parsed.deinit();

        var sceneDocument = try allocator.create(SceneDocument);
        sceneDocument.* = SceneDocument.init(allocator);
        sceneDocument.scene = scene;
        sceneDocument.load();

        return sceneDocument;
    }
};
