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

# Report file
REPORT_FILE="$OUTPUT_DIR/conversion_report.txt"
> "$REPORT_FILE"

echo "Converting H.264 10-bit files from: $INPUT_DIR"
echo "Temporary files in: $OUTPUT_DIR"
echo "Report will be saved to: $REPORT_FILE"
echo "------------------------------------------------"

# Initialize report sections
SUCCESSFUL_CONVERSIONS=""
OTHER_RESULTS=""

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
        OTHER_RESULTS="${OTHER_RESULTS}$msg\n"

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
        if ffmpeg -v error -stats -i "$file" -c:v libx264 -pix_fmt yuv420p -c:a aac "$reencode_path"; then
            # Conversion successful

            # Create backup of original file
            backup_file="$file.bak"
            if mv "$file" "$backup_file"; then
                # Copy reencoded file to original location
                if cp "$reencode_path" "$file"; then
                    msg="SUCCESS: $file -> converted and replaced (backup: $backup_file)"
                    echo "$msg"
                    SUCCESSFUL_CONVERSIONS="${SUCCESSFUL_CONVERSIONS}$msg\n"
                else
                    # Failed to copy back, restore original
                    mv "$backup_file" "$file"
                    msg="ERROR (Copy failed): $file - restored from backup"
                    echo "$msg"
                    OTHER_RESULTS="${OTHER_RESULTS}$msg\n"
                fi
            else
                msg="ERROR (Backup failed): $file - could not create backup"
                echo "$msg"
                OTHER_RESULTS="${OTHER_RESULTS}$msg\n"
            fi
        else
            # Conversion failed
            msg="ERROR (Conversion failed): $file"
            echo "$msg"
            OTHER_RESULTS="${OTHER_RESULTS}$msg\n"
        fi
    else
        # Not H.264 10-bit - skip
        msg="SKIPPED (Not H.264 10-bit): $file"
        echo "$msg"
        OTHER_RESULTS="${OTHER_RESULTS}$msg\n"
    fi
done

echo "------------------------------------------------"
echo "Conversion complete."

# Write report
{
    echo "CONVERSION REPORT"
    echo "Generated on: $(date)"
    echo "Input directory: $INPUT_DIR"
    echo "Output directory: $OUTPUT_DIR"
    echo ""
    echo "=================================================="
    echo "SECTION A: SUCCESSFUL CONVERSIONS"
    echo "=================================================="
    if [ -n "$SUCCESSFUL_CONVERSIONS" ]; then
        printf "$SUCCESSFUL_CONVERSIONS"
    else
        echo "No successful conversions."
    fi
    echo ""
    echo "=================================================="
    echo "SECTION B: OTHER RESULTS (Errors, Skipped, Failed)"
    echo "=================================================="
    if [ -n "$OTHER_RESULTS" ]; then
        printf "$OTHER_RESULTS"
    else
        echo "No other results."
    fi
} > "$REPORT_FILE"

echo "Report saved to: $REPORT_FILE"
