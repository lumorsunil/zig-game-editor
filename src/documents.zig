pub const generic = @import("documents/generic.zig");
pub const scene = @import("documents/scene.zig");

    pub usingnamespace @import("documents/tilemap/document.zig");
    pub usingnamespace @import("documents/animation/document.zig");
    pub const animation = struct {
        pub usingnamespace @import("documents/animation/animation.zig");
    };
    pub usingnamespace @import("documents/texture/document.zig");
    pub usingnamespace @import("documents/sound/document.zig");
    pub usingnamespace @import("documents/font/document.zig");
    pub usingnamespace @import("documents/entity-type/document.zig");
