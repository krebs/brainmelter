#!/usr/bin/env bash
# setup.sh - Initial setup for BrainMelter
# This script checks for dependencies and helps set up the BrainMelter environment

set -e

# Text formatting
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo -e "${BOLD}BrainMelter Setup${RESET}"
echo "This script will check for dependencies and set up BrainMelter."
echo

# Function to check if a command exists
check_command() {
    local cmd="$1"
    local package="$2"
    local install_hint="$3"
    
    echo -n "Checking for $cmd... "
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}Found${RESET}"
        return 0
    else
        echo -e "${RED}Not found${RESET}"
        echo -e "${YELLOW}Please install $package:${RESET}"
        echo "$install_hint"
        return 1
    fi
}

# Check dependencies
MISSING_DEPS=0

# Check for liquidsoap
check_command "liquidsoap" "Liquidsoap" "Visit https://www.liquidsoap.info/doc-dev/install.html or use your package manager" || MISSING_DEPS=$((MISSING_DEPS + 1))

# Check for ffmpeg
check_command "ffmpeg" "FFmpeg" "Use your package manager (apt install ffmpeg, brew install ffmpeg, etc.)" || MISSING_DEPS=$((MISSING_DEPS + 1))

# Check for netcat
check_command "nc" "Netcat" "Use your package manager (apt install netcat, brew install netcat, etc.)" || MISSING_DEPS=$((MISSING_DEPS + 1))

# Check for flite
check_command "flite" "Flite TTS" "Use your package manager (apt install flite, brew install flite, etc.)" || MISSING_DEPS=$((MISSING_DEPS + 1))

# Check for espeak (optional)
check_command "espeak" "eSpeak TTS" "Optional: Use your package manager (apt install espeak, brew install espeak, etc.)" || echo -e "${YELLOW}eSpeak is optional if using Flite${RESET}"

# Check for bc
check_command "bc" "Basic Calculator" "Use your package manager (apt install bc, brew install bc, etc.)" || MISSING_DEPS=$((MISSING_DEPS + 1))

echo
if [ $MISSING_DEPS -gt 0 ]; then
    echo -e "${YELLOW}Missing $MISSING_DEPS dependencies. Please install them and run this script again.${RESET}"
    exit 1
else
    echo -e "${GREEN}All required dependencies found!${RESET}"
fi

# Make scripts executable
echo "Making scripts executable..."
chmod +x scripts/*.sh

# Create symbolic links
echo "Creating symbolic links to scripts..."
mkdir -p ~/.local/bin
ln -sf "$(pwd)/scripts/espeak-direct.sh" ~/.local/bin/espeak-to-brainmelter
ln -sf "$(pwd)/scripts/irc-to-brainmelter.sh" ~/.local/bin/irc-to-brainmelter
ln -sf "$(pwd)/scripts/parallel-speech-irc.sh" ~/.local/bin/parallel-speech

echo
echo -e "${GREEN}Setup complete!${RESET}"
echo "You can now start BrainMelter with:"
echo "  liquidsoap config/brainmelter.liq"
echo
echo "And use the commands:"
echo "  espeak-to-brainmelter \"Your text here\""
echo "  irc-to-brainmelter --test-file examples/test_phrases.txt"
echo "  parallel-speech --local"
echo
echo "Make sure ~/.local/bin is in your PATH, or run the scripts directly from the scripts directory."