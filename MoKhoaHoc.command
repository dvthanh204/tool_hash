#!/bin/bash
echo "====================================================="
echo "   KHOA HOC TU XA - SLIDELOCK (HE THONG BAO MAT MAC)  "
echo "====================================================="
echo "Dang thiet lap quyen truy cap ung dung..."
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

if [ -d "SlideLock.app" ]; then
    xattr -cr SlideLock.app
    chmod -R 755 SlideLock.app
    echo "[OK] Da go bo Gatekeeper thanh cong!"
    echo ""
    echo "Luu y quan trong khi hoc bai:"
    echo "1. Khi ung dung yeu cau quyen Tro Nang (Accessibility) va Tu Dong Hoa,"
    echo "   vui long chon 'Mo Cai dat he thong' va gat BAT cho SlideLock."
    echo "2. Khong dong cua so SlideLock (nut X) trong luc hoc bai."
    echo "-----------------------------------------------------"
    echo "Bay gio ban co the mo SlideLock.app de hoc bai."
else
    echo "[LOI] Khong tim thay SlideLock.app trong thu muc nay!"
    echo "Vui long dam bao ban da giai nen dung cach."
fi

echo "====================================================="
echo "Ban co the dong cua so Terminal nay."
