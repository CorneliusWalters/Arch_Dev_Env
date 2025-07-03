# #!/bin/bash
# ###     file: snapshots.sh
###     dir: /mnt/c/wsl/scripts/lib/snapshots.sh


# #######--- START OF FILE ---#######

# SNAPSHOT_DIR=~/wsl_snapshots

# init_snapshots() {
#     mkdir -p "$SNAPSHOT_DIR"
#     log_message "INFO" "Initialized snapshot system at $SNAPSHOT_DIR"
# }

# create_snapshot() {
#     local snapshot_name="snapshot_$(date +%Y%m%d_%H%M%S)"
#     local snapshot_path="$SNAPSHOT_DIR/${snapshot_name}.tar"
    
#     print_status "Creating WSL snapshot: $snapshot_name"
#     log_message "SNAPSHOT" "Creating snapshot: $snapshot_path"
    
#     local distro_name=$(wsl.exe -l --running | grep -i "Arch" | awk '{print $1}')
    
#     if wsl.exe --export "$distro_name" "$snapshot_path"; then
#         log_message "SNAPSHOT" "Successfully created snapshot: $snapshot_path"
#         echo "$snapshot_path"
#         return 0
#     else
#         log_message "ERROR" "Failed to create snapshot: $snapshot_path"
#         return 1
#     fi
# }

# restore_snapshot() {
#     local snapshot_path="$1"
#     local distro_name=$(wsl.exe -l --running | grep -i "Arch" | awk '{print $1}')
    
#     print_status "Restoring WSL snapshot: $snapshot_path"
#     log_message "SNAPSHOT" "Restoring snapshot: $snapshot_path"
    
#     wsl.exe --terminate "$distro_name"
#     wsl.exe --unregister "$distro_name"
    
#     if wsl.exe --import "$distro_name" "$HOME/wsl/$distro_name" "$snapshot_path"; then
#         log_message "SNAPSHOT" "Successfully restored snapshot: $snapshot_path"
#         return 0
#     else
#         log_message "ERROR" "Failed to restore snapshot: $snapshot_path"
#         return 1
#     fi
# }

# cleanup_old_snapshots() {
#     local keep_last=5
#     print_status "Cleaning up old snapshots..."
#     ls -t "$SNAPSHOT_DIR"/*.tar 2>/dev/null | tail -n +$((keep_last + 1)) | xargs -r rm
#     log_message "CLEANUP" "Removed old snapshots, keeping last $keep_last"
# }


# #######--- END OF FILE ---#######