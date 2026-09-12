source /usr/share/cachyos-zsh-config/cachyos-config.zsh
eval "$(starship init zsh)"
eval "$(starship init zsh)"

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

fastfetch

export PATH="$HOME/.local/bin:$PATH"
