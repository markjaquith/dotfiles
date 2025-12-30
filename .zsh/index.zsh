#!/usr/bin/env zsh
source $(dirname "$0")/000-init.zsh

# ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
# ┃             Module         #┃ Description                  ┃ Condition      ┃
# ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
  ┃  005-profile-start         #┃ Start profiling              ┃ ZSH_PROFILE    ┃
  ┃  010-paths                 #┃ Set paths                    ┃                ┃
  ┃  020-history               #┃ Configure zsh history        ┃                ┃
  ┃  040-pkgx                  #┃ Load Pkgx                    ┃                ┃
  ┃  050-bun                   #┃ Load Bun                     ┃                ┃
  ┃  070-zinit                 #┃ Load Zinit                   ┃                ┃
  ┃  075-nvm                   #┃ Load NVM                     ┃ DOTFILES_NVM   ┃
  ┃  080-mise                  #┃ Configure Mise and HK        ┃                ┃
  ┃  090-completions           #┃ Init completions system      ┃                ┃
  ┃  100-aliases               #┃ Aliases                      ┃                ┃
  ┃  105-misc                  #┃ Misc                         ┃                ┃
  ┃  110-shortcuts             #┃ Keyboard shortcuts           ┃                ┃
  ┃  140-fzf                   #┃ Load fzf (fuzzy finder)      ┃                ┃
  ┃  150-powerlevel10k         #┃ Powerlevel10k prompt         ┃                ┃
  ┃  160-syntax-highlighting   #┃ Syntax highlighting          ┃                ┃
  ┃  170-zoxide                #┃ Load Zoxide                  ┃                ┃
  ┃  999-profile-end           #┃ End profiling                ┃ ZSH_PROFILE    ┃
# ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
