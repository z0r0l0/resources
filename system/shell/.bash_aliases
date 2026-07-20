# ============================================================================
# ZRL Shell Aliases
# Managed by Hermes Agent
# ============================================================================

# --- System ---
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -lh --group-directories-first'
alias la='ls -lAh --group-directories-first'
alias l='ls -CF --group-directories-first'
alias c='clear'
alias p='pwd'
alias h='history'
alias j='jobs -l'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# --- Safety ---
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -i'
alias mkdir='mkdir -p'

# --- Network ---
alias myip='curl -s ifconfig.me'
alias ping='ping -c 4'
alias ports='ss -tulanp'
alias proxy-on='export http_proxy=http://127.0.0.1:7897; export https_proxy=http://127.0.0.1:7897; echo "🌐 Proxy ON"'
alias proxy-off='unset http_proxy https_proxy; echo "🌐 Proxy OFF"'
alias proxy-status='echo "http_proxy=$http_proxy"; echo "https_proxy=$https_proxy"'

# --- Git ---
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gb='git branch'
alias gl='git log --oneline --graph --decorate --all'
alias gd='git diff'
alias gds='git diff --staged'
alias gp='git push'
alias gpl='git pull'
alias gcl='git clone'
alias gr='git remote -v'

# --- Dev ---
alias py='python3'
alias pyv='python3 --version'
alias pip='pip3'
alias nv='node --version'
alias npmv='npm --version'

# --- Docker ---
alias d='docker'
alias dps='docker ps'
alias di='docker images'
alias dc='docker compose'
alias dcup='docker compose up -d'
alias dcdown='docker compose down'
alias dlog='docker logs -f'

# --- WSL ---
alias wsl-ip='hostname -I | awk "{print \$1}"'
alias windows='cd /mnt/c/Users/张'
alias desktop='cd /mnt/c/Users/张/Desktop'
alias docs='cd /mnt/c/Users/张/Documents'
alias downloads='cd /mnt/c/Users/张/Downloads'

# --- Hermes ---
alias hermes-status='systemctl --user status hermes-gateway 2>/dev/null || echo "Gateway service not found"'
alias hermes-restart='systemctl --user restart hermes-gateway'
alias hermes-log='journalctl --user -u hermes-gateway -n 50 -f'
alias hermes-update='cd ~/.hermes/hermes-agent && git pull && ./install.sh'
