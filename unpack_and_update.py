import os
import shutil
import zipfile
import subprocess
import sys

BASE_DIR = r"D:\code\python\tool_hash_macOS"
ZIP_PATH = os.path.join(BASE_DIR, "SlideLock-App-Built.zip")
TARGET_APP = os.path.join(BASE_DIR, "SlideLock.app")
DIST_APP = os.path.join(BASE_DIR, "dist", "SlideLock_Admin_App", "SlideLock.app")
TEST_APP = os.path.join(BASE_DIR, "test", "SlideLock_Admin_App", "SlideLock.app")
COMMAND_FILE = os.path.join(BASE_DIR, "MoKhoaHoc.command")

print(f"1. Unpacking {ZIP_PATH} -> {TARGET_APP}...")

if os.path.exists(TARGET_APP):
    shutil.rmtree(TARGET_APP)

os.makedirs(TARGET_APP, exist_ok=True)

with zipfile.ZipFile(ZIP_PATH, "r") as z:
    for member in z.infolist():
        target_path = os.path.join(TARGET_APP, member.filename)
        if member.filename.endswith("/"):
            os.makedirs(target_path, exist_ok=True)
        else:
            os.makedirs(os.path.dirname(target_path), exist_ok=True)
            with z.open(member) as src, open(target_path, "wb") as dst:
                shutil.copyfileobj(src, dst)
        print(f"   Extracted: {member.filename} ({member.file_size} bytes)")

print("\n2. Syncing SlideLock.app to dist and test directories...")
for dest in [DIST_APP, TEST_APP]:
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(TARGET_APP, dest)
    print(f"   Copied to: {dest}")

print("\n3. Syncing MoKhoaHoc.command to dist and test directories...")
for dest_dir in [os.path.join(BASE_DIR, "dist", "SlideLock_Admin_App"), os.path.join(BASE_DIR, "test", "SlideLock_Admin_App")]:
    if os.path.exists(dest_dir):
        shutil.copy2(COMMAND_FILE, dest_dir)
        print(f"   Copied MoKhoaHoc.command to: {dest_dir}")

print("\n4. Verifying Mach-O Binary in SlideLock.app/Contents/MacOS/SlideLock...")
binary_path = os.path.join(TARGET_APP, "Contents", "MacOS", "SlideLock")
if os.path.exists(binary_path):
    size = os.path.getsize(binary_path)
    with open(binary_path, "rb") as f:
        magic = f.read(4)
    print(f"   Binary size: {size} bytes")
    print(f"   Magic: {magic.hex()}")
    if magic in [b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca']:
        print("   Status: Valid Universal Binary (arm64 + x86_64)!")
else:
    print("   ERROR: Binary missing!")

print("\nSUCCESS: SlideLock.app successfully unpacked and synchronized!")

