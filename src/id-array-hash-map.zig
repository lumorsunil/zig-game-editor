const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;

const ParseOptions = std.json.ParseOptions;
const innerParse = std.json.innerParse;
const innerParseFromValue = std.json.innerParseFromValue;
const Value = std.json.Value;

const K = UUID;

fn deserializeKey(k: []const u8) !K {
    return UUID.deserialize(k) catch {
        return std.json.Error.SyntaxError;
    };
}

pub fn IdArrayHashMap(comptime V: type) type {
    return struct {
        map: std.AutoArrayHashMapUnmanaged(K, V) = .empty,

        pub const empty: @This() = .{};

        pub fn deinit(self: *@This(), allocator: Allocator) void {
            self.map.deinit(allocator);
        }

        pub fn jsonParse(allocator: Allocator, source: anytype, options: ParseOptions) !@This() {
            var map: std.AutoArrayHashMapUnmanaged(K, V) = .empty;
            errdefer map.deinit(allocator);

            if (.object_begin != try source.next()) return error.UnexpectedToken;
            while (true) {
                const token = try source.nextAlloc(allocator, options.allocate.?);
                switch (token) {
                    inline .string, .allocated_string => |k| {
                        defer allocator.free(k);
                        const uuidKey = try deserializeKey(k);
                        const gop = try map.getOrPut(allocator, uuidKey);
                        if (gop.found_existing) {
                            switch (options.duplicate_field_behavior) {
                                .use_first => {
                                    // Parse and ignore the redundant value.
                                    // We don't want to skip the value, because we want type checking.
                                    _ = try innerParse(V, allocator, source, options);
                                    continue;
                                },
                                .@"error" => return error.DuplicateField,
                                .use_last => {},
                            }
                        }
                        gop.value_ptr.* = try innerParse(V, allocator, source, options);
                    },
                    .object_end => break,
                    else => unreachable,
                }
            }
            return .{ .map = map };
        }

        pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
            if (source != .object) return error.UnexpectedToken;

            var map: std.AutoArrayHashMapUnmanaged(K, V) = .empty;
            errdefer map.deinit(allocator);

            var it = source.object.iterator();
            while (it.next()) |kv| {
                try map.put(allocator, try deserializeKey(kv.key_ptr.*), try innerParseFromValue(V, allocator, kv.value_ptr.*, options));
            }
            return .{ .map = map };
        }

        pub fn jsonStringify(self: @This(), jws: anytype) !void {
            try jws.beginObject();
            var it = self.map.iterator();
            while (it.next()) |kv| {
                try jws.objectField(&kv.key_ptr.*.serialize());
                try jws.write(kv.value_ptr.*);
            }
            try jws.endObject();
        }
    };
}
