# Mark Jaquith's Dotfiles

These are [@markjaquith][mj]'s dotfiles. They are for Mark. You can use them for inspiration if you want, but they are for Mark.

They will change drastically over time, often suddenly, and without warning.

## Philosophy

- Dotfiles should be stored in `~/dotfiles`
- Dotfiles should mirror the home directory ([GNU stow][stow] handles symlinks)
- Dotfiles should be extensible with a `~/.local-dotfiles` directory that can append/prepend (TODO: support full overriding if needed)
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
	- Might be replacing this soon with a custom tool
- [stow][stow] — classic GNU util for managing symlinks (more below in **Living with Dotfiles**)

## Living with Dotfiles

The main things I run are `dotfiles` and `dotfiles-install`.

### Syncing dotfiles

The `dotfiles` command uses [GNU stow][stow] to symlink things from `~/` to their mapped location in `~/dotfiles`

This allows me to not have `~/` be a Git checkout.

### Installing

The `dotfiles-install` command does a bunch of things:

- Installs software
- Handles various manual symlinks
- Creates empty directories where needed
- Merges files from `~/.local-dotfiles`
	- Looks for `.default.` files in the main repo
	- Matches them with `.prepend.` or `.append.` files in the local dotfiles (if present)
	- Concatenates as appropriate
- Sets up `.githooks` dir
	- `pre-push` command prevents me from committing work things or secrets

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
