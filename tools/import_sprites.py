import os
import shutil
import argparse
from pathlib import Path

def sync_sprites(source_dir: Path, target_dir: Path, dry_run: bool = False):
    """
    Syncs the sprite directories from the source to the target.
    
    Args:
        source_dir: Path to the sprites-master/sprites directory.
        target_dir: Path to the primal-harmony/assets/sprites directory.
        dry_run: If True, only prints what would be copied.
    """
    if not source_dir.exists():
        print(f"Error: Source directory {source_dir} does not exist.")
        return

    print(f"Starting sprite sync from {source_dir} to {target_dir}")
    print(f"Mode: {'DRY RUN' if dry_run else 'EXECUTE'}\n")

    # The subdirectories in sprites-master/sprites we want to sync
    categories = ['badges', 'items', 'pokemon', 'types']

    for category in categories:
        src_path = source_dir / category
        dst_path = target_dir / category

        if not src_path.exists():
            print(f"Warning: Category {category} not found in source ({src_path}). Skipping.")
            continue
            
        print(f"Syncing {category}...")
        
        if dry_run:
            # Doing a simple walk to show what would be copied
            files_count = sum(len(files) for _, _, files in os.walk(src_path))
            print(f"  [Dry Run] Would sync {files_count} files to {dst_path}")
        else:
            # Execute copy
            os.makedirs(dst_path, exist_ok=True)
            shutil.copytree(src_path, dst_path, dirs_exist_ok=True)
            print(f"  Successfully synced {category} to {dst_path}")

    print("\nSync complete!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import sprites from sprites-master to primal-harmony")
    
    # Default paths assume the script relies in primal-harmony/tools/
    current_file_path = Path(__file__).resolve()
    primal_harmony_root = current_file_path.parent.parent
    project_root = primal_harmony_root.parent
    
    default_source = project_root / "sprites-master" / "sprites"
    default_target = primal_harmony_root / "assets" / "sprites"
    
    parser.add_argument("--source", type=Path, default=default_source, help="Path to sprites-master/sprites directory")
    parser.add_argument("--target", type=Path, default=default_target, help="Path to primal-harmony/assets/sprites directory")
    parser.add_argument("--dry-run", action="store_true", help="Print what would be done without actually copying files")

    args = parser.parse_args()

    sync_sprites(args.source, args.target, args.dry_run)
