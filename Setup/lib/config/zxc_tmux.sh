
#!/bin/bash
###     file name: zxc_tmux.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zxc_tmux.sh


#######--- START OF FILE ---#######
# Setup tmux configuration
print_status "Setting up tmux configuration..."
cat > ~/.config/tmux/tmux.conf << 'EOL'
# Change prefix from 'Ctrl+b' to 'Ctrl+a' 
unbind C-b 
set-option -g prefix C-a 
bind-key C-a send-prefix 

set-option -g status-position top


# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Enable mouse mode
set -g mouse on 

# Start window numbering at 1 
set -g base-index 1 
set -g pane-base-index 1

# Modern colors 
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
set -g status-bg black
set -g status-fg colour91
set -g pane-active-border-style fg=colour91

bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Set locale options
set-option -g default-shell /usr/bin/zsh
set-option -g status-interval 1

# Improve escape time
set -sg escape-time 0

# Increase scrollback buffer size
set -g history-limit 50000

# Enable focus events
set -g focus-events on
EOL


#######--- END OF FILE ---#######
