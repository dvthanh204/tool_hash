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

class ModernAuthorApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("SlideLock Admin Suite • Hệ Thống Bảo Mật Bài Giảng macOS")
        self.geometry("1060x720")
        self.minsize(980, 660)
        self.configure(fg_color="#090D16") # Deep Cyber Obsidian
        
        # Biến lưu trữ trạng thái
        self.selected_files = []
        self.single_lock_files = []
        self.current_tab = "tab_pack"
        
        self._init_layout()
        self.update_system_stats()
        self.select_tab("tab_pack")

    def _init_layout(self):
        # ── SIDEBAR TRÁI ─────────────────────────────────────────────
        self.sidebar = ctk.CTkFrame(self, fg_color="#0F172A", width=250, corner_radius=0, border_width=1, border_color="#1E293B")
        self.sidebar.pack(side="left", fill="y")
        self.sidebar.pack_propagate(False)
        
        # Logo & App Title
        logo_frame = ctk.CTkFrame(self.sidebar, fg_color="transparent")
        logo_frame.pack(fill="x", padx=20, pady=(24, 15))
        
        brand_icon = ctk.CTkLabel(logo_frame, text="✦", font=ctk.CTkFont(size=26, weight="bold"), text_color="#6366F1")
        brand_icon.pack(side="left", padx=(0, 8))
        
        brand_title = ctk.CTkLabel(logo_frame, text="SLIDELOCK", font=ctk.CTkFont(family="Segoe UI", size=20, weight="bold"), text_color="#F8FAFC")
        brand_title.pack(side="left")
        
        brand_sub = ctk.CTkLabel(self.sidebar, text="ADMIN SECURITY WORKSPACE", font=ctk.CTkFont(family="Segoe UI", size=9, weight="bold"), text_color="#64748B")
        brand_sub.pack(anchor="w", padx=24, pady=(0, 15))
        
        # Trạng thái Shell Engine Pill
        self.status_pill = ctk.CTkFrame(self.sidebar, fg_color="#1E293B", corner_radius=12, height=32)
        self.status_pill.pack(fill="x", padx=18, pady=(0, 20))
        self.status_dot = ctk.CTkLabel(self.status_pill, text="●", font=ctk.CTkFont(size=14), text_color="#10B981")
        self.status_dot.pack(side="left", padx=(12, 6), pady=6)
        self.status_text = ctk.CTkLabel(self.status_pill, text="Engine: macOS 14/15 OK", font=ctk.CTkFont(size=11, weight="bold"), text_color="#94A3B8")
        self.status_text.pack(side="left", pady=6)
        
        # Menu Navigation Buttons
        self.nav_buttons = {}
        nav_items = [
            ("tab_pack", "⚡ Đóng Gói Khóa Học", "#6366F1"),
            ("tab_single", "🔒 Khóa PPTX Lẻ", "#8B5CF6"),
            ("tab_key", "🔑 Cấp Key Bản Quyền", "#3B82F6"),
            ("tab_ban", "🚫 Quản Lý Blacklist", "#EF4444"),
            ("tab_pardon", "🕊️ Thẻ Bài Ân Xá", "#F59E0B")
        ]
        
        for tab_id, label, accent in nav_items:
            btn = ctk.CTkButton(
                self.sidebar,
                text=label,
                font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
                fg_color="transparent",
                text_color="#94A3B8",
                hover_color="#1E293B",
                anchor="w",
                height=44,
                corner_radius=10,
                command=lambda t=tab_id: self.select_tab(t)
            )
            btn.pack(fill="x", padx=14, pady=4)
            self.nav_buttons[tab_id] = (btn, accent)
            
        # Thống kê tóm tắt ở đáy Sidebar
        self.sidebar_footer = ctk.CTkFrame(self.sidebar, fg_color="#090D16", corner_radius=12, border_width=1, border_color="#1E293B")
        self.sidebar_footer.pack(side="bottom", fill="x", padx=14, pady=16)
        
        self.lbl_stat_banned = ctk.CTkLabel(self.sidebar_footer, text="Máy bị cấm: 0", font=ctk.CTkFont(size=11), text_color="#64748B")
        self.lbl_stat_banned.pack(anchor="w", padx=12, pady=(10, 2))
        
        self.lbl_stat_shell = ctk.CTkLabel(self.sidebar_footer, text="Shell: SlideLock.app", font=ctk.CTkFont(size=11), text_color="#10B981")
        self.lbl_stat_shell.pack(anchor="w", padx=12, pady=(2, 10))

        # ── KHU VỰC NỘI DUNG CHÍNH (MAIN CONTENT) ─────────────────────
        self.content_area = ctk.CTkFrame(self, fg_color="transparent")
        self.content_area.pack(side="right", fill="both", expand=True, padx=30, pady=24)
        
        self.tab_frames = {
            "tab_pack": ctk.CTkFrame(self.content_area, fg_color="transparent"),
            "tab_single": ctk.CTkFrame(self.content_area, fg_color="transparent"),
            "tab_key": ctk.CTkFrame(self.content_area, fg_color="transparent"),
            "tab_ban": ctk.CTkFrame(self.content_area, fg_color="transparent"),
            "tab_pardon": ctk.CTkFrame(self.content_area, fg_color="transparent")
        }
        
        self._build_tab_pack()
        self._build_tab_single()
        self._build_tab_key()
        self._build_tab_ban()
        self._build_tab_pardon()

    def get_db(self):
        if os.path.exists("revocations.json"):
            try:
                return json.load(open("revocations.json", "r", encoding="utf-8"))
            except: return {}
        return {}

    def save_db(self, d):
        json.dump(d, open("revocations.json", "w", encoding="utf-8"), indent=4)
        self.update_system_stats()

    def update_system_stats(self):
        db = self.get_db()
        banned_count = len(db)
        self.lbl_stat_banned.configure(text=f"Máy bị cấm: {banned_count} thiết bị")
        
        has_app = os.path.exists("SlideLock.app")
        if has_app:
            self.status_dot.configure(text_color="#10B981")
            self.status_text.configure(text="Engine: macOS Sẵn Sàng")
            self.lbl_stat_shell.configure(text="Shell: SlideLock.app ✓", text_color="#10B981")
        else:
            self.status_dot.configure(text_color="#EF4444")
            self.status_text.configure(text="Engine: Thiếu SlideLock.app")
            self.lbl_stat_shell.configure(text="Shell: Chưa nạp app!", text_color="#EF4444")

    def select_tab(self, tab_id):
        self.current_tab = tab_id
        for tid, (btn, accent) in self.nav_buttons.items():
            if tid == tab_id:
                btn.configure(fg_color="#1E293B", text_color="#FFFFFF")
            else:
                btn.configure(fg_color="transparent", text_color="#94A3B8")
                
        for frame in self.tab_frames.values():
            frame.pack_forget()
            
        self.tab_frames[tab_id].pack(fill="both", expand=True)

    def _create_card(self, parent, title, subtitle):
        card = ctk.CTkFrame(parent, fg_color="#0F172A", corner_radius=20, border_width=1, border_color="#1E293B")
        card.pack(fill="both", expand=True, padx=10, pady=10)
        
        header = ctk.CTkFrame(card, fg_color="transparent")
        header.pack(fill="x", padx=32, pady=(28, 16))
        
        ctk.CTkLabel(header, text=title, font=ctk.CTkFont(family="Segoe UI", size=22, weight="bold"), text_color="#F8FAFC").pack(anchor="w")
        ctk.CTkLabel(header, text=subtitle, font=ctk.CTkFont(family="Segoe UI", size=13), text_color="#64748B").pack(anchor="w", pady=(4, 0))
        
        body = ctk.CTkFrame(card, fg_color="transparent")
        body.pack(fill="both", expand=True, padx=32, pady=(0, 24))
        return body

    # ══════════════════════════════════════════════════════════════════
    # TAB 1: ĐÓNG GÓI KHÓA HỌC
    # ══════════════════════════════════════════════════════════════════
    def _build_tab_pack(self):
        body = self._create_card(
            self.tab_frames["tab_pack"],
            "Đóng Gói Khóa Học Cho Mac (Universal)",
            "Đóng gói toàn bộ bài giảng PPTX thành file .zip phân phối kèm app SlideLock đã ký số."
        )
        
        # Khu vực chọn tệp
        picker_box = ctk.CTkFrame(body, fg_color="#1E293B", corner_radius=14, border_width=1, border_color="#334155")
        picker_box.pack(fill="x", pady=(0, 16), ipady=8)
        
        self.pack_file_count_lbl = ctk.CTkLabel(picker_box, text="Chưa chọn tệp bài giảng nào", font=ctk.CTkFont(size=13, weight="bold"), text_color="#94A3B8")
        self.pack_file_count_lbl.pack(side="left", padx=20)
        
        btn_sel = ctk.CTkButton(
            picker_box,
            text="📁 Thêm File PPTX...",
            font=ctk.CTkFont(size=13, weight="bold"),
            fg_color="#3B82F6",
            hover_color="#2563EB",
            height=38,
            corner_radius=10,
            command=self._sel_pack_files
        )
        btn_sel.pack(side="right", padx=16, pady=8)
        
        # Danh sách tệp cuộn được (File Scrollable List)
        self.pack_files_frame = ctk.CTkScrollableFrame(body, fg_color="#090D16", corner_radius=12, height=180, border_width=1, border_color="#1E293B")
        self.pack_files_frame.pack(fill="both", expand=True, pady=(0, 16))
        self._refresh_pack_file_list()
        
        # Progress Bar & Status
        self.pack_progress = ctk.CTkProgressBar(body, fg_color="#1E293B", progress_color="#10B981", height=8, corner_radius=4)
        self.pack_progress.pack(fill="x", pady=(0, 12))
        self.pack_progress.set(0)
        
        self.pack_status_lbl = ctk.CTkLabel(body, text="Sẵn sàng đóng gói bài giảng.", font=ctk.CTkFont(size=12), text_color="#64748B")
        self.pack_status_lbl.pack(anchor="w", pady=(0, 12))
        
        # Nút Build Lớn với Hiệu Ứng
        self.btn_pack_run = ctk.CTkButton(
            body,
            text="⚡ KHỞI TẠO VÀ XUẤT GÓI KHÓA HỌC (KhoaHoc_Mac.zip)",
            font=ctk.CTkFont(family="Segoe UI", size=15, weight="bold"),
            fg_color="#10B981",
            hover_color="#059669",
            height=50,
            corner_radius=12,
            command=self._run_pack_mac
        )
        self.btn_pack_run.pack(fill="x")

    def _sel_pack_files(self):
        pths = filedialog.askopenfilenames(filetypes=[("PowerPoint Presentation", "*.pptx")])
        if pths:
            for p in pths:
                if p not in self.selected_files:
                    self.selected_files.append(p)
            self._refresh_pack_file_list()

    def _refresh_pack_file_list(self):
        for widget in self.pack_files_frame.winfo_children():
            widget.destroy()
            
        if not self.selected_files:
            empty_lbl = ctk.CTkLabel(self.pack_files_frame, text="Chưa có bài học nào được chọn. Nhấn 'Thêm File PPTX...' bên trên.", font=ctk.CTkFont(size=12), text_color="#475569")
            empty_lbl.pack(pady=40)
            self.pack_file_count_lbl.configure(text="Chưa chọn tệp bài giảng nào", text_color="#94A3B8")
            return
            
        self.pack_file_count_lbl.configure(text=f"Đã chọn: {len(self.selected_files)} bài giảng", text_color="#38BDF8")
        
        for idx, fpath in enumerate(self.selected_files):
            item = ctk.CTkFrame(self.pack_files_frame, fg_color="#131B2A", corner_radius=8, height=36)
            item.pack(fill="x", padx=4, pady=3)
            
            badge = ctk.CTkLabel(item, text=f"#{idx+1}", font=ctk.CTkFont(size=11, weight="bold"), text_color="#6366F1", width=36)
            badge.pack(side="left", padx=(8, 4))
            
            fname = os.path.basename(fpath)
            fsize = f"{os.path.getsize(fpath) / (1024*1024):.1f} MB" if os.path.exists(fpath) else ""
            
            name_lbl = ctk.CTkLabel(item, text=f"{fname}  ({fsize})", font=ctk.CTkFont(size=12, weight="bold"), text_color="#E2E8F0")
            name_lbl.pack(side="left", padx=6)
            
            btn_del = ctk.CTkButton(
                item,
                text="✕",
                font=ctk.CTkFont(size=11, weight="bold"),
                width=28,
                height=24,
                fg_color="transparent",
                hover_color="#EF4444",
                text_color="#94A3B8",
                corner_radius=6,
                command=lambda p=fpath: self._remove_pack_file(p)
            )
            btn_del.pack(side="right", padx=8)

    def _remove_pack_file(self, p):
        if p in self.selected_files:
            self.selected_files.remove(p)
            self._refresh_pack_file_list()

    def _run_pack_mac(self):
        if not self.selected_files:
            return messagebox.showerror("Lỗi", "Vui lòng chọn ít nhất 1 file .pptx để đóng gói!")
        if not os.path.exists("SlideLock.app"):
            return messagebox.showerror("Lỗi", "Không tìm thấy thư mục 'SlideLock.app' vỏ hệ thống trong thư mục làm việc!")
            
        self.btn_pack_run.configure(state="disabled", text="⏳ Đang mã hóa và đóng gói...")
        self.pack_progress.set(0.2)
        self.pack_status_lbl.configure(text="Đang mã hóa AES-256 GCM lõi bài giảng...")
        
        def worker():
            try:
                mz = io.BytesIO()
                manifest = {}
                with zipfile.ZipFile(mz, 'w', zipfile.ZIP_DEFLATED) as zf:
                    for idx, p_pth in enumerate(self.selected_files):
                        orig_name = os.path.basename(p_pth)
                        safe_name = f"lesson_{idx}.pptx"
                        with open(p_pth, 'rb') as f_pptx:
                            zf.writestr(safe_name, f_pptx.read())
                        manifest[safe_name] = orig_name
                    zf.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False).encode('utf-8'))
                    zf.write("revocations.json", "revocations.json") if os.path.exists("revocations.json") else zf.writestr("revocations.json", "{}")
                
                self.pack_progress.set(0.5)
                self.pack_status_lbl.configure(text="Đang khởi tạo mã hóa chống dịch ngược...")
                
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
                self.pack_status_lbl.configure(text=f"Đang đóng gói file phân phối: {out_name}...")
                
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
                self.pack_status_lbl.configure(text=f"✓ Đã xuất thành công gói {out_name}!")
                messagebox.showinfo("Thành Công", f"Đã xuất xong gói phân phối {out_name}!\n\nĐường dẫn tệp:\n{os.path.abspath(out_name)}")
            except Exception as e:
                messagebox.showerror("Lỗi", str(e))
            finally:
                self.btn_pack_run.configure(state="normal", text="⚡ KHỞI TẠO VÀ XUẤT GÓI KHÓA HỌC (KhoaHoc_Mac.zip)")
                
        threading.Thread(target=worker, daemon=True).start()

    # ══════════════════════════════════════════════════════════════════
    # TAB 2: KHÓA FILE PPTX LẺ
    # ══════════════════════════════════════════════════════════════════
    def _build_tab_single(self):
        body = self._create_card(
            self.tab_frames["tab_single"],
            "Khóa Mã Hóa File PPTX Lẻ",
            "Gán mã lỗi 0xSL-E994 & mã hóa AES-GCM. Học viên mở trực tiếp sẽ báo lỗi, bắt buộc mở qua SlideLock."
        )
        
        picker_box = ctk.CTkFrame(body, fg_color="#1E293B", corner_radius=14, border_width=1, border_color="#334155")
        picker_box.pack(fill="x", pady=(0, 16), ipady=8)
        
        self.single_count_lbl = ctk.CTkLabel(picker_box, text="Chưa chọn file PPTX nào", font=ctk.CTkFont(size=13, weight="bold"), text_color="#94A3B8")
        self.single_count_lbl.pack(side="left", padx=20)
        
        btn_sel = ctk.CTkButton(
            picker_box,
            text="📁 Chọn File PPTX...",
            font=ctk.CTkFont(size=13, weight="bold"),
            fg_color="#8B5CF6",
            hover_color="#7C3AED",
            height=38,
            corner_radius=10,
            command=self._sel_single_files
        )
        btn_sel.pack(side="right", padx=16, pady=8)
        
        self.single_files_frame = ctk.CTkScrollableFrame(body, fg_color="#090D16", corner_radius=12, height=200, border_width=1, border_color="#1E293B")
        self.single_files_frame.pack(fill="both", expand=True, pady=(0, 16))
        self._refresh_single_file_list()
        
        btn_lock = ctk.CTkButton(
            body,
            text="🔒 MÃ HÓA & GÁN MÃ LỖI SLIDELOCK NGAY",
            font=ctk.CTkFont(family="Segoe UI", size=15, weight="bold"),
            fg_color="#6366F1",
            hover_color="#4F46E5",
            height=50,
            corner_radius=12,
            command=self._run_single_lock
        )
        btn_lock.pack(fill="x")

    def _sel_single_files(self):
        pths = filedialog.askopenfilenames(filetypes=[("PowerPoint Presentation", "*.pptx")])
        if pths:
            for p in pths:
                if p not in self.single_lock_files:
                    self.single_lock_files.append(p)
            self._refresh_single_file_list()

    def _refresh_single_file_list(self):
        for widget in self.single_files_frame.winfo_children():
            widget.destroy()
            
        if not self.single_lock_files:
            empty_lbl = ctk.CTkLabel(self.single_files_frame, text="Chưa có file PPTX nào được chọn.", font=ctk.CTkFont(size=12), text_color="#475569")
            empty_lbl.pack(pady=40)
            self.single_count_lbl.configure(text="Chưa chọn file PPTX nào", text_color="#94A3B8")
            return
            
        self.single_count_lbl.configure(text=f"Đã chọn: {len(self.single_lock_files)} tệp", text_color="#C084FC")
        
        for idx, fpath in enumerate(self.single_lock_files):
            item = ctk.CTkFrame(self.single_files_frame, fg_color="#131B2A", corner_radius=8, height=36)
            item.pack(fill="x", padx=4, pady=3)
            
            badge = ctk.CTkLabel(item, text=f"PPTX", font=ctk.CTkFont(size=10, weight="bold"), text_color="#F97316", width=42)
            badge.pack(side="left", padx=(8, 4))
            
            fname = os.path.basename(fpath)
            name_lbl = ctk.CTkLabel(item, text=fname, font=ctk.CTkFont(size=12, weight="bold"), text_color="#E2E8F0")
            name_lbl.pack(side="left", padx=6)
            
            btn_del = ctk.CTkButton(
                item,
                text="✕",
                font=ctk.CTkFont(size=11, weight="bold"),
                width=28,
                height=24,
                fg_color="transparent",
                hover_color="#EF4444",
                text_color="#94A3B8",
                corner_radius=6,
                command=lambda p=fpath: self._remove_single_file(p)
            )
            btn_del.pack(side="right", padx=8)

    def _remove_single_file(self, p):
        if p in self.single_lock_files:
            self.single_lock_files.remove(p)
            self._refresh_single_file_list()

    def _run_single_lock(self):
        if not self.single_lock_files:
            return messagebox.showerror("Lỗi", "Vui lòng chọn ít nhất 1 file PPTX!")
        try:
            aesgcm = AESGCM(b"12345678901234567890123456789012")
            locked_count = 0
            out_files = []
            for p_pth in self.single_lock_files:
                if not os.path.exists(p_pth): continue
                with open(p_pth, "rb") as f_in:
                    raw_data = f_in.read()
                
                if raw_data.startswith(b"SLIDELOCK_ENCRYPTED_FILE_V1"):
                    continue
                
                nonce = os.urandom(12)
                enc = aesgcm.encrypt(nonce, raw_data, None)
                payload = nonce + enc
                
                header = (
                    "SLIDELOCK_ENCRYPTED_FILE_V1\n"
                    "[ERROR_CODE: 0xSL-E994-UNAUTHORIZED_SAVE_AS_DETECTED]\n"
                    "================================================================================\n"
                    "⚠️ CẢNH BÁO BẢO MẬT BẢN QUYỀN SLIDELOCK:\n"
                    "MÃ LỖI (ERROR CODE): 0xSL-E994-UNAUTHORIZED_SAVE_AS_DETECTED\n"
                    "TRẠNG THÁI: TỆP BÀI GIẢNG ĐÃ BỊ KHÓA BẢN QUYỀN DO PHÁT HIỆN LƯU / SAVE AS TRÁI PHÉP.\n"
                    "THÔNG BÁO: Tệp này không thể mở bằng Microsoft PowerPoint thông thường.\n"
                    "BẮT BUỘC PHẢI MỞ THÔNG QUA ỨNG DỤNG SLIDELOCK ĐÃ ĐƯỢC CẤP KEY HỢP LỆ.\n"
                    f"THỜI GIAN KHÓA: {datetime.now().isoformat()}\n"
                    "================================================================================\n"
                    "---SLIDELOCK_PAYLOAD_BEGIN---\n"
                ).encode('utf-8')
                
                dirname = os.path.dirname(p_pth)
                base = os.path.splitext(os.path.basename(p_pth))[0]
                out_path = os.path.join(dirname, f"{base}_locked.pptx")
                with open(out_path, "wb") as f_out:
                    f_out.write(header + payload)
                locked_count += 1
                out_files.append(os.path.basename(out_path))
                
            if locked_count > 0:
                files_str = "\n".join(out_files[:5])
                if len(out_files) > 5:
                    files_str += f"\n... và {len(out_files) - 5} tệp khác"
                messagebox.showinfo("Thành Công", f"Đã mã hóa và gán mã lỗi SlideLock cho {locked_count} tệp!\n\nDanh sách:\n{files_str}\n\nKhi mở bằng PowerPoint máy sẽ báo lỗi không đọc được. Bắt buộc phải mở qua SlideLock!")
            else:
                messagebox.showwarning("Thông Báo", "Tất cả các tệp được chọn đã được mã hóa từ trước!")
        except Exception as e:
            messagebox.showerror("Lỗi", str(e))

    # ══════════════════════════════════════════════════════════════════
    # TAB 3: CẤP KEY BẢN QUYỀN
    # ══════════════════════════════════════════════════════════════════
    def _generate_hmac_key(self, u):
        raw = f"{u.strip().upper()}".encode('utf-8')
        sig = hmac.new(b"12345678901234567890123456789012", raw, hashlib.sha256).digest()
        num = int.from_bytes(sig[:8], byteorder='big')
        code = str(num % 1000000000000).zfill(12)
        return f"{code[:4]}-{code[4:8]}-{code[8:12]}"

    def _build_tab_key(self):
        body = self._create_card(
            self.tab_frames["tab_key"],
            "Cấp Key Bản Quyền (HMAC-SHA256)",
            "Tạo khóa kích hoạt gắn chặt với phần cứng MacBook của từng học viên."
        )
        
        ctk.CTkLabel(body, text="NHẬP MÃ THIẾT BỊ (MACHINE ID DO HỌC VIÊN GỬI):", font=ctk.CTkFont(size=12, weight="bold"), text_color="#94A3B8").pack(anchor="w", pady=(10, 6))
        
        self.entry_machine_id = ctk.CTkEntry(
            body,
            height=50,
            placeholder_text="Ví dụ: ABCD-1234-EF56-7890...",
            font=ctk.CTkFont(family="Consolas", size=16),
            fg_color="#090D16",
            border_color="#334155",
            border_width=2,
            corner_radius=12
        )
        self.entry_machine_id.pack(fill="x", pady=(0, 16))
        
        btn_gen = ctk.CTkButton(
            body,
            text="✨ TẠO CHÌA KHÓA BẢN QUYỀN DUY NHẤT",
            font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"),
            fg_color="#3B82F6",
            hover_color="#2563EB",
            height=46,
            corner_radius=12,
            command=self._generate_key_action
        )
        btn_gen.pack(fill="x", pady=(0, 20))
        
        ctk.CTkLabel(body, text="KHÓA KÍCH HOẠT ĐƯỢC TẠO RA (12 CHỮ SỐ):", font=ctk.CTkFont(size=12, weight="bold"), text_color="#10B981").pack(anchor="w", pady=(0, 6))
        
        self.generated_key_var = ctk.StringVar()
        self.entry_key_output = ctk.CTkEntry(
            body,
            textvariable=self.generated_key_var,
            height=60,
            font=ctk.CTkFont(family="Consolas", size=24, weight="bold"),
            justify="center",
            state="readonly",
            fg_color="#090D16",
            text_color="#10B981",
            border_color="#10B981",
            border_width=2,
            corner_radius=12
        )
        self.entry_key_output.pack(fill="x", pady=(0, 14))
        
        self.btn_copy_key = ctk.CTkButton(
            body,
            text="📋 SAO CHÉP KEY VÀO BỘ NHỚ TẠM",
            font=ctk.CTkFont(family="Segoe UI", size=13, weight="bold"),
            fg_color="#1E293B",
            hover_color="#334155",
            text_color="#F8FAFC",
            height=42,
            corner_radius=10,
            command=self._copy_key_action
        )
        self.btn_copy_key.pack(fill="x")

    def _generate_key_action(self):
        mid = self.entry_machine_id.get().strip()
        if not mid:
            return messagebox.showerror("Lỗi", "Vui lòng nhập Machine ID của học viên!")
        key = self._generate_hmac_key(mid)
        self.generated_key_var.set(key)
        self.btn_copy_key.configure(text="📋 SAO CHÉP KEY VÀO BỘ NHỚ TẠM", fg_color="#1E293B", text_color="#F8FAFC")

    def _copy_key_action(self):
        key = self.generated_key_var.get()
        if not key: return
        self.clipboard_clear()
        self.clipboard_append(key)
        self.btn_copy_key.configure(text="✓ ĐÃ SAO CHÉP KEY THÀNH CÔNG!", fg_color="#065F46", text_color="#34D399")
        self.after(2000, lambda: self.btn_copy_key.configure(text="📋 SAO CHÉP KEY VÀO BỘ NHỚ TẠM", fg_color="#1E293B", text_color="#F8FAFC"))

    # ══════════════════════════════════════════════════════════════════
    # TAB 4: QUẢN LÝ BLACKLIST (KHÓA MÁY)
    # ══════════════════════════════════════════════════════════════════
    def _build_tab_ban(self):
        body = self._create_card(
            self.tab_frames["tab_ban"],
            "Quản Lý Danh Sách Đen (Blacklist)",
            "Tước quyền sử dụng và cấm vĩnh viễn các máy tính vi phạm bản quyền khỏi hệ thống."
        )
        
        ctk.CTkLabel(body, text="NHẬP MACHINE ID CẦN CẤM KHẨN CẤP:", font=ctk.CTkFont(size=12, weight="bold"), text_color="#EF4444").pack(anchor="w", pady=(10, 6))
        
        self.entry_ban_id = ctk.CTkEntry(
            body,
            height=50,
            placeholder_text="Dán Machine ID của thiết bị vi phạm...",
            font=ctk.CTkFont(family="Consolas", size=15),
            fg_color="#090D16",
            text_color="#F87171",
            border_color="#7F1D1D",
            border_width=2,
            corner_radius=12
        )
        self.entry_ban_id.pack(fill="x", pady=(0, 14))
        
        btn_ban = ctk.CTkButton(
            body,
            text="🚫 TIÊU DIỆT & CẤM THIẾT BỊ NÀY VĨNH VIỄN",
            font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"),
            fg_color="#EF4444",
            hover_color="#DC2626",
            height=46,
            corner_radius=12,
            command=self._ban_device_action
        )
        btn_ban.pack(fill="x", pady=(0, 20))
        
        ctk.CTkLabel(body, text="DANH SÁCH THIẾT BỊ ĐANG BỊ CẤM TRONG HỆ THỐNG:", font=ctk.CTkFont(size=12, weight="bold"), text_color="#94A3B8").pack(anchor="w", pady=(0, 6))
        
        self.ban_list_frame = ctk.CTkScrollableFrame(body, fg_color="#090D16", corner_radius=12, height=160, border_width=1, border_color="#1E293B")
        self.ban_list_frame.pack(fill="both", expand=True)
        self._refresh_ban_list()

    def _refresh_ban_list(self):
        for w in self.ban_list_frame.winfo_children(): w.destroy()
        db = self.get_db()
        if not db:
            ctk.CTkLabel(self.ban_list_frame, text="Chưa có thiết bị nào bị đưa vào danh sách đen.", font=ctk.CTkFont(size=12), text_color="#475569").pack(pady=30)
            return
            
        for mid in db.keys():
            item = ctk.CTkFrame(self.ban_list_frame, fg_color="#1C1917", corner_radius=8, height=36)
            item.pack(fill="x", padx=4, pady=3)
            
            ctk.CTkLabel(item, text="BANNED", font=ctk.CTkFont(size=10, weight="bold"), text_color="#EF4444", width=55).pack(side="left", padx=8)
            ctk.CTkLabel(item, text=mid, font=ctk.CTkFont(family="Consolas", size=13, weight="bold"), text_color="#FCA5A5").pack(side="left", padx=6)
            
            btn_unban = ctk.CTkButton(
                item,
                text="Gỡ phạt",
                font=ctk.CTkFont(size=11, weight="bold"),
                width=65,
                height=26,
                fg_color="#334155",
                hover_color="#475569",
                corner_radius=6,
                command=lambda m=mid: self._quick_unban(m)
            )
            btn_unban.pack(side="right", padx=8)

    def _quick_unban(self, mid):
        db = self.get_db()
        if mid in db:
            del db[mid]
            self.save_db(db)
            self._refresh_ban_list()
            messagebox.showinfo("Ân Xá", f"Đã tháo gỡ án phạt cho thiết bị {mid}!")

    def _ban_device_action(self):
        u = self.entry_ban_id.get().strip().upper()
        if not u:
            return messagebox.showerror("Lỗi", "Vui lòng nhập Machine ID cần cấm!")
        db = self.get_db()
        db[u] = 1
        self.save_db(db)
        self.entry_ban_id.delete(0, 'end')
        self._refresh_ban_list()
        messagebox.showinfo("Thành Công", f"Đã cấm vĩnh viễn thiết bị '{u}' khỏi toàn bộ hệ thống!")

    # ══════════════════════════════════════════════════════════════════
    # TAB 5: ÂN XÁ (PARDON)
    # ══════════════════════════════════════════════════════════════════
    def _build_tab_pardon(self):
        body = self._create_card(
            self.tab_frames["tab_pardon"],
            "Thẻ Bài Ân Xá Thiết Bị",
            "Xóa án phạt trong danh sách đen và cấp lại ngay chìa khóa gốc cho học viên."
        )
        
        ctk.CTkLabel(body, text="NHẬP MACHINE ID ĐANG BỊ CẤM CẦN ÂN XÁ:", font=ctk.CTkFont(size=12, weight="bold"), text_color="#F59E0B").pack(anchor="w", pady=(10, 6))
        
        self.entry_pardon_id = ctk.CTkEntry(
            body,
            height=50,
            placeholder_text="Nhập Machine ID đang bị cấm...",
            font=ctk.CTkFont(family="Consolas", size=15),
            fg_color="#090D16",
            border_color="#78350F",
            border_width=2,
            corner_radius=12
        )
        self.entry_pardon_id.pack(fill="x", pady=(0, 16))
        
        btn_pardon = ctk.CTkButton(
            body,
            text="🕊️ GỠ ÁN PHẠT & XUẤT LẠI KEY GỐC",
            font=ctk.CTkFont(family="Segoe UI", size=14, weight="bold"),
            fg_color="#F59E0B",
            hover_color="#D97706",
            height=46,
            corner_radius=12,
            command=self._pardon_action
        )
        btn_pardon.pack(fill="x", pady=(0, 20))
        
        ctk.CTkLabel(body, text="CHÌA KHÓA GỐC ĐỂ HỌC VIÊN TIẾP TỤC HỌC BÀI:", font=ctk.CTkFont(size=12, weight="bold"), text_color="#F59E0B").pack(anchor="w", pady=(0, 6))
        
        self.pardon_key_var = ctk.StringVar()
        self.entry_pardon_out = ctk.CTkEntry(
            body,
            textvariable=self.pardon_key_var,
            height=60,
            font=ctk.CTkFont(family="Consolas", size=24, weight="bold"),
            justify="center",
            state="readonly",
            fg_color="#090D16",
            text_color="#F59E0B",
            border_color="#F59E0B",
            border_width=2,
            corner_radius=12
        )
        self.entry_pardon_out.pack(fill="x")

    def _pardon_action(self):
        u = self.entry_pardon_id.get().strip().upper()
        if not u:
            return messagebox.showerror("Lỗi", "Vui lòng nhập Machine ID cần ân xá!")
        db = self.get_db()
        if u in db:
            del db[u]
            self.save_db(db)
        key = self._generate_hmac_key(u)
        self.pardon_key_var.set(key)
        self._refresh_ban_list()
        messagebox.showinfo("Ân Xá Thành Công", f"Đã gỡ án phạt cho thiết bị '{u}'!\nHọc viên có thể sử dụng lại Key gốc bên dưới để tiếp tục học bài.")

if __name__ == "__main__":
    app = ModernAuthorApp()
    app.mainloop()
