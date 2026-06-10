#!/usr/bin/env zsh

# Robust completion installation script
# This script automatically installs shell completions for various CLI tools

set -uo pipefail

# Quick exit if no tools are available
if ! command -v deck &> /dev/null && ! command -v kubectl &> /dev/null && ! command -v confluent &> /dev/null && ! command -v quarkus &> /dev/null; then
    # If none of the major tools are available, exit quickly
    exit 0
fi

# Configuration
COMPLETION_DIR="$HOME/.zfunc"
LOG_FILE="$HOME/.completion-install.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Print colored output
print_status() {
    local color=$1
    local message=$2
    if [[ -t 1 ]]; then  # Only use colors if outputting to a terminal
        echo -e "${color}${message}${NC}"
    else
        echo "$message"
    fi
    log "$message"
}

# Create completion directory if it doesn't exist
create_completion_dir() {
    if [[ ! -d "$COMPLETION_DIR" ]]; then
        mkdir -p "$COMPLETION_DIR"
        print_status "$GREEN" "✓ Created completion directory: $COMPLETION_DIR"
    fi
}

# Install completion for a single tool
install_completion() {
    local tool=$1
    local completion_command=$2
    local completion_file="$COMPLETION_DIR/_$tool"
    
    # Check if tool is available
    if ! command -v "$tool" &> /dev/null; then
        print_status "$YELLOW" "⚠ $tool not found, skipping completion"
        return 0
    fi
    
    # Check if completion file already exists and is recent (less than 30 days old)
    if [[ -f "$completion_file" ]]; then
        local file_age=$(( $(date +%s) - $(stat -f %m "$completion_file" 2>/dev/null || echo 0) ))
        if [[ $file_age -lt 2592000 ]]; then  # 30 days in seconds
            print_status "$BLUE" "→ $tool completion is up to date"
            return 0
        fi
    fi
    
    # Generate completion
    print_status "$BLUE" "→ Installing completion for $tool..."
    
    if eval "$completion_command" > "$completion_file" 2>/dev/null; then
        print_status "$GREEN" "✓ Installed completion for $tool"
    else
        print_status "$RED" "✗ Failed to install completion for $tool"
        rm -f "$completion_file"  # Clean up failed attempt
        return 1
    fi
}

# Main installation function
main() {
    local start_time=$(date +%s)
    print_status "$BLUE" "Starting completion installation..."
    
    create_completion_dir
    
    # Define tools and their completion commands
    # Format: "tool_name:completion_command"
    local tools=(
        "deck:deck completion zsh"
        "kind:kind completion zsh"
        "kumactl:kumactl completion zsh"
        "minikube:minikube completion zsh"
        "skaffold:skaffold completion zsh"
        "confluent:confluent completion zsh"
        "kubectl:kubectl completion zsh"
        "helm:helm completion zsh"
        "docker:docker completion zsh"
        "gh:gh completion -s zsh"
        "just:just --completions zsh"
        "terraform:terraform -install-autocomplete"
        "aws:aws_completer"
        "quarkus:quarkus completion"
    )
    
    local success_count=0
    local total_count=${#tools[@]}
    
    for tool_spec in "${tools[@]}"; do
        local tool="${tool_spec%%:*}"
        local command="${tool_spec#*:}"
        
        # Special handling for some tools
        case "$tool" in
            "terraform")
                if command -v terraform &> /dev/null; then
                    if terraform -install-autocomplete 2>/dev/null; then
                        print_status "$GREEN" "✓ Installed completion for terraform"
                        ((success_count++))
                    else
                        print_status "$YELLOW" "⚠ terraform completion may already be installed"
                    fi
                fi
                ;;
            "aws")
                # AWS CLI v2 ships its own completer. The correct setup is
                # `complete -C aws_completer aws` in your .zshrc (via
                # bashcompinit), NOT a generated _aws compdef file.
                # We skip this entry — leave it to the shell rc to wire up.
                if command -v aws &> /dev/null && command -v aws_completer &> /dev/null; then
                    print_status "$BLUE" "→ aws: use 'complete -C aws_completer aws' in .zshrc"
                fi
                ;;
            "quarkus")
                # `quarkus completion` emits a picocli/bash-format script
                # (uses `complete -F _complete_quarkus`), not a zsh #compdef
                # file. Write it with a .bash suffix so zsh doesn't try to
                # autoload it as a completion function; .zshrc sources it
                # after bashcompinit.
                if command -v quarkus &> /dev/null; then
                    local quarkus_file="$COMPLETION_DIR/quarkus_completion.bash"
                    if [[ -f "$quarkus_file" ]]; then
                        local file_age=$(( $(date +%s) - $(stat -f %m "$quarkus_file" 2>/dev/null || echo 0) ))
                        if [[ $file_age -lt 2592000 ]]; then
                            print_status "$BLUE" "→ quarkus completion is up to date"
                            ((success_count++))
                            continue
                        fi
                    fi
                    print_status "$BLUE" "→ Installing completion for quarkus..."
                    if quarkus completion > "$quarkus_file" 2>/dev/null; then
                        print_status "$GREEN" "✓ Installed completion for quarkus"
                        ((success_count++))
                    else
                        print_status "$RED" "✗ Failed to install completion for quarkus"
                        rm -f "$quarkus_file"
                    fi
                else
                    print_status "$YELLOW" "⚠ quarkus not found, skipping completion"
                fi
                ;;
            *)
                if install_completion "$tool" "$command"; then
                    ((success_count++))
                fi
                ;;
        esac
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    print_status "$GREEN" "Completion installation finished: $success_count/$total_count tools (${duration}s)"
    
    # Suggest reloading completions
    if [[ $success_count -gt 0 ]]; then
        print_status "$YELLOW" "💡 Run 'autoload -U compinit && compinit' to reload completions"
    fi
}

# Run main function
main "$@"