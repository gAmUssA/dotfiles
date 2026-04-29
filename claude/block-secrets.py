#!/usr/bin/env python3
"""
PreToolUse hook — block Claude from reading/editing/writing sensitive files.

Wired into claude/settings.json as a PreToolUse hook on Read|Edit|Write|Bash.
Matters most when running with --dangerously-skip-permissions (the `yolo`
alias in zsh_custom/aliases.zsh): yolo mode lets Claude move fast, this hook
makes sure the fast path doesn't include reading ~/.aws/credentials or .env.

Returns a Claude Code hook JSON response with permissionDecision: deny when
a tool call hits a sensitive pattern. Allows .env.example/.sample/.template.

Vendored and lightly adapted from
https://github.com/c4snipes/iterm2-claude-integration (MIT, hooks-examples/).
"""
import json
import sys
import os
import re

# Sensitive file patterns
SENSITIVE_EXACT = {
    ".env",
    ".env.local",
    ".env.development",
    ".env.production",
    ".env.staging",
    ".secrets",
    ".secret",
    "secrets.json",
    "secrets.yaml",
    "secrets.yml",
    "credentials.json",
    "credentials.yaml",
    "credentials.yml",
    "service-account.json",
    "id_rsa",
    "id_ed25519",
    "id_ecdsa",
    "id_dsa",
    ".npmrc",
    ".pypirc",
    ".netrc",
    ".aws/credentials",
    ".aws/config",
}

SENSITIVE_EXTENSIONS = {
    ".pem",
    ".key",
    ".p12",
    ".pfx",
    ".jks",
    ".keystore",
    ".crt",
    ".cer",
}

SENSITIVE_PATTERNS = [
    r"\.env\.",           # .env.anything
    r"secret",            # Contains 'secret'
    r"credential",        # Contains 'credential'
    r"/secrets/",         # In secrets directory
    r"api[_-]?key",       # API key files
    r"private[_-]?key",   # Private key files
    r"\.kube/config",     # Kubernetes config
]

# Allowed exceptions (templates, examples — not real secrets)
ALLOWED_PATTERNS = [
    r"\.env\.example",
    r"\.env\.sample",
    r"\.env\.template",
    r"secrets\.example",
]


def is_allowed(file_path: str) -> bool:
    path_lower = file_path.lower()
    for pattern in ALLOWED_PATTERNS:
        if re.search(pattern, path_lower):
            return True
    return False


def is_sensitive_file(file_path: str) -> tuple[bool, str]:
    if not file_path:
        return False, ""

    if is_allowed(file_path):
        return False, ""

    path_lower = file_path.lower()
    basename = os.path.basename(file_path).lower()

    if basename in SENSITIVE_EXACT:
        return True, f"File '{basename}' is a known sensitive file"

    for exact in SENSITIVE_EXACT:
        if exact in path_lower:
            return True, f"Path contains sensitive file pattern '{exact}'"

    for ext in SENSITIVE_EXTENSIONS:
        if path_lower.endswith(ext):
            return True, f"File has sensitive extension '{ext}'"

    for pattern in SENSITIVE_PATTERNS:
        if re.search(pattern, path_lower):
            return True, f"Path matches sensitive pattern '{pattern}'"

    return False, ""


def extract_file_path(tool_input: dict) -> str:
    for field in ["file_path", "path", "filepath", "file"]:
        if field in tool_input:
            return tool_input[field]
    if "command" in tool_input:
        return tool_input["command"]
    return ""


def check_bash_command(command: str) -> tuple[bool, str]:
    """Block shell commands that try to leak secrets via cat/grep/printenv/etc."""
    read_patterns = [
        r"cat\s+.*\.env",
        r"less\s+.*\.env",
        r"more\s+.*\.env",
        r"head\s+.*\.env",
        r"tail\s+.*\.env",
        r"grep\s+.*\.env",
        r"cat\s+.*secret",
        r"cat\s+.*credential",
        r"echo\s+\$[A-Z_]*KEY",
        r"echo\s+\$[A-Z_]*SECRET",
        r"echo\s+\$[A-Z_]*TOKEN",
        r"echo\s+\$[A-Z_]*PASSWORD",
        r"printenv\s+.*KEY",
        r"printenv\s+.*SECRET",
    ]

    for pattern in read_patterns:
        if re.search(pattern, command, re.IGNORECASE):
            return True, "Command attempts to read sensitive data"

    return False, ""


def deny(reason: str) -> None:
    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }
    print(json.dumps(output))
    sys.exit(0)


def main() -> None:
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        # Allow on parse failure rather than block legitimate work
        print(f"block-secrets: parse error: {e}", file=sys.stderr)
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # File-based tools: Read/Edit/Write/MultiEdit
    if tool_name in {"Read", "Edit", "Write", "MultiEdit"}:
        file_path = extract_file_path(tool_input)
        is_sensitive, reason = is_sensitive_file(file_path)
        if is_sensitive:
            deny(f"Blocked: {reason}. Use a *.example/*.sample/*.template instead.")

    # Bash commands that try to leak secrets
    if tool_name == "Bash":
        command = tool_input.get("command", "")
        is_sensitive, reason = check_bash_command(command)
        if is_sensitive:
            deny(f"Blocked: {reason}. Don't access secrets via shell.")

    sys.exit(0)


if __name__ == "__main__":
    main()
