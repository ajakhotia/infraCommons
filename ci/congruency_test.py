import sys
import difflib
import argparse
from pathlib import Path
from typing import Set


DEFAULT_IGNORE_FILES = {
    'LICENSE',
    'License.md',
    'license.md',
    'license.txt',
    'README.md',
    'ReadMe.md',
    'Readme.md',
    'readme.md',
    'readMe.md',
}


def compare_directories(template_dir: str, client_dir: str, ignore_files: Set[str]) -> bool:
    # Convert paths to Path objects
    template_dir_path = Path(template_dir)
    client_dir_path = Path(client_dir)
    
    # Check if both directories exist
    if not template_dir_path.is_dir() or not client_dir_path.is_dir():
        print("Error: One or both paths are not valid directories")
        return False
    
    # Get all files recursively in both directories
    template_files = {f.relative_to(template_dir_path) for f in template_dir_path.rglob('*') if f.is_file()}
    client_files = {f.relative_to(client_dir_path) for f in client_dir_path.rglob('*') if f.is_file()}

    # Remove ignored files from both sets
    ignored_in_client = {f for f in client_files if f.name in ignore_files}
    if ignored_in_client:
        print("Ignoring files:", ", ".join(sorted(f.name for f in ignored_in_client)))

    template_files = {f for f in template_files if f.name not in ignore_files}
    client_files = {f for f in client_files if f.name not in ignore_files}

    # Find common files
    common_files = template_files & client_files
    
    if not common_files:
        print("No common files found")
        return True
    
    all_identical = True
    
    # Compare each common file
    for relative_file_path in common_files:
        template_file_path = template_dir_path / relative_file_path
        client_file_path = client_dir_path / relative_file_path
        
        with open(template_file_path, 'r') as template_file, open(client_file_path, 'r') as client_file:
            template_content = template_file.readlines()
            client_content = client_file.readlines()
            
            if template_content != client_content:
                all_identical = False
                print(f"\nDifferences in {relative_file_path}:")
                diff = difflib.unified_diff(
                    template_content, client_content,
                    fromfile=str(template_file_path),
                    tofile=str(client_file_path)
                )
                sys.stdout.writelines(diff)
    
    return all_identical


def parse_ignore_files(ignore_file_list: str) -> Set[str]:
    """Convert a comma-separated ignore-file-list to a set"""
    if not ignore_file_list:
        return set()

    return {name.strip() for name in ignore_file_list.split(',')}


def parse_arguments():
    parser = argparse.ArgumentParser(
        description='Compare files that are common between template and client directories.',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    
    parser.add_argument(
        '-t', '--template-directory',
        required=True,
        help='Template directory path to compare'
    )
    
    parser.add_argument(
        '-c', '--client-directory',
        required=True,
        help='Client directory path to compare'
    )
    
    parser.add_argument(
        '-i', '--ignore-files',
        default='',
        help='Comma-separated list of additional files to ignore'
    )
    
    parser.add_argument(
        '--no-default-ignores',
        action='store_true',
        help='Disable default ignore list'
    )
    
    return parser.parse_args()


def main() -> int:
    args = parse_arguments()
    
    # Build the complete ignore list
    ignore_files = set()
    if not args.no_default_ignores:
        ignore_files.update(DEFAULT_IGNORE_FILES)
    ignore_files.update(parse_ignore_files(args.ignore_files))
    
    success = compare_directories(args.template_directory, args.client_directory, ignore_files)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
