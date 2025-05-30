# Game Editor Todo

## General

- [x] Add ctrl+s to save
- [x] Add ctrl+o to open
- [x] Add ctrl+n to make a new tilemap
- [x] Add label to show currently opened file
- [x] Store editor state on quit
- [x] Load editor state on startup
- [ ] Quitting with changes dialog
- [ ] Interruption handling
- [ ] Able to visually see or draw the hitbox of entities somehow
- [x] Update to 0.14.1

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

### Multiple documents opened

- [ ] Storage
- [ ] Able to switch between documents
- [ ] Tabs/thumbnails buttons for switching between documents

### Multiple editors

- [x] Different documents activates corresponding editor
- [x] Document types
  - [x] Tilemaps
  - [ ] Tilesheets
  - [ ] Spritesheets
  - [x] Animations
  - [x] Scenes
- [x] Ability to switch between editors

## Assets manager

- [x] Assets manager menu
  - [x] Create directory
  - [x] Create new asset
    - [x] Tilemap
    - [x] Scene
    - [x] Animation
  - [x] List assets as icons
    - [x] Double-click to open editor for asset
  - [x] Go up a directory
  - [ ] Move files
  - [ ] Delete files

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
  - [x] Randomize tile
    - [x] (Bug) Randomize only when painting on next cell
- [ ] Bucket tool
- [x] Select tool
  - [x] Copy/paste tiles
  - [x] Move tiles
  - [x] Delete tiles

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

## Scene editor

- [x] Entities
  - [x] Add metadata
  - [x] Exit entities
    - [x] Set target scene
    - [x] Open target scene
  - [x] Entrance entities
    - [x] Set key
- [x] Add Play button
  - [x] Preview scene in game (run command with arguments --scene etc)
  - [x] F5 shortcut
- [ ] Fill this space out

### Scene editor initial version 0.0.1

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

### Scene editor version 0.0.2

- [x] Select entity
- [x] Move entity
- [x] Delete entity
- [x] Save to file
- [x] Load from file
