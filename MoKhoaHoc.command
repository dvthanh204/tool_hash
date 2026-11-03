#!/bin/bash
echo "====================================================="
echo "   KHOA HOC TU XA - SLIDELOCK (HE THONG BAO MAT MAC)  "
echo "====================================================="
echo "Dang thiet lap quyen va bao mat tren macOS..."
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

# Go bo toan bo thuoc tinh Quarantine do macOS / Trinh duyet gan vao
xattr -cr . 2>/dev/null || true
xattr -dr com.apple.quarantine . 2>/dev/null || true
if [ -d "SlideLock.app" ]; then
    xattr -cr "SlideLock.app" 2>/dev/null || true
    xattr -dr com.apple.quarantine "SlideLock.app" 2>/dev/null || true
    chmod -R 755 "SlideLock.app" 2>/dev/null || true
    chmod +x "SlideLock.app/Contents/MacOS/"* 2>/dev/null || true
    echo "[OK] Da thiet lap quyen va go bo Gatekeeper thanh cong!"
    echo ""
    echo "Luu y quan trong khi hoc bai tren MacBook:"
    echo "1. Khi ung dung yeu cau quyen Tro Nang (Accessibility) va Tu Dong Hoa (Automation),"
    echo "   vui long chon 'Mo Cai dat he thong' va gat BAT cho SlideLock."
    echo "2. Khong dong cua so SlideLock trong luc hoc bai."
    echo "-----------------------------------------------------"
    echo "Dang khoi dong SlideLock.app..."
    open "SlideLock.app"
else
    echo "[LOI] Khong tim thay SlideLock.app trong thu muc nay!"
    echo "Vui long dam bao ban da giai nen dung cach."
fi

echo "====================================================="
echo "Ban co the dong cua so Terminal nay."
