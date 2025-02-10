const BrushTool = @import("tools/brush.zig").BrushTool;

pub const Tool = struct {
    name: [:0]const u8,
    impl: ImplTool,

    pub fn init(name: [:0]const u8, impl: ImplTool) Tool {
        return Tool{
            .name = name,
            .impl = impl,
        };
    }
};

pub const ImplTool = union(enum) {
    brush: BrushTool,
};
