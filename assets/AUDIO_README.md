# Music & SFX - Copyright-Free Sources

## Required files to add:

### /assets/music/ (looping)
- `menu_theme.ogg` - Calm menu background (loop enabled in import)
- `game_theme.ogg` - Upbeat gameplay music (loop enabled)

### /assets/sfx/
- `block_place.wav` - Block landing sound
- `game_over.ogg` - Game over jingle

## Copyright-Free Downloads (CC0/Public Domain):

### FreePD.com
```
Menu Theme: https://freepd.com/?page_id=47  (Cafe_Bar or Chill_Out)
Game Theme: https://freepd.com/?page_id=105 (Arcade or Action music)
```

### Zapsplat (free tier - requires registration)
```
Block Land: https://www.zapsplat.com/sound-effect-category/wood-block/
Game Over: https://www.zapsplat.com/sound-effect-category/games/
```

### OpenGameArt.org (no registration)
```
Menu: https://opengameart.org/content/ambient-menu-theme
Game: https://opengameart.org/content/platformer-game-music
SFX: https://opengameart.org/content/block-sounds
```

### YouTube Audio Library (for reference - extract MP3)
- Search "Lo-fi Chill" for menu
- Search "8-bit Game" for gameplay

## Godot Import Settings:
1. Select each `.ogg` file in Godot editor
2. Enable "Loop" in Import tab
3. Click "Reimport"
4. WAV files work as-is for short SFX

## Quick test commands once files added:
```bash
# Verify files exist
ls -la assets/music/ assets/sfx/
```