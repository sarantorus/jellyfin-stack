import os
import re

# Paths on your M5
SOURCE = os.path.expanduser("~/jellyfin-stack/zurg/mnt/__all__")
TARGET = os.path.expanduser("~/jellyfin-stack/clean_library")

def build():
    for item in os.listdir(SOURCE):
        if item.startswith('.') or item == "unplayable": continue
        
        # Categorize
        cat = "TV" if re.search(r'S\d{2}|E\d{2}|Season|Sezon', item, re.I) else "Movies"
        dest_dir = os.path.join(TARGET, cat)
        os.makedirs(dest_dir, exist_ok=True)
        
        # THE MAGIC: Relative link 
        # From 'clean_library/Movies/MovieName' up to 'clean_library' then into 'zurg/mnt/__all__'
        rel_path = os.path.join("../../zurg/mnt/__all__", item)
        
        try:
            os.symlink(rel_path, os.path.join(dest_dir, item))
        except FileExistsError:
            pass

    print("✅ Logic Deployed: Relative Symlinks are now Live.")

if __name__ == "__main__":
    build()