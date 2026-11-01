import customtkinter as ctk
from tkinter import filedialog, messagebox
import json, os, sys, zipfile, io, base64, threading, time
from datetime import datetime
import hmac, hashlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# Đảm bảo thư mục làm việc luôn là thư mục chứa file thực thi / script
if getattr(sys, 'frozen', False):
    os.chdir(os.path.dirname(os.path.abspath(sys.executable)))
else:
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class SlideLockModernAdmin(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("SLIDELOCK • Admin Security Workspace")
        self.geometry("1100x740")
        self.minsize(1020, 680)
        
        # Bảng màu Tươi Sáng & Đậm Chất Công Nghệ (Electric Tech Theme)
        self.C_BG = "#060B19"          # Nền vũ trụ công nghệ sâu thẳm
        self.C_SIDEBAR = "#091228"     # Sidebar xanh đêm huyền bí
        self.C_BORDER = "#1B2C55"      # Viền công nghệ tinh tế
        self.C_CARD_BG = "#0D1938"     # Thẻ nội dung xanh đậm
        self.C_CYAN = "#00D2FF"        # Màu nhấn Cyan rực rỡ
        self.C_BLUE = "#0066FF"        # Màu nút chính Electric Blue
        self.C_BLUE_HOVER = "#0052CC"  # Hover xanh đậm
        self.C_TEXT_WHITE = "#FFFFFF"  # Chữ trắng sáng
        self.C_TEXT_MUTED = "#7D95C2"  # Chữ phụ xanh xám dịu mắt
        self.C_ACCENT_GREEN = "#10B981" # Xanh lá bảo mật OK
        
        self.configure(fg_color=self.C_BG)
        
        self.selected_files = []
        self.single_lock_files = []
        self.current_tab = "tab_pack"
        
        self._init_layout()
        self.update_system_stats()
        self.select_tab("tab_pack")

    def _init_layout(self):
        # ── SIDEBAR TRÁI (THEO ĐÚNG HÌNH ẢNH MẪU) ──────────────────────
        self.sidebar = ctk.CTkFrame(self, fg_color=self.C_SIDEBAR, width=265, corner_radius=0, border_width=1, border_color=self.C_BORDER)
        self.sidebar.pack(side="left", fill="y")
        self.sidebar.pack_propagate(False)
        
        # 1. Logo & App Title (Hình Khiên Khóa Neon)
        logo_box = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        logo_box.pack(fill="x", padx=20, pady=(24, 16))
        
        # Icon khiên phát sáng
        shield_canvas = ctk.CTkFrame(logo_box, fg_color="#0066FF", corner_radius=14, width=46, height=46, border_width=2, border_color=self.C_CYAN)
        shield_canvas.pack(side="left", padx=(0, 12))
        shield_canvas.pack_propagate(False)
        ctk.CTkLabel(shield_canvas, text="🔒", font=ctk.CTkFont(size=20)).place(relx=0.5, rely=0.5, anchor="center")
        
        title_box = ctk.CTkFrame(logo_box, fg_color="transparent")
        title_box.pack(side="left", fill="both", expand=True)
        
        lbl_app_name = ctk.CTkLabel(title_box, text="SLIDELOCK", font=ctk.CTkFont(family="Segoe UI", size=20, weight="bold"), text_color=self.C_CYAN)
        lbl_app_name.pack(anchor="w")
        
        lbl_app_sub = ctk.CTkLabel(title_box, text="ADMIN SECURITY WORKSPACE", font=ctk.CTkFont(family="Segoe UI", size=8, weight="bold"), text_color=self.C_TEXT_MUTED)
        lbl_app_sub.pack(anchor="w")
        
        # 2. Card Trạng Thái Engine (Có nhịp tim EKG xanh công nghệ)
        engine_card = ctk.CTkFrame(self.sidebar, fg_color="#0D1B3E", corner_radius=14, border_width=1, border_color="#20356B")
        engine_card.pack(fill="x", padx=16, pady=(0, 20))
        
        top_eng = ctk.CTkFrame(engine_card, fg_color="transparent")
        top_eng.pack(fill="x", padx=14, pady=(12, 2))
        
        self.dot_eng = ctk.CTkLabel(top_eng, text="●", font=ctk.CTkFont(size=14), text_color=self.C_ACCENT_GREEN)
        self.dot_eng.pack(side="left", padx=(0, 6))
        
        self.lbl_eng_title = ctk.CTkLabel(top_eng, text="Engine: macOS Sẵn Sàng", font=ctk.CTkFont(family="Segoe UI", size=12, weight="bold"), text_color=self.C_TEXT_WHITE)
        self.lbl_eng_title.pack(side="left")
        
        ekg_icon = ctk.CTkLabel(top_eng, text="∿v∿", font=ctk.CTkFont(size=14, weight="bold"), text_color=self.C_CYAN)
        ekg_icon.pack(side="right")
        
        lbl_eng_desc = ctk.CTkLabel(engine_card, text="Bảo vệ bài giảng của bạn an toàn", font=ctk.CTkFont(size=10), text_color=self.C_TEXT_MUTED)
        lbl_eng_desc.pack(anchor="w", padx=14, pady=(0, 10))
        
        # 3. Các Nút Điều Hướng Navigation (Chuẩn Gradient Xanh Neon)
        self.nav_buttons = {}
        nav_items = [
            ("tab_pack", "⚡ Đóng Gói Khóa Học", "arrow"),
            ("tab_key", "🔑 Cấp Key Bản Quyền", ""),
            ("tab_ban", "🚫 Quản Lý Blacklist", ""),
            ("tab_pardon", "🛡️ Thẻ Bài Ân Xá", "")
        ]
        
        for tab_id, label, extra in nav_items:
            btn = ctk.CTkButton(
                self.sidebar,
                text=label + ("   ›" if extra else ""),
                font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
                fg_color="transparent",
                text_color=self.C_TEXT_MUTED,
                hover_color="#122046",
                anchor="w",
                height=48,
                corner_radius=14,
                command=lambda t=tab_id: self.select_tab(t)
            )
            btn.pack(fill="x", padx=14, pady=4)
            self.nav_buttons[tab_id] = btn

        # 4. Footer Sidebar (Hiển thị tóm tắt thiết bị và vỏ app)
        self.sidebar_footer = ctk.CTkFrame(self.sidebar, fg_color="#0D1B3E", corner_radius=14, border_width=1, border_color="#1F356B")
        self.sidebar_footer.pack(side="bottom", fill="x", padx=14, pady=16)
        
        f_row1 = ctk.CTkFrame(self.sidebar_footer, fg_color="transparent")
        f_row1.pack(fill="x", padx=12, pady=(10, 4))
        ctk.CTkLabel(f_row1, text="ℹ", font=ctk.CTkFont(size=13, weight="bold"), text_color=self.C_CYAN).pack(side="left", padx=(0, 8))
        self.lbl_stat_banned = ctk.CTkLabel(f_row1, text="Máy bị cấm: 0 thiết bị", font=ctk.CTkFont(size=11, weight="bold"), text_color=self.C_TEXT_WHITE)
        self.lbl_stat_banned.pack(side="left")
        
        f_row2 = ctk.CTkFrame(self.sidebar_footer, fg_color="transparent")
        f_row2.pack(fill="x", padx=12, pady=(0, 10))
        ctk.CTkLabel(f_row2, text="✔", font=ctk.CTkFont(size=12, weight="bold"), text_color=self.C_ACCENT_GREEN).pack(side="left", padx=(0, 8))
        self.lbl_stat_shell = ctk.CTkLabel(f_row2, text="Shell: SlideLock.app ✓", font=ctk.CTkFont(size=11, weight="bold"), text_color=self.C_ACCENT_GREEN)
        self.lbl_stat_shell.pack(side="left")

        # ── KHU VỰC NỘI DUNG CHÍNH (RIGHT MAIN CARD) ──────────────────
        self.content_area = ctk.CTkFrame(self, fg_color="transparent")
        self.content_area.pack(side="right", fill="both", expand=True, padx=24, pady=20)
        
        self.tab_frames = {
            "tab_pack": ctk.CTkFrame(self.content_area, fg_color="transparent"),
            "tab_key": ctk.CTkFrame(self.content_area, fg_color="transparent"),
            "tab_ban": ctk.CTkFrame(self.content_area, fg_color="transparent"),
            "tab_pardon": ctk.CTkFrame(self.content_area, fg_color="transparent")
        }
        
        self._build_tab_pack()
        self._build_tab_key()
        self._build_tab_ban()
        self._build_tab_pardon()

    def get_db(self):
        if os.path.exists("revocations.json"):
            try: return json.load(open("revocations.json", "r", encoding="utf-8"))
            except: return {}
        return {}

    def save_db(self, d):
        json.dump(d, open("revocations.json", "w", encoding="utf-8"), indent=4)
        self.update_system_stats()

    def update_system_stats(self):
        db = self.get_db()
        self.lbl_stat_banned.configure(text=f"Máy bị cấm: {len(db)} thiết bị")
        has_app = os.path.exists("SlideLock.app")
        if has_app:
            self.dot_eng.configure(text_color=self.C_ACCENT_GREEN)
            self.lbl_eng_title.configure(text="Engine: macOS Sẵn Sàng")
            self.lbl_stat_shell.configure(text="Shell: SlideLock.app ✓", text_color=self.C_ACCENT_GREEN)
        else:
            self.dot_eng.configure(text_color="#EF4444")
            self.lbl_eng_title.configure(text="Engine: Thiếu SlideLock.app")
            self.lbl_stat_shell.configure(text="Shell: Chưa nạp SlideLock.app", text_color="#EF4444")

    def select_tab(self, tab_id):
        self.current_tab = tab_id
        for tid, btn in self.nav_buttons.items():
            if tid == tab_id:
                btn.configure(
                    fg_color=self.C_BLUE,
                    text_color=self.C_TEXT_WHITE,
                    border_width=1,
                    border_color=self.C_CYAN
                )
            else:
                btn.configure(
                    fg_color="transparent",
                    text_color=self.C_TEXT_MUTED,
                    border_width=0
                )
                
        for frame in self.tab_frames.values():
            frame.pack_forget()
            
        self.tab_frames[tab_id].pack(fill="both", expand=True)

    # ══════════════════════════════════════════════════════════════════
    # TAB 1: ĐÓNG GÓI KHÓA HỌC (THIẾT KẾ Y HỆT ẢNH MẪU 100%)
    # ══════════════════════════════════════════════════════════════════
    def _build_tab_pack(self):
        main_card = ctk.CTkFrame(self.tab_frames["tab_pack"], fg_color=self.C_CARD_BG, corner_radius=22, border_width=1, border_color=self.C_BORDER)
        main_card.pack(fill="both", expand=True)
        
        # 1. Header Khóa Học với Icon Tròn Phát Sáng & Laptop 3D Minh Họa
        header_frame = ctk.CTkFrame(main_card, fg_color="transparent")
        header_frame.pack(fill="x", padx=28, pady=(22, 14))
        
        # Nút icon tròn tia sét xanh
        round_icon_box = ctk.CTkFrame(header_frame, fg_color="#0066FF", corner_radius=28, width=54, height=54, border_width=2, border_color=self.C_CYAN)
        round_icon_box.pack(side="left", padx=(0, 16))
        round_icon_box.pack_propagate(False)
        ctk.CTkLabel(round_icon_box, text="⚡", font=ctk.CTkFont(size=24)).place(relx=0.5, rely=0.5, anchor="center")
        
        header_text = ctk.CTkFrame(header_frame, fg_color="transparent")
        header_text.pack(side="left", fill="both", expand=True)
        
        title_row = ctk.CTkFrame(header_text, fg_color="transparent")
        title_row.pack(anchor="w")
        ctk.CTkLabel(title_row, text="Đóng Gói Khóa Học Cho Mac ", font=ctk.CTkFont(family="Segoe UI", size=20, weight="bold"), text_color=self.C_TEXT_WHITE).pack(side="left")
        ctk.CTkLabel(title_row, text="(Universal)", font=ctk.CTkFont(family="Segoe UI", size=20, weight="bold"), text_color=self.C_CYAN).pack(side="left")
        
        sub_desc = ctk.CTkLabel(
            header_text,
            text="Đóng gói toàn bộ bài giảng PPTX thành file .zip phân phối kèm app SlideLock đã ký số.",
            font=ctk.CTkFont(family="Segoe UI", size=12),
            text_color=self.C_TEXT_MUTED
        )
        sub_desc.pack(anchor="w", pady=(2, 0))
        
        # Huy hiệu Laptop 3D bảo mật
        laptop_badge = ctk.CTkFrame(header_frame, fg_color="#0A1636", corner_radius=16, border_width=1, border_color="#203975")
        laptop_badge.pack(side="right", padx=(10, 0))
        ctk.CTkLabel(laptop_badge, text="💻 P 🔒", font=ctk.CTkFont(size=18)).pack(padx=14, pady=8)

        # 2. Thanh Chọn Tệp Trên Cùng (Folder Pill Bar)
        pill_bar = ctk.CTkFrame(main_card, fg_color="#101C3D", corner_radius=14, border_width=1, border_color="#233B75", height=50)
        pill_bar.pack(fill="x", padx=28, pady=(0, 14))
        pill_bar.pack_propagate(False)
        
        folder_icon = ctk.CTkLabel(pill_bar, text="📁", font=ctk.CTkFont(size=18))
        folder_icon.pack(side="left", padx=(16, 10))
        
        self.pack_summary_lbl = ctk.CTkLabel(
            pill_bar,
            text="Chưa chọn tệp bài giảng nào",
            font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
            text_color=self.C_TEXT_WHITE
        )
        self.pack_summary_lbl.pack(side="left")
        
        btn_add_files = ctk.CTkButton(
            pill_bar,
            text="📁 Thêm File PPTX...",
            font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
            fg_color=self.C_BLUE,
            hover_color=self.C_BLUE_HOVER,
            text_color=self.C_TEXT_WHITE,
            height=36,
            corner_radius=10,
            border_width=1,
            border_color=self.C_CYAN,
            command=self._sel_pack_files
        )
        btn_add_files.pack(side="right", padx=10, pady=7)

        # 3. Vùng Kéo Thả / Danh Sách Bài Học (Dashed Dropzone Card)
        self.dropzone_box = ctk.CTkFrame(main_card, fg_color="#08122C", corner_radius=16, border_width=2, border_color="#203975")
        self.dropzone_box.pack(fill="both", expand=True, padx=28, pady=(0, 16))
        
        # Khung chứa nội dung bên trong dropzone (tự động chuyển đổi giữa icon kéo thả và danh sách file)
        self.dropzone_content = ctk.CTkFrame(self.dropzone_box, fg_color="transparent")
        self.dropzone_content.pack(fill="both", expand=True, padx=16, pady=16)
        
        self._render_pack_dropzone_empty()

        # 4. Trạng Thái & Thanh Tiến Trình (Progress Bar)
        progress_row = ctk.CTkFrame(main_card, fg_color="transparent")
        progress_row.pack(fill="x", padx=28, pady=(0, 16))
        
        status_left = ctk.CTkFrame(progress_row, fg_color="transparent")
        status_left.pack(side="left")
        ctk.CTkLabel(status_left, text="✔", font=ctk.CTkFont(size=13, weight="bold"), text_color=self.C_ACCENT_GREEN).pack(side="left", padx=(0, 6))
        self.lbl_pack_msg = ctk.CTkLabel(status_left, text="Sẵn sàng đóng gói bài giảng.", font=ctk.CTkFont(family="Segoe UI", size=12), text_color=self.C_TEXT_MUTED)
        self.lbl_pack_msg.pack(side="left")
        
        self.lbl_pack_pct = ctk.CTkLabel(progress_row, text="Sẵn sàng • 0%", font=ctk.CTkFont(family="Segoe UI", size=12, weight="bold"), text_color=self.C_TEXT_MUTED)
        self.lbl_pack_pct.pack(side="right")
        
        self.pack_progress = ctk.CTkProgressBar(main_card, fg_color="#101D40", progress_color=self.C_CYAN, height=6, corner_radius=3)
        self.pack_progress.pack(fill="x", padx=28, pady=(0, 16))
        self.pack_progress.set(0)

        # 5. Nút Khởi Tạo Lớn Phát Sáng Hình Pill (Chuẩn Theo Hình Ảnh Mẫu)
        self.btn_run_pack = ctk.CTkButton(
            main_card,
            text="⚡  KHỞI TẠO VÀ XUẤT GÓI KHÓA HỌC (KhoaHoc_Mac.zip)        ➔",
            font=ctk.CTkFont(family="Segoe UI", size=15, weight="bold"),
            fg_color=self.C_BLUE,
            hover_color=self.C_BLUE_HOVER,
            text_color=self.C_TEXT_WHITE,
            height=54,
            corner_radius=27,
            border_width=1.5,
            border_color=self.C_CYAN,
            command=self._run_pack_mac
        )
        self.btn_run_pack.pack(fill="x", padx=28, pady=(0, 24))

    def _render_pack_dropzone_empty(self):
        for w in self.dropzone_content.winfo_children(): w.destroy()
        
        center_wrapper = ctk.CTkFrame(self.dropzone_content, fg_color="transparent")
        center_wrapper.place(relx=0.5, rely=0.5, anchor="center")
        
        # Icon Tài liệu PowerPoint 3D lớn
        doc_card = ctk.CTkFrame(center_wrapper, fg_color="#14244E", corner_radius=18, width=80, height=80, border_width=1.5, border_color=self.C_CYAN)
        doc_card.pack(pady=(0, 12))
        doc_card.pack_propagate(False)
        
        ctk.CTkLabel(doc_card, text="P", font=ctk.CTkFont(family="Segoe UI", size=32, weight="bold"), text_color="#F97316").place(relx=0.4, rely=0.45, anchor="center")
        
        # Vòng tròn mũi tên tải lên
        up_circle = ctk.CTkFrame(doc_card, fg_color=self.C_BLUE, corner_radius=12, width=24, height=24, border_width=1, border_color=self.C_CYAN)
        up_circle.place(relx=0.75, rely=0.75, anchor="center")
        up_circle.pack_propagate(False)
        ctk.CTkLabel(up_circle, text="↑", font=ctk.CTkFont(size=14, weight="bold"), text_color="#FFFFFF").place(relx=0.5, rely=0.5, anchor="center")
        
        ctk.CTkLabel(center_wrapper, text="Kéo thả file PPTX vào đây", font=ctk.CTkFont(family="Segoe UI", size=16, weight="bold"), text_color=self.C_TEXT_WHITE).pack()
        ctk.CTkLabel(center_wrapper, text="hoặc nhấn nút \"Thêm File PPTX...\" để chọn tệp", font=ctk.CTkFont(family="Segoe UI", size=12), text_color=self.C_TEXT_MUTED).pack(pady=(4, 0))

    def _sel_pack_files(self):
        pths = filedialog.askopenfilenames(filetypes=[("PowerPoint Presentation", "*.pptx")])
        if pths:
            for p in pths:
                if p not in self.selected_files:
                    self.selected_files.append(p)
            self._render_pack_dropzone_list()

    def _render_pack_dropzone_list(self):
        if not self.selected_files:
            self._render_pack_dropzone_empty()
            self.pack_summary_lbl.configure(text="Chưa chọn tệp bài giảng nào", text_color=self.C_TEXT_WHITE)
            return
            
        for w in self.dropzone_content.winfo_children(): w.destroy()
        
        self.pack_summary_lbl.configure(text=f"Đã chọn {len(self.selected_files)} bài giảng sẵn sàng bọc thép", text_color=self.C_CYAN)
        
        scroll = ctk.CTkScrollableFrame(self.dropzone_content, fg_color="transparent")
        scroll.pack(fill="both", expand=True)
        
        for idx, fpath in enumerate(self.selected_files):
            item = ctk.CTkFrame(scroll, fg_color="#101D40", corner_radius=10, height=38, border_width=1, border_color="#203975")
            item.pack(fill="x", padx=4, pady=4)
            
            badge = ctk.CTkLabel(item, text=f"#{idx+1}", font=ctk.CTkFont(size=11, weight="bold"), text_color=self.C_CYAN, width=36)
            badge.pack(side="left", padx=(8, 4))
            
            fname = os.path.basename(fpath)
            fsize = f"{os.path.getsize(fpath) / (1024*1024):.1f} MB" if os.path.exists(fpath) else ""
            
            ctk.CTkLabel(item, text=f"{fname}  ({fsize})", font=ctk.CTkFont(size=12, weight="bold"), text_color=self.C_TEXT_WHITE).pack(side="left", padx=6)
            
            btn_del = ctk.CTkButton(
                item,
                text="✕",
                font=ctk.CTkFont(size=11, weight="bold"),
                width=28,
                height=24,
                fg_color="transparent",
                hover_color="#EF4444",
                text_color=self.C_TEXT_MUTED,
                corner_radius=6,
                command=lambda p=fpath: self._remove_pack_file(p)
            )
            btn_del.pack(side="right", padx=8)

    def _remove_pack_file(self, p):
        if p in self.selected_files:
            self.selected_files.remove(p)
            self._render_pack_dropzone_list()

    def _harden_pptx_for_mac(self, raw_bytes: bytes) -> bytes:
        """
        Khóa bảo vệ cấu trúc bài giảng PPTX trước khi đóng gói:
        1. Vô hiệu hóa Save As, Save a Copy, Export, Print trong CustomUI
        2. Vô hiệu hóa Copy, Cut, Duplicate slide và nội dung
        3. Ẩn nhóm Clipboard và các tab Backstage
        4. Xóa font nhúng để triệt tiêu popup cảnh báo font của PowerPoint
        """
        try:
            in_mem = io.BytesIO(raw_bytes)
            out_mem = io.BytesIO()
            
            custom_ui_2007 = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<customUI xmlns="http://schemas.microsoft.com/office/2006/01/customui">
    <commands>
        <command idMso="FileSave" enabled="true"/>
        <command idMso="FileSaveAs" enabled="false"/>
        <command idMso="FileSaveAsMenu" enabled="false"/>
        <command idMso="FileSaveAsMac" enabled="false"/>
        <command idMso="FileSaveAsPdfOrXps" enabled="false"/>
        <command idMso="FileSaveACopy" enabled="false"/>
        <command idMso="FileSaveCopyAs" enabled="false"/>
        <command idMso="FileSaveAsPicture" enabled="false"/>
        <command idMso="PictureSaveAs" enabled="false"/>
        <command idMso="SaveMediaAs" enabled="false"/>
        <command idMso="Export" enabled="false"/>
        <command idMso="FileExport" enabled="false"/>
        <command idMso="FileExportAsPdf" enabled="false"/>
        <command idMso="PublishToPdfOrXps" enabled="false"/>
        <command idMso="CreateVideo" enabled="false"/>
        <command idMso="FileExportToVideo" enabled="false"/>
        <command idMso="PackageForCd" enabled="false"/>
        <command idMso="CreateHandouts" enabled="false"/>
        <command idMso="Share" enabled="false"/>
        <command idMso="ShareDocument" enabled="false"/>
        <command idMso="FileSendAsAttachment" enabled="false"/>
        <command idMso="FileSendAsPdf" enabled="false"/>
        <command idMso="FileSendAsXps" enabled="false"/>
        <command idMso="FilePrint" enabled="false"/>
        <command idMso="FilePrintMac" enabled="false"/>
        <command idMso="FilePrintQuick" enabled="false"/>
        <command idMso="PrintPreviewAndPrint" enabled="false"/>
        <command idMso="ApplicationOptionsDialog" enabled="false"/>
        <command idMso="Duplicate" enabled="false"/>
        <command idMso="FileDuplicate" enabled="false"/>
        <command idMso="FileMove" enabled="false"/>
        <command idMso="Copy" enabled="false"/>
        <command idMso="Cut" enabled="false"/>
        <command idMso="Paste" enabled="false"/>
        <command idMso="PasteSpecial" enabled="false"/>
        <command idMso="ClipboardCopy" enabled="false"/>
        <command idMso="SlideCopy" enabled="false"/>
        <command idMso="SlidePaste" enabled="false"/>
        <command idMso="SlideDuplicate" enabled="false"/>
        <command idMso="SlideCut" enabled="false"/>
        <command idMso="SlideReuse" enabled="false"/>
        <command idMso="SlidesReuse" enabled="false"/>
        <command idMso="ReuseSlides" enabled="false"/>
        <command idMso="SlideMasterDuplicate" enabled="false"/>
        <command idMso="SlideMasterCopy" enabled="false"/>
        <command idMso="SlideLayoutDuplicate" enabled="false"/>
        <command idMso="SlideLayoutCopy" enabled="false"/>
        <command idMso="CopyFormat" enabled="false"/>
        <command idMso="ObjectDuplicate" enabled="false"/>
        <command idMso="SelectionDuplicate" enabled="false"/>
    </commands>
    <ribbon>
        <officeMenu>
            <button idMso="FileSaveAs" visible="false"/>
            <button idMso="FileSaveAsMenu" visible="false"/>
            <button idMso="FilePrint" visible="false"/>
            <button idMso="FilePrintMenu" visible="false"/>
            <menu idMso="FileSendMenu" visible="false"/>
            <button idMso="FilePublishToPdfOrXps" visible="false"/>
        </officeMenu>
        <tabs>
            <tab idMso="TabHome">
                <group idMso="GroupClipboard" visible="false"/>
            </tab>
        </tabs>
    </ribbon>
</customUI>""".encode('utf-8')

            custom_ui_2010 = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<customUI xmlns="http://schemas.microsoft.com/office/2009/07/customui">
    <commands>
        <command idMso="FileSave" enabled="true"/>
        <command idMso="FileSaveAs" enabled="false"/>
        <command idMso="FileSaveAsMenu" enabled="false"/>
        <command idMso="FileSaveAsMac" enabled="false"/>
        <command idMso="FileSaveAsPdfOrXps" enabled="false"/>
        <command idMso="FileSaveACopy" enabled="false"/>
        <command idMso="FileSaveCopyAs" enabled="false"/>
        <command idMso="FileSaveAsPicture" enabled="false"/>
        <command idMso="PictureSaveAs" enabled="false"/>
        <command idMso="SaveMediaAs" enabled="false"/>
        <command idMso="Export" enabled="false"/>
        <command idMso="FileExport" enabled="false"/>
        <command idMso="FileExportAsPdf" enabled="false"/>
        <command idMso="PublishToPdfOrXps" enabled="false"/>
        <command idMso="CreateVideo" enabled="false"/>
        <command idMso="FileExportToVideo" enabled="false"/>
        <command idMso="PackageForCd" enabled="false"/>
        <command idMso="CreateHandouts" enabled="false"/>
        <command idMso="Share" enabled="false"/>
        <command idMso="ShareDocument" enabled="false"/>
        <command idMso="FileSendAsAttachment" enabled="false"/>
        <command idMso="FileSendAsPdf" enabled="false"/>
        <command idMso="FileSendAsXps" enabled="false"/>
        <command idMso="FilePrint" enabled="false"/>
        <command idMso="FilePrintMac" enabled="false"/>
        <command idMso="FilePrintQuick" enabled="false"/>
        <command idMso="PrintPreviewAndPrint" enabled="false"/>
        <command idMso="ApplicationOptionsDialog" enabled="false"/>
        <command idMso="Duplicate" enabled="false"/>
        <command idMso="FileDuplicate" enabled="false"/>
        <command idMso="FileMove" enabled="false"/>
        <command idMso="Copy" enabled="false"/>
        <command idMso="Cut" enabled="false"/>
        <command idMso="Paste" enabled="false"/>
        <command idMso="PasteSpecial" enabled="false"/>
        <command idMso="ClipboardCopy" enabled="false"/>
        <command idMso="SlideCopy" enabled="false"/>
        <command idMso="SlidePaste" enabled="false"/>
        <command idMso="SlideDuplicate" enabled="false"/>
        <command idMso="SlideCut" enabled="false"/>
        <command idMso="SlideReuse" enabled="false"/>
        <command idMso="SlidesReuse" enabled="false"/>
        <command idMso="ReuseSlides" enabled="false"/>
        <command idMso="SlideMasterDuplicate" enabled="false"/>
        <command idMso="SlideMasterCopy" enabled="false"/>
        <command idMso="SlideLayoutDuplicate" enabled="false"/>
        <command idMso="SlideLayoutCopy" enabled="false"/>
        <command idMso="CopyFormat" enabled="false"/>
        <command idMso="ObjectDuplicate" enabled="false"/>
        <command idMso="SelectionDuplicate" enabled="false"/>
    </commands>
    <ribbon>
        <backstage>
            <tab idMso="TabSave" visible="false"/>
            <tab idMso="TabPrint" visible="false"/>
            <tab idMso="TabExport" visible="false"/>
            <tab idMso="TabShare" visible="false"/>
            <tab idMso="TabPublish" visible="false"/>
        </backstage>
        <tabs>
            <tab idMso="TabHome">
                <group idMso="GroupClipboard" visible="false"/>
            </tab>
        </tabs>
    </ribbon>
</customUI>""".encode('utf-8')

            with zipfile.ZipFile(in_mem, 'r') as zin, zipfile.ZipFile(out_mem, 'w', zipfile.ZIP_DEFLATED) as zout:
                rels_found = False
                for item in zin.infolist():
                    if item.filename.startswith('ppt/fonts/'):
                        continue
                    file_bytes = zin.read(item.filename)
                    if item.filename == '_rels/.rels':
                        rels_found = True
                        rels_str = file_bytes.decode('utf-8', errors='ignore')
                        if 'customUI/customUI.xml' not in rels_str:
                            rel_tag = '<Relationship Id="rIdCustomUI" Type="http://schemas.microsoft.com/office/2006/relationships/ui/extensibility" Target="customUI/customUI.xml"/>'
                            if '</Relationships>' in rels_str:
                                rels_str = rels_str.replace('</Relationships>', f'{rel_tag}</Relationships>')
                        if 'customUI/customUI14.xml' not in rels_str:
                            rel_tag14 = '<Relationship Id="rIdCustomUI14" Type="http://schemas.microsoft.com/office/2007/relationships/ui/extensibility" Target="customUI/customUI14.xml"/>'
                            if '</Relationships>' in rels_str:
                                rels_str = rels_str.replace('</Relationships>', f'{rel_tag14}</Relationships>')
                        file_bytes = rels_str.encode('utf-8')
                    elif item.filename == 'ppt/presentation.xml':
                        p_str = file_bytes.decode('utf-8', errors='ignore')
                        p_str = re.sub(r'(?is)<p:embeddedFontLst\b[^>]*>.*?</p:embeddedFontLst>', '', p_str)
                        p_str = re.sub(r'(?is)<p:embeddedFontLst\b[^>]*/>', '', p_str)
                        p_str = re.sub(r'(?is)<p:embedTrueTypeFonts\b[^>]*>.*?</p:embedTrueTypeFonts>', '<p:embedTrueTypeFonts val="0"/>', p_str)
                        p_str = re.sub(r'(?is)<p:embedTrueTypeFonts\b[^>]*/>', '<p:embedTrueTypeFonts val="0"/>', p_str)
                        p_str = re.sub(r'(?is)<p:saveSubsetFonts\b[^>]*>.*?</p:saveSubsetFonts>', '', p_str)
                        p_str = re.sub(r'(?is)<p:saveSubsetFonts\b[^>]*/>', '', p_str)
                        file_bytes = p_str.encode('utf-8')
                    elif item.filename == 'ppt/_rels/presentation.xml.rels':
                        r_str = file_bytes.decode('utf-8', errors='ignore')
                        r_str = re.sub(r'<Relationship[^>]*relationships/font[^>]*/>', '', r_str)
                        file_bytes = r_str.encode('utf-8')
                    zout.writestr(item, file_bytes)

                if not rels_found:
                    default_rels = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
<Relationship Id="rIdCustomUI" Type="http://schemas.microsoft.com/office/2006/relationships/ui/extensibility" Target="customUI/customUI.xml"/>
<Relationship Id="rIdCustomUI14" Type="http://schemas.microsoft.com/office/2007/relationships/ui/extensibility" Target="customUI/customUI14.xml"/>
</Relationships>""".encode('utf-8')
                    zout.writestr('_rels/.rels', default_rels)

                zout.writestr('customUI/customUI.xml', custom_ui_2007)
                zout.writestr('customUI/customUI14.xml', custom_ui_2010)

            return out_mem.getvalue()
        except Exception as e:
            return raw_bytes

    def _run_pack_mac(self):
        if not self.selected_files:
            return messagebox.showerror("Lỗi", "Vui lòng chọn ít nhất 1 bài giảng .pptx!")
        if not os.path.exists("SlideLock.app"):
            return messagebox.showerror("Lỗi", "Không tìm thấy thư mục vỏ 'SlideLock.app' trong hệ thống!")
            
        self.btn_run_pack.configure(state="disabled", text="⏳ ĐANG TIẾN HÀNH ĐÓNG GÓI BẢO MẬT...")
        self.pack_progress.set(0.2)
        self.lbl_pack_msg.configure(text="Đang mã hóa AES-256 GCM lõi bài giảng...")
        self.lbl_pack_pct.configure(text="Đang xử lý • 20%")
        
        def worker():
            try:
                mz = io.BytesIO()
                manifest = {}
                with zipfile.ZipFile(mz, 'w', zipfile.ZIP_DEFLATED) as zf:
                    for idx, p_pth in enumerate(self.selected_files):
                        orig_name = os.path.basename(p_pth)
                        safe_name = f"lesson_{idx}.pptx"
                        with open(p_pth, 'rb') as f_pptx:
                            raw_data = f_pptx.read()
                        hardened_data = self._harden_pptx_for_mac(raw_data)
                        zf.writestr(safe_name, hardened_data)
                        manifest[safe_name] = orig_name
                    zf.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False).encode('utf-8'))
                    zf.write("revocations.json", "revocations.json") if os.path.exists("revocations.json") else zf.writestr("revocations.json", "{}")
                
                self.pack_progress.set(0.5)
                self.lbl_pack_pct.configure(text="Đang xử lý • 50%")
                
                aesgcm = AESGCM(b"12345678901234567890123456789012")
                nonce = os.urandom(12)
                enc = aesgcm.encrypt(nonce, mz.getvalue(), None)
                with open("baigiang.khoa", "wb") as f: f.write(nonce + enc)
                
                counter = 1
                out_name = "KhoaHoc_Mac_1.zip"
                while os.path.exists(out_name):
                    counter += 1
                    out_name = f"KhoaHoc_Mac_{counter}.zip"
                    
                self.pack_progress.set(0.7)
                self.lbl_pack_msg.configure(text=f"Đang xuất file nén phân phối: {out_name}...")
                self.lbl_pack_pct.configure(text="Đang xử lý • 70%")
                
                with zipfile.ZipFile(out_name, 'w', zipfile.ZIP_DEFLATED) as zf:
                    base_folder = "KhoaHoc_Mac/"
                    for d_path in [base_folder, base_folder + "SlideLock.app/"]:
                        z_info_dir = zipfile.ZipInfo(d_path)
                        z_info_dir.create_system = 3
                        z_info_dir.external_attr = (0x41ED) << 16
                        zf.writestr(z_info_dir, "")
                        
                    z_info_file = zipfile.ZipInfo(f"{base_folder}baigiang.khoa")
                    z_info_file.create_system = 3
                    z_info_file.external_attr = (0x81A4) << 16
                    with open("baigiang.khoa", "rb") as f_in: zf.writestr(z_info_file, f_in.read())
                    
                    if os.path.exists("MoKhoaHoc.command"):
                        z_info_cmd = zipfile.ZipInfo(f"{base_folder}MoKhoaHoc.command")
                        z_info_cmd.create_system = 3
                        z_info_cmd.external_attr = (0x81ED) << 16
                        with open("MoKhoaHoc.command", "rb") as f_in: zf.writestr(z_info_cmd, f_in.read().replace(b"\r\n", b"\n"))
                        
                    for r, d, fs in os.walk("SlideLock.app"):
                        for folder in d:
                            dp = os.path.join(r, folder)
                            arcname_dir = os.path.relpath(dp, ".").replace("\\", "/") + "/"
                            z_info = zipfile.ZipInfo(base_folder + arcname_dir)
                            z_info.create_system = 3
                            z_info.external_attr = (0x41ED) << 16
                            zf.writestr(z_info, "")
                        for f in fs:
                            fp = os.path.join(r, f)
                            arcname = os.path.relpath(fp, ".").replace("\\", "/")
                            z_info = zipfile.ZipInfo.from_file(fp, base_folder + arcname)
                            z_info.create_system = 3
                            if "Contents/MacOS/" in arcname and not arcname.endswith(".plist") and not arcname.endswith(".txt"):
                                z_info.external_attr = (0x81ED) << 16
                            else:
                                z_info.external_attr = (0x81A4) << 16
                            with open(fp, "rb") as f_in: zf.writestr(z_info, f_in.read())
                
                os.remove("baigiang.khoa")
                
                self.pack_progress.set(1.0)
                self.lbl_pack_msg.configure(text=f"✓ Đã xuất xong gói {out_name} thành công!")
                self.lbl_pack_pct.configure(text="Hoàn tất • 100%")
                messagebox.showinfo("Thành Công", f"Đã xuất xong gói phân phối {out_name} siêu bảo mật!\n\nĐường dẫn tệp:\n{os.path.abspath(out_name)}")
            except Exception as e:
                messagebox.showerror("Lỗi", str(e))
            finally:
                self.btn_run_pack.configure(state="normal", text="⚡  KHỞI TẠO VÀ XUẤT GÓI KHÓA HỌC (KhoaHoc_Mac.zip)        ➔")
                
        threading.Thread(target=worker, daemon=True).start()

    # ══════════════════════════════════════════════════════════════════
    # TAB 2: CẤP KEY BẢN QUYỀN (ELECTRIC CYAN THEME)
    # ══════════════════════════════════════════════════════════════════
    def _generate_hmac_key(self, u):
        raw = f"{u.strip().upper()}".encode('utf-8')
        sig = hmac.new(b"12345678901234567890123456789012", raw, hashlib.sha256).digest()
        num = int.from_bytes(sig[:8], byteorder='big')
        code = str(num % 1000000000000).zfill(12)
        return f"{code[:4]}-{code[4:8]}-{code[8:12]}"

    def _build_tab_key(self):
        main_card = ctk.CTkFrame(self.tab_frames["tab_key"], fg_color=self.C_CARD_BG, corner_radius=22, border_width=1, border_color=self.C_BORDER)
        main_card.pack(fill="both", expand=True)
        
        header_frame = ctk.CTkFrame(main_card, fg_color="transparent")
        header_frame.pack(fill="x", padx=28, pady=(24, 20))
        
        round_icon_box = ctk.CTkFrame(header_frame, fg_color=self.C_BLUE, corner_radius=28, width=54, height=54, border_width=2, border_color=self.C_CYAN)
        round_icon_box.pack(side="left", padx=(0, 16))
        round_icon_box.pack_propagate(False)
        ctk.CTkLabel(round_icon_box, text="🔑", font=ctk.CTkFont(size=22)).place(relx=0.5, rely=0.5, anchor="center")
        
        header_text = ctk.CTkFrame(header_frame, fg_color="transparent")
        header_text.pack(side="left", fill="both", expand=True)
        ctk.CTkLabel(header_text, text="Cấp Key Bản Quyền (HMAC-SHA256)", font=ctk.CTkFont(family="Segoe UI", size=20, weight="bold"), text_color=self.C_TEXT_WHITE).pack(anchor="w")
        ctk.CTkLabel(header_text, text="Tạo khóa kích hoạt 12 chữ số gắn chặt với phần cứng MacBook của học viên.", font=ctk.CTkFont(family="Segoe UI", size=12), text_color=self.C_TEXT_MUTED).pack(anchor="w", pady=(2, 0))
        
        body_box = ctk.CTkFrame(main_card, fg_color="#08122C", corner_radius=16, border_width=2, border_color="#203975")
        body_box.pack(fill="both", expand=True, padx=28, pady=(0, 24))
        
        ctk.CTkLabel(body_box, text="NHẬP MACHINE ID CỦA HỌC VIÊN:", font=ctk.CTkFont(size=12, weight="bold"), text_color=self.C_CYAN).pack(anchor="w", padx=24, pady=(24, 8))
        
        self.entry_mid = ctk.CTkEntry(
            body_box,
            height=52,
            placeholder_text="Ví dụ: ABCD-1234-EF56-7890...",
            font=ctk.CTkFont(family="Consolas", size=16),
            fg_color="#0D1B3E",
            border_color="#233E78",
            border_width=2,
            corner_radius=12
        )
        self.entry_mid.pack(fill="x", padx=24, pady=(0, 16))
        
        ctk.CTkButton(
            body_box,
            text="✨ TẠO CHÌA KHÓA BẢN QUYỀN DUY NHẤT        ➔",
            font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"),
            fg_color=self.C_BLUE,
            hover_color=self.C_BLUE_HOVER,
            height=48,
            corner_radius=12,
            border_width=1,
            border_color=self.C_CYAN,
            command=self._gen_key_action
        ).pack(fill="x", padx=24, pady=(0, 20))
        
        ctk.CTkLabel(body_box, text="KHÓA KÍCH HOẠT (12 CHỮ SỐ BẢN QUYỀN):", font=ctk.CTkFont(size=12, weight="bold"), text_color=self.C_ACCENT_GREEN).pack(anchor="w", padx=24, pady=(0, 8))
        
        self.key_output_var = ctk.StringVar()
        self.entry_key_out = ctk.CTkEntry(
            body_box,
            textvariable=self.key_output_var,
            height=62,
            font=ctk.CTkFont(family="Consolas", size=24, weight="bold"),
            justify="center",
            state="readonly",
            fg_color="#0D1B3E",
            text_color=self.C_CYAN,
            border_color=self.C_CYAN,
            border_width=2,
            corner_radius=12
        )
        self.entry_key_out.pack(fill="x", padx=24, pady=(0, 16))
        
        self.btn_copy = ctk.CTkButton(
            body_box,
            text="📋 SAO CHÉP KEY VÀO BỘ NHỚ TẠM",
            font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
            fg_color="#101D40",
            hover_color="#1A2D60",
            text_color=self.C_TEXT_WHITE,
            height=44,
            corner_radius=10,
            command=self._copy_key_action
        )
        self.btn_copy.pack(fill="x", padx=24, pady=(0, 24))

    def _gen_key_action(self):
        mid = self.entry_mid.get().strip()
        if not mid: return messagebox.showerror("Lỗi", "Vui lòng nhập Machine ID của học viên!")
        self.key_output_var.set(self._generate_hmac_key(mid))
        self.btn_copy.configure(text="📋 SAO CHÉP KEY VÀO BỘ NHỚ TẠM", fg_color="#101D40", text_color=self.C_TEXT_WHITE)

    def _copy_key_action(self):
        key = self.key_output_var.get()
        if not key: return
        self.clipboard_clear()
        self.clipboard_append(key)
        self.btn_copy.configure(text="✓ ĐÃ SAO CHÉP KEY VÀO CLIPBOARD!", fg_color="#065F46", text_color="#34D399")
        self.after(2000, lambda: self.btn_copy.configure(text="📋 SAO CHÉP KEY VÀO BỘ NHỚ TẠM", fg_color="#101D40", text_color=self.C_TEXT_WHITE))

    # ══════════════════════════════════════════════════════════════════
    # TAB 4: QUẢN LÝ BLACKLIST
    # ══════════════════════════════════════════════════════════════════
    def _build_tab_ban(self):
        main_card = ctk.CTkFrame(self.tab_frames["tab_ban"], fg_color=self.C_CARD_BG, corner_radius=22, border_width=1, border_color=self.C_BORDER)
        main_card.pack(fill="both", expand=True)
        
        header_frame = ctk.CTkFrame(main_card, fg_color="transparent")
        header_frame.pack(fill="x", padx=28, pady=(24, 20))
        
        round_icon_box = ctk.CTkFrame(header_frame, fg_color="#EF4444", corner_radius=28, width=54, height=54, border_width=2, border_color="#F87171")
        round_icon_box.pack(side="left", padx=(0, 16))
        round_icon_box.pack_propagate(False)
        ctk.CTkLabel(round_icon_box, text="🚫", font=ctk.CTkFont(size=22)).place(relx=0.5, rely=0.5, anchor="center")
        
        header_text = ctk.CTkFrame(header_frame, fg_color="transparent")
        header_text.pack(side="left", fill="both", expand=True)
        ctk.CTkLabel(header_text, text="Quản Lý Danh Sách Đen (Blacklist)", font=ctk.CTkFont(family="Segoe UI", size=20, weight="bold"), text_color=self.C_TEXT_WHITE).pack(anchor="w")
        ctk.CTkLabel(header_text, text="Tước quyền sử dụng và cấm vĩnh viễn các máy tính vi phạm khỏi hệ thống.", font=ctk.CTkFont(family="Segoe UI", size=12), text_color=self.C_TEXT_MUTED).pack(anchor="w", pady=(2, 0))
        
        body_box = ctk.CTkFrame(main_card, fg_color="#08122C", corner_radius=16, border_width=2, border_color="#203975")
        body_box.pack(fill="both", expand=True, padx=28, pady=(0, 24))
        
        ctk.CTkLabel(body_box, text="NHẬP MACHINE ID CẦN CẤM KHẨN CẤP:", font=ctk.CTkFont(size=12, weight="bold"), text_color="#EF4444").pack(anchor="w", padx=24, pady=(20, 8))
        
        self.entry_ban = ctk.CTkEntry(
            body_box,
            height=50,
            placeholder_text="Dán Machine ID của thiết bị vi phạm...",
            font=ctk.CTkFont(family="Consolas", size=15),
            fg_color="#0D1B3E",
            text_color="#FCA5A5",
            border_color="#7F1D1D",
            border_width=2,
            corner_radius=12
        )
        self.entry_ban.pack(fill="x", padx=24, pady=(0, 14))
        
        ctk.CTkButton(
            body_box,
            text="🚫 TIÊU DIỆT & CẤM THIẾT BỊ NÀY VĨNH VIỄN",
            font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"),
            fg_color="#EF4444",
            hover_color="#DC2626",
            height=46,
            corner_radius=12,
            command=self._ban_action
        ).pack(fill="x", padx=24, pady=(0, 18))
        
        ctk.CTkLabel(body_box, text="DANH SÁCH THIẾT BỊ BỊ CẤM:", font=ctk.CTkFont(size=12, weight="bold"), text_color=self.C_TEXT_MUTED).pack(anchor="w", padx=24, pady=(0, 8))
        
        self.ban_box = ctk.CTkScrollableFrame(body_box, fg_color="#0D1B3E", corner_radius=12, height=140)
        self.ban_box.pack(fill="both", expand=True, padx=24, pady=(0, 20))
        self._refresh_ban_list()

    def _refresh_ban_list(self):
        for w in self.ban_box.winfo_children(): w.destroy()
        db = self.get_db()
        if not db:
            ctk.CTkLabel(self.ban_box, text="Chưa có thiết bị nào bị đưa vào danh sách đen.", font=ctk.CTkFont(size=12), text_color=self.C_TEXT_MUTED).pack(pady=30)
            return
            
        for mid in db.keys():
            item = ctk.CTkFrame(self.ban_box, fg_color="#1C1917", corner_radius=8, height=36)
            item.pack(fill="x", padx=4, pady=3)
            ctk.CTkLabel(item, text="BANNED", font=ctk.CTkFont(size=10, weight="bold"), text_color="#EF4444", width=55).pack(side="left", padx=8)
            ctk.CTkLabel(item, text=mid, font=ctk.CTkFont(family="Consolas", size=13, weight="bold"), text_color="#FCA5A5").pack(side="left", padx=6)
            ctk.CTkButton(
                item,
                text="Gỡ phạt",
                font=ctk.CTkFont(size=11, weight="bold"),
                width=65,
                height=26,
                fg_color="#334155",
                hover_color="#475569",
                corner_radius=6,
                command=lambda m=mid: self._quick_unban(m)
            ).pack(side="right", padx=8)

    def _quick_unban(self, mid):
        db = self.get_db()
        if mid in db:
            del db[mid]
            self.save_db(db)
            self._refresh_ban_list()
            messagebox.showinfo("Ân Xá", f"Đã tháo gỡ án phạt cho thiết bị {mid}!")

    def _ban_action(self):
        u = self.entry_ban.get().strip().upper()
        if not u: return messagebox.showerror("Lỗi", "Vui lòng nhập Machine ID cần cấm!")
        db = self.get_db()
        db[u] = 1
        self.save_db(db)
        self.entry_ban.delete(0, 'end')
        self._refresh_ban_list()
        messagebox.showinfo("Thành Công", f"Đã cấm vĩnh viễn thiết bị '{u}' khỏi toàn bộ hệ thống!")

    # ══════════════════════════════════════════════════════════════════
    # TAB 5: ÂN XÁ
    # ══════════════════════════════════════════════════════════════════
    def _build_tab_pardon(self):
        main_card = ctk.CTkFrame(self.tab_frames["tab_pardon"], fg_color=self.C_CARD_BG, corner_radius=22, border_width=1, border_color=self.C_BORDER)
        main_card.pack(fill="both", expand=True)
        
        header_frame = ctk.CTkFrame(main_card, fg_color="transparent")
        header_frame.pack(fill="x", padx=28, pady=(24, 20))
        
        round_icon_box = ctk.CTkFrame(header_frame, fg_color="#F59E0B", corner_radius=28, width=54, height=54, border_width=2, border_color="#FCD34D")
        round_icon_box.pack(side="left", padx=(0, 16))
        round_icon_box.pack_propagate(False)
        ctk.CTkLabel(round_icon_box, text="🕊️", font=ctk.CTkFont(size=22)).place(relx=0.5, rely=0.5, anchor="center")
        
        header_text = ctk.CTkFrame(header_frame, fg_color="transparent")
        header_text.pack(side="left", fill="both", expand=True)
        ctk.CTkLabel(header_text, text="Thẻ Bài Ân Xá Thiết Bị", font=ctk.CTkFont(family="Segoe UI", size=20, weight="bold"), text_color=self.C_TEXT_WHITE).pack(anchor="w")
        ctk.CTkLabel(header_text, text="Gỡ phạt trong danh sách đen và lập tức cấp lại chìa khóa gốc cho học viên.", font=ctk.CTkFont(family="Segoe UI", size=12), text_color=self.C_TEXT_MUTED).pack(anchor="w", pady=(2, 0))
        
        body_box = ctk.CTkFrame(main_card, fg_color="#08122C", corner_radius=16, border_width=2, border_color="#203975")
        body_box.pack(fill="both", expand=True, padx=28, pady=(0, 24))
        
        ctk.CTkLabel(body_box, text="NHẬP MACHINE ID ĐANG BỊ CẤM CẦN ÂN XÁ:", font=ctk.CTkFont(size=12, weight="bold"), text_color="#F59E0B").pack(anchor="w", padx=24, pady=(20, 8))
        
        self.entry_pardon = ctk.CTkEntry(
            body_box,
            height=50,
            placeholder_text="Nhập Machine ID đang bị cấm...",
            font=ctk.CTkFont(family="Consolas", size=15),
            fg_color="#0D1B3E",
            border_color="#78350F",
            border_width=2,
            corner_radius=12
        )
        self.entry_pardon.pack(fill="x", padx=24, pady=(0, 16))
        
        ctk.CTkButton(
            body_box,
            text="🕊️ GỠ ÁN PHẠT & XUẤT LẠI KEY GỐC",
            font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"),
            fg_color="#F59E0B",
            hover_color="#D97706",
            height=46,
            corner_radius=12,
            command=self._pardon_action
        ).pack(fill="x", padx=24, pady=(0, 20))
        
        ctk.CTkLabel(body_box, text="CHÌA KHÓA GỐC ĐỂ TIẾP TỤC HỌC BÀI:", font=ctk.CTkFont(size=12, weight="bold"), text_color="#F59E0B").pack(anchor="w", padx=24, pady=(0, 8))
        
        self.pardon_out_var = ctk.StringVar()
        self.entry_pardon_out = ctk.CTkEntry(
            body_box,
            textvariable=self.pardon_out_var,
            height=60,
            font=ctk.CTkFont(family="Consolas", size=24, weight="bold"),
            justify="center",
            state="readonly",
            fg_color="#0D1B3E",
            text_color="#F59E0B",
            border_color="#F59E0B",
            border_width=2,
            corner_radius=12
        )
        self.entry_pardon_out.pack(fill="x", padx=24, pady=(0, 24))

    def _pardon_action(self):
        u = self.entry_pardon.get().strip().upper()
        if not u: return messagebox.showerror("Lỗi", "Vui lòng nhập Machine ID cần ân xá!")
        db = self.get_db()
        if u in db:
            del db[u]
            self.save_db(db)
        key = self._generate_hmac_key(u)
        self.pardon_out_var.set(key)
        self._refresh_ban_list()
        messagebox.showinfo("Ân Xá Thành Công", f"Đã gỡ án phạt cho thiết bị '{u}'!\nHọc viên có thể dùng Key gốc bên dưới để tiếp tục học bài.")

if __name__ == "__main__":
    app = SlideLockModernAdmin()
    app.mainloop()
