const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const rl = @import("raylib");
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const json = lib.json;
const StringZ = lib.StringZ;
const PropertyObject = lib.PropertyObject;
const Context = lib.Context;
const DocumentVersion = lib.documents.DocumentVersion;
const firstDocumentVersion = lib.documents.firstDocumentVersion;
const upgrade = lib.upgrade;

pub const SceneEntity = struct {
    id: UUID,
    position: Vector,
    scale: @Vector(2, f32),
    type: SceneEntityType,

    pub fn init(
        position: Vector,
        entityType: SceneEntityType,
    ) SceneEntity {
        return SceneEntity{
            .id = UUID.init(),
            .position = position,
            .scale = .{ 1, 1 },
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
            .scale = self.scale,
            .type = self.type.clone(allocator),
        };
    }

    const defaultResizable = true;

    pub fn isResizable(self: SceneEntity) bool {
        switch (self.type) {
            inline else => |t| {
                if (@hasDecl(@TypeOf(t), "isResizable")) {
                    return t.isResizable();
                } else {
                    return defaultResizable;
                }
            },
        }
    }

    pub fn isPointInEntityRect(
        self: SceneEntity,
        point: @Vector(2, f32),
    ) bool {
        switch (self.type) {
            inline else => |t| {
                if (@hasDecl(@TypeOf(t), "isPointInEntityRect")) {
                    return t.isPointInEntityRect(@floatFromInt(self.position), point);
                } else {
                    return false;
                }
            },
        }
    }
};

pub const SceneEntityType = union(enum) {
    custom: SceneEntityCustom,
    exit: SceneEntityExit,
    entrance: SceneEntityEntrance,
    point: SceneEntityPoint,
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
    entranceKey: StringZ,
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
    key: StringZ,
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

pub const SceneEntityPoint = struct {
    key: StringZ,

    pub fn init(allocator: Allocator) SceneEntityPoint {
        return SceneEntityPoint{
            .key = .initFmt(allocator, "New Point", .{}),
        };
    }

    pub fn deinit(self: SceneEntityPoint, allocator: Allocator) void {
        self.key.deinit(allocator);
    }

    pub fn clone(self: SceneEntityPoint, allocator: Allocator) SceneEntityPoint {
        return SceneEntityPoint{
            .key = self.key.clone(allocator),
        };
    }

    pub fn isResizable(_: SceneEntityPoint) bool {
        return false;
    }

    pub fn getLabelRect(self: SceneEntityPoint, position: @Vector(2, f32)) rl.Rectangle {
        var buffer: [256:0]u8 = undefined;
        const text = std.fmt.bufPrintZ(&buffer, "{}", .{self.key}) catch unreachable;
        const textHeight = 24;
        const textWidth: f32 = @floatFromInt(rl.measureText(text, textHeight));
        const textPosition = rl.Vector2.init(position[0] - textWidth / 2, position[1] - textHeight - 4);

        const textRec = rl.Rectangle.init(
            textPosition.x,
            textPosition.y,
            textWidth,
            textHeight,
        );

        return textRec;
    }

    pub fn drawLabel(self: SceneEntityPoint, textRec: rl.Rectangle) void {
        var buffer: [256:0]u8 = undefined;
        const text = std.fmt.bufPrintZ(&buffer, "{}", .{self.key}) catch unreachable;

        rl.drawRectanglePro(textRec, rl.Vector2.zero(), 0, rl.Color.black.alpha(0.5));
        rl.drawTextEx(rl.getFontDefault() catch unreachable, text, .{ .x = textRec.x, .y = textRec.y }, textRec.height, 2, rl.Color.white.alpha(0.5));
    }

    pub fn isPointInEntityRect(
        self: SceneEntityPoint,
        entityPosition: @Vector(2, f32),
        point: @Vector(2, f32),
    ) bool {
        var textRec = self.getLabelRect(entityPosition);
        textRec.x += textRec.width / 2 - textRec.width / 8;
        textRec.width /= 4;
        textRec.y += textRec.height / 2 - textRec.height / 8;
        textRec.height /= 4;
        textRec.y += textRec.height * 2;
        return rl.checkCollisionPointRec(.{ .x = point[0], .y = point[1] }, textRec);
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
    version: DocumentVersion,
    id: UUID,
    entities: ArrayList(*SceneEntity),

    pub const currentVersion: DocumentVersion = firstDocumentVersion + 3;

    pub const upgraders = .{
        @import("upgrades/0-1.zig"),
        @import("upgrades/1-2.zig"),
        @import("upgrades/2-3.zig"),
    };

    pub const UpgradeContainer = upgrade.Container.init(&.{});

    pub fn init(allocator: Allocator) Scene {
        return Scene{
            .version = currentVersion,
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
};
