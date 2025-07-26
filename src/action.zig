const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const Tilemap = lib.Tilemap;
const TilemapDocument = lib.documents.TilemapDocument;

pub const Action = union(enum) {
    brushPaint: BrushPaint,
    brushDelete: BrushDelete,
    select: Select,
    selectAdd: SelectAdd,
    selectSubtract: SelectSubtract,
    createFloatingSelection: CreateFloatingSelection,
    mergeFloatingSelection: MergeFloatingSelection,
    resize: ResizeTilemap,
    addLayer: AddLayer,
    removeLayer: RemoveLayer,
    renameLayer: RenameLayer,

    pub fn deinit(self: *Action, allocator: Allocator) void {
        switch (self.*) {
            inline else => |*action| action.deinit(allocator),
        }
    }

    pub fn clone(self: Action, allocator: Allocator) Action {
        const i = @intFromEnum(self);

        switch (i) {
            inline 0...std.meta.fields(Action).len - 1 => |x| {
                const field = std.meta.fields(Action)[x];
                const action = @field(self, field.name);
                return @unionInit(Action, field.name, action.clone(allocator));
            },
            else => unreachable,
        }
    }

    pub fn undo(self: Action, allocator: Allocator, tilemap: *Tilemap) void {
        switch (self) {
            inline else => |action| action.undo(allocator, tilemap),
        }
    }

    pub fn redo(self: Action, allocator: Allocator, tilemap: *Tilemap) void {
        switch (self) {
            inline else => |action| action.redo(allocator, tilemap),
        }
    }

    pub fn Generic(comptime name: []const u8) type {
        return struct {
            snapshotBefore: Tilemap,
            snapshotAfter: Tilemap,

            pub const label = name;

            const Self = @This();

            pub fn init(snapshotBefore: Tilemap, allocator: Allocator) Self {
                return Self{
                    .snapshotBefore = snapshotBefore.clone(allocator),
                    .snapshotAfter = undefined,
                };
            }

            pub fn deinit(self: *Self, allocator: Allocator) void {
                self.snapshotAfter.deinit(allocator);
                self.snapshotBefore.deinit(allocator);
            }

            pub fn clone(self: Self, allocator: Allocator) Self {
                return Self{
                    .snapshotBefore = self.snapshotBefore.clone(allocator),
                    .snapshotAfter = self.snapshotAfter.clone(allocator),
                };
            }

            pub fn materialize(self: *Self, allocator: Allocator, snapshotAfter: Tilemap) void {
                self.snapshotAfter = snapshotAfter.clone(allocator);
            }

            pub fn undo(self: Self, allocator: Allocator, tilemap: *Tilemap) void {
                tilemap.deinit(allocator);
                tilemap.* = self.snapshotBefore.clone(allocator);
            }

            pub fn redo(self: Self, allocator: Allocator, tilemap: *Tilemap) void {
                tilemap.deinit(allocator);
                tilemap.* = self.snapshotAfter.clone(allocator);
            }
        };
    }

    pub const BrushPaint = Generic("Paint");
    pub const BrushDelete = Generic("Delete");
    pub const Select = Generic("Select");
    pub const SelectAdd = Generic("SelectAdd");
    pub const SelectSubtract = Generic("SelectSubtract");
    pub const CreateFloatingSelection = Generic("CreateFloatingSelection");
    pub const MergeFloatingSelection = Generic("MergeFloatingSelection");
    pub const ResizeTilemap = Generic("Resize");
    pub const AddLayer = Generic("Add Layer");
    pub const RemoveLayer = Generic("Remove Layer");
    pub const RenameLayer = Generic("Rename Layer");
};
