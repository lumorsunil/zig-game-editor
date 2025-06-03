const std = @import("std");
const Allocator = std.mem.Allocator;
const uuid = @import("uuid");
const lib = @import("root").lib;
const UUID = lib.UUIDSerializable;
const Vector = lib.Vector;
const rl = @import("raylib");
const Context = lib.Context;
const config = @import("root").config;
const StringZ = lib.StringZ;

const tileSize = config.tileSize;

pub const EntityTypeIcon = struct {
    texturePath: ?[:0]const u8,
    gridPosition: Vector,
    cellSize: Vector,

    pub const empty = EntityTypeIcon{
        .texturePath = null,
        .gridPosition = .{ 0, 0 },
        .cellSize = .{ 0, 0 },
    };

    pub fn init(
        allocator: Allocator,
        texturePath: ?[:0]const u8,
        gridPosition: Vector,
        cellSize: Vector,
    ) EntityTypeIcon {
        return EntityTypeIcon{
            .texturePath = if (texturePath) |t| allocator.dupeZ(u8, t) catch unreachable else null,
            .gridPosition = gridPosition,
            .cellSize = cellSize,
        };
    }

    pub fn deinit(self: EntityTypeIcon, allocator: Allocator) void {
        if (self.texturePath) |t| allocator.free(t);
    }

    pub fn clone(self: EntityTypeIcon, allocator: Allocator) EntityTypeIcon {
        return EntityTypeIcon.init(
            allocator,
            self.texturePath,
            self.gridPosition,
            self.cellSize,
        );
    }

    pub fn setTexturePath(self: *EntityTypeIcon, allocator: Allocator, texturePath: [:0]const u8) void {
        if (self.texturePath) |t| allocator.free(t);
        self.texturePath = allocator.dupeZ(u8, texturePath) catch unreachable;
    }

    pub fn draw(self: EntityTypeIcon, context: *Context, position: Vector) void {
        const texturePath = self.texturePath orelse return;

        if (context.requestTexture(texturePath)) |texture| {
            const scale = context.scale;
            const sourcePosition: @Vector(2, f32) = @floatFromInt(self.gridPosition * self.cellSize);
            const source = rl.Rectangle.init(
                sourcePosition[0],
                sourcePosition[1],
                @floatFromInt(self.cellSize[0]),
                @floatFromInt(self.cellSize[1]),
            );
            const fPosition: @Vector(2, f32) = @floatFromInt(position);
            const dest = rl.Rectangle.init(
                fPosition[0] * scale,
                fPosition[1] * scale,
                source.width * scale,
                source.height * scale,
            );
            const origin = rl.Vector2.init(source.width / 2 * scale, source.height / 2 * scale);

            rl.drawTexturePro(texture, source, dest, origin, 0, rl.Color.white);
        }
    }
};

pub const EntityType = struct {
    id: UUID,
    name: StringZ(64),
    icon: EntityTypeIcon,

    pub fn init(allocator: Allocator) EntityType {
        return EntityType{
            .id = UUID.init(),
            .name = .init(allocator, "new-entity-type"),
            .icon = .empty,
        };
    }

    pub fn deinit(self: *EntityType, allocator: Allocator) void {
        self.name.deinit(allocator);
        self.icon.deinit(allocator);
    }

    pub fn clone(self: EntityType, allocator: Allocator) EntityType {
        var cloned = EntityType.init(allocator);
        cloned.id = self.id;
        cloned.name = .init(allocator, self.name.buffer);
        cloned.icon = self.icon.clone(allocator);
        return cloned;
    }
};
