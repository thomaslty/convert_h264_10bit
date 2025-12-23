#!/bin/bash

# Check for minimum number of arguments
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <input_dir> [output_dir]"
    echo "  input_dir: Directory to scan for H.264 10-bit files"
    echo "  output_dir: Directory for temporary files (defaults to current directory)"
    exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="${2:-$(pwd)}"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Log files - delete existing ones if they exist
SUCCESS_LOG="$OUTPUT_DIR/success.log"
FAILED_LOG="$OUTPUT_DIR/failed.error"
SKIPPED_LOG="$OUTPUT_DIR/skipped.log"
[ -f "$SUCCESS_LOG" ] && rm "$SUCCESS_LOG"
[ -f "$FAILED_LOG" ] && rm "$FAILED_LOG"
[ -f "$SKIPPED_LOG" ] && rm "$SKIPPED_LOG"

echo "Converting H.264 10-bit files from: $INPUT_DIR"
echo "Temporary files in: $OUTPUT_DIR"
echo "Success log: $SUCCESS_LOG"
echo "Failed/error log: $FAILED_LOG"
echo "Skipped log: $SKIPPED_LOG"
echo "------------------------------------------------"

# Find .mp4 files recursively
find "$INPUT_DIR" -type f -name "*.mp4" -print0 | while IFS= read -r -d '' file; do

    # Extract metadata
    metadata=$(ffprobe -v quiet -select_streams v:0 -show_entries stream=codec_name,pix_fmt -of csv=p=0 "$file")

    # Capture exit status of ffprobe
    status=$?

    if [ $status -ne 0 ]; then
        # ERROR CASE: ffprobe failed to read the file
        msg="ERROR (Unreadable): $file"
        echo "$msg"
        echo "$msg" >> "$FAILED_LOG"

    elif [[ "$metadata" == *"h264"* ]] && [[ "$metadata" == *"10"* ]]; then
        # FOUND H.264 10-bit file - attempt conversion
        filename=$(basename "$file")
        filename_noext="${filename%.*}"
        extension="${filename##*.}"

        echo "Processing: $file"

        # Remove existing _reencode.mp4 if it exists
        reencode_path="$OUTPUT_DIR/_reencode.mp4"
        [ -f "$reencode_path" ] && rm "$reencode_path"

        # Convert using ffmpeg
        if ffmpeg -y -nostdin -v error -stats -i "$file" -c:v libx264 -pix_fmt yuv420p -c:a aac "$reencode_path"; then
            # Conversion successful

            # Create backup of original file
            backup_file="$file.bak"
            if mv "$file" "$backup_file"; then
                # Copy reencoded file to original location
                if cp "$reencode_path" "$file"; then
                    # Remove the backup file after successful copy
                    rm "$backup_file"
                    msg="SUCCESS: $file -> converted and replaced"
                    echo "$msg"
                    echo "$msg" >> "$SUCCESS_LOG"
                else
                    # Failed to copy back, restore original
                    mv "$backup_file" "$file"
                    msg="ERROR (Copy failed): $file - restored from backup"
                    echo "$msg"
                    echo "$msg" >> "$FAILED_LOG"
                fi
            else
                msg="ERROR (Backup failed): $file - could not create backup"
                echo "$msg"
                echo "$msg" >> "$FAILED_LOG"
            fi
        else
            # Conversion failed
            msg="ERROR (Conversion failed): $file"
            echo "$msg"
            echo "$msg" >> "$FAILED_LOG"
        fi
    else
        # Not H.264 10-bit - skip
        msg="SKIPPED (Not H.264 10-bit): $file"
        echo "$msg"
        echo "$msg" >> "$SKIPPED_LOG"
    fi
done

echo "------------------------------------------------"
echo "Conversion complete."
echo "Success log: $SUCCESS_LOG"
echo "Failed/error log: $FAILED_LOG"
echo "Skipped log: $SKIPPED_LOG"
