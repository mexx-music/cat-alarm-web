#!/bin/bash

# iOS Icon Generation Script for Cat Alarm

SOURCE_IMAGE="assets/icons/catalarm.png"
iOS_ICON_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"

echo "Generating iOS icons from $SOURCE_IMAGE..."

# iOS Icon specifications (name and size)
ICONS=(
    "Icon-App-20x20@1x:20"
    "Icon-App-20x20@2x:40"
    "Icon-App-20x20@3x:60"
    "Icon-App-29x29@1x:29"
    "Icon-App-29x29@2x:58"
    "Icon-App-29x29@3x:87"
    "Icon-App-40x40@1x:40"
    "Icon-App-40x40@2x:80"
    "Icon-App-40x40@3x:120"
    "Icon-App-60x60@2x:120"
    "Icon-App-60x60@3x:180"
    "Icon-App-76x76@1x:76"
    "Icon-App-76x76@2x:152"
    "Icon-App-83.5x83.5@2x:167"
    "Icon-App-1024x1024@1x:1024"
)

for icon_spec in "${ICONS[@]}"; do
    icon_name="${icon_spec%:*}"
    size="${icon_spec#*:}"
    output_file="$iOS_ICON_DIR/${icon_name}.png"

    echo "Creating $icon_name (${size}x${size})..."
    sips -z $size $size "$SOURCE_IMAGE" --out "$output_file"
done

echo "iOS icon generation completed!"
