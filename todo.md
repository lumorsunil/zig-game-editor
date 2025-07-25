# Game Editor Todo

## General

- [x] Add ctrl+s to save
- [x] Add ctrl+o to open
- [x] Add ctrl+n to make a new tilemap
- [x] Add label to show currently opened file
- [x] Store editor state on quit
- [x] Load editor state on startup
- [ ] Quitting with changes dialog
- [x] Update to 0.14.1
- [ ] Checkerboard background
- [x] Asset inputs
  - [ ] Add help (?) tooltip that explains how to use the input
  - [x] If value is "None", have option to create a new asset directly
  - [x] Context menu
    - [ ] Unset (clear input)
    - [ ] Open asset directory in asset manager
    - [x] Open asset editor
- [ ] Camera for background should be per editor instead of only one in the context

### References

- [x] Each asset should have an ID
- [x] Assets should be indexed to an index file
  - [x] Load index on startup
  - [x] Save index on update
- [x] Each asset referencing other assets should use the asset ID instead
  - [x] Animations (texture)
  - [x] Tilemap (texture)
  - [x] Entity Type (texture)
  - [x] Scenes (tilemap)
- [x] Document container should use asset ID as keys
- [x] Whenever an action is made that should update index, we update the index
  - [x] Moving an asset
  - [x] Creating an asset
  - [x] Deleting an asset
- [x] All assets require a json file that includes the ID (i.e. textures)
- [ ] Reference index
  - [ ] Interface function for documents to produce a list of references to other documents
  - [ ] Store reference index on file system
  - [ ] References lookup function
- [ ] Sanity checks
  - [ ] Rebuild index if duplicates found
  - [ ] Prune non-existing files

### Undo/redo

- [x] General structure
- [x] Tilemap Editor
  - [x] Adjust tools to support undo/redo
    - [x] Generic tool
    - [x] Brush tool
      - [ ] Optimize action
    - [x] Add layer
      - [ ] Optimize action
    - [x] Remove layer
      - [ ] Optimize action
    - [x] Rename layer
      - [ ] Optimize action
    - [ ] Select
    - [ ] Select add
    - [ ] Select subtract
    - [ ] Create floating selection
    - [ ] Move floating selection
    - [ ] Merge floating selection
    - [ ] Copy selection
    - [ ] Paste
- [x] History per document
- [x] Save history in document?
  - [ ] Binary format? Gzip? (jq can be used to query a document in a streaming manner [https://stackoverflow.com/questions/67414225/is-it-possible-to-read-gzip-file-directly-with-jq])

### Multiple editors

- [x] Different documents activates corresponding editor
- [x] Document types
  - [x] Tilemaps
  - [ ] Tilesheets
  - [ ] Spritesheets
  - [x] Animations
  - [x] Scenes
- [x] Ability to switch between editors
- [x] Tabs for each document
  - [x] Click on a tab to go to that editor
  - [x] X button to unload the document and close the editor for that document
  - [ ] Context menu
    - [ ] Go to document in assets library
    - [ ] Close to the left
    - [ ] Close to the right
    - [ ] Close everything but this

## Assets manager

- [x] Assets manager menu
  - [ ] File tree view (list instead of "cards")
  - [x] Create directory
  - [x] Create new asset
    - [x] Tilemap
    - [x] Scene
    - [x] Animation
    - [x] Texture
    - [x] When creating a new asset that can be opened, open it
    - [x] New asset dialog
      - [ ] Input to choose which directory the asset will be created in (file-tree view?)
      - [x] Pressing enter will submit the form
      - [x] Auto-focus on name input
      - [x] Cancel button
  - [x] List assets as icons
    - [x] Double-click to open editor for asset
  - [x] Go up a directory
  - [x] Move files
    - [x] Asset library needs to be updated
    - [x] Asset index needs to be updated after move
    - [x] Allow moving file to parent directory
    - [x] BUG: When having an asset filter on, moving a file crashes the program
  - [ ] Rename file
  - [x] Delete files
    - [x] Asset library needs to be updated
    - [x] Asset index needs to be updated after deletion
    - [x] Confirmation dialog
    - [ ] Show error label on reference inputs with missing documents
  - [ ] Selecting multiple files
    - [ ] Move multiple files
    - [ ] Delete multiple files
  - [x] Drag and drop asset basic functionality
  - [x] Filter
  - [ ] Search bar
  - [x] Asset Type Icons
    - [x] Add icon types for all document types
  - [x] Thumbnails
    - [x] Store persistent thumbnails (file system)
    - [x] Request thumbnail for document
    - [x] Update thumbnail
      - [x] Texture
      - [x] Entity Type
      - [x] Animation
      - [x] Tilemap
      - [x] Scene (only tilemap)
    - [ ] Delete thumbnails that are no longer used

## Resource manager

- [x] Container for documents
- [ ] Way to define dependencies on other documents
- [ ] Way to load dependencies
  - [x] Way to load documents
  - [ ] Way to lazy-load documents

## Tilemap editor

- [ ] Show/hide grid
- [x] Highlight hovered cell
- [ ] Tile flip/rotate
- [ ] Tile tint color
- [x] Resize tilemap
- [x] Layers
- [x] Brush tool
  - [x] Set tileset
  - [x] Randomize tile
    - [x] (Bug) Randomize only when painting on next cell
  - [x] Line drawing with shift-click
  - [x] When setting tile with ctrl-click on tilemap, clear random selection
- [ ] Bucket tool
- [x] Select tool
  - [x] Copy/paste tiles
  - [x] Move tiles
  - [x] Delete tiles
  - [ ] Move selected tiles to another layer
- [x] Setting to disable/enable auto-expand when drawing outside of boundary
- [ ] Show mouse grid coordinates

## Tilesheet editor

- [ ] Tilesheet source image
- [ ] Spacing, offset, tile size options
- [ ] Metadata for specific tiles
  - [ ] isSolid
  - [ ] use json schema for possible values? (also can use json schema for generating a ui for different options)

## Spritesheet editor

- [ ] Spritesheet source image
- [ ] Generating sprites
  - [ ] Spacing, offset, sprite size options
  - [ ] Able to select a portion of the sheet and generate with specific options
    - [ ] This could even be saved in the spritesheet so that edits to the original image will be easily imported and re-generated into the spritesheet
- [ ] Per-sprite options
  - [ ] Origin

## Animation editor

- [x] Redo functionality of animation studio in new environment
  - [x] Set texture
  - [x] Add new animation button
  - [x] List of selectable animations
  - [x] Animation details
    - [x] Animation name input
    - [x] Grid size
    - [x] Frame duration
    - [x] Total animation duration
    - [x] Delete animation button
  - [x] Frames window
    - [x] List of selectable frames
    - [ ] Account for origin (postpone until we need it)
    - [ ] Duration scale modifier label
  - [x] Click on spritesheet to add/replace frame
    - [x] Highlight hovered grid cell
    - [ ] Highlight currently selected frame's source cell
  - [x] Frame details
    - [x] Origin input
    - [x] Duration scale input
    - [x] Starting time of frame
    - [x] Delete frame button
  - [x] Preview window
  - [x] Reload texture button
  - [x] Match serialized json data with old format

## Entity type editor

- [x] Custom entities
  - [x] Custom entity editor
    - [x] Add new custom entity
      - [ ] Set name of new entity to same name as filename
    - [x] Custom entity details
      - [x] Set name
      - [x] Set icon
      - [x] Set size
  - [x] Data structure
    - [x] Type ID
    - [x] Name
    - [x] Icon
    - [x] Size
    - [x] Properties
      - [x] Add property
      - [x] Delete property
      - [x] Label
      - [x] Data type
        - [x] String
          - [ ] Max length
        - [x] Number
        - [x] Object
        - [x] Asset Reference
        - [x] Entity Reference
      - [x] Default property values

## Scene editor

- [x] Entities
  - [x] Add metadata
  - [ ] Scale vector for all entities
  - [x] Entity instance details
    - [x] Properties
      - [x] Label
      - [x] Data type
        - [x] String
          - [ ] Max length
        - [x] Integer
        - [x] Float
        - [x] Object
        - [x] Asset Reference
        - [x] Entity Reference
          - [x] Set entity
          - [ ] Entity reference preview
          - [ ] Button to go to entity reference
  - [x] (Remove metadata feature once properties are implemented)
  - [x] Exit entities
    - [x] Set target scene
    - [x] Open target scene
  - [x] Entrance entities
    - [x] Set key
  - [x] Add entity from assets library
- [x] Add Play button
  - [x] Preview scene in game (run command with arguments --scene etc)
  - [x] F5 shortcut
- [x] Scene document
- [x] Create entities
  - [x] Drag and drop entites to create them
  - [x] Position
  - [x] Type
    - [x] String ("klet", "player", "npc", "tilemap")
  - [x] Graphic
    - [x] "klet" => "klet sprite"
    - [x] "player" => "player sprite"
    - [x] "npc" => "npc sprite"
    - [x] "tilemap" => "draw tilemap"
- [x] Select entity
  - [ ] Select multiple entities
  - [ ] Deselect entity
- [x] Move entity
  - [ ] Move multiple entities
- [x] Delete entity
  - [ ] Delete multiple entities
- [x] Save to file
- [x] Load from file
- [ ] Show boundary from tilemap

## Project

- [x] Project structure (project root directory, relative paths inside project)
- [x] Create new project
- [x] Open project
- [x] Close project
- [x] Project options
  - [x] Default tileset
  - [ ] Tile size
  - [ ] Fill this out
- [x] Scene map (shows all scenes and how they are connected, able to jump to scenes through the map)

## Document Versions

- [x] Version upgrade system
  - [x] Each document should have a version stored in the persistent data
  - [x] Each document type should have a "current version"
  - [x] Each document type should have an upgrade implementation for each adjacent version transition (1 -> 2, 2 -> 3, NOT 1 -> 3 directly; in that case it would be first 1 -> 2 and then 2 -> 3)
  - [x] When a document is loaded, it is also upgraded in memory if it is an old version

## Editor Session

- [x] Store editor session when quitting program
- [x] Restore editor session on program startup
  - [x] Current project and opened editors
  - [ ] Current opened directory in assets manager

## Bugs

- [x] BUG: Thumbnails not showing after closing and opening a project
- [x] Add no_bring_to_front_on_focus flag to all side menues
- [x] When closing the current editor, open the next available tab
- [x] Store multiple opened documents in the editor session
- [ ] Crash when deleting an animation (created a new one without saving, added frames)
- [x] Update scene map when tilemap is saved
- [x] When scene map is updated, the cell size and position didn't change
- [ ] Highlighting cell is offset wrongly when in negative coordinates
- [ ] When auto expanding a tilemap, then undoing, the scene entities positions are not undoed
- [ ] Painting a line sometimes the line will keep going to the edge of the tilemap
- [ ] Asset input for textures: The + button should open the normal add texture dialog (also in the future we probably want to have a better new asset dialog for textures, where you can choose destination folder and source file. Possibly also the + button you should be able to choose between creating a new asset or selecting an already existing one.)
- [ ] Animations play fast after window has been unfocused for a while (happens probably because t increases a lot while the animation nextFrameAt is only increasing by the duration of the animation so it basically tries to play the animation as fast as it can back to t again)
