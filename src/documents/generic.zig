const std = @import("std");
const Allocator = std.mem.Allocator;
const lib = @import("lib");
const json = lib.json;
const upgrade = lib.upgrade;
const Scene = lib.scene.Scene;

const DOCUMENT_MAX_BYTES = 1024 * 1024 * 1024;

pub const DocumentVersion = usize;
// Don't change this.
pub const firstDocumentVersion: DocumentVersion = 0;

pub const DocumentVersionHeader = struct {
    version: DocumentVersion,
};

pub const DocumentGenericConfig = struct {};

pub const DocumentError = error{UpgraderVersionMismatch};

pub fn DocumentGeneric(
    comptime PersistentData: type,
    comptime NonPersistentData: type,
    comptime config: DocumentGenericConfig,
) type {
    return struct {
        persistentData: *PersistentData,
        nonPersistentData: *NonPersistentData,

        const Self = @This();

        pub const _PersistentData = PersistentData;
        pub const _NonPersistentData = NonPersistentData;
        pub const _config = config;

        pub fn init(allocator: Allocator) Self {
            return Self{
                .persistentData = initPersistentData(allocator),
                .nonPersistentData = initNonPersistentData(allocator),
            };
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            self.persistentData.deinit(allocator);
            allocator.destroy(self.persistentData);
            self.nonPersistentData.deinit(allocator);
            allocator.destroy(self.nonPersistentData);
        }

        fn initPersistentData(allocator: Allocator) *PersistentData {
            const persistentData = allocator.create(PersistentData) catch unreachable;
            persistentData.* = PersistentData.init(allocator);
            return persistentData;
        }

        fn initNonPersistentData(allocator: Allocator) *NonPersistentData {
            const nonPersistentData = allocator.create(NonPersistentData) catch unreachable;
            nonPersistentData.* = NonPersistentData.init(allocator);
            return nonPersistentData;
        }

        pub fn serialize(self: *const Self, writer: *std.Io.Writer) !void {
            try writer.print("{f}", .{std.json.fmt(self.persistentData.*, .{})});
        }

        pub fn deserialize(allocator: Allocator, dir: std.fs.Dir, path: [:0]const u8) !Self {
            var document = Self{
                .persistentData = try parseFileAndHandleUpgrades(allocator, dir, path),
                .nonPersistentData = initNonPersistentData(allocator),
            };
            document.load(path);

            return document;
        }

        fn parseFileAndHandleUpgrades(
            allocator: Allocator,
            dir: std.fs.Dir,
            path: []const u8,
        ) !*PersistentData {
            const file = dir.openFile(path, .{}) catch |err| {
                std.log.err("Could not open file {s}: {}", .{ path, err });
                return err;
            };
            defer file.close();

            const fileContents = file.readToEndAlloc(allocator, DOCUMENT_MAX_BYTES) catch |err| {
                std.log.err("Could not read file {s}: {}", .{ path, err });
                return err;
            };
            defer allocator.free(fileContents);

            const persistentData = allocator.create(PersistentData) catch unreachable;
            errdefer allocator.destroy(persistentData);

            const upgradeDocumentResult = handleUpgradeDocument(allocator, fileContents) catch |err| {
                std.log.err("Could not upgrade document {s}: {}", .{ path, err });
                return err;
            };

            if (upgradeDocumentResult) |persistentDataValue| {
                persistentData.* = persistentDataValue;
            } else {
                const final = try readAsVersion(
                    allocator,
                    upgrade.finalUpgraderVersion(PersistentData),
                    fileContents,
                );
                if (PersistentData == Scene) {
                    std.log.debug("FINALSCENE: {any}", .{final});
                }
                persistentData.* = upgradeFinal(allocator, final);
            }

            return persistentData;
        }

        pub fn load(self: Self, path: [:0]const u8) void {
            self.nonPersistentData.load(path, self.persistentData);
        }

        fn handleUpgradeDocument(allocator: Allocator, fileContents: []u8) !?PersistentData {
            var fileReader = std.Io.Reader.fixed(fileContents);
            var jsonReader = std.json.Reader.init(allocator, &fileReader);
            defer jsonReader.deinit();

            const headerParsed = std.json.parseFromTokenSource(DocumentVersionHeader, allocator, &jsonReader, .{ .ignore_unknown_fields = true }) catch |err| {
                switch (err) {
                    std.json.ParseError(@TypeOf(jsonReader)).MissingField => {
                        return try upgradeDocument(allocator, firstDocumentVersion, fileContents);
                    },
                    else => {
                        json.reportJsonError(jsonReader, err);
                        return err;
                    },
                }
            };
            defer headerParsed.deinit();

            if (headerParsed.value.version < PersistentData.currentVersion) {
                return try upgradeDocument(allocator, headerParsed.value.version, fileContents);
            }

            return null;
        }

        fn upgradeDocument(
            allocator: Allocator,
            fromVersion: DocumentVersion,
            fileContents: []u8,
        ) !PersistentData {
            std.log.info("Upgrading document from version {} to {}", .{ fromVersion, PersistentData.currentVersion });

            validateCurrentVersionEqualsFinalUpgrader();
            std.debug.assert(fromVersion < PersistentData.currentVersion);
            std.debug.assert(fromVersion >= firstDocumentVersion);

            var current = readAsVersion(allocator, fromVersion, fileContents) catch |err| {
                std.log.err("Could not read old document version: {}", .{err});
                return err;
            };
            upgradeIntermediates(allocator, &current, fromVersion) catch |err| {
                std.log.err("Could not upgrade intermediates: {}", .{err});
                return err;
            };
            return upgradeFinal(allocator, current);
        }

        fn validateCurrentVersionEqualsFinalUpgrader() void {
            comptime {
                const finalUpgraderVersion = upgrade.finalUpgraderVersion(PersistentData);
                if (finalUpgraderVersion != PersistentData.currentVersion) {
                    @compileError("Current version of " ++ @typeName(PersistentData) ++ " does not match final upgrader version.");
                }
            }
        }

        const endVersion = @max(PersistentData.currentVersion, firstDocumentVersion + 1) - 1;

        fn readAsVersion(
            allocator: Allocator,
            version: DocumentVersion,
            fileContents: []const u8,
        ) !*anyopaque {
            std.log.info("Reading document as version {}", .{version});

            switch (version) {
                inline firstDocumentVersion...PersistentData.currentVersion => |v| {
                    const documentVersions = upgrade.documentVersions(PersistentData);
                    const DocumentT = documentVersions[v];
                    const prev = try allocator.create(DocumentT);
                    errdefer allocator.destroy(prev);
                    prev.* = try json.parseFromSliceWithErrorReportingLeaky(
                        DocumentT,
                        allocator,
                        fileContents,
                        .{ .ignore_unknown_fields = true },
                    );
                    return prev;
                },
                else => unreachable,
            }
        }

        fn upgradeIntermediates(
            allocator: Allocator,
            current: **anyopaque,
            fromVersion: DocumentVersion,
        ) !void {
            if (endVersion == firstDocumentVersion) {
                // try upgradeIntermediate(allocator, current, firstDocumentVersion);
                return;
            }

            _ = upgrade: switch (fromVersion) {
                inline firstDocumentVersion...endVersion => |v| {
                    try upgradeIntermediate(allocator, current, v);
                    break :upgrade v + 1;
                },
                PersistentData.currentVersion => return,
                else => unreachable,
            };
        }

        fn upgradeIntermediate(
            allocator: Allocator,
            current: **anyopaque,
            comptime version: DocumentVersion,
        ) !void {
            const upgrader = PersistentData.upgraders[version];
            const prev: *upgrader.DocumentPrev = @ptrCast(@alignCast(current.*));
            const next = try allocator.create(upgrader.DocumentNext);
            next.* = upgrader.upgrader(allocator, prev.*, upgrade.Container.Intermediate);
            allocator.destroy(prev);
            if (next.version != version + 1) return DocumentError.UpgraderVersionMismatch;
            current.* = next;
        }

        fn upgradeFinal(allocator: Allocator, current: *anyopaque) PersistentData {
            const DocumentFinal = upgrade.DocumentFinal(PersistentData);
            const finalPtr: *DocumentFinal = @ptrCast(@alignCast(current));
            const final: DocumentFinal = finalPtr.*;
            allocator.destroy(finalPtr);
            return upgrade.upgradeValue(
                PersistentData,
                allocator,
                final,
                PersistentData.UpgradeContainer,
            );
        }

        // TODO: ? Automatic breaking change checker:
        // 1. Create new document of the current version
        // 2. Serialize it
        // 3. Take the latestUpgrader and take the "Next" version of that
        // 4. Now deserialize using that "Next" version
        // 5. If there are any JSON errors, that indicates a breaking change
        // 6. If not, it's probably fine
    };
}
