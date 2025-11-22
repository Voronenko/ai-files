#!/bin/bash

# update.sh - Copy contents from ai-files/dist/ to git repo's .ai-files/ directory
# This script can be executed from any directory within a git repository
# Rules:
# - Copy recursive contents of all folders except .specify
# - For .specify folder, only copy files that don't exist yet (preserve local modifications)
# - Auto-detects git repository root and creates .ai-files/ there

set -euo pipefail  # Exit on errors, undefined variables, and pipe failures

# Source directory - will be overridden by DIST_DIR environment variable if set
SOURCE_DIR="${DIST_DIR:-$HOME/ai-files/dist}"
TARGET_DIR=".ai-files"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to detect git repository root
detect_git_root() {
    local current_dir="$(pwd)"

    # Traverse up to find git repository root
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done

    return 1
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Update .ai-files/ directory in current git repository from ai-files distribution.

Options:
    -h, --help          Show this help message
    -s, --source DIR    Specify source directory (default: \$HOME/ai-files/dist)
    -v, --verbose       Enable verbose output
    --dry-run          Show what would be copied without actually copying

Environment Variables:
    DIST_DIR           Source directory override (same as --source)

Examples:
    $(basename "$0")                    # Use default source directory
    $(basename "$0") -s /path/to/dist   # Use custom source directory
    $(basename "$0") --dry-run          # Preview changes only

EOF
}

# Parse command line arguments
VERBOSE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -s|--source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo "🔄 Updating .ai-files/ in git repository from $SOURCE_DIR..."

# Detect git repository root
GIT_ROOT=$(detect_git_root)
if [[ $? -ne 0 ]]; then
    print_error "Not in a git repository! This script must be run within a git repository."
    exit 1
fi

print_info "Git repository root detected: $GIT_ROOT"
cd "$GIT_ROOT"

# Check if source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    print_error "Source directory $SOURCE_DIR does not exist!"
    print_info "Please ensure ai-files distribution is available or specify custom source with --source"
    exit 1
fi

# Create target directory if it doesn't exist
TARGET_FULL_PATH="$GIT_ROOT/$TARGET_DIR"
if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$TARGET_FULL_PATH"
fi

# Function to copy directory recursively
copy_recursive() {
    local src="$1"
    local dest="$2"

    if [[ ! -d "$src" ]]; then
        return 0
    fi

    local dir_name=$(basename "$src")
    print_info "Processing directory: $dir_name"

    if [[ "$VERBOSE" == "true" ]]; then
        print_info "  Source: $src"
        print_info "  Destination: $dest"
    fi

    # Create destination directory if needed
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$dest"
    fi

    # Copy all files and subdirectories
    file_count=0
    find "$src" -type f | while read -r src_file; do
        rel_path="${src_file#$src/}"
        dest_file="$dest/$rel_path"

        # Create destination subdirectory if needed
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$(dirname "$dest_file")"
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  📄 Would copy: $rel_path"
        else
            if [[ "$VERBOSE" == "true" ]]; then
                echo "  📄 Copying: $rel_path"
            fi
            cp "$src_file" "$dest_file"
        fi
        file_count=$((file_count + 1))
    done

    if [[ "$DRY_RUN" == "false" && "$VERBOSE" == "true" ]]; then
        print_success "  Copied directory: $dir_name"
    elif [[ "$DRY_RUN" == "true" ]]; then
        print_warning "  Would copy directory: $dir_name"
    fi
}

# Function to copy only non-existing files (for .specify directory)
copy_non_existing() {
    local src="$1"
    local dest="$2"

    if [[ ! -d "$src" ]]; then
        return 0
    fi

    local dir_name=$(basename "$src")
    print_info "Processing .specify directory: $dir_name"

    if [[ "$VERBOSE" == "true" ]]; then
        print_info "  Source: $src"
        print_info "  Destination: $dest"
    fi

    # Create destination directory if needed
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$dest"
    fi

    copied_count=0
    skipped_count=0

    # Find all files in source and copy only if they don't exist in destination
    find "$src" -type f | while read -r src_file; do
        rel_path="${src_file#$src/}"
        dest_file="$dest/$rel_path"

        # Create destination subdirectory if needed
        if [[ "$DRY_RUN" == "false" ]]; then
            mkdir -p "$(dirname "$dest_file")"
        fi

        # Copy only if destination file doesn't exist
        if [[ ! -f "$dest_file" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "  ✅ Would add new file: $rel_path"
            else
                if [[ "$VERBOSE" == "true" ]]; then
                    echo "  ✅ Adding new file: $rel_path"
                fi
                cp "$src_file" "$dest_file"
            fi
            copied_count=$((copied_count + 1))
        else
            if [[ "$VERBOSE" == "true" ]]; then
                echo "  ⏭️  Skipping existing file: $rel_path"
            fi
            skipped_count=$((skipped_count + 1))
        fi
    done

    if [[ "$DRY_RUN" == "false" ]]; then
        print_success "  .specify directory processed (preserving existing local files)"
    fi
}

# Statistics
TOTAL_DIRS=0
PROCESSED_DIRS=0
SKIPPED_DIRS=0

# Process each directory in dist (including hidden directories)
# Use a simple for loop with proper quoting to handle all directories

# Change to source directory to make path handling easier
cd "$SOURCE_DIR"

# Process all directories except . and ..
for dir_path in * .*; do
    # Skip . and .. and any non-directory
    if [[ "$dir_path" == "." || "$dir_path" == ".." || ! -d "$dir_path" ]]; then
        continue
    fi

    dir_name="$dir_path"
    TOTAL_DIRS=$((TOTAL_DIRS + 1))

    case "$dir_name" in
        ".specify")
            # Special handling for .specify - only copy non-existing files
            copy_non_existing "$SOURCE_DIR/$dir_name" "$TARGET_FULL_PATH/.specify"
            PROCESSED_DIRS=$((PROCESSED_DIRS + 1))
            ;;
        ".ai-files")
            # Skip .ai-files to avoid circular copying
            print_warning "Skipping .ai-files directory to avoid conflicts"
            SKIPPED_DIRS=$((SKIPPED_DIRS + 1))
            ;;
        *)
            # Copy all other directories recursively
            copy_recursive "$SOURCE_DIR/$dir_name" "$TARGET_FULL_PATH/$dir_name"
            PROCESSED_DIRS=$((PROCESSED_DIRS + 1))
            ;;
    esac
done

# Change back to git root
cd "$GIT_ROOT"

# Final summary
echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    print_warning "DRY RUN COMPLETED - No files were actually copied"
else
    print_success "Update completed successfully!"
fi

echo "📂 Source: $SOURCE_DIR"
echo "📂 Target: $TARGET_FULL_PATH"
echo ""
echo "📋 Summary:"
echo "   • Total directories found: $TOTAL_DIRS"
echo "   • Directories processed: $PROCESSED_DIRS"
echo "   • Directories skipped: $SKIPPED_DIRS"
echo ""
echo "📝 Rules applied:"
echo "   • All directories (except .specify and .ai-files) copied recursively"
echo "   • .specify files copied only if they don't already exist (preserving local modifications)"
echo "   • .ai-files directory skipped to avoid circular copying"

if [[ "$DRY_RUN" == "false" ]]; then
    print_info "You can now use the updated .ai-files/ in your git repository"
else
    print_info "Run without --dry-run to actually copy the files"
fi

# Exit successfully
exit 0