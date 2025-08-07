# PICO-8 Development Container - Minimal Build
FROM debian:12-slim

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install only essential dependencies in a single layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core utilities
    curl \
    git \
    ca-certificates \
    # X11 minimal dependencies for PICO-8 GUI
    xvfb \
    # Audio support (minimal)
    libasound2 \
    # SDL2 runtime (PICO-8 requirement)
    libsdl2-2.0-0 \
    # Essential libraries PICO-8 needs
    libc6 \
    libgcc-s1 \
    libstdc++6 \
    # Minimal Python for scripting
    python3-minimal \
    # Clean up in same layer to reduce size
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Create user and directories in single layer
RUN groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid vscode --shell /bin/bash --create-home vscode \
    && mkdir -p /opt/pico8 \
    && mkdir -p /home/vscode/pico8/{carts,exports,screenshots} \
    && chown -R vscode:vscode /home/vscode

# Create essential scripts in single layer
RUN printf '#!/bin/bash\nif [ -f "/opt/pico8/pico8" ]; then\n  cd /home/vscode/pico8\n  /opt/pico8/pico8 "$@"\nelse\n  echo "Add PICO-8 binary to /opt/pico8/pico8"\nfi\n' > /usr/local/bin/pico8 \
    && printf '#!/bin/bash\nXvfb :99 -screen 0 1024x768x16 >/dev/null 2>&1 &\n' > /usr/local/bin/start-x11.sh \
    && chmod +x /usr/local/bin/pico8 /usr/local/bin/start-x11.sh

# Set working directory and switch to user
WORKDIR /home/vscode/pico8
USER vscode

# Minimal user setup
RUN echo 'export DISPLAY=:99' >> /home/vscode/.bashrc \
    && echo 'alias pico8="/usr/local/bin/pico8"' >> /home/vscode/.bashrc

# Expose minimal ports
EXPOSE 8080

CMD ["/bin/bash"]
