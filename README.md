# BrainMelter

A multi-voice audio mixer and streamer that takes speech input from IRC or local files and creates a surreal audio experience with parallel voices, effects, and harbors.

## Overview

BrainMelter is a suite of tools for creating layered speech audio experiences. It combines:

- A Liquidsoap server for multi-channel audio mixing
- Text-to-speech synthesis (espeak and flite support)
- Audio effects (echo, reverb, pitch shifting, vocoder)
- IRC connectivity for remote control
- Multiple audio harbors for parallel audio streams

## Setup

### Prerequisites

- Liquidsoap (for audio mixing)
- espeak and/or flite (for text-to-speech)
- ffmpeg (for audio processing)
- netcat (for IRC connectivity)
- bc (for calculations)

### Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/brainmelter.git
cd brainmelter
```

2. Make scripts executable:
```bash
chmod +x *.sh
```

3. Start the Liquidsoap server:
```bash
liquidsoap brainmelter.liq
```

## Usage

### Basic Text-to-Speech

Send speech directly to BrainMelter:

```bash
./espeak-direct.sh "Your text here" --harbor main --effect none
```

### IRC Connection

Connect to an IRC server and send messages to BrainMelter:

```bash
./irc-to-brainmelter.sh --server irc.example.com --channel "#mychannel"
```

### Testing with Text Files

Process a text file with sample phrases:

```bash
./irc-to-brainmelter.sh --test-file test_phrases.txt --delay 3
```

### Parallel Speech

Play multiple speech streams simultaneously:

```bash
./parallel-speech-irc.sh --local
```

## Script Documentation

### espeak-direct.sh

Direct streaming of text-to-speech to Liquidsoap:

```bash
./espeak-direct.sh "Text to speak" [--harbor HARBOR] [--voice VOICE] [--effect EFFECT] [--volume VOLUME]
```

### irc-to-brainmelter.sh

Connect to IRC and stream messages to BrainMelter:

```bash
./irc-to-brainmelter.sh [--server HOST] [--port PORT] [--channel CHANNEL] [--nick NAME]
```

### parallel-speech-irc.sh

Play multiple voices in parallel through different harbors:

```bash
./parallel-speech-irc.sh [--local] [--tts ENGINE] [--duration SECONDS]
```

## Audio Harbors

BrainMelter uses multiple "harbors" for audio streams:

- `main` - Primary audio channel
- `fx1` - Effects channel 1
- `fx2` - Effects channel 2
- `ambient` - Background ambient sounds
- `drums` - Rhythmic sounds

## Audio Effects

Available effects:

- `none` - No effect
- `echo` - Simple echo effect
- `reverb` - Reverberation effect
- `pitch` - Pitch shifting
- `vocoder` - Voice modulation effect

## License

MIT License

## Acknowledgments

- Inspired by kmein's brainmelter.nix from the niveum project