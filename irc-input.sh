set -e

SERVER="brockman.news"
PORT=6667
NICK="brainmelter"
USER="brainmelter"
CHANNEL="#all"
PATTERN='go.brockman.news\/\S\+ '
TEST_FILE=""
TEST_MODE=false
DELAY=3

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --server|-s)
            SERVER="$2"
            shift 2
            ;;
        --port|-p)
            PORT="$2"
            shift 2
            ;;
        --nick|-n)
            NICK="$2"
            shift 2
            ;;
        --user|-u)
            USER="$2"
            shift 2
            ;;
        --channel|-c)
            CHANNEL="$2"
            shift 2
            ;;
        --pattern|-P)
            PATTERN="$2"
            shift 2
            ;;
        --test-file|-t)
            TEST_FILE="$2"
            TEST_MODE=true
            shift 2
            ;;
        --delay|-d)
            DELAY="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Connect to IRC and stream messages to brainmelter."
            echo ""
            echo "Options:"
            echo "  -s, --server SERVER   IRC server to connect to (default: brockman.news)"
            echo "  -p, --port PORT       Server port (default: 6667)"
            echo "  -n, --nick NICK       IRC nickname (default: brainmelter)"
            echo "  -u, --user USER       IRC username (default: brainmelter)"
            echo "  -c, --channel CHANNEL IRC channel to join (default: #all)"
            echo "  -P, --pattern PATTERN Regex pattern to extract messages (default: go.brockman.news\/\S\+ )"
            echo "  -t, --test-file FILE  Test with a local text file instead of IRC"
            echo "  -d, --delay SECONDS   Delay between lines when using test file (default: 3)"
            echo "  -h, --help            Display this help message"
            echo ""
            echo "Uses Flite TTS with random voices (awb, kal, rms, slt, kal16) for speech synthesis."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Create temporary directory and files
TEMP_DIR=$(mktemp -d)
FIFO="$TEMP_DIR/irc_fifo"
PIDS_FILE="$TEMP_DIR/pids.txt"
LOG_FILE="$TEMP_DIR/irc.log"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    if [[ -f "$PIDS_FILE" ]]; then
        for pid in $(cat "$PIDS_FILE"); do
            kill $pid 2>/dev/null || true
        done
    fi
    rm -rf "$TEMP_DIR"
    exit 0
}
trap cleanup EXIT INT TERM

# Create FIFO for IRC communication
mkfifo "$FIFO"
touch "$PIDS_FILE"

# Function to get a random voice, harbor, and effect
random_voice() {
    # Available flite voices: awb (Scottish male), kal (American male),
    # rms (American male), slt (American female), kal16 (American male 16kHz)
    echo -e "awb\nkal\nrms\nslt\nkal16" | shuf -n1
}

random_harbor() {
    number_of_harbors="${BRAINMELTER_HARBORS:-6}"
    seq "$number_of_harbors" | shuf -n 1
}

random_effect() {
    echo -e "none\necho\nreverb\npitch\nvocoder" | shuf -n1
}

# Function to stream text to brainmelter
stream_to_brainmelter() {
    local text="$1"
    local voice=$(random_voice)
    local harbor=$(random_harbor)
    local effect=$(random_effect)

    echo "[$(date +%H:%M:%S)] Streaming to harbor $harbor: \"$text\"" | tee -a "$LOG_FILE"

    # Create a temporary file for the speech
    local temp_wav="$TEMP_DIR/speech_$(date +%s%N).wav"

    # Generate speech with flite
    flite -voice "$voice" -t "$text" -o "$temp_wav" || {
        echo "Error generating speech with flite. Voice: $voice" | tee -a "$LOG_FILE"
        # Fallback to default voice if specified voice fails
        flite -t "$text" -o "$temp_wav"
    }

    # Choose effect filter
    local effect_filter=""
    case "$effect" in
        echo)
            effect_filter="-af aecho=0.8:0.9:1000:0.3"
            ;;
        reverb)
            effect_filter="-af areverse,aecho=0.8:0.88:60:0.4,areverse"
            ;;
        pitch)
            effect_filter="-af asetrate=44100*0.9,aresample=44100"
            ;;
        vocoder)
            effect_filter="-af afftfilt=real='hypot(re,im)*sin(0)':imag='hypot(re,im)*cos(0)':win_size=512:overlap=0.75"
            ;;
    esac

    # Stream to brainmelter
    ffmpeg -hide_banner -loglevel error \
        -f wav -i "$temp_wav" \
        $effect_filter \
        -c:a libmp3lame -b:a 192k -content_type audio/mpeg \
        -f mp3 "icecast://source:hackme@localhost:8005/$harbor" &

    local ffmpeg_pid=$!
    echo $ffmpeg_pid >> "$PIDS_FILE"

    # Schedule removal of temporary file
    (
        sleep 10
        rm -f "$temp_wav"
    ) &
}

# Main execution starts here
if [[ "$TEST_MODE" == "true" ]]; then
    echo "=== BrainMelter Test Mode with Flite TTS ==="
    echo "Reading from file: $TEST_FILE"
    echo "Using Flite TTS with random voices for speech synthesis"
    echo "Delay between lines: $DELAY seconds"

    if [[ ! -f "$TEST_FILE" ]]; then
        echo "Error: Test file not found: $TEST_FILE"
        exit 1
    fi

    # Process each line of the test file
    while IFS= read -r line; do
        echo "Processing: $line"
        if [[ -n "$line" ]]; then
            stream_to_brainmelter "$line"
            sleep "$DELAY"
        fi
    done < "$TEST_FILE"

    echo "Test file processing complete."
else
    echo "=== IRC to BrainMelter with Flite TTS ==="
    echo "Connecting to $SERVER:$PORT as $NICK"
    echo "Joining channel $CHANNEL"
    echo "Starting IRC connection..."
    echo "Using Flite TTS with random voices for speech synthesis"

    # Send IRC commands
    {
        echo "NICK $NICK"
        echo "USER $USER 0 * :$USER"
        sleep 3
        echo "JOIN $CHANNEL"

        # Send periodic pings to keep the connection alive
        while true; do
            sleep 30
            echo "PING :keepalive"
        done
    } > "$FIFO" &
    echo $! >> "$PIDS_FILE"

    # Read messages from IRC and process them
    nc "$SERVER" "$PORT" < "$FIFO" | while IFS= read -r line; do
        echo "$line" >> "$LOG_FILE"

        # Extract message content using the pattern
        message=$(echo "$line" | sed -n "s/.*$PATTERN//p")

        if [[ -n "$message" ]]; then
            stream_to_brainmelter "$message"
        fi

        # Respond to server PINGs to avoid timeout
        if [[ "$line" == PING* ]]; then
            server_ping=$(echo "$line" | cut -d':' -f2)
            echo "PONG :$server_ping" > "$FIFO"
        fi
    done
fi
