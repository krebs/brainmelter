#!/usr/bin/env bash
# parallel-speech-irc.sh - Integrated script that combines parallel speech with IRC brainmelter functionality
# Usage: ./parallel-speech-irc.sh [OPTIONS]
# Options:
#   --server HOST     IRC server to connect to (default: brockman.news)
#   --port PORT       IRC server port (default: 6667)
#   --channel CHAN    IRC channel to join (default: #all)
#   --nick NAME       IRC nickname (default: brainmelter)
#   --local           Use local liquidsoap server instead of IRC
#   --tts ENGINE      TTS engine to use: espeak or flite (default: espeak)
#   --duration SEC    Duration in seconds for the session (default: run until Ctrl+C)

set -e

# Configuration
TEMP_DIR=$(mktemp -d)
PIDS_FILE="$TEMP_DIR/pids.txt"
LOG_FILE="$TEMP_DIR/brainmelter.log"
FIFO="$TEMP_DIR/irc_fifo"

# Default settings
SERVER="brockman.news"
PORT=6667
CHANNEL="#all"
NICK="brainmelter"
USER="brainmelter"
TTS_ENGINE="espeak"
DURATION=0  # 0 means run indefinitely
LOCAL_MODE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --server)
            SERVER="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --channel)
            CHANNEL="$2"
            shift 2
            ;;
        --nick)
            NICK="$2"
            shift 2
            ;;
        --local)
            LOCAL_MODE=true
            shift
            ;;
        --tts)
            TTS_ENGINE="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --server HOST     IRC server to connect to (default: brockman.news)"
            echo "  --port PORT       IRC server port (default: 6667)"
            echo "  --channel CHAN    IRC channel to join (default: #all)"
            echo "  --nick NAME       IRC nickname (default: brainmelter)"
            echo "  --local           Use local liquidsoap server instead of IRC"
            echo "  --tts ENGINE      TTS engine to use: espeak or flite (default: espeak)"
            echo "  --duration SEC    Duration in seconds for the session (default: run until Ctrl+C)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Clean up function
cleanup() {
    echo "Cleaning up..." | tee -a "$LOG_FILE"
    
    # Kill all background processes
    if [ -f "$PIDS_FILE" ]; then
        for pid in $(cat "$PIDS_FILE"); do
            kill $pid 2>/dev/null || true
        done
    fi
    
    # Remove temporary directory
    rm -rf "$TEMP_DIR"
    
    echo "Exiting."
    exit 0
}

# Set up trap for clean exit
trap cleanup EXIT INT TERM

# Initialize PID file
touch "$PIDS_FILE"

# Function to speak text with selected TTS engine
speak_text() {
    local text="$1"
    local voice="$2"
    local harbor="$3"
    local effect="$4"
    local volume="${5:-1.0}"
    
    echo "Speaking: $text" | tee -a "$LOG_FILE"
    
    if [[ "$TTS_ENGINE" == "espeak" ]]; then
        if [[ "$LOCAL_MODE" == "true" ]]; then
            # Use local liquidsoap server
            ./espeak-direct.sh "$text" --harbor "$harbor" --voice "$voice" --effect "$effect" --volume "$volume" &
            echo $! >> "$PIDS_FILE"
        else
            # Just use espeak directly
            espeak -v "$voice" "$text" &
            echo $! >> "$PIDS_FILE"
        fi
    elif [[ "$TTS_ENGINE" == "flite" ]]; then
        # Use flite (similar to brainmelter.nix)
        if [[ "$LOCAL_MODE" == "true" ]]; then
            # Create temp WAV and stream to liquidsoap
            local temp_wav="$TEMP_DIR/temp_$RANDOM.wav"
            flite -voice "$voice" -t "$text" -o "$temp_wav"
            
            ffmpeg -hide_banner -loglevel error \
                -f wav -i "$temp_wav" \
                -af "volume=$volume" \
                -c:a libmp3lame -b:a 192k -content_type audio/mpeg \
                -f mp3 "icecast://source:hackme@localhost:8005/$harbor" &
            
            echo $! >> "$PIDS_FILE"
            
            # Schedule cleanup of temp file
            (sleep 10 && rm -f "$temp_wav") &
        else
            # Just use flite directly
            flite -voice "$voice" -t "$text" &
            echo $! >> "$PIDS_FILE"
        fi
    else
        echo "Unknown TTS engine: $TTS_ENGINE" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Function to get a random voice
random_voice() {
    if [[ "$TTS_ENGINE" == "espeak" ]]; then
        echo -e "en\nen-us\nen-uk\nen-scottish" | shuf -n1
    elif [[ "$TTS_ENGINE" == "flite" ]]; then
        echo -e "awb\nkal\nrms\nslt" | shuf -n1
    fi
}

# Function to get a random harbor
random_harbor() {
    echo -e "main\nfx1\nfx2\nambient\ndrums" | shuf -n1
}

# Function to get a random effect
random_effect() {
    echo -e "none\necho\nreverb\npitch\nvocoder" | shuf -n1
}

if [[ "$LOCAL_MODE" == "false" ]]; then
    # Connect to IRC server (from brainmelter.nix)
    echo "=== BrainMelter IRC Mode ==="
    echo "Connecting to $SERVER:$PORT as $NICK, joining $CHANNEL"
    
    # Create FIFO for IRC communication
    mkfifo "$FIFO"
    
    # Send IRC commands
    {
        echo "NICK $NICK"
        echo "USER $USER 0 * :$USER"
        sleep 5
        echo "JOIN $CHANNEL"
        while true; do
            sleep 30
            echo "PING :keepalive"
        done
    } > "$FIFO" &
    echo $! >> "$PIDS_FILE"
    
    # Set up time limit if specified
    if [[ $DURATION -gt 0 ]]; then
        (sleep $DURATION && echo "Time limit reached" && kill -INT $$) &
        echo $! >> "$PIDS_FILE"
    fi
    
    # Read from server and process messages
    nc "$SERVER" "$PORT" < "$FIFO" | while IFS= read -r line; do
        echo "IRC: $line" >> "$LOG_FILE"
        
        # Get message content (adjust pattern based on server format)
        message=$(echo "$line" | sed -n 's/.*go.brockman.news\/\S\+ //p')
        
        if [[ -n "$message" ]]; then
            # Speak the message with a random voice, harbor, and effect
            voice=$(random_voice)
            harbor=$(random_harbor)
            effect=$(random_effect)
            volume=$(echo "0.6 + (0.4 * $RANDOM / 32767)" | bc -l | head -c 4)
            
            speak_text "$message" "$voice" "$harbor" "$effect" "$volume"
        fi
        
        # Respond to PINGs to avoid timeout
        if [[ "$line" == PING* ]]; then
            server_ping=$(echo "$line" | cut -d':' -f2)
            echo "PONG :$server_ping" > "$FIFO"
        fi
    done
else
    # Local liquidsoap mode with IRC connection
    echo "=== BrainMelter Local Parallel Mode with IRC Input ==="
    
    # Create FIFO for IRC communication
    mkfifo "$FIFO"
    
    # Send IRC commands
    {
        echo "NICK $NICK"
        echo "USER $USER 0 * :$USER"
        sleep 5
        echo "JOIN $CHANNEL"
        while true; do
            sleep 30
            echo "PING :keepalive"
        done
    } > "$FIFO" &
    echo $! >> "$PIDS_FILE"
    
    echo "Connected to IRC server $SERVER as $NICK"
    echo "Joined channel $CHANNEL"
    echo "Listening for messages and streaming to Liquidsoap..."
    
    # Set up time limit if specified
    if [[ $DURATION -gt 0 ]]; then
        (sleep $DURATION && echo "Time limit reached" && kill -INT $$) &
        echo $! >> "$PIDS_FILE"
    fi
    
    # Read from server and process messages
    nc "$SERVER" "$PORT" < "$FIFO" | while IFS= read -r line; do
        echo "IRC: $line" >> "$LOG_FILE"
        
        # Get message content (adjust pattern based on server format)
        message=$(echo "$line" | sed -n 's/.*go.brockman.news\/\S\+ //p')
        
        if [[ -n "$message" ]]; then
            # Speak the message with a random voice, harbor, and effect
            voice=$(random_voice)
            harbor=$(random_harbor)
            effect=$(random_effect)
            volume=$(echo "0.6 + (0.4 * $RANDOM / 32767)" | bc -l | head -c 4)
            
            # In local mode, we use local liquidsoap server
            speak_text "$message" "$voice" "$harbor" "$effect" "$volume"
        fi
        
        # Respond to PINGs to avoid timeout
        if [[ "$line" == PING* ]]; then
            server_ping=$(echo "$line" | cut -d':' -f2)
            echo "PONG :$server_ping" > "$FIFO"
        fi
    done
fi