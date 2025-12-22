#!/bin/bash

# Check for minimum number of arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <input_dir> [output_path_for_result_txt]"
    exit 1
fi

INPUT_DIR="$1"
RESULT_FILE="$2"

# Setup Output (File vs Console)
if [ -n "$RESULT_FILE" ]; then
    mkdir -p "$(dirname "$RESULT_FILE")"
    > "$RESULT_FILE"
    echo "Scanning: $INPUT_DIR"
    echo "Logging to: $RESULT_FILE"
else
    echo "Scanning: $INPUT_DIR (Console Output Only)"
fi

echo "------------------------------------------------"

# Find .mkv and .mp4 files recursively
find "$INPUT_DIR" -type f \( -name "*.mkv" -o -name "*.mp4" \) -print0 | while IFS= read -r -d '' file; do
    
    # Extract metadata
    metadata=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name,pix_fmt -of csv=p=0 "$file")
    
    # Capture exit status of ffprobe
    status=$?

    if [ $status -ne 0 ]; then
        # ERROR CASE: ffprobe failed to read the file
        msg="ERROR (Unreadable): $file"
        echo "$msg"
        [[ -n "$RESULT_FILE" ]] && echo "$msg" >> "$RESULT_FILE"
    
    elif [[ "$metadata" == *"h264"* ]] && [[ "$metadata" == *"10"* ]]; then
        # SUCCESS CASE: H.264 10-bit found
        msg="FOUND (H264 10-bit): $file"
        echo "$msg"
        [[ -n "$RESULT_FILE" ]] && echo "$file" >> "$RESULT_FILE"
    fi
done

echo "------------------------------------------------"
echo "Scan complete."
if [ -n "$RESULT_FILE" ]; then
    echo "Summary saved to $RESULT_FILE"
fi
