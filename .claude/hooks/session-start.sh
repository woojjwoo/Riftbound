#!/bin/bash
set -euo pipefail

# Only run in remote (Claude Code on the web) environments
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.6.1-stable"
GODOT_BIN="Godot_v${GODOT_VERSION}_linux.x86_64"
GODOT_ZIP="${GODOT_BIN}.zip"
INSTALL_DIR="/usr/local/bin"

# Install Godot if not already present
if ! command -v godot &> /dev/null; then
  echo "Installing Godot ${GODOT_VERSION}..."
  cd /tmp
  wget -q "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"
  unzip -o "${GODOT_ZIP}"
  chmod +x "${GODOT_BIN}"
  mv "${GODOT_BIN}" "${INSTALL_DIR}/godot"
  rm -f "${GODOT_ZIP}"
  echo "Godot installed to ${INSTALL_DIR}/godot"
fi

# Import project to generate .godot cache (needed for script validation)
cd "$CLAUDE_PROJECT_DIR"
godot --headless --import 2>/dev/null || true

echo "Session start hook complete."
