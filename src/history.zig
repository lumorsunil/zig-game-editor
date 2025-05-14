const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayListUnmanaged;
const Action = @import("action.zig").Action;
const Tilemap = @import("tilemap.zig").Tilemap;

pub const History = struct {
    actions: ArrayList(Action),
    nextActionIndex: usize,

    pub fn init() History {
        return History{
            .actions = ArrayList(Action).initBuffer(&.{}),
            .nextActionIndex = 0,
        };
    }

    pub fn deinit(self: *History, allocator: Allocator) void {
        for (self.actions.items) |*action| {
            action.deinit(allocator);
        }
        self.actions.deinit(allocator);
    }

    pub fn clone(self: History, allocator: Allocator) History {
        var cloned = self;

        cloned.actions = std.ArrayListUnmanaged(Action).initCapacity(allocator, self.actions.items.len) catch unreachable;
        for (self.actions.items) |action| {
            cloned.actions.appendAssumeCapacity(action.clone(allocator));
        }

        return cloned;
    }

    pub fn push(self: *History, allocator: Allocator, action: Action) void {
        if (self.canRedo()) {
            for (self.actions.items[self.nextActionIndex..]) |*nextAction| {
                nextAction.deinit(allocator);
            }
            self.actions.shrinkRetainingCapacity(self.nextActionIndex);
        }

        self.actions.append(allocator, action) catch unreachable;
        self.nextActionIndex = self.actions.items.len;
    }

    pub fn undo(self: *History, allocator: Allocator, tilemap: *Tilemap) void {
        if (!self.canUndo()) return;

        const i = self.nextActionIndex - 1;
        const lastAction = &self.actions.items[i];
        lastAction.undo(allocator, tilemap);
        self.nextActionIndex = i;
    }

    pub fn redo(self: *History, allocator: Allocator, tilemap: *Tilemap) void {
        if (!self.canRedo()) return;

        const i = self.nextActionIndex;
        const nextAction = &self.actions.items[i];
        nextAction.redo(allocator, tilemap);
        self.nextActionIndex = i + 1;
    }

    pub fn canUndo(self: History) bool {
        return self.nextActionIndex > 0;
    }

    pub fn canRedo(self: History) bool {
        return self.nextActionIndex < self.actions.items.len;
    }
};
