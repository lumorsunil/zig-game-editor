const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const StringZ = lib.StringZ;

pub const StringZContext = struct {
    const K = StringZ;

    pub fn hash(self: @This(), s: K) u32 {
        _ = self;
        return std.array_hash_map.hashString(s.slice());
    }
    pub fn eql(self: @This(), a: K, b: K, b_index: usize) bool {
        _ = self;
        _ = b_index;
        return std.mem.eql(u8, a.slice(), b.slice());
    }
};

pub fn StringZArrayHashMap(comptime V: type) type {
    const K = StringZ;

    const InnerHashMap = std.ArrayHashMapUnmanaged(K, V, StringZContext, false);

    return struct {
        map: InnerHashMap = .empty,

        pub const empty: @This() = .{};

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            for (self.map.keys()) |k| {
                k.deinit(allocator);
            }
            self.map.clearAndFree(allocator);
        }

        pub fn clone(self: @This(), allocator: Allocator) @This() {
            var cloned = self;

            cloned.map = .empty;
            cloned.map.ensureTotalCapacity(allocator, self.map.capacity()) catch unreachable;

            for (self.map.values(), 0..) |v, i| {
                const k = self.map.keys()[i];
                cloned.map.putAssumeCapacity(k.clone(allocator), v.clone(allocator));
            }

            return cloned;
        }

        pub fn jsonParse(
            allocator: Allocator,
            source: anytype,
            options: std.json.ParseOptions,
        ) !@This() {
            var map: InnerHashMap = .empty;
            errdefer map.deinit(allocator);

            if (.object_begin != try source.next()) return error.UnexpectedToken;
            while (true) {
                const token = try source.nextAlloc(allocator, options.allocate.?);
                switch (token) {
                    inline .string, .allocated_string => |k| {
                        defer allocator.free(k);
                        const kZ = try allocator.dupeZ(u8, k);
                        defer allocator.free(kZ);
                        const stringZKey: K = .init(allocator, kZ);
                        const gop = try map.getOrPut(allocator, stringZKey);
                        if (gop.found_existing) {
                            switch (options.duplicate_field_behavior) {
                                .use_first => {
                                    // Parse and ignore the redundant value.
                                    // We don't want to skip the value, because we want type checking.
                                    _ = try std.json.innerParse(V, allocator, source, options);
                                    continue;
                                },
                                .@"error" => return error.DuplicateField,
                                .use_last => {},
                            }
                        }
                        gop.value_ptr.* = try std.json.innerParse(V, allocator, source, options);
                    },
                    .object_end => break,
                    else => unreachable,
                }
            }
            return .{ .map = map };
        }

        pub fn jsonParseFromValue(
            allocator: Allocator,
            source: std.json.Value,
            options: std.json.ParseOptions,
        ) !@This() {
            if (source != .object) return error.UnexpectedToken;

            var map: InnerHashMap = .empty;
            errdefer map.deinit(allocator);

            var it = source.object.iterator();
            while (it.next()) |kv| {
                const kZ = try allocator.dupeZ(u8, kv.key_ptr.*);
                defer allocator.free(kZ);
                const stringZKey: K = .init(allocator, kZ);
                try map.put(allocator, stringZKey, try std.json.innerParseFromValue(V, allocator, kv.value_ptr.*, options));
            }
            return .{ .map = map };
        }

        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.beginObject();
            var it = self.map.iterator();
            while (it.next()) |kv| {
                try jws.objectField(@ptrCast(kv.key_ptr.slice()));
                try jws.write(kv.value_ptr.*);
            }
            try jws.endObject();
        }

        /// key is duplicated, so caller needs to free it
        pub fn put(self: *@This(), allocator: Allocator, key: [:0]const u8, value: V) void {
            const stringZKey: K = .init(allocator, key);
            self.map.put(allocator, stringZKey, value) catch unreachable;
        }

        /// key is duplicated, so caller needs to free it
        pub fn putAssumeCapacity(
            self: *@This(),
            allocator: Allocator,
            key: [:0]const u8,
            value: V,
        ) void {
            const stringZKey: K = .init(allocator, key);
            self.map.putAssumeCapacity(stringZKey, value);
        }

        pub fn getPtr(self: *@This(), allocator: Allocator, key: [:0]const u8) ?*V {
            const stringZKey: K = .init(allocator, key);
            defer stringZKey.deinit(allocator);
            return self.map.getPtr(stringZKey);
        }

        pub fn contains(self: @This(), allocator: Allocator, key: []const u8) bool {
            const keyDuped = allocator.dupeZ(u8, key) catch unreachable;
            defer allocator.free(keyDuped);
            const stringZKey = K{ .buffer = keyDuped };
            return self.map.contains(stringZKey);
        }

        pub fn fetchOrderedRemove(
            self: *@This(),
            allocator: Allocator,
            key: [:0]const u8,
        ) ?InnerHashMap.KV {
            const stringZKey: K = .init(allocator, key);
            return self.map.fetchOrderedRemove(stringZKey);
        }
    };
}
