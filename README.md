# PICO-8 Development Environment

This VS Code dev container provides a complete development environment for PICO-8 fantasy console development.

## Features

- Ubuntu 22.04 base with all necessary dependencies
- X11 forwarding support for GUI applications
- Audio support (PulseAudio/ALSA)
- Python 3 with useful libraries for game development
- Node.js for web export tools
- Pre-configured PICO-8 directory structure

## Setup Instructions

1. **Install PICO-8**: You'll need to manually add the PICO-8 binary since it's not freely redistributable:
   - Download PICO-8 from [https://www.lexaloffle.com/pico-8.php](https://www.lexaloffle.com/pico-8.php)
   - Extract the Linux version
   - Copy the `pico8` binary to `.devcontainer/pico8/` folder
   - The container will automatically make it available

2. **Build and run the container**:
   ```bash
   # Open in VS Code with Dev Containers extension
   # Or manually build:
   docker build -t pico8-dev .devcontainer/
   ```

## Container Structure

```
/home/vscode/pico8/          # Main working directory
├── carts/                   # Your PICO-8 cart files (.p8)
├── exports/                 # Exported games (HTML, PNG, etc.)
└── screenshots/             # Screenshots and GIFs

/opt/pico8/                  # PICO-8 installation directory
└── pico8                    # PICO-8 binary (you need to add this)
```

## Usage

### Running PICO-8
```bash
# Start PICO-8 (will show install instructions if not found)
pico8

# Start with a specific cart
pico8 carts/mycart.p8
```

### Development Workflow

1. Create your cart files in the `carts/` directory
2. Use PICO-8's built-in editor or VS Code with the HexEditor extension
3. Export your games to the `exports/` directory
4. Use version control for your cart files

### X11 Display
The container includes X11 forwarding. If you need to run PICO-8 with GUI:

```bash
# Start virtual display (usually automatic)
start-x11.sh

# Run PICO-8
DISPLAY=:99 pico8
```

## VS Code Extensions Included

- **Hex Editor**: For viewing/editing .p8 files in binary mode
- **Todo Tree**: For tracking TODOs in your code
- **Python**: For scripting and tools
- **JSON**: For configuration files

## Tips

- PICO-8 cart files (.p8) are actually text files and can be edited directly
- Use the sprite/map/sfx editors in PICO-8 for assets
- The container supports headless operations for automated builds
- Port 8080 is forwarded for web exports

## Adding PICO-8 Binary

Since PICO-8 is not freely redistributable, you need to:

1. Purchase PICO-8 from Lexaloffle
2. Download the Linux version
3. Place the `pico8` binary in `/opt/pico8/` inside the container
4. Or mount it as a volume: `-v /path/to/your/pico8:/opt/pico8`

## Troubleshooting

- **No sound**: Make sure PulseAudio is running and audio devices are accessible
- **Graphics issues**: Ensure X11 forwarding is properly configured
- **Permission errors**: Check that the vscode user has proper permissions

## Development Tools

The container includes several helper scripts:
- `pico8`: Launch PICO-8 with proper environment
- `start-x11.sh`: Start virtual X11 display
- `cart-to-png.py`: Convert carts to PNG (work in progress)

## Fishing cart checks and exports

Run `./test_fishing.sh` to execute scripted gameplay and rendering checks in
PICO-8, then build fresh `exports/simple_fishing.p8.png` and
`exports/simple_fishing.html` / `.js` files. The checks cover aiming and landing,
bite timing, catches and rarity points, line tension, effect cleanup, and drawing
without changing gameplay randomness. Audio checks cover cue priorities, splash
cooldowns, music recovery, day/night ambience, and independent mute toggles.
Failures, timeouts, and missing export
files return a nonzero exit code.

The runner uses `/opt/pico8/pico8` by default. Set `PICO8_BIN` to an executable
launcher if your environment needs a different installation or architecture
compatibility setup. Python 3, Bash, `timeout`, and `rg` are also required.

The fishing cart pause menu includes separate **music** and **sounds** toggles.
Music fades out during bites and fights, then returns after catch feedback.
