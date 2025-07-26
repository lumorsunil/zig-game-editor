const rl = @import("raylib");
const lib = @import("lib");
const Context = lib.Context;
const UUID = lib.UUIDSerializable;
const generateThumbnail = lib.generateThumbnail;

pub fn requestThumbnailById(self: *Context, id: UUID) !?*rl.Texture2D {
    const p = &(self.currentProject orelse return null);
    return p.requestThumbnailById(self.allocator, id);
}

pub fn updateThumbnailById(self: *Context, id: UUID) void {
    const p = &(self.currentProject orelse return);
    const path = self.getFilePathById(id) orelse return;
    const document = self.requestDocumentById(id) orelse return;
    const image = generateThumbnail(self, document) catch |err| {
        self.showError("Could not update thumbnail for document {s}: {}", .{ path, err });
        return;
    } orelse return;
    defer rl.unloadImage(image);

    p.updateThumbnailById(self.allocator, id, image) catch |err| {
        self.showError("Could not update thumbnail for document {s}: {}", .{ path, err });
    };
}
