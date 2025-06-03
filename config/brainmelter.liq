#!/usr/bin/env liquidsoap

# BrainMelter - Simple multi-input audio mixer
# 
# This script sets up a multi-channel audio mixer where multiple input streams
# are mixed together and output to the default audio device and as an HTTP stream.
#
# Set log level (3=Info, 4=Debug)
set("log.level", 3)

# Harbor settings
set("harbor.bind_addr", "0.0.0.0")
set("harbor.port", 8005)

# Create inputs for different streams with meaningful IDs
input_main = input.harbor("main", id="main_input", buffer=0.5)
input_fx1 = input.harbor("fx1", id="fx1_input", buffer=0.5)
input_fx2 = input.harbor("fx2", id="fx2_input", buffer=0.5)
input_ambient = input.harbor("ambient", id="ambient_input", buffer=0.5)
input_drums = input.harbor("drums", id="drums_input", buffer=0.5)

# Create fallbacks for each input with blank sources
# This ensures we always have a valid source even when no stream is connected
fallback_main = fallback(track_sensitive=false, [input_main, blank(duration=1.0)], id="fallback_main")
fallback_fx1 = fallback(track_sensitive=false, [input_fx1, blank(duration=1.0)], id="fallback_fx1")
fallback_fx2 = fallback(track_sensitive=false, [input_fx2, blank(duration=1.0)], id="fallback_fx2")
fallback_ambient = fallback(track_sensitive=false, [input_ambient, blank(duration=1.0)], id="fallback_ambient")
fallback_drums = fallback(track_sensitive=false, [input_drums, blank(duration=1.0)], id="fallback_drums")

# Mix all inputs together
mixed = add([
  fallback_main,
  fallback_fx1,
  fallback_fx2,
  fallback_ambient,
  fallback_drums
])

# Output to the default audio device
out(mixed)

# Make the stream available as HTTP stream
# This creates an HTTP stream that can be accessed by media players
output.harbor(
  %mp3(bitrate=192),
  port=8001,
  mount="brainmelter.mp3",
  mixed
)

# Log that we're running
print("BrainMelter is running!")
print("Available inputs: main, fx1, fx2, ambient, drums")
print("HTTP stream available at: http://localhost:8001/brainmelter.mp3")
print("System ready!")