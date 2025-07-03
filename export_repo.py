import os
import subprocess

def export_git_repo_to_text(output_filename="repo_contents.txt"):
    """
    Exports the structure and content of text files in a Git repository
    to a single text file.
    """
    repo_root = os.getcwd() # Assumes script is run from repo root

    try:
        # Get list of tracked files using git ls-files
        result = subprocess.run(
            ["git", "ls-files"],
            capture_output=True,
            text=True,
            check=True
        )
        files_to_export = result.stdout.strip().split('\n')
    except subprocess.CalledProcessError as e:
        print(f"Error listing Git files: {e}")
        return

    print(f"Exporting Git repository structure and content to {output_filename}")

    with open(output_filename, 'w', encoding='utf-8') as outfile:
        outfile.write("Exported Git Repository Contents\n")
        outfile.write("--------------------------------------------------------\n\n")

        for file_path in files_to_export:
            full_path = os.path.join(repo_root, file_path)

            if not os.path.isfile(full_path):
                # This should ideally not happen with git ls-files, but good to check
                continue

            try:
                # Try to read as text. If it fails, it's likely a binary file.
                with open(full_path, 'r', encoding='utf-8') as infile:
                    content = infile.read()
                
                outfile.write(f"--- FILE: {file_path} ---\n")
                outfile.write("```\n") # Markdown-style code block start
                outfile.write(content)
                outfile.write("\n```\n\n") # Markdown-style code block end
            except UnicodeDecodeError:
                # Handle binary files or files with non-UTF-8 encoding
                outfile.write(f"--- BINARY FILE (SKIPPED): {file_path} ---\n\n")
            except Exception as e:
                # Catch other potential file reading errors
                outfile.write(f"--- ERROR READING FILE: {file_path} ({e}) ---\n\n")

    print(f"Export complete. Check '{output_filename}'.")

if __name__ == "__main__":
    export_git_repo_to_text()