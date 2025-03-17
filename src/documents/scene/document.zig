const std = @import("std");
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("root").lib;
const config = @import("root").config;
const Context = lib.Context;
const Vector = lib.Vector;
const UUID = lib.UUIDSerializable;
const drawTilemap = lib.drawTilemap;

pub const SceneEntity = struct {
    id: UUID,
    position: Vector,
    type: SceneEntityType,

    pub fn init(position: Vector, entityType: SceneEntityType) SceneEntity {
        return SceneEntity{
            .id = UUID.init(),
            .position = position,
            .type = entityType,
        };
    }
};

pub const SceneEntityType = enum {
    klet,
    player,
    npc,
    tilemap,
};

pub const Scene = struct {
    entities: ArrayList(*SceneEntity),

    pub fn init() Scene {
        return Scene{
            .entities = ArrayList(*SceneEntity).initBuffer(&.{}),
        };
    }
};

pub const SceneDocument = struct {
    scene: Scene,

    kletTexture: rl.Texture2D = undefined,
    playerTexture: rl.Texture2D = undefined,
    npcTexture: rl.Texture2D = undefined,

    dragPayload: ?SceneEntityType = null,

    pub fn init() SceneDocument {
        return SceneDocument{
            .scene = Scene.init(),
        };
    }

    pub fn deinit(self: SceneDocument) void {
        rl.unloadTexture(self.kletTexture);
        rl.unloadTexture(self.playerTexture);
        rl.unloadTexture(self.npcTexture);
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
            else => unreachable,
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
        }
    }
};
