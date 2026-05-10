#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./rename.sh "New App Name" com.yourorg
#   ./rename.sh "New App Name" com.yourorg com.yourorg.custom.bundleid   # optional explicit bundle id

OLD_PROJECT_NAME="TemplateApp"

if [ $# -lt 2 ]; then
  echo "Usage: $0 \"New App Name\" com.yourorg [com.yourorg.bundleid]"
  exit 1
fi

NEW_NAME_RAW="$1"
ORG_ID="$2"
EXPLICIT_BUNDLE_ID="${3:-}"

# Check if we're in the right directory
if [ ! -d "$OLD_PROJECT_NAME" ] || [ ! -d "${OLD_PROJECT_NAME}.xcodeproj" ]; then
  echo "❌ Template project not found. Expected '$OLD_PROJECT_NAME' directory and '${OLD_PROJECT_NAME}.xcodeproj' in current directory."
  echo "   Current directory: $(pwd)"
  echo "   Please run this script from the template project root directory."
  exit 1
fi

# Sanitize filesystem name
NEW_NAME="$NEW_NAME_RAW"
NEW_NAME="${NEW_NAME//:/-}"
NEW_NAME="${NEW_NAME//\//-}"
NEW_NAME="${NEW_NAME//\"/}"
NEW_NAME="${NEW_NAME//\'/}"
NEW_NAME="${NEW_NAME//$/}"
NEW_NAME="${NEW_NAME//&/and}"

# RFC1034-ish component for bundle id suffix
name_rfc1034() {
  # lowercase, spaces/underscores -> hyphen, keep [a-z0-9-], trim hyphens
  printf "%s" "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[ _]+/-/g' \
    | tr -cd '[:alnum:]-' \
    | sed -E 's/^-+//; s/-+$//'
}
APP_ID_COMPONENT="$(name_rfc1034 "$NEW_NAME_RAW")"
if [ -z "$APP_ID_COMPONENT" ]; then
  echo "❌ Could not derive bundle id component from name '$NEW_NAME_RAW'"
  exit 1
fi

NEW_BUNDLE_ID="${EXPLICIT_BUNDLE_ID:-$ORG_ID.$APP_ID_COMPONENT}"
NEW_TESTS_NAME="${NEW_NAME}Tests"
NEW_UITESTS_NAME="${NEW_NAME}UITests"
NEW_TESTS_BUNDLE_ID="$ORG_ID.${APP_ID_COMPONENT}Tests"
NEW_UITESTS_BUNDLE_ID="$ORG_ID.${APP_ID_COMPONENT}UITests"

echo "🚀 Renaming project in place:"
echo "   Working dir : $(pwd)"
echo "   App name    : $NEW_NAME"
echo "   Bundle ID   : $NEW_BUNDLE_ID"
echo "   Tests ID    : $NEW_TESTS_BUNDLE_ID"
echo "   UITests ID  : $NEW_UITESTS_BUNDLE_ID"
echo

# Detect sed flavor (BSD on macOS vs GNU)
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=('sed' '-i')
else
  SED_INPLACE=('sed' '-i' '')
fi

# 1) Rename directories
echo "📁 Renaming directories..."
if [ -d "$OLD_PROJECT_NAME" ]; then
  mv "$OLD_PROJECT_NAME" "$NEW_NAME"
fi

if [ -d "${OLD_PROJECT_NAME}.xcodeproj" ]; then
  mv "${OLD_PROJECT_NAME}.xcodeproj" "${NEW_NAME}.xcodeproj"
fi

if [ -d "${OLD_PROJECT_NAME}Tests" ]; then
  mv "${OLD_PROJECT_NAME}Tests" "$NEW_TESTS_NAME"
fi

if [ -d "${OLD_PROJECT_NAME}UITests" ]; then
  mv "${OLD_PROJECT_NAME}UITests" "$NEW_UITESTS_NAME"
fi

# 2) Rename scheme files
SCHEME_DIR="${NEW_NAME}.xcodeproj/xcshareddata/xcschemes"
if [ -d "$SCHEME_DIR" ] && [ -f "$SCHEME_DIR/${OLD_PROJECT_NAME}.xcscheme" ]; then
  mv "$SCHEME_DIR/${OLD_PROJECT_NAME}.xcscheme" "$SCHEME_DIR/${NEW_NAME}.xcscheme"
fi

# 3) Bulk replace strings in all text files
echo "🔄 Replacing strings in files..."
LOWER_OLD="templateapp"

# Find all text files (excluding binary files)
FILES=$(find . -type f \( \
  -name "*.pbxproj" -o \
  -name "*.xcscheme" -o \
  -name "*.swift" -o \
  -name "*.plist" -o \
  -name "*.xcconfig" -o \
  -name "*.m" -o \
  -name "*.h" -o \
  -name "*.mm" -o \
  -name "*.hpp" -o \
  -name "*.cpp" -o \
  -name "Package.resolved" \
\) ! -path "*/\.*" ! -name "*.xcuserstate" ! -name "*.xcuserdatad" ! -name "*.DS_Store" ! -path "./rename.sh")

# Add .gitignore files separately (they're hidden files)
GITIGNORE_FILES=$(find . -type f -name ".gitignore" ! -path "./rename.sh" 2>/dev/null)
ALL_FILES="$FILES $GITIGNORE_FILES"

for f in $ALL_FILES; do
  # Replace longer strings first to avoid partial replacements
  # Replace TemplateAppUITests before TemplateAppTests before TemplateApp
  "${SED_INPLACE[@]}" "s/${OLD_PROJECT_NAME}UITests/${NEW_UITESTS_NAME}/g" "$f"
  "${SED_INPLACE[@]}" "s/${OLD_PROJECT_NAME}Tests/${NEW_TESTS_NAME}/g" "$f"
  "${SED_INPLACE[@]}" "s/${OLD_PROJECT_NAME}/${NEW_NAME}/g" "$f"
  
  # Replace bundle IDs - handle various formats (longer first)
  "${SED_INPLACE[@]}" "s/com\\.prokopik\\.${OLD_PROJECT_NAME}UITests/${NEW_UITESTS_BUNDLE_ID}/g" "$f"
  "${SED_INPLACE[@]}" "s/com\\.prokopik\\.${OLD_PROJECT_NAME}Tests/${NEW_TESTS_BUNDLE_ID}/g" "$f"
  "${SED_INPLACE[@]}" "s/com\\.prokopik\\.${OLD_PROJECT_NAME}/${NEW_BUNDLE_ID}/g" "$f"
  "${SED_INPLACE[@]}" "s/com\\.example\\.${OLD_PROJECT_NAME}UITests/${NEW_UITESTS_BUNDLE_ID}/g" "$f"
  "${SED_INPLACE[@]}" "s/com\\.example\\.${OLD_PROJECT_NAME}Tests/${NEW_TESTS_BUNDLE_ID}/g" "$f"
  "${SED_INPLACE[@]}" "s/com\\.example\\.${OLD_PROJECT_NAME}/${NEW_BUNDLE_ID}/g" "$f"
  "${SED_INPLACE[@]}" "s/com\\.example\\.${LOWER_OLD}/${NEW_BUNDLE_ID}/g" "$f"
done

# 4) Update Info.plist files
echo "📝 Updating Info.plist files..."
PLISTS=$(find . -type f -name "Info.plist")
for p in $PLISTS; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName '$NEW_NAME'" "$p" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string '$NEW_NAME'" "$p" 2>/dev/null || true

  /usr/libexec/PlistBuddy -c "Set :CFBundleName '$NEW_NAME'" "$p" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleName string '$NEW_NAME'" "$p" 2>/dev/null || true
done

# 5) Rename Swift files if needed (optional, but helpful for consistency)
echo "📄 Renaming Swift files..."
# Note: Directories are already renamed, so we check for files that might still have old names
# but we need to look in the renamed directories
find "$NEW_NAME" -name "*${OLD_PROJECT_NAME}*.swift" -type f 2>/dev/null | while read -r f; do
  new_name=$(echo "$f" | sed "s/${OLD_PROJECT_NAME}/${NEW_NAME}/g")
  if [ "$f" != "$new_name" ]; then
    mv "$f" "$new_name" 2>/dev/null || true
  fi
done

find "$NEW_TESTS_NAME" -name "*${OLD_PROJECT_NAME}*.swift" -type f 2>/dev/null | while read -r f; do
  new_name=$(echo "$f" | sed "s/${OLD_PROJECT_NAME}Tests/${NEW_TESTS_NAME}/g")
  if [ "$f" != "$new_name" ]; then
    mv "$f" "$new_name" 2>/dev/null || true
  fi
done

find "$NEW_UITESTS_NAME" -name "*${OLD_PROJECT_NAME}*.swift" -type f 2>/dev/null | while read -r f; do
  new_name=$(echo "$f" | sed "s/${OLD_PROJECT_NAME}UITests/${NEW_UITESTS_NAME}/g")
  if [ "$f" != "$new_name" ]; then
    mv "$f" "$new_name" 2>/dev/null || true
  fi
done

echo "✅ Done!"
echo "   Open: ${NEW_NAME}.xcodeproj"