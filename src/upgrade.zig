const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const StringZ = lib.StringZ;
const StringZArrayHashMap = lib.StringZArrayHashMap;
const PropertyObject = lib.properties.PropertyObject;
const Property = lib.properties.Property;
const DocumentVersion = lib.documents.DocumentVersion;

fn UpgraderFn(comptime From: type, comptime To: type) type {
    return fn (Allocator, From, Container) To;
}

pub fn finalUpgrader(comptime PersistentData: type) type {
    return PersistentData.upgraders[finalUpgraderVersion(PersistentData) - 1];
}

pub fn finalUpgraderVersion(comptime PersistentData: type) DocumentVersion {
    return PersistentData.upgraders.len;
}

pub fn DocumentFinal(comptime PersistentData: type) type {
    const versions = documentVersions(PersistentData);
    return versions[versions.len - 1];
}

pub fn documentVersions(comptime PersistentData: type) []const type {
    comptime {
        var versions: []const type = &.{};

        if (PersistentData.upgraders.len == 0) {
            if (@hasDecl(PersistentData, "NoUpgradersDocument")) {
                return &.{PersistentData.NoUpgradersDocument};
            } else {
                @compileError("No document versions found for \"" ++ @typeName(PersistentData) ++ "\". Either add upgraders or NoUpgradersDocument declaration if it's the first version.");
            }
        }

        for (PersistentData.upgraders) |upgrade| {
            versions = versions ++ &[_]type{upgrade.DocumentPrev};
        }

        versions = versions ++ &[_]type{finalUpgrader(PersistentData).DocumentNext};

        return versions;
    }
}

fn defaultMatch(comptime From: type, comptime To: type, comptime UpgradeContainer: type) ?UpgraderFn(From, To) {
    inline for (@typeInfo(UpgradeContainer).@"struct".decls) |decl| {
        if (std.mem.eql(u8, decl.name, "match")) continue;
        const fun = @field(UpgradeContainer, decl.name);
        const FunFrom = @typeInfo(@TypeOf(fun)).@"fn".params[1].type.?;
        const FunTo = @typeInfo(@TypeOf(fun)).@"fn".return_type orelse {
            @compileLog("Function return type is null: " ++ decl.name);
        };

        if (FunFrom == From and FunTo == To) {
            return fun;
        }
    }

    return null;
}

const IntermediateUpgradeContainer = struct {
    fn makeUpgradeSliceFn(
        comptime FromElem: type,
        comptime ToElem: type,
    ) fn (Allocator, []const FromElem, Container) []const ToElem {
        return struct {
            pub fn upgradeSlice(
                allocator: Allocator,
                from: []const FromElem,
                container: Container,
            ) []ToElem {
                const toElems = allocator.alloc(ToElem, from.len) catch unreachable;
                defer allocator.free(from);
                for (0..from.len) |i| {
                    toElems[i] = upgradeValue(ToElem, allocator, from[i], container);
                }
                return toElems;
            }
        }.upgradeSlice;
    }

    fn makeUpgradeArrayHashMapFn(
        comptime FromElem: type,
        comptime ToElem: type,
    ) fn (Allocator, std.json.ArrayHashMap(FromElem), Container) std.json.ArrayHashMap(ToElem) {
        return struct {
            pub fn upgradeArrayHashMap(
                allocator: Allocator,
                from: std.json.ArrayHashMap(FromElem),
                container: Container,
            ) std.json.ArrayHashMap(ToElem) {
                var fromMut = from;
                defer fromMut.deinit(allocator);
                var toElems: std.json.ArrayHashMap(ToElem) = .{ .map = .empty };
                toElems.map.ensureTotalCapacity(allocator, from.map.count()) catch unreachable;
                for (from.map.values(), 0..) |fromElem, i| {
                    const k = from.map.keys()[i];
                    toElems.map.putAssumeCapacity(
                        k,
                        upgradeValue(ToElem, allocator, fromElem, container),
                    );
                }
                return toElems;
            }
        }.upgradeArrayHashMap;
    }

    pub fn match(
        comptime From: type,
        comptime To: type,
    ) ?fn (Allocator, From, Container) To {
        brk: switch (@typeInfo(From)) {
            .pointer => |p| return makeUpgradeSliceFn(p.child, std.meta.Elem(To)),
            .@"struct" => {
                const FromElem = getArrayHashMapElem(From) orelse break :brk;
                const ToElem = getArrayHashMapElem(To) orelse break :brk;

                return makeUpgradeArrayHashMapFn(FromElem, ToElem);
            },
            else => {},
        }

        return defaultMatch(From, To, @This());
    }
};

fn getArrayHashMapElem(comptime T: type) ?type {
    if (@hasField(T, "map")) {
        const Map = @FieldType(T, "map");

        if (@hasField(Map, "entries")) {
            return @FieldType(Map.KV, "value");
        }
    }

    return null;
}

pub const StandardContainer = struct {
    pub fn upgradeStringZ(allocator: Allocator, from: []const u8, _: Container) StringZ {
        const to = StringZ.initFmt(allocator, "{s}", .{from});
        allocator.free(from);
        return to;
    }

    fn makeUpgradeArrayHashMapFn(
        comptime FromElem: type,
    ) fn (Allocator, std.json.ArrayHashMap(FromElem), Container) PropertyObject {
        return struct {
            pub fn upgradeArrayHashMap(
                allocator: Allocator,
                from: std.json.ArrayHashMap(FromElem),
                container: Container,
            ) PropertyObject {
                var fromMut = from;
                defer fromMut.deinit(allocator);
                var toElems: PropertyObject = .empty;
                toElems.fields.map.ensureTotalCapacity(allocator, from.map.count()) catch unreachable;
                for (from.map.values(), 0..) |fromElem, i| {
                    const k = allocator.dupeZ(u8, from.map.keys()[i]) catch unreachable;
                    defer allocator.free(from.map.keys()[i]);
                    defer allocator.free(k);
                    toElems.fields.putAssumeCapacity(
                        allocator,
                        k,
                        upgradeValue(Property, allocator, fromElem, container),
                    );
                }
                return toElems;
            }
        }.upgradeArrayHashMap;
    }

    pub fn match(
        comptime From: type,
        comptime To: type,
    ) ?fn (Allocator, From, Container) To {
        brk: switch (@typeInfo(From)) {
            .@"struct" => {
                const FromElem = getArrayHashMapElem(From) orelse break :brk;

                return makeUpgradeArrayHashMapFn(FromElem);
            },
            else => {},
        }

        return defaultMatch(From, To, @This());
    }
};

pub const Container = struct {
    upgraders: []const type,

    pub const Intermediate = Container.initWithoutStandard(&.{IntermediateUpgradeContainer});

    pub fn init(comptime upgraders: []const type) Container {
        const standardUpgraders: []const type = &[_]type{StandardContainer};

        return Container{
            .upgraders = upgraders ++ standardUpgraders,
        };
    }

    pub fn initWithoutStandard(comptime upgraders: []const type) Container {
        return Container{
            .upgraders = upgraders,
        };
    }

    pub fn add(self: Container, comptime upgrader: type) Container {
        return Container.initWithoutStandard(self.upgraders ++ &[_]type{upgrader});
    }

    pub fn getUpgrader(
        self: Container,
        comptime To: type,
        comptime From: type,
    ) ?fn (Allocator, From, Container) To {
        comptime {
            for (self.upgraders) |Upgrader| {
                if (@hasDecl(Upgrader, "match")) {
                    if (Upgrader.match(From, To)) |upgrader| return upgrader;
                } else {
                    if (defaultMatch(From, To, Upgrader)) |upgrader| return upgrader;
                }
            }

            return null;
        }
    }
};

pub fn upgradeValue(
    comptime T: type,
    allocator: Allocator,
    source: anytype,
    comptime container: Container,
) T {
    if (container.getUpgrader(T, @TypeOf(source))) |upgrader| {
        return upgrader(allocator, source, container);
    }

    validateIntermediateType(@TypeOf(source));

    return switch (@typeInfo(@TypeOf(source))) {
        .pointer => upgradeList(
            std.meta.Elem(@FieldType(T, "items")),
            allocator,
            source,
            container,
        ),
        .@"struct" => upgradeObject(T, allocator, source, container),
        .@"enum" => upgradeEnum(T, allocator, source, container),
        .@"union" => upgradeUnion(T, allocator, source, container),
        .optional => upgradeOptional(T, allocator, source, container),
        else => source,
    };
}

fn validateIntermediateType(comptime T: type) void {
    if (T == StringZ or T == [:0]const u8 or T == [:0]u8 or T == []u8) {
        @compileError("Invalid intermediate document type: " ++ @typeName(T));
    }
}

fn upgradeObject(
    comptime T: type,
    allocator: Allocator,
    object: anytype,
    container: Container,
) T {
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            var result: T = undefined;

            inline for (s.fields) |field| {
                @field(result, field.name) = upgradeValue(
                    field.type,
                    allocator,
                    @field(object, field.name),
                    container,
                );
            }

            return result;
        },
        .pointer => |p| {
            const resultPtr = allocator.create(p.child) catch unreachable;
            resultPtr.* = upgradeObject(p.child, allocator, object, container);
            return resultPtr;
        },
        else => unreachable,
    }
}

fn upgradeList(
    comptime T: type,
    allocator: Allocator,
    slice: anytype,
    container: Container,
) std.ArrayListUnmanaged(T) {
    var list = std.ArrayListUnmanaged(T).initCapacity(allocator, slice.len) catch unreachable;

    for (slice) |elem| {
        list.appendAssumeCapacity(upgradeValue(T, allocator, elem, container));
    }

    allocator.free(slice);

    return list;
}

fn upgradeEnum(comptime T: type, _: Allocator, source: anytype, _: Container) T {
    return std.meta.stringToEnum(T, @tagName(source)).?;
}

fn upgradeUnion(comptime T: type, allocator: Allocator, source: anytype, container: Container) T {
    switch (source) {
        inline else => |v, t| {
            const resultTag = comptime std.meta.stringToEnum(std.meta.Tag(T), @tagName(t)).?;
            @setEvalBranchQuota(2000);
            const Payload = std.meta.TagPayload(T, resultTag);
            return @unionInit(T, @tagName(t), upgradeValue(Payload, allocator, v, container));
        },
    }
}

fn upgradeOptional(
    comptime T: type,
    allocator: Allocator,
    source: anytype,
    container: Container,
) T {
    if (source) |s| return upgradeValue(@typeInfo(T).optional.child, allocator, s, container);
    return null;
}
