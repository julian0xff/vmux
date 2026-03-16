#!/usr/bin/env bash
set -euo pipefail

APP_NAME="vmux DEV"
BUNDLE_ID="com.vmuxterm.app.debug"
BASE_APP_NAME="vmux DEV"
DERIVED_DATA=""
NAME_SET=0
BUNDLE_SET=0
DERIVED_SET=0
TAG=""
VMUX_DEBUG_LOG=""
LAST_SOCKET_PATH_DIR="$HOME/Library/Application Support/vmux"
LAST_SOCKET_PATH_FILE="${LAST_SOCKET_PATH_DIR}/last-socket-path"

write_last_socket_path() {
  local socket_path="$1"
  mkdir -p "$LAST_SOCKET_PATH_DIR"
  echo "$socket_path" > "$LAST_SOCKET_PATH_FILE" || true
  echo "$socket_path" > /tmp/vmux-last-socket-path || true
}

usage() {
  cat <<'EOF'
Usage: ./scripts/reload.sh --tag <name> [options]

Options:
  --tag <name>           Required. Short tag for parallel builds (e.g., feature-xyz-lol).
                         Sets app name, bundle id, and derived data path unless overridden.
  --name <app name>      Override app display/bundle name.
  --bundle-id <id>       Override bundle identifier.
  --derived-data <path>  Override derived data path.
  -h, --help             Show this help.
EOF
}

sanitize_bundle() {
  local raw="$1"
  local cleaned
  cleaned="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/./g; s/^\\.+//; s/\\.+$//; s/\\.+/./g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  echo "$cleaned"
}

sanitize_path() {
  local raw="$1"
  local cleaned
  cleaned="$(echo "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')"
  if [[ -z "$cleaned" ]]; then
    cleaned="agent"
  fi
  echo "$cleaned"
}

tagged_derived_data_path() {
  local slug="$1"
  echo "$HOME/Library/Developer/Xcode/DerivedData/vmux-${slug}"
}

print_tag_cleanup_reminder() {
  local current_slug="$1"
  local path=""
  local tag=""
  local seen=" "
  local -a stale_tags=()

  while IFS= read -r -d '' path; do
    if [[ "$path" == /tmp/vmux-* ]]; then
      tag="${path#/tmp/vmux-}"
    elif [[ "$path" == "$HOME/Library/Developer/Xcode/DerivedData/vmux-"* ]]; then
      tag="${path#$HOME/Library/Developer/Xcode/DerivedData/vmux-}"
    else
      continue
    fi
    if [[ "$tag" == "$current_slug" ]]; then
      continue
    fi
    # Only surface stale debug tag builds.
    if [[ ! -d "$path/Build/Products/Debug" ]]; then
      continue
    fi
    if [[ "$seen" == *" $tag "* ]]; then
      continue
    fi
    seen="${seen}${tag} "
    stale_tags+=("$tag")
  done < <(
    find /tmp -maxdepth 1 -name 'vmux-*' -print0 2>/dev/null
    find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 1 -type d -name 'vmux-*' -print0 2>/dev/null
  )

  echo
  echo "Tag cleanup status:"
  echo "  current tag: ${current_slug} (keep this running until you verify)"
  if [[ "${#stale_tags[@]}" -eq 0 ]]; then
    echo "  stale tags: none"
    echo "  stale cleanup: not needed"
  else
    echo "  stale tags:"
    for tag in "${stale_tags[@]}"; do
      echo "    - ${tag}"
    done
    echo "Cleanup stale tags only:"
    for tag in "${stale_tags[@]}"; do
      echo "  pkill -f \"vmux DEV ${tag}.app/Contents/MacOS/vmux DEV\""
      echo "  rm -rf \"$(tagged_derived_data_path "$tag")\" \"/tmp/vmux-${tag}\" \"/tmp/vmux-debug-${tag}.sock\""
      echo "  rm -f \"/tmp/vmux-debug-${tag}.log\""
      echo "  rm -f \"$HOME/Library/Application Support/vmux/vmuxd-dev-${tag}.sock\""
    done
  fi
  echo "After you verify current tag, cleanup command:"
  echo "  pkill -f \"vmux DEV ${current_slug}.app/Contents/MacOS/vmux DEV\""
  echo "  rm -rf \"$(tagged_derived_data_path "$current_slug")\" \"/tmp/vmux-${current_slug}\" \"/tmp/vmux-debug-${current_slug}.sock\""
  echo "  rm -f \"/tmp/vmux-debug-${current_slug}.log\""
  echo "  rm -f \"$HOME/Library/Application Support/vmux/vmuxd-dev-${current_slug}.sock\""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="${2:-}"
      if [[ -z "$TAG" ]]; then
        echo "error: --tag requires a value" >&2
        exit 1
      fi
      shift 2
      ;;
    --name)
      APP_NAME="${2:-}"
      if [[ -z "$APP_NAME" ]]; then
        echo "error: --name requires a value" >&2
        exit 1
      fi
      NAME_SET=1
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="${2:-}"
      if [[ -z "$BUNDLE_ID" ]]; then
        echo "error: --bundle-id requires a value" >&2
        exit 1
      fi
      BUNDLE_SET=1
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA="${2:-}"
      if [[ -z "$DERIVED_DATA" ]]; then
        echo "error: --derived-data requires a value" >&2
        exit 1
      fi
      DERIVED_SET=1
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TAG" ]]; then
  echo "error: --tag is required (example: ./scripts/reload.sh --tag fix-sidebar-theme)" >&2
  usage
  exit 1
fi

if [[ -n "$TAG" ]]; then
  TAG_ID="$(sanitize_bundle "$TAG")"
  TAG_SLUG="$(sanitize_path "$TAG")"
  if [[ "$NAME_SET" -eq 0 ]]; then
    APP_NAME="vmux DEV ${TAG}"
  fi
  if [[ "$BUNDLE_SET" -eq 0 ]]; then
    BUNDLE_ID="com.vmuxterm.app.debug.${TAG_ID}"
  fi
  if [[ "$DERIVED_SET" -eq 0 ]]; then
    DERIVED_DATA="$(tagged_derived_data_path "$TAG_SLUG")"
  fi
fi

XCODEBUILD_ARGS=(
  -project GhosttyTabs.xcodeproj
  -scheme vmux
  -configuration Debug
  -destination 'platform=macOS'
)
if [[ -n "$DERIVED_DATA" ]]; then
  XCODEBUILD_ARGS+=(-derivedDataPath "$DERIVED_DATA")
fi
if [[ -z "$TAG" ]]; then
  XCODEBUILD_ARGS+=(
    INFOPLIST_KEY_CFBundleName="$APP_NAME"
    INFOPLIST_KEY_CFBundleDisplayName="$APP_NAME"
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
  )
fi
XCODEBUILD_ARGS+=(build)

XCODE_LOG="/tmp/vmux-xcodebuild-${TAG_SLUG}.log"
xcodebuild "${XCODEBUILD_ARGS[@]}" 2>&1 | tee "$XCODE_LOG" | grep -E '(warning:|error:|fatal:|BUILD FAILED|BUILD SUCCEEDED|\*\* BUILD)' || true
XCODE_EXIT="${PIPESTATUS[0]}"
echo "Full build log: $XCODE_LOG"
if [[ "$XCODE_EXIT" -ne 0 ]]; then
  echo "error: xcodebuild failed with exit code $XCODE_EXIT" >&2
  exit "$XCODE_EXIT"
fi
sleep 0.2

FALLBACK_APP_NAME="$BASE_APP_NAME"
SEARCH_APP_NAME="$APP_NAME"
if [[ -n "$TAG" ]]; then
  SEARCH_APP_NAME="$BASE_APP_NAME"
fi
if [[ -n "$DERIVED_DATA" ]]; then
  APP_PATH="${DERIVED_DATA}/Build/Products/Debug/${SEARCH_APP_NAME}.app"
  if [[ ! -d "${APP_PATH}" && "$SEARCH_APP_NAME" != "$FALLBACK_APP_NAME" ]]; then
    APP_PATH="${DERIVED_DATA}/Build/Products/Debug/${FALLBACK_APP_NAME}.app"
  fi
else
  APP_BINARY="$(
    find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/${SEARCH_APP_NAME}.app/Contents/MacOS/${SEARCH_APP_NAME}" -print0 \
    | xargs -0 /usr/bin/stat -f "%m %N" 2>/dev/null \
    | sort -nr \
    | head -n 1 \
    | cut -d' ' -f2-
  )"
  if [[ -n "${APP_BINARY}" ]]; then
    APP_PATH="$(dirname "$(dirname "$(dirname "$APP_BINARY")")")"
  fi
  if [[ -z "${APP_PATH}" && "$SEARCH_APP_NAME" != "$FALLBACK_APP_NAME" ]]; then
    APP_BINARY="$(
      find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug/${FALLBACK_APP_NAME}.app/Contents/MacOS/${FALLBACK_APP_NAME}" -print0 \
      | xargs -0 /usr/bin/stat -f "%m %N" 2>/dev/null \
      | sort -nr \
      | head -n 1 \
      | cut -d' ' -f2-
    )"
    if [[ -n "${APP_BINARY}" ]]; then
      APP_PATH="$(dirname "$(dirname "$(dirname "$APP_BINARY")")")"
    fi
  fi
fi
if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "${APP_NAME}.app not found in DerivedData" >&2
  exit 1
fi

if [[ -n "${TAG_SLUG:-}" ]]; then
  TMP_COMPAT_DERIVED_LINK="/tmp/vmux-${TAG_SLUG}"
  if [[ "$DERIVED_DATA" != "$TMP_COMPAT_DERIVED_LINK" ]]; then
    ABS_DERIVED_DATA="$(cd "$DERIVED_DATA" && pwd)"
    rm -rf "$TMP_COMPAT_DERIVED_LINK"
    ln -s "$ABS_DERIVED_DATA" "$TMP_COMPAT_DERIVED_LINK"
  fi
fi

if [[ -n "$TAG" && "$APP_NAME" != "$SEARCH_APP_NAME" ]]; then
  TAG_APP_PATH="$(dirname "$APP_PATH")/${APP_NAME}.app"
  rm -rf "$TAG_APP_PATH"
  cp -R "$APP_PATH" "$TAG_APP_PATH"
  INFO_PLIST="$TAG_APP_PATH/Contents/Info.plist"
  if [[ -f "$INFO_PLIST" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$INFO_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleName string $APP_NAME" "$INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$INFO_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $APP_NAME" "$INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$INFO_PLIST" 2>/dev/null \
      || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$INFO_PLIST"
    if [[ -n "${TAG_SLUG:-}" ]]; then
      APP_SUPPORT_DIR="$HOME/Library/Application Support/vmux"
      VMUXD_SOCKET="${APP_SUPPORT_DIR}/vmuxd-dev-${TAG_SLUG}.sock"
      VMUX_SOCKET="/tmp/vmux-debug-${TAG_SLUG}.sock"
      VMUX_DEBUG_LOG="/tmp/vmux-debug-${TAG_SLUG}.log"
      write_last_socket_path "$VMUX_SOCKET"
      echo "$VMUX_DEBUG_LOG" > /tmp/vmux-last-debug-log-path || true
      /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$INFO_PLIST" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Set :LSEnvironment:VMUXD_UNIX_PATH \"${VMUXD_SOCKET}\"" "$INFO_PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :LSEnvironment:VMUXD_UNIX_PATH string \"${VMUXD_SOCKET}\"" "$INFO_PLIST"
      /usr/libexec/PlistBuddy -c "Set :LSEnvironment:VMUX_SOCKET_PATH \"${VMUX_SOCKET}\"" "$INFO_PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :LSEnvironment:VMUX_SOCKET_PATH string \"${VMUX_SOCKET}\"" "$INFO_PLIST"
      /usr/libexec/PlistBuddy -c "Set :LSEnvironment:VMUX_DEBUG_LOG \"${VMUX_DEBUG_LOG}\"" "$INFO_PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :LSEnvironment:VMUX_DEBUG_LOG string \"${VMUX_DEBUG_LOG}\"" "$INFO_PLIST"
      if [[ -S "$VMUXD_SOCKET" ]]; then
        for PID in $(lsof -t "$VMUXD_SOCKET" 2>/dev/null); do
          kill "$PID" 2>/dev/null || true
        done
        rm -f "$VMUXD_SOCKET"
      fi
      if [[ -S "$VMUX_SOCKET" ]]; then
        rm -f "$VMUX_SOCKET"
      fi
    fi
    /usr/bin/codesign --force --sign - --timestamp=none --generate-entitlement-der "$TAG_APP_PATH" >/dev/null 2>&1 || true
  fi
  APP_PATH="$TAG_APP_PATH"
fi

# Ensure any running instance is fully terminated, regardless of DerivedData path.
/usr/bin/osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true
sleep 0.3
if [[ -z "$TAG" ]]; then
  # Non-tag mode: kill any running instance (across any DerivedData path) to avoid socket conflicts.
  pkill -f "/${BASE_APP_NAME}.app/Contents/MacOS/${BASE_APP_NAME}" || true
else
  # Tag mode: only kill the tagged instance; allow side-by-side with the main app.
  pkill -f "${APP_NAME}.app/Contents/MacOS/${BASE_APP_NAME}" || true
fi
sleep 0.3
VMUXD_SRC="$PWD/vmuxd/zig-out/bin/vmuxd"
GHOSTTY_HELPER_SRC="$PWD/ghostty/zig-out/bin/ghostty"
if [[ -d "$PWD/vmuxd" ]]; then
  (cd "$PWD/vmuxd" && zig build -Doptimize=ReleaseFast)
fi
if [[ -d "$PWD/ghostty" ]]; then
  (cd "$PWD/ghostty" && zig build cli-helper -Dapp-runtime=none -Demit-macos-app=false -Demit-xcframework=false -Doptimize=ReleaseFast -Dsentry=false)
fi
if [[ -x "$VMUXD_SRC" ]]; then
  BIN_DIR="$APP_PATH/Contents/Resources/bin"
  mkdir -p "$BIN_DIR"
  cp "$VMUXD_SRC" "$BIN_DIR/vmuxd"
  chmod +x "$BIN_DIR/vmuxd"
fi
if [[ -x "$GHOSTTY_HELPER_SRC" ]]; then
  BIN_DIR="$APP_PATH/Contents/Resources/bin"
  mkdir -p "$BIN_DIR"
  cp "$GHOSTTY_HELPER_SRC" "$BIN_DIR/ghostty"
  chmod +x "$BIN_DIR/ghostty"
fi
CLI_PATH="$APP_PATH/Contents/Resources/bin/vmux"
if [[ -x "$CLI_PATH" ]]; then
  echo "$CLI_PATH" > /tmp/vmux-last-cli-path || true
fi
# Avoid inheriting vmux/ghostty environment variables from the terminal that
# runs this script (often inside another vmux instance), which can cause
# socket and resource-path conflicts.
OPEN_CLEAN_ENV=(
  env
  -u VMUX_SOCKET_PATH
  -u VMUX_TAB_ID
  -u VMUX_PANEL_ID
  -u VMUXD_UNIX_PATH
  -u VMUX_TAG
  -u VMUX_DEBUG_LOG
  -u VMUX_BUNDLE_ID
  -u VMUX_SHELL_INTEGRATION
  -u GHOSTTY_BIN_DIR
  -u GHOSTTY_RESOURCES_DIR
  -u GHOSTTY_SHELL_FEATURES
  # Dev shells (including CI/Codex) often force-disable paging by exporting these.
  # Don't leak that into vmux, otherwise `git diff` won't page even with PAGER=less.
  -u GIT_PAGER
  -u GH_PAGER
  -u TERMINFO
  -u XDG_DATA_DIRS
)

if [[ -n "${TAG_SLUG:-}" && -n "${VMUX_SOCKET:-}" ]]; then
  # Ensure tag-specific socket paths win even if the caller has VMUX_* overrides.
  "${OPEN_CLEAN_ENV[@]}" VMUX_TAG="$TAG_SLUG" VMUX_SOCKET_PATH="$VMUX_SOCKET" VMUXD_UNIX_PATH="$VMUXD_SOCKET" VMUX_DEBUG_LOG="$VMUX_DEBUG_LOG" open -g "$APP_PATH"
elif [[ -n "${TAG_SLUG:-}" ]]; then
  "${OPEN_CLEAN_ENV[@]}" VMUX_TAG="$TAG_SLUG" VMUX_DEBUG_LOG="$VMUX_DEBUG_LOG" open -g "$APP_PATH"
else
  echo "/tmp/vmux-debug.log" > /tmp/vmux-last-debug-log-path || true
  "${OPEN_CLEAN_ENV[@]}" open -g "$APP_PATH"
fi

# Safety: ensure only one instance is running.
sleep 0.2
PIDS=($(pgrep -f "${APP_PATH}/Contents/MacOS/" || true))
if [[ "${#PIDS[@]}" -gt 1 ]]; then
  NEWEST_PID=""
  NEWEST_AGE=999999
  for PID in "${PIDS[@]}"; do
    AGE="$(ps -o etimes= -p "$PID" | tr -d ' ')"
    if [[ -n "$AGE" && "$AGE" -lt "$NEWEST_AGE" ]]; then
      NEWEST_AGE="$AGE"
      NEWEST_PID="$PID"
    fi
  done
  for PID in "${PIDS[@]}"; do
    if [[ "$PID" != "$NEWEST_PID" ]]; then
      kill "$PID" 2>/dev/null || true
    fi
  done
fi

if [[ -n "${TAG_SLUG:-}" ]]; then
  print_tag_cleanup_reminder "$TAG_SLUG"
fi
