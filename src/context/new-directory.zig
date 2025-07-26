const std = @import("std");
const lib = @import("lib");
const Context = lib.Context;

pub fn newDirectory(self: *Context, name: []const u8) void {
    const p = &(self.currentProject orelse return);
    var currentDir = self.openCurrentDirectory() catch return;
    defer currentDir.close();
    const cd = p.assetsLibrary.currentDirectory orelse unreachable;

    currentDir.makeDir(name) catch |err| {
        self.showError("Could not create directory {s} in {s}: {}", .{ name, cd, err });
        return;
    };

    const relativeToRoot = std.fs.path.joinZ(self.allocator, &.{ cd, name }) catch unreachable;
    defer self.allocator.free(relativeToRoot);

    p.assetsLibrary.appendNewDirectory(self.allocator, relativeToRoot);
}
