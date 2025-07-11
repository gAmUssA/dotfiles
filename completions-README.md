# Shell Completion Management

This directory contains an automated shell completion management system for various CLI tools.

## Files

- `install-completions.sh` - Main completion installation script

## How it works

The `install-completions.sh` script automatically:

1. **Detects available CLI tools** on your system
2. **Generates completion files** for each tool in `~/.zfunc/`
3. **Avoids duplicates** by checking if files exist and are recent (< 30 days)
4. **Logs activity** to `~/.completion-install.log`
5. **Runs in background** when shell starts (via .zshrc)

## Supported Tools

The script supports completions for:

- **deck** - GitOps tool
- **kind** - Kubernetes in Docker
- **kumactl** - Kuma service mesh
- **minikube** - Local Kubernetes
- **skaffold** - Kubernetes development
- **confluent** - Confluent Cloud CLI
- **kubectl** - Kubernetes CLI
- **helm** - Kubernetes package manager
- **docker** - Container platform
- **gh** - GitHub CLI
- **terraform** - Infrastructure as Code
- **aws** - AWS CLI

## Manual Usage

You can run the completion installer manually:

```bash
# Install/update all completions
~/projects/dotfiles/install-completions.sh

# Check what was installed
ls -la ~/.zfunc/

# View installation log
cat ~/.completion-install.log
```

## Adding New Tools

To add a new CLI tool completion:

1. Edit `install-completions.sh`
2. Add the tool to the `tools` array in format: `"tool_name:completion_command"`
3. Example: `"newtool:newtool completion zsh"`

## Troubleshooting

If completions aren't working:

1. **Reload completions**: `autoload -U compinit && compinit`
2. **Check fpath**: `echo $fpath | grep zfunc`
3. **Verify files**: `ls -la ~/.zfunc/`
4. **Check logs**: `cat ~/.completion-install.log`

## Performance

- Runs in background to avoid slowing shell startup
- Checks file age to avoid unnecessary regeneration
- Skips tools that aren't installed
- Lightweight and fast execution