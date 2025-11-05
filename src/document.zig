const document = @import("documents/document.zig");
const generic = @import("documents/generic.zig");

pub const Document = document.Document;
pub const DocumentTag = document.DocumentTag;
pub const DocumentContent = document.DocumentContent;
pub const DocumentError = document.DocumentError;

pub const DocumentGeneric = generic.DocumentGeneric;
pub const DocumentGenericConfig = generic.DocumentGenericConfig;
pub const DocumentVersion = generic.DocumentVersion;
pub const DocumentVersionHeader = generic.DocumentVersionHeader;
pub const firstDocumentVersion = generic.firstDocumentVersion;

pub const SceneDocument = @import("documents/scene/document.zig").SceneDocument;
pub const ScenePersistentData = SceneDocument.DocumentType._PersistentData;
pub const SceneNonPersistentData = SceneDocument.DocumentType._NonPersistentData;

pub const TilemapDocument = @import("documents/tilemap/document.zig").TilemapDocument;
pub const TilemapPersistentData = TilemapDocument.DocumentType._PersistentData;
pub const TilemapNonPersistentData = TilemapDocument.DocumentType._NonPersistentData;

pub const AnimationsDocument = @import("documents/animation/document.zig").AnimationsDocument;
pub const AnimationsPersistentData = AnimationsDocument.DocumentType._PersistentData;
pub const AnimationsNonPersistentData = AnimationsDocument.DocumentType._NonPersistentData;

pub const EntityTypeDocument = @import("documents/entity-type/document.zig").EntityTypeDocument;
pub const EntityTypePersistentData = EntityTypeDocument.DocumentType._PersistentData;
pub const EntityTypeNonPersistentData = EntityTypeDocument.DocumentType._NonPersistentData;

pub const TextureDocument = @import("documents/texture/document.zig").TextureDocument;
pub const TexturePersistentData = TextureDocument.DocumentType._PersistentData;
pub const TextureNonPersistentData = TextureDocument.DocumentType._NonPersistentData;

pub const SoundDocument = @import("documents/sound/document.zig").SoundDocument;
pub const SoundPersistentData = SoundDocument.DocumentType._PersistentData;
pub const SoundNonPersistentData = SoundDocument.DocumentType._NonPersistentData;

pub const MusicDocument = @import("documents/music/document.zig").MusicDocument;
pub const MusicPersistentData = MusicDocument.DocumentType._PersistentData;
pub const MusicNonPersistentData = MusicDocument.DocumentType._NonPersistentData;

pub const FontDocument = @import("documents/font/document.zig").FontDocument;
pub const FontPersistentData = FontDocument.DocumentType._PersistentData;
pub const FontNonPersistentData = FontDocument.DocumentType._NonPersistentData;
