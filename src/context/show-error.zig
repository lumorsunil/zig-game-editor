const std = @import("std");
const lib = @import("lib");
const Context = lib.Context;

pub fn showError(self: *Context, comptime fmt: []const u8, args: anytype) void {
    std.log.err(fmt, args);
    self.errorMessage = std.fmt.bufPrintZ(&self.errorMessageBuffer, fmt, args) catch unreachable;
    self.isErrorDialogOpen = true;
}
