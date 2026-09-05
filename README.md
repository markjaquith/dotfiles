# Mark Jaquith's Dotfiles

These are [@markjaquith][mj]'s dotfiles. They are for Mark. You can use them for inspiration if you want, but they are for Mark.

They will change drastically over time, often suddenly, and without warning.

## Philosophy

- Dotfiles should be stored in `~/dotfiles`
- Files under `~/dotfiles/home` should mirror the home directory ([GNU stow][stow] handles symlinks)
- Dotfiles should be extensible with one or more local overlay repos (e.g. `~/.local-dotfiles`) whose `home/` directories override specific files
- Embrace Git and do not keep things that are no longer being used
- Operations should be idempotent
- Dotfiles should install with minimum fussiness (i.e. don't rewrite into Rust because that would introduce dependencies for spinning them up on a new machine)
- Don't worry about installation of packages not being customized per-machine — it's okay if a work machine where I do not use PHP has a PHP binary available

## Main Components

- [Ghostty][ghostty] — the best terminal emulator
- [zsh][zsh] — I know people are hyped about fish, but I'm sticking with zsh for now
- [p10k][p10k] — fast and fancy terminal prompt
- [tmux][tmux] — for managing processes and windows and sessions
- [sesh][sesh] — switcher and manager for tmux sessions that ties them to directories
- [Neovim][nvim] — BTW
- [Lazygit][lazygit] — TUI for Git that I use about half of the time
- [pet][pet] — snippets manager, for things that aren't quite worth a zsh alias/function
  - might be replacing this soon with a custom tool
- [stow][stow] — classic GNU util for managing symlinks (more below in **Living with Dotfiles**)
- [hk][hk] — for managing Git hooks in this repo that do things like linting, and secret exfiltration protection
- [secretlint][secretlint] — for preventing secret exfiltration from this repo

## Living with Dotfiles

The main things I run are `dotfiles` and `dotfiles-install`.

### Syncing dotfiles

The `dotfiles` command uses [GNU stow][stow] to symlink files from `~/dotfiles/home` into `~/`.

Repository-only files such as `bin/`, `.fonts/`, tests, and local agent instructions remain at the repository root and are not stowed. This allows me to keep `~/dotfiles/bin` directly on `PATH` without making `~/` a Git checkout.

Local zsh bootstrap lives in `~/.local-dotfiles/local-init.zsh` and is sourced from `~/.zshrc`. Deployable local overrides live under `~/.local-dotfiles/home` and are overlaid into `~/dotfiles/home`.

### Installing

The `dotfiles-install` command does a bunch of things:

- Installs software
- Handles various manual symlinks
- Creates empty directories where needed

The `dotfiles` command handles Stow syncing and local overlay reconciliation for overlapping files.

`dotfiles --pure` temporarily removes all overlay overrides, restoring the base dotfiles checkout so you can edit files that are normally shadowed by overlay symlinks. Running `dotfiles` again (without `--pure`) re-applies overlays.

### Managing cron jobs

`crontab-sync` manages fenced sections of the current user's crontab from JSON. By default, it manages the existing unnamed section from `~/.config/crontab/jobs.json`. Entries outside the selected section remain untouched.

```json
{
	"jobs": [
		{
			"name": "example",
			"description": "Run an example task every morning",
			"schedule": "0 8 * * *",
			"command": "/absolute/path/to/example",
			"enabled": true
		}
	]
}
```

Validate and inspect changes before applying them:

```zsh
crontab-sync check
crontab-sync render
crontab-sync diff
crontab-sync apply
```

Use `--name` to manage additional sections independently. Names may contain ASCII letters, digits, underscores, and hyphens. Named calls preserve the unnamed section, differently named sections, and unmanaged entries:

```zsh
crontab-sync apply --name local -f ~/.local-dotfiles/home/.config/crontab/jobs.json
```

This produces fences such as `# BEGIN crontab-sync managed section: local` and `# END crontab-sync managed section: local`. Calls without `--name` continue to use the original unnamed fences.

Jobs require `name`, `schedule`, and `command`. `description` and `enabled` are optional. Schedules accept the standard five fields or macros such as `@daily` and `@reboot`.

### Installing the HEIC to JPG Folder Action

Install the workflow in the macOS Folder Actions directory:

```zsh
mkdir -p "$HOME/Library/Workflows/Applications/Folder Actions"
ditto "$HOME/dotfiles/bin/HEIC to JPG.workflow" "$HOME/Library/Workflows/Applications/Folder Actions/HEIC to JPG.workflow"
```

Then attach it to a folder:

1. In Finder, right-click the folder to watch, such as `Downloads`.
2. Select **Services** → **Folder Actions Setup…**.
3. Enable Folder Actions.
4. Attach `HEIC to JPG.workflow`.

The workflow converts incoming `.heic` images to `.jpg` and deletes the original `.heic` files after conversion.

[mj]: https://github.com/markjaquith
[ghostty]: https://ghostty.io/
[zsh]: https://www.zsh.org/
[p10k]: https://github.com/romkatv/powerlevel10k
[tmux]: https://github.com/tmux/tmux/wiki
[sesh]: https://github.com/joshmedeski/sesh
[nvim]: https://neovim.io/
[pet]: https://github.com/knqyf263/pet
[stow]: https://www.gnu.org/software/stow/
[lazygit]: https://github.com/jesseduffield/lazygit
[hk]: https://hk.jdx.dev/
[secretlint]: https://github.com/secretlint/secretlint
