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
  - [ ] Animations
  - [x] Scenes
- [x] Ability to switch between editors

## Assets manager

- [ ] Able to "import" assets (basically create a link to a file that can be accessed)
- [ ] Assets can be anything like tilesets, tilemaps, animations, spritesheets, images, sounds etc

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

- [ ] Redo functionality of animation studio in new environment
- [ ] Incorporate spritesheets as a source of sprites

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
