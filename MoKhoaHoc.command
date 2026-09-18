#!/bin/bash
echo "Dang thiet lap quyen truy cap ung dung Khoa Hoc Tu Xa..."
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

if [ -d "SlideLock.app" ]; then
    xattr -cr SlideLock.app
    chmod -R 755 SlideLock.app
    echo "Thanh cong! Bay gio ban co the mo SlideLock.app."
else
    echo "Loi: Khong tim thay SlideLock.app trong thu muc nay!"
    echo "Cam doan ban da giai nen dung cach."
fi

echo "=================================="
echo "Ban co the dong cua so nay."
