const std = @import("std");
const lib = @import("root").lib;
const Context = lib.Context;

// Returns true if successful
pub fn saveIndex(self: *Context) bool {
    const p = self.currentProject orelse return false;
    std.log.debug("Updating index", .{});
    p.saveIndex() catch |err| {
        std.log.err("Could not save asset index: {}", .{err});
        return false;
    };
    return true;
}
