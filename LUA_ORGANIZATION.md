# PICO-8 Lua Script Organization Guide

## Directory Structure

```
/workspaces/pico8-devcontainer/
├── carts/              # Main PICO-8 cartridge files (.p8)
├── lib/                # Reusable Lua libraries
├── src/                # Source Lua files for complex projects
├── tools/              # Development and build scripts
└── examples/           # Example implementations
```

## 1. External Lua Libraries (`lib/`)

**Purpose**: Reusable code that can be included in multiple carts
**Usage**: `#include lib/filename.lua`

**Examples**:
- `lib/utils.lua` - Common utility functions
- `lib/ai.lua` - AI behavior patterns
- `lib/physics.lua` - Physics calculations
- `lib/ui.lua` - User interface components

## 2. Cart-Specific Scripts (`carts/`)

**For simple projects**: Keep Lua files next to your `.p8` files
```
carts/
├── mygame.p8
├── mygame-player.lua
├── mygame-enemies.lua
└── mygame-levels.lua
```

**Usage in cart**:
```lua
#include mygame-player.lua
#include mygame-enemies.lua
#include mygame-levels.lua
```

## 3. Source Organization (`src/`)

**For complex projects**: Separate source code from compiled carts
```
src/
├── mygame/
│   ├── main.lua
│   ├── player.lua
│   ├── enemies.lua
│   └── build.lua    # Script to combine into .p8
└── shared/
    ├── math.lua
    └── input.lua
```

## 4. Include Syntax

PICO-8 supports several include formats:

```lua
#include filename.lua              -- Include Lua file
#include cartridge.p8:1           -- Include specific tab from cart
#include cartridge.p8             -- Include all tabs from cart
```

## 5. Best Practices

### File Naming
- Use lowercase with hyphens: `enemy-ai.lua`
- Be descriptive: `physics-collision.lua` vs `physics.lua`
- Group related functionality: `ui-menus.lua`, `ui-dialogs.lua`

### Code Organization
```lua
-- At the top of your main cart:
#include lib/utils.lua
#include lib/physics.lua
#include player.lua
#include enemies.lua

function _init()
    -- Your init code
end
```

### Library Structure
```lua
-- lib/utils.lua
-- Keep functions focused and well-documented

-- Math utilities
function distance(x1, y1, x2, y2)
    -- Implementation
end

function clamp(val, min, max)
    -- Implementation
end

-- Don't put initialization code in libraries
-- Libraries should only contain functions and constants
```

## 6. Development Workflow

### Option A: Direct Include (Simple)
1. Write Lua files in `lib/` or next to your cart
2. Use `#include` in your main cart
3. Test directly in PICO-8

### Option B: Build System (Advanced)
1. Write modular code in `src/`
2. Create build script to combine files
3. Generate final `.p8` cart
4. Useful for large projects or team development

## 7. Example Project Structure

```
mygame/
├── carts/
│   └── mygame.p8              # Final combined cart
├── src/
│   ├── main.lua               # Main game logic
│   ├── player.lua             # Player system
│   ├── enemies.lua            # Enemy system
│   └── levels.lua             # Level data
├── lib/
│   ├── utils.lua              # Shared utilities
│   ├── collision.lua          # Collision detection
│   └── particles.lua          # Particle effects
└── tools/
    └── build.sh               # Combines src/ into cart
```

## 8. Testing External Includes

```bash
# Test if your includes work
cd /workspaces/pico8-devcontainer
SDL_AUDIODRIVER=dummy /opt/pico8/pico8 -load carts/your-cart.p8

# Test headless execution
SDL_AUDIODRIVER=dummy /opt/pico8/pico8 -x carts/your-cart.p8
```

## 9. Common Issues

### Path Problems
- Includes are relative to the cart's location
- Save your cart before using includes
- Use forward slashes even on Windows

### Token Limits
- External files count toward the 8192 token limit
- Use compressed/minified code for release
- Consider multiple carts for large projects

### Circular Dependencies
- Avoid files including each other
- Keep libraries focused and independent
- Use a main file to orchestrate includes

## 10. Advanced Techniques

### Conditional Includes
```lua
-- Only include debug tools in development
#include debug-tools.lua
```

### Multi-Cart Projects
```lua
-- Data cart
#include data-levels.p8
#include data-sprites.p8

-- Main game cart references data
reload(0x0, 0x0, 0x2000, "data-levels.p8")
```

This organization keeps your code modular, reusable, and maintainable while working within PICO-8's limitations.
