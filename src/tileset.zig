pub const Tileset = struct {
    source: [:0]const u8,

    pub fn init(source: [:0]const u8) Tileset {
        return Tileset{
            .source = source,
        };
    }
};
