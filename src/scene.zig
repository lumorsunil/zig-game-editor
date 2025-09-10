const persistentData = @import("documents/scene/persistent-data.zig");
const nonPersistentData = @import("documents/scene/non-persistent-data.zig");

pub const Scene = persistentData.Scene;
pub const SceneEntity = persistentData.SceneEntity;
pub const SceneEntityType = persistentData.SceneEntityType;
pub const SceneEntityTilemap = persistentData.SceneEntityTilemap;
pub const SceneEntityCustom = persistentData.SceneEntityCustom;
pub const SceneEntityEntrance = persistentData.SceneEntityEntrance;
pub const SceneEntityExit = persistentData.SceneEntityExit;
pub const SceneEntityPoint = persistentData.SceneEntityPoint;
pub const DragState = nonPersistentData.DragState;
pub const DragEntityState = nonPersistentData.DragEntityState;
pub const DragAction = nonPersistentData.DragAction;
pub const ResizeAction = nonPersistentData.ResizeAction;
