const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const UUID = lib.UUIDSerializable;
const DocumentTag = lib.DocumentTag;
const StringZArrayHashMap = lib.StringZArrayHashMap;
const StringZ = lib.StringZ;
const json = lib.json;

pub const PropertyTypeTag = enum {
    object,
    array,
    string,
    integer,
    float,
    boolean,
    entityReference,
    assetReference,
};

pub const PropertyType = union(PropertyTypeTag) {
    object: PropertyObject,
    array: PropertyArray,
    string: PropertyString,
    integer: PropertyInteger,
    float: PropertyFloat,
    boolean: PropertyBoolean,
    entityReference: PropertyEntityReference,
    assetReference: PropertyAssetReference,
};

pub const Property = struct {
    id: UUID,
    property: PropertyType,

    pub fn init() Property {
        return .{ .id = UUID.init(), .property = .{ .float = .empty } };
    }

    pub fn initWithType(allocator: Allocator, propertyType: PropertyTypeTag) Property {
        const property: PropertyType = switch (propertyType) {
            .string => .{ .string = .init(allocator) },
            inline else => |t| @unionInit(PropertyType, @tagName(t), .empty),
        };
        return .{ .id = UUID.init(), .property = property };
    }

    pub fn deinit(self: *Property, allocator: Allocator) void {
        return switch (self.property) {
            inline else => |*p| p.deinit(allocator),
        };
    }

    pub fn clone(self: Property, allocator: Allocator) Property {
        return switch (self.property) {
            inline else => |p, tag| .{
                .id = self.id,
                .property = @unionInit(PropertyType, @tagName(tag), p.clone(allocator)),
            },
        };
    }

    pub fn setType(self: *Property, allocator: Allocator, newType: PropertyTypeTag) void {
        self.deinit(allocator);
        self.property = switch (newType) {
            inline else => |t| @unionInit(PropertyType, @tagName(t), .init(allocator)),
        };
    }
};

pub const PropertyString = struct {
    value: StringZ,

    pub fn init(allocator: Allocator) PropertyString {
        return PropertyString{
            .value = .init(allocator, ""),
        };
    }

    pub fn deinit(self: *PropertyString, allocator: Allocator) void {
        self.value.deinit(allocator);
    }

    pub fn clone(self: PropertyString, allocator: Allocator) PropertyString {
        return .{ .value = self.value.clone(allocator) };
    }
};

pub const PropertyInteger = struct {
    value: i32,

    pub const empty: PropertyInteger = .{ .value = 0 };

    pub fn init(_: Allocator) PropertyInteger {
        return .empty;
    }

    pub fn deinit(_: *PropertyInteger, _: Allocator) void {}

    pub fn clone(self: PropertyInteger, _: Allocator) PropertyInteger {
        return self;
    }
};

pub const PropertyFloat = struct {
    value: f32,

    pub const empty: PropertyFloat = .{ .value = 0 };

    pub fn init(_: Allocator) PropertyFloat {
        return .empty;
    }

    pub fn deinit(_: *PropertyFloat, _: Allocator) void {}

    pub fn clone(self: PropertyFloat, _: Allocator) PropertyFloat {
        return self;
    }
};

pub const PropertyBoolean = struct {
    value: bool,

    pub const empty: PropertyBoolean = .{ .value = false };

    pub fn init(_: Allocator) PropertyBoolean {
        return .empty;
    }

    pub fn deinit(_: *PropertyBoolean, _: Allocator) void {}

    pub fn clone(self: PropertyBoolean, _: Allocator) PropertyBoolean {
        return self;
    }
};

pub const PropertyEntityReference = struct {
    sceneId: ?UUID = null,
    entityId: ?UUID = null,

    pub const empty: PropertyEntityReference = .{};

    pub fn init(_: Allocator) PropertyEntityReference {
        return .empty;
    }

    pub fn deinit(_: *PropertyEntityReference, _: Allocator) void {}

    pub fn clone(self: PropertyEntityReference, _: Allocator) PropertyEntityReference {
        return self;
    }
};

pub const PropertyAssetReference = struct {
    assetId: ?UUID = null,
    assetType: DocumentTag = .entityType,

    pub const empty: PropertyAssetReference = .{};

    pub fn init(_: Allocator) PropertyAssetReference {
        return .empty;
    }

    pub fn deinit(_: *PropertyAssetReference, _: Allocator) void {}

    pub fn clone(self: PropertyAssetReference, _: Allocator) PropertyAssetReference {
        return self;
    }
};

pub const PropertyObject = struct {
    fields: StringZArrayHashMap(Property),

    pub const K = StringZ;

    pub const empty: PropertyObject = .{ .fields = .empty };

    pub fn init(_: Allocator) PropertyObject {
        return .empty;
    }

    pub fn deinit(self: *PropertyObject, allocator: Allocator) void {
        for (self.fields.map.values()) |*v| {
            v.deinit(allocator);
        }
        self.fields.deinit(allocator);
    }

    pub fn clone(self: PropertyObject, allocator: Allocator) PropertyObject {
        var cloned: PropertyObject = .empty;

        cloned.fields = self.fields.clone(allocator);

        return cloned;
    }

    pub fn jsonParse(
        allocator: Allocator,
        source: anytype,
        options: std.json.ParseOptions,
    ) !PropertyObject {
        const hashMap = try std.json.innerParse(StringZArrayHashMap(Property), allocator, source, options);

        return .{
            .fields = hashMap,
        };
    }

    pub fn jsonStringify(self: @This(), jw: anytype) !void {
        try jw.write(self.fields);
    }

    fn generateNewPropertyName(self: PropertyObject, allocator: Allocator) [:0]const u8 {
        const baseName = "New Property";
        if (!self.fields.contains(allocator, baseName)) return allocator.dupeZ(u8, baseName) catch unreachable;
        var i: usize = 2;
        const MAX_I = 100;
        while (true) {
            const candidateName = std.fmt.allocPrintZ(allocator, baseName ++ " {d}", .{i}) catch unreachable;
            if (!self.fields.contains(allocator, candidateName)) return candidateName;
            allocator.free(candidateName);
            i += 1;
            if (i > MAX_I) {
                std.debug.panic("Could not generate a new property name: Too many iterations ({d})", .{i});
            }
        }
    }

    pub fn addNewProperty(self: *PropertyObject, allocator: Allocator) void {
        const newPropertyName = self.generateNewPropertyName(allocator);
        defer allocator.free(newPropertyName);
        self.fields.put(allocator, newPropertyName, .init());
    }

    pub fn deleteProperty(self: *PropertyObject, allocator: Allocator, key: K) void {
        var entry = self.fields.map.fetchOrderedRemove(key) orelse return;

        entry.key.deinit(allocator);
        entry.value.deinit(allocator);
    }

    pub fn iterator(self: *PropertyObject) @TypeOf(self.fields.map).Iterator {
        return self.fields.map.iterator();
    }

    pub fn getByKey(self: *PropertyObject, allocator: Allocator, key: [:0]const u8) ?*Property {
        return self.fields.getPtr(allocator, key);
    }
};

pub const PropertyArray = struct {
    subType: PropertyTypeTag = .float,
    items: std.ArrayListUnmanaged(Property) = .empty,

    pub const empty: PropertyArray = .{};

    pub fn init(_: Allocator) PropertyArray {
        return .empty;
    }

    pub fn deinit(self: *PropertyArray, allocator: Allocator) void {
        for (self.items.items) |*item| item.deinit(allocator);
        self.items.clearAndFree(allocator);
    }

    pub fn clone(self: PropertyArray, allocator: Allocator) PropertyArray {
        var cloned: PropertyArray = .empty;

        cloned.subType = self.subType;
        cloned.items = self.items.clone(allocator) catch unreachable;
        for (cloned.items.items, 0..) |*item, i| {
            item.* = self.items.items[i].clone(allocator);
        }

        return cloned;
    }

    pub fn addNewItem(self: *PropertyArray, allocator: Allocator) void {
        self.items.append(allocator, .initWithType(allocator, self.subType)) catch unreachable;
    }

    pub fn deleteItem(self: *PropertyArray, allocator: Allocator, index: usize) void {
        if (index >= self.items.items.len) return;
        var item = self.items.orderedRemove(index);
        item.deinit(allocator);
    }

    pub fn setSubType(
        self: *PropertyArray,
        allocator: Allocator,
        newSubType: PropertyTypeTag,
    ) void {
        self.subType = newSubType;
        self.deinit(allocator);
    }

    pub fn jsonStringify(self: *const @This(), jw: anytype) !void {
        try json.writeObject(self.*, jw);
    }
};
