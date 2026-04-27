#!/usr/bin/env bash
#
# test-ai-files-skills-add.sh - Test suite for ai-files-skills-add script
#
# This script tests all functionality of the ai-files-skills-add script
# including listing, installing, error handling, and edge cases.
#
# Usage: scripts/test-ai-files-skills-add.sh

set -euo pipefail

#=============================================================================
# TEST CONFIGURATION
#=============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_SCRIPT="${SCRIPT_DIR}/ai-files-skills-add"
TEST_REPO="vercel-labs/agent-skills"
TEMP_BASE="/tmp/ai-files-skills-add-test"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup on exit
cleanup() {
    rm -rf "$TEMP_BASE" 2>/dev/null || true
    # Clean up any test installations in global dir
    rm -rf ~/.claude/skills/web-design-guidelines 2>/dev/null || true
    rm -rf ~/.cache/skills/web-design-guidelines 2>/dev/null || true
}

trap cleanup EXIT

#=============================================================================
# TEST UTILITIES
#=============================================================================

# Print test header
test_header() {
    local name="$1"
    echo ""
    echo "========================================"
    echo "TEST: $name"
    echo "========================================"
}

# Print test result
test_result() {
    local result="$1"
    local message="${2:-}"

    ((TESTS_RUN++)) || true

    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
        ((TESTS_PASSED++)) || true
    else
        echo -e "${RED}✗ FAIL${NC}: $message"
        ((TESTS_FAILED++)) || true
    fi
}

# Create a temporary test directory
create_test_dir() {
    local name="$1"
    local test_dir="${TEMP_BASE}/${name}"
    rm -rf "$test_dir" 2>/dev/null || true
    mkdir -p "$test_dir"
    echo "$test_dir"
}

# Check if file/directory exists
check_exists() {
    local path="$1"
    local type="${2:-any}"  # any, file, dir, symlink
    local result=1

    if [[ ! -e "$path" ]]; then
        return 1
    fi

    case "$type" in
        file)
            [[ -f "$path" ]]
            ;;
        dir)
            [[ -d "$path" ]]
            ;;
        symlink)
            [[ -L "$path" ]]
            ;;
        *)
            result=0
            ;;
    esac

    return $result
}

#=============================================================================
# TEST: Help flag
#=============================================================================

test_help_flag() {
    test_header "Help Flag (--help)"

    local output
    output=$("$MAIN_SCRIPT" --help 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && echo "$output" | grep -q "Usage:"; then
        test_result "PASS" "Help flag displays usage information"
    else
        test_result "FAIL" "Help flag failed (exit code: $exit_code)"
    fi
}

#=============================================================================
# TEST: List available skills
#=============================================================================

test_list_skills() {
    test_header "List Available Skills (--list)"

    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" --list 2>&1)
    exit_code=$?

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        test_result "FAIL" "List command failed with exit code $exit_code"
        return
    fi

    # Check for expected skills in output
    if echo "$output" | grep -q "web-design-guidelines" && \
       echo "$output" | grep -q "vercel-composition-patterns"; then
        test_result "PASS" "List command shows available skills"
    else
        test_result "FAIL" "List command missing expected skills"
    fi
}

#=============================================================================
# TEST: Install specific skill
#=============================================================================

test_install_specific_skill() {
    test_header "Install Specific Skill (--skill)"

    local test_dir
    test_dir=$(create_test_dir "install-specific")
    local original_dir
    original_dir=$(pwd)

    cd "$test_dir" || {
        test_result "FAIL" "Cannot change to test directory"
        return
    }

    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" --skill web-design-guidelines --yes 2>&1)
    exit_code=$?

    cd "$original_dir" || true

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        test_result "FAIL" "Install failed with exit code $exit_code"
        return
    fi

    # Check if skill was installed
    if check_exists "${test_dir}/.claude/skills/web-design-guidelines"; then
        test_result "PASS" "Skill installed successfully"
    else
        test_result "FAIL" "Skill not found at target directory"
    fi
}

#=============================================================================
# TEST: Install invalid skill (error handling)
#=============================================================================

test_install_invalid_skill() {
    test_header "Install Invalid Skill (error handling)"

    local test_dir
    test_dir=$(create_test_dir "install-invalid")
    local original_dir
    original_dir=$(pwd)

    cd "$test_dir" || {
        test_result "FAIL" "Cannot change to test directory"
        return
    }

    local output
    local exit_code
    set +e  # Disable exit on error for this command
    output=$("$MAIN_SCRIPT" "$TEST_REPO" --skill nonexistent-skill --yes 2>&1)
    exit_code=$?
    set -e  # Re-enable exit on error

    cd "$original_dir" || true

    # Check exit code is 5 (EXIT_INVALID_SKILL)
    if [[ $exit_code -eq 5 ]]; then
        test_result "PASS" "Invalid skill returns exit code 5"
    else
        test_result "FAIL" "Expected exit code 5, got $exit_code"
        return
    fi

    # Check error message lists available skills
    if echo "$output" | grep -q "Available skills:" && \
       echo "$output" | grep -q "web-design-guidelines"; then
        test_result "PASS" "Error message lists available skills"
    else
        test_result "FAIL" "Error message doesn't list available skills"
    fi
}

#=============================================================================
# TEST: Install all skills
#=============================================================================

test_install_all_skills() {
    test_header "Install All Skills (--all)"

    local test_dir
    test_dir=$(create_test_dir "install-all")
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir" || { test_result "FAIL" "Cannot change to test directory"; return; }

    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" --all --yes 2>&1)
    exit_code=$?

    cd "$original_dir" || true

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        test_result "FAIL" "Install all failed with exit code $exit_code"
        return
    fi

    # Count installed skills
    local skill_count
    skill_count=$(ls -1 "${test_dir}/.claude/skills/" 2>/dev/null | wc -l)

    if [[ $skill_count -ge 3 ]]; then
        test_result "PASS" "Installed $skill_count skills"
    else
        test_result "FAIL" "Expected at least 3 skills, found $skill_count"
    fi
}

#=============================================================================
# TEST: Install multiple skills
#=============================================================================

test_install_multiple_skills() {
    test_header "Install Multiple Skills"

    local test_dir
    test_dir=$(create_test_dir "install-multiple")
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir" || { test_result "FAIL" "Cannot change to test directory"; return; }

    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" \
        --skill web-design-guidelines \
        --skill vercel-composition-patterns \
        --yes 2>&1)
    exit_code=$?

    cd "$original_dir" || true

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        test_result "FAIL" "Multiple skills install failed with exit code $exit_code"
        return
    fi

    # Count installed skills
    local skill_count
    skill_count=$(ls -1 "${test_dir}/.claude/skills/" 2>/dev/null | wc -l)

    if [[ $skill_count -eq 2 ]]; then
        test_result "PASS" "Installed exactly 2 skills"
    else
        test_result "FAIL" "Expected 2 skills, found $skill_count"
    fi
}

#=============================================================================
# TEST: Wildcard skill selection
#=============================================================================

test_wildcard_skill() {
    test_header "Wildcard Skill Selection (--skill '*')"

    local test_dir
    test_dir=$(create_test_dir "wildcard")
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir" || { test_result "FAIL" "Cannot change to test directory"; return; }

    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" --skill '*' --yes 2>&1)
    exit_code=$?

    cd "$original_dir" || true

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        test_result "FAIL" "Wildcard install failed with exit code $exit_code"
        return
    fi

    # Check that multiple skills were installed
    local skill_count
    skill_count=$(ls -1 "${test_dir}/.claude/skills/" 2>/dev/null | wc -l)

    if [[ $skill_count -ge 3 ]]; then
        test_result "PASS" "Wildcard installed $skill_count skills"
    else
        test_result "FAIL" "Wildcard installed only $skill_count skills"
    fi
}

#=============================================================================
# TEST: Global installation
#=============================================================================

test_global_installation() {
    test_header "Global Installation (-g)"

    # Clean up any existing test skill
    rm -rf ~/.claude/skills/test-global-skill 2>/dev/null || true

    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" \
        --skill web-design-guidelines \
        --global \
        --yes 2>&1)
    exit_code=$?

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        test_result "FAIL" "Global install failed with exit code $exit_code"
        return
    fi

    # Check if skill was installed in global directory
    if check_exists ~/.claude/skills/web-design-guidelines; then
        test_result "PASS" "Skill installed in global directory"
    else
        test_result "FAIL" "Skill not found in global directory"
    fi

    # Clean up
    rm -rf ~/.claude/skills/web-design-guidelines 2>/dev/null || true
    rm -rf ~/.cache/skills/web-design-guidelines 2>/dev/null || true
}

#=============================================================================
# TEST: Copy method installation
#=============================================================================

test_copy_method() {
    test_header "Copy Method Installation (--method copy)"

    local test_dir
    test_dir=$(create_test_dir "copy-method")
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir" || { test_result "FAIL" "Cannot change to test directory"; return; }

    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" \
        --skill web-design-guidelines \
        --method copy \
        --yes 2>&1)
    exit_code=$?

    cd "$original_dir" || true

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        test_result "FAIL" "Copy method failed with exit code $exit_code"
        return
    fi

    # Check if skill was installed as a directory (not symlink)
    local skill_path="${test_dir}/.claude/skills/web-design-guidelines"
    if [[ -d "$skill_path" ]] && [[ ! -L "$skill_path" ]]; then
        test_result "PASS" "Skill installed as directory (copy mode)"
    else
        test_result "FAIL" "Copy mode didn't create a regular directory (symlink=$([ -L "$skill_path" ] && echo yes || echo no), dir=$([ -d "$skill_path" ] && echo yes || echo no))"
    fi
}

#=============================================================================
# TEST: Invalid repository URL
#=============================================================================

test_invalid_repository() {
    test_header "Invalid Repository URL"

    local test_dir
    test_dir=$(create_test_dir "invalid-repo")
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir" || { test_result "FAIL" "Cannot change to test directory"; return; }

    local output
    local exit_code
    set +e
    output=$("$MAIN_SCRIPT" this-repo-does-not-exist-12345/fake --list 2>&1)
    exit_code=$?
    set -e

    cd "$original_dir" || true

    # Check exit code is 4 (EXIT_NETWORK)
    if [[ $exit_code -eq 4 ]]; then
        test_result "PASS" "Invalid repository returns exit code 4"
    else
        test_result "FAIL" "Expected exit code 4, got $exit_code"
    fi

    # Check error message
    if echo "$output" | grep -q "Unable to clone repository"; then
        test_result "PASS" "Error message shows clone failure"
    else
        test_result "FAIL" "Error message doesn't show clone failure"
    fi
}

#=============================================================================
# TEST: Mutual exclusion of --all and --skill
#=============================================================================

test_mutual_exclusion() {
    test_header "Mutual Exclusion (--all and --skill)"

    local output
    local exit_code
    set +e
    output=$("$MAIN_SCRIPT" "$TEST_REPO" --all --skill web-design-guidelines 2>&1)
    exit_code=$?
    set -e

    # Check exit code is 2 (EXIT_ERROR)
    if [[ $exit_code -eq 2 ]]; then
        test_result "PASS" "Mutual exclusion returns exit code 2"
    else
        test_result "FAIL" "Expected exit code 2, got $exit_code"
        return
    fi

    # Check error message
    if echo "$output" | grep -q "mutually exclusive"; then
        test_result "PASS" "Error message mentions mutual exclusion"
    else
        test_result "FAIL" "Error message doesn't mention mutual exclusion"
    fi
}

#=============================================================================
# TEST: Missing repository argument
#=============================================================================

test_missing_repository() {
    test_header "Missing Repository Argument"

    local output
    local exit_code
    set +e
    output=$("$MAIN_SCRIPT" --list 2>&1)
    exit_code=$?
    set -e

    # Check exit code is 2 (EXIT_ERROR)
    if [[ $exit_code -eq 2 ]]; then
        test_result "PASS" "Missing repository returns exit code 2"
    else
        test_result "FAIL" "Expected exit code 2, got $exit_code"
        return
    fi

    # Check error message
    if echo "$output" | grep -q "required"; then
        test_result "PASS" "Error message mentions requirement"
    else
        test_result "FAIL" "Error message doesn't mention requirement"
    fi
}

#=============================================================================
# TEST: Symlink fallback to copy
#=============================================================================

test_symlink_fallback() {
    test_header "Symlink Mode (default)"

    local test_dir
    test_dir=$(create_test_dir "symlink-default")
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir" || { test_result "FAIL" "Cannot change to test directory"; return; }

    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" \
        --skill web-design-guidelines \
        --yes 2>&1)
    exit_code=$?

    cd "$original_dir" || true

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        test_result "FAIL" "Symlink mode failed with exit code $exit_code"
        return
    fi

    # Check if skill was installed (symlink or directory is fine)
    if check_exists "${test_dir}/.claude/skills/web-design-guidelines"; then
        test_result "PASS" "Skill installed successfully"
    else
        test_result "FAIL" "Skill not found at target directory"
    fi
}

#=============================================================================
# TEST: Already installed skill (non-interactive skip)
#=============================================================================

test_already_installed_skip() {
    test_header "Already Installed Skill (non-interactive skip)"

    local test_dir
    test_dir=$(create_test_dir "already-installed")
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir" || { test_result "FAIL" "Cannot change to test directory"; return; }

    # Install first time
    "$MAIN_SCRIPT" "$TEST_REPO" --skill web-design-guidelines --yes > /dev/null 2>&1

    # Install second time (should skip)
    local output
    local exit_code
    output=$("$MAIN_SCRIPT" "$TEST_REPO" --skill web-design-guidelines --yes 2>&1)
    exit_code=$?

    cd "$original_dir" || true

    # Check exit code
    if [[ $exit_code -eq 0 ]]; then
        test_result "PASS" "Re-install succeeds with exit code 0"
    else
        test_result "FAIL" "Re-install failed with exit code $exit_code"
        return
    fi

    # Check for skip message
    if echo "$output" | grep -q "Skipping"; then
        test_result "PASS" "Output shows skip message"
    else
        test_result "FAIL" "Output doesn't show skip message"
    fi
}

#=============================================================================
# TEST: Verify script is executable
#=============================================================================

test_script_executable() {
    test_header "Script Executable Permission"

    if [[ -x "$MAIN_SCRIPT" ]]; then
        test_result "PASS" "Script has executable permission"
    else
        test_result "FAIL" "Script lacks executable permission"
    fi
}

#=============================================================================
# TEST: Verify shebang and bash strict mode
#=============================================================================

test_script_strict_mode() {
    test_header "Script Strict Mode"

    local first_line
    first_line=$(head -1 "$MAIN_SCRIPT")

    if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
        test_result "PASS" "Script has proper shebang"
    else
        test_result "FAIL" "Script missing proper shebang"
        return
    fi

    if grep -q "set -euo pipefail" "$MAIN_SCRIPT"; then
        test_result "PASS" "Script has strict mode enabled"
    else
        test_result "FAIL" "Script missing strict mode"
    fi
}

#=============================================================================
# TEST: Verify function documentation
#=============================================================================

test_function_documentation() {
    test_header "Function Documentation"

    # Check for key section headers and comments
    local sections=(
        "SKILL DISCOVERY"
        "SKILL INSTALLATION"
        "ERROR HANDLING"
        "GIT CLONE"
        "URL NORMALIZATION"
    )

    local missing_docs=0
    for section in "${sections[@]}"; do
        if ! grep -q "#*$section" "$MAIN_SCRIPT"; then
            ((missing_docs++)) || true
        fi
    done

    if [[ $missing_docs -eq 0 ]]; then
        test_result "PASS" "All sections have documentation headers"
    else
        test_result "FAIL" "$missing_docs sections missing documentation"
    fi
}

#=============================================================================
# MAIN TEST RUNNER
#=============================================================================

main() {
    echo ""
    echo "========================================"
    echo "ai-files-skills-add TEST SUITE"
    echo "========================================"
    echo "Testing: $MAIN_SCRIPT"
    echo "Test Repository: $TEST_REPO"
    echo "Test Base: $TEMP_BASE"

    # Verify main script exists
    if [[ ! -f "$MAIN_SCRIPT" ]]; then
        echo -e "${RED}ERROR: Main script not found: $MAIN_SCRIPT${NC}"
        exit 1
    fi

    # Run all tests
    test_script_executable
    test_script_strict_mode
    test_function_documentation
    test_help_flag
    test_list_skills
    test_install_specific_skill
    test_install_invalid_skill
    test_install_all_skills
    test_install_multiple_skills
    test_wildcard_skill
    test_global_installation
    test_copy_method
    test_symlink_fallback
    test_already_installed_skip
    test_invalid_repository
    test_mutual_exclusion
    test_missing_repository

    # Print summary
    echo ""
    echo "========================================"
    echo "TEST SUMMARY"
    echo "========================================"
    echo "Tests Run:    $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    else
        echo -e "Tests Failed: $TESTS_FAILED"
    fi
    echo "========================================"

    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}ALL TESTS PASSED${NC}"
        exit 0
    else
        echo -e "${RED}SOME TESTS FAILED${NC}"
        exit 1
    fi
}

# Run main function
main "$@"
