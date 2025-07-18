
#!/bin/bash
###     file name: zxc_tmux.sh
###     dir: /mnt/c/wsl/scripts/lib/config/zxc_tmux.sh


#######--- START OF FILE ---#######
# Setup tmux configuration
# Define Patch paths
TMUX_PRISTINE="$PRISTINE_DIR/tmux"
TMUX_WORKING="$WORKING_FILE/tmux.conf"
TMUX_PATC="$TMUX_WORKING.patch"

#1 - Setup Pristine tmux config  
print_status "Setting up tmux configuration..."

cat > "$TMUX_PRISTINE/tmux.conf" << 'EOL'

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


# 2. Copy the pristine file to the working location.
cp "$TMUX_PRISTINE/tmux.conf" "$TMUX_WORKING"

# 3. Check if a user patch exists and apply it.
if [ -f "$PATCH_FILE" ]; then
    print_status "TMUX_CONF" "Found existing patch file. Applying user modifications..."
    # The 'patch' command applies the diff.
    # -p1 strips the first path component from the diff file (e.g., 'a/path/to/file')
    # --forward ensures we don't accidentally un-patch.
    if patch --forward -p1 "$WORKING_FILE" < "$PATCH_FILE"; then
        print_success "TMUX_CONF" "Successfully applied user patch to tmux.conf."
    else
        print_error "TMUX_CONF" "Failed to apply patch to tmux.conf. The base file may have changed too much. Please resolve manually."
        # A .rej (reject) file is often created with the failed parts of the patch.
    fi
else
    print_status "TMUX_CONF" "No user patch found for tmux.conf. Using pristine version."
fi

#######--- END OF FILE ---#######
