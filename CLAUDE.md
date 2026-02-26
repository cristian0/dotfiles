# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository containing shell configuration, aliases, functions, and environment setup for macOS development. The repository provides a collection of bash configurations, vim setup, and installation scripts for bootstrapping a new machine.

**Key points:**
- This is a personal dotfiles repo maintained primarily for the owner's use
- The repo follows the pattern established by [mathias's dotfiles](https://github.com/mathiasbynens/dotfiles/) and [alrra's fork](https://github.com/alrra/dotfiles/)
- All files in the root are configuration files (prefixed with `.`) or setup scripts
- The `.vim/` directory contains Vim configuration and plugins
- The `bin/` directory contains executable utilities

## Common Development Tasks

### Quick commands for daily use

- **Reload shell config** (without restarting terminal):
  ```bash
  reload  # Alias that executes exec ${SHELL} -l
  ```

- **Edit and reload config**:
  ```bash
  $EDITOR ~/.aliases
  reload
  ```

### Setting up on a new machine

1. **Fork and clone** the repository to your machine
2. **Run setup script** (selectively):
   ```bash
   ./setup-a-new-machine.sh
   ```
   This script is designed to be run in sections, not all at once. Review and copy-paste commands as needed.

3. **Create symlinks** for all dotfiles:
   ```bash
   ./symlink-setup.sh
   ```
   This script interactively symlinks all dotfiles from the repo into your home directory. It will prompt you if files already exist.

4. **Configure git** locally:
   - Create `~/.gitconfig.local` with your user details (never commit this):
     ```ini
     [user]
         name = Your Name
         email = your.email@example.com
     ```

5. **Install Homebrew packages** (after reviewing):
   ```bash
   ./brew.sh
   ```

6. **Load z (jump around)** - this is referenced in `.bash_profile` but requires initial learning:
   - Navigate around your filesystem normally
   - The `z` utility learns from your cd history
   - See [z repository](https://github.com/rupa/z) for details

7. **Create `.extra`** file for local-only configuration:
   ```bash
   touch ~/.extra && $EDITOR $_
   ```
   This file is gitignored and can contain personal exports, PATH customizations, and local aliases/functions.

### Editing configurations

- **Shell aliases**: Edit [`.aliases`](.aliases) - they're loaded automatically by `.bash_profile`
- **Shell functions**: Edit [`.functions`](.functions) - they're loaded automatically by `.bash_profile`
- **Environment variables**: Edit [`.exports`](.exports) - they're loaded automatically by `.bash_profile`
- **Prompt/colors**: Edit [`.bash_prompt`](.bash_prompt) - customizes the shell prompt appearance
- **Vim configuration**: Edit [`.vimrc`](.vimrc)
- **Private configuration**: Edit `~/.extra` (local file, not committed) - for machine-specific settings

### Applying OS X defaults

The [`.osx`](.osx) script contains sensible defaults for macOS. Review it before running:
```bash
./.osx
```

This sets preferences for Finder, Safari, system services, and more. Always review before executing as it modifies system settings.

## Architecture & Structure

### Shell Configuration Loading Order

When bash starts, `.bash_profile` sources files in this order:
1. `~/.extra` (optional, user-created, for sensitive/machine-specific config)
2. `~/.bash_prompt` (PS1 and prompt customization)
3. `~/.exports` (environment variables)
4. `~/.aliases` (command aliases)
5. `~/.functions` (bash functions)
6. `~/.secret` and `~/.dc` (optional, if they exist)

This layering allows:
- Core reusable configs in repo (exported/aliases/functions)
- Machine-specific overrides in `~/.extra`
- Private/sensitive info in `~/.secret` (gitignored)

### Readline Configuration (.inputrc)

The [`.inputrc`](.inputrc) file enhances bash prompt behavior with:
- **Tab completion**: Unlimited tab completion without "Display all 1745 possibilities?" prompt
- **Case-insensitive completion**: Type `cat <TAB>` to complete filenames regardless of case
- **History search**: Type `cat <UP>` to cycle through previous `cat` commands (prefix search)
- **Intelligent navigation**: Readline shortcuts for moving and editing on the command line

No additional setup needed—it's automatically loaded by bash.

### Key Features

**Navigation shortcuts:**
- `z <pattern>` - Jump to any directory you've visited (learns from history)
- `..`, `...`, `....`, `.....` - Quick navigation up directory levels
- `cdf` - Change to directory open in Finder

**Useful functions in `.functions`:**
- `mkd <path>` - Create directory and cd into it
- `targz <path>` - Create compressed tar.gz with smart compression (zopfli > pigz > gzip)
- `fs <path>` - Show file or directory size
- `server [port]` - Start simple HTTP server (default port 8000)
- `tre` - Tree view with colors, git/node_modules ignored
- `getcertnames <domain>` - Show SSL certificate details
- `dataurl <file>` - Convert file to data URL

**Aliases overview:**
- **Navigation**: `..`, `...`, `....` etc.
- **Git**: `g` (git), `gs` (git status)
- **Network**: `ip`, `localip`, `ips`, `dig`, `airport`
- **Utilities**: `cleanup` (remove .DS_Store), `emptytrash`, `show/hide` (hidden files)
- **macOS-specific**: `afk`, `chromekill`, `updateall`

### File Categories

**Automatic config files** (don't edit directly unless updating repo):
- `.ackrc` - ack/grep configuration
- `.inputrc` - readline prompt behavior
- `.bashrc` - minimal, just redirects to bash_profile

**Shell environment** (main files to edit):
- `.aliases` - command shortcuts
- `.bash_profile` - main entry point, loads other files
- `.bash_prompt` - PS1 customization
- `.exports` - environment variables (PATH, HISTSIZE, etc.)
- `.functions` - reusable bash functions

**Setup scripts** (run manually, don't edit unless improving):
- `setup-a-new-machine.sh` - Interactive guide for new machine setup
- `symlink-setup.sh` - Creates symlinks for all dotfiles (interactive)
- `.osx` - Applies sensible macOS defaults
- `brew.sh` - Installs Homebrew packages

**Git config**:
- `.gitconfig` - Global git settings
- `.gitconfig.local` - Local user config (create manually, not in repo)
- `.gitattributes` - Git attributes

### Important Notes

- `~/.extra` is gitignored and should contain all machine-specific/sensitive config
- `.gitconfig.local` is where to put your user credentials (gitignored)
- `~/.dc` - Optional local-only file sourced after functions (purpose: machine-specific setup if needed)
- The `.osx` script modifies system settings - always review before running
- When adding new config, prefer [`.aliases`](.aliases) for simple commands or [`.functions`](.functions) for more complex scripts
- Modifications to shell configuration take effect on next shell restart or after running `reload` alias

## Dependencies

**Required tools** (installed via `brew.sh`):
- bash (typically 4+ for modern syntax)
- git
- curl/wget for downloading
- grc (generic colouriser, optional but recommended)

**Optional tools that enhance functionality:**
- `z` - directory jumping utility (must be cloned to `~/proj/z/` and sourced in `.bash_profile`)
- `tree` - used by `tre` function
- Compression tools: `zopfli`, `pigz`, or `gzip`
- `openssh` (usually pre-installed)

## Version Management

The repo includes configuration for:
- **nvm** - Node version management (loaded in `.bash_profile`)
- **pyenv** - Python version management (loaded in `.bash_profile`)
- **ruby** - Homebrew-installed Ruby path included

Check `.bash_profile` for initialization of these tools.

## Troubleshooting

**z (jump) not working**: The `z` utility learns from cd history. After initial setup, navigate normally for 10-20 cd commands before expecting smart jumps. You can also copy an existing `.z` file if migrating machines.

**Completions not working**: Run `reload` to source updated `.bash_profile`. If using bash < 4, some completions may not work—check bash version with `echo $BASH_VERSION`.

**Symlinks failed**: If `symlink-setup.sh` fails on existing dotfiles, the script prompts for confirmation. Choose 'y' to overwrite or 'n' to keep existing files, then rerun for others.

**SSH completion not appearing**: Ensure `~/.ssh/config` exists and has `Host` entries. Run `reload` after adding new hosts.
