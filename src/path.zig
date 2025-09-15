const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

// TODO: Implement copying assets into the project folder
// so we don't have to worry about absolute paths
pub fn normalizePathZ(allocator: Allocator, path: [:0]const u8) ![:0]const u8 {
    const normalized: [:0]u8 = if (builtin.os.tag == .windows)
        try allocator.dupeZ(u8, path)
    else brk: {
        // TODO: Make this more generic
        const normalizedSize = std.mem.replacementSize(u8, path, "D:", "/mnt/d");
        const normalized: [:0]u8 = try allocator.allocSentinel(u8, normalizedSize + 1, 0);
        _ = std.mem.replace(u8, path, "D:", "/mnt/d", normalized);
        normalized[normalizedSize] = 0;
        break :brk normalized;
    };

    std.mem.replaceScalar(u8, normalized, '\\', '/');
    return normalized;
}
