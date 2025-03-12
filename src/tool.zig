const std = @import("std");
const Allocator = std.mem.Allocator;
const BrushTool = @import("tools/brush.zig").BrushTool;
const SelectTool = @import("tools/select.zig").SelectTool;

pub const Tool = struct {
    name: [:0]const u8,
    impl: ImplTool,

    pub fn init(name: [:0]const u8, impl: ImplTool) Tool {
        return Tool{
            .name = name,
            .impl = impl,
        };
    }

    pub fn deinit(self: *Tool, allocator: Allocator) void {
        switch (self.impl) {
            inline else => |*tool| tool.deinit(allocator),
        }
    }
};

pub const ImplTool = union(enum) {
    brush: BrushTool,
    select: SelectTool,
};
