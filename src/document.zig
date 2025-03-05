const TilemapDocument = @import("documents/tilemap/document.zig").TilemapDocument;

pub const Document = struct {
    name: []const u8,
    filePath: []const u8,
    content: Content,

    pub const Content = union(enum) {
        tilemap: TilemapDocument,
    };
};
