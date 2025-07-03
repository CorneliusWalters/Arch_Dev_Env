import os
import subprocess
from datetime import datetime # Import the datetime module

def export_git_repo_to_text():
    """
    Exports the structure and content of text files in a Git repository
    to a single text file, with a timestamp in the filename.
    """
    repo_root = os.getcwd() # Assumes script is run from repo root

    # Generate a timestamp for the filename
    now = datetime.now()
    timestamp_str = now.strftime("%Y%m%d_%H%M%S") # Format: YYYYMMDD_HHMMSS

    # Construct the output filename
    output_filename = f"repo_contents_{timestamp_str}.txt"

    print(f"Attempting to list Git files from: {repo_root}")
    try:
        # Get list of tracked files using git ls-files
        result = subprocess.run(
            ["git", "ls-files"],
            capture_output=True,
            text=True,
            check=True # This will raise an error if the git command fails
        )
        # Split lines and filter out any empty strings that might result
        files_to_export = [f for f in result.stdout.strip().split('\n') if f]

    except subprocess.CalledProcessError as e:
        print(f"ERROR: Git command failed. Is '{repo_root}' a Git repository and is Git installed?")
        print(f"Git command output (stderr): {e.stderr}")
        return
    except FileNotFoundError:
        print("ERROR: 'git' command not found. Is Git installed and in your system's PATH?")
        return

    if not files_to_export:
        print("WARNING: No files found by 'git ls-files'.")
        print("This could mean:")
        print("  - The repository is empty.")
        print("  - There are no files currently tracked by Git (i.e., you haven't run 'git add' and 'git commit').")
        print(f"Raw output from 'git ls-files': '{result.stdout.strip()}'")
        print("No output file will be generated as there's no content to export.")
        return

    print(f"Found {len(files_to_export)} tracked files. Exporting to {output_filename}")

    # Use 'with open' to ensure the file is properly closed
    with open(output_filename, 'w', encoding='utf-8') as outfile:
        # Write header with full timestamp
        outfile.write(f"Exported Git Repository Contents - Generated on {now.strftime('%Y-%m-%d %H:%M:%S')}\n")
        outfile.write("--------------------------------------------------------\n\n")

        file_counter = 0 # Initialize a counter for exported text files

        for file_path in files_to_export:
            full_path = os.path.join(repo_root, file_path)

            if not os.path.isfile(full_path):
                # This case might happen if a file was tracked but then deleted locally
                outfile.write(f"--- FILE NOT FOUND (SKIPPED): {file_path} ---\n\n")
                continue

            try:
                # Try to read the file as text (UTF-8 encoding is common for code)
                with open(full_path, 'r', encoding='utf-8') as infile:
                    content = infile.read()
                
                file_counter += 1 # Increment counter for successfully read text files
                outfile.write(f"--- FILE {file_counter}: {file_path} ---\n") # Add file counter
                outfile.write("```\n") # Markdown-style code block start
                outfile.write(content)
                outfile.write("\n```\n\n") # Markdown-style code block end
            except UnicodeDecodeError:
                # If it's not valid UTF-8, it's likely a binary file
                outfile.write(f"--- BINARY FILE (SKIPPED): {file_path} ---\n\n")
            except Exception as e:
                # Catch any other reading errors
                outfile.write(f"--- ERROR READING FILE: {file_path} (Error: {e}) ---\n\n")

    print(f"Export complete. Check '{output_filename}'. {file_counter} text files processed.")

if __name__ == "__main__":
    export_git_repo_to_text()