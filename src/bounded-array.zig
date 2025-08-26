pub fn BoundedArray(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T = undefined,
        len: usize = 0,

        pub const empty: @This() = .{};

        pub fn append(self: *@This(), item: T) void {
            self.buffer[self.len] = item;
            self.len += 1;
        }

        pub fn appendSlice(self: *@This(), items: []T) void {
            for (0..items.len) |i| {
                self.buffer[self.len + i] = items[i];
            }
            self.len += items.len;
        }

        pub fn get(self: @This(), index: usize) T {
            return self.buffer[index];
        }

        pub fn slice(self: @This()) []const T {
            return self.buffer[0..self.len];
        }
    };
}
