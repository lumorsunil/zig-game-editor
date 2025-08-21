pub const config = @import("config.zig");
pub usingnamespace @import("context.zig");
pub usingnamespace @import("vector.zig");
pub usingnamespace @import("uuid.zig");
pub usingnamespace @import("history.zig");
pub usingnamespace @import("tilemap.zig");
pub usingnamespace @import("action.zig");
pub usingnamespace @import("project.zig");
pub usingnamespace @import("project-options.zig");
pub usingnamespace @import("document.zig");
pub usingnamespace @import("tool.zig");
pub const tools = struct {
    pub usingnamespace @import("tools/brush.zig");
    pub usingnamespace @import("tools/select.zig");
};
pub const documents = struct {
    pub usingnamespace @import("documents/generic.zig");
    pub usingnamespace @import("documents/scene/document.zig");
    pub const scene = struct {
        pub usingnamespace @import("documents/scene/persistent-data.zig");
        pub usingnamespace @import("documents/scene/versions/1.zig");
    };
    pub usingnamespace @import("documents/tilemap/document.zig");
    pub usingnamespace @import("documents/animation/document.zig");
    pub const animation = struct {
        pub usingnamespace @import("documents/animation/animation.zig");
    };
    pub usingnamespace @import("documents/texture/document.zig");
    pub usingnamespace @import("documents/sound/document.zig");
    pub usingnamespace @import("documents/font/document.zig");
    pub usingnamespace @import("documents/entity-type/document.zig");
};
pub const layouts = struct {
    pub usingnamespace @import("layout/layouts.zig");
    pub usingnamespace @import("layout/scene.zig");
    pub usingnamespace @import("layout/tilemap.zig");
    pub usingnamespace @import("layout/animation.zig");
    pub usingnamespace @import("layout/entity-type.zig");
    pub usingnamespace @import("layout/assets-manager.zig");
    pub const sceneMap = @import("layout/scene-map.zig");
    pub const project = @import("layout/project.zig");
    pub const utils = @import("layout/utils.zig");
};
pub usingnamespace @import("layout-generic.zig");
pub usingnamespace @import("editor-session.zig");
pub usingnamespace @import("serializer.zig");
pub usingnamespace @import("draw-tilemap.zig");
pub usingnamespace @import("string.zig");
pub usingnamespace @import("editor.zig");
pub usingnamespace @import("assets-library.zig");
pub usingnamespace @import("asset-index.zig");
pub const json = @import("json.zig");
pub usingnamespace @import("id-array-hash-map.zig");
pub usingnamespace @import("string-z-array-hash-map.zig");
pub usingnamespace @import("documents/entity-type/property.zig");
pub usingnamespace @import("thumbnail-generator.zig");
pub usingnamespace @import("scene-map.zig");
pub const upgrade = @import("upgrade.zig");
pub usingnamespace @import("select-box.zig");
