import customtkinter as ctk
from tkinter import filedialog, messagebox
import json, os, zipfile, io, base64
import hmac, hashlib
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class AuthorApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("SlideLock Admin Workspace")
        self.geometry("900x650")
        self.configure(fg_color="#09090B") # Zinc 950
        
        # --- TOP HEADER NAVIGATION ---
        self.header_frame = ctk.CTkFrame(self, fg_color="#18181B", corner_radius=0, height=70) # Zinc 900
        self.header_frame.pack(fill="x", side="top")
        
        title_lbl = ctk.CTkLabel(self.header_frame, text=" ✦ SLIDELOCK PANEL ", font=ctk.CTkFont(family="Helvetica", size=22, weight="bold"), text_color="#818CF8")
        title_lbl.pack(side="left", padx=30, pady=20)
        
        self.nav_frame = ctk.CTkFrame(self.header_frame, fg_color="transparent")
        self.nav_frame.pack(side="right", padx=20)
        
        self.nav_btns = []
        def nav_btn(text, cmd):
            btn = ctk.CTkButton(self.nav_frame, text=text, font=ctk.CTkFont(family="Inter", size=13, weight="bold"), fg_color="transparent", text_color="#A1A1AA", hover_color="#27272A", width=120, height=40, corner_radius=20, command=cmd)
            btn.pack(side="left", padx=5)
            self.nav_btns.append(btn)
            return btn
            
        nav_btn("MÃ HÓA", lambda: self.select_menu("tab1"))
        nav_btn("CẤP KEY", lambda: self.select_menu("tab2"))
        nav_btn("KHÓA MÁY", lambda: self.select_menu("tab3"))
        nav_btn("ÂN XÁ", lambda: self.select_menu("tab4"))
        
        # --- MAIN CONTENT AREA ---
        self.main_area = ctk.CTkFrame(self, fg_color="transparent")
        self.main_area.pack(fill="both", expand=True, padx=40, pady=30)
        
        self.frames = {
            "tab1": ctk.CTkFrame(self.main_area, fg_color="transparent"),
            "tab2": ctk.CTkFrame(self.main_area, fg_color="transparent"),
            "tab3": ctk.CTkFrame(self.main_area, fg_color="transparent"),
            "tab4": ctk.CTkFrame(self.main_area, fg_color="transparent")
        }

        self.init_t1(); self.init_t2(); self.init_t3(); self.init_t4()
        self.select_menu("tab1")

    def get_db(self):
        return json.load(open("revocations.json", "r")) if os.path.exists("revocations.json") else {}

    def save_db(self, d):
        json.dump(d, open("revocations.json", "w"), indent=4)

    def select_menu(self, menu_id):
        for btn in self.nav_btns:
            btn.configure(fg_color="transparent", text_color="#A1A1AA")
        idx = ["tab1", "tab2", "tab3", "tab4"].index(menu_id)
        self.nav_btns[idx].configure(fg_color="#6366F1", text_color="#FFFFFF")
        for f in self.frames.values(): f.pack_forget()
        self.frames[menu_id].pack(fill="both", expand=True)

    def build_card(self, parent, title, desc):
        # Biến Content vào giữa
        wrapper = ctk.CTkFrame(parent, fg_color="transparent")
        wrapper.pack(expand=True, fill="both")
        
        card = ctk.CTkFrame(wrapper, fg_color="#18181B", corner_radius=24, border_width=1, border_color="#27272A")
        card.place(relx=0.5, rely=0.45, anchor="center", relwidth=0.85, relheight=0.9)
        
        ctk.CTkLabel(card, text=title, font=ctk.CTkFont(family="Inter", size=24, weight="bold"), text_color="#FFFFFF").pack(pady=(40, 5), anchor="center")
        ctk.CTkLabel(card, text=desc, font=ctk.CTkFont(family="Inter", size=14), text_color="#71717A").pack(pady=(0, 30), anchor="center")
        return card

    def init_t1(self):
        card = self.build_card(self.frames["tab1"], "Bọc Thép Bài Giảng", "Đóng gói an toàn các tệp PowerPoint trước khi gửi cho học viên Mac.")
        self.filepath_var = ctk.StringVar()
        
        row = ctk.CTkFrame(card, fg_color="transparent")
        row.pack(fill="x", padx=50, pady=10)
        
        entry_file = ctk.CTkEntry(row, textvariable=self.filepath_var, height=55, placeholder_text="🔗 Chọn một hay nhiều file .pptx ...", font=ctk.CTkFont(family="Inter", size=14), fg_color="#09090B", border_color="#27272A", border_width=2, corner_radius=12)
        entry_file.pack(side="left", fill="x", expand=True, padx=(0, 10))
        
        btn_browse = ctk.CTkButton(row, text="Duyệt...", font=ctk.CTkFont(family="Inter", size=14, weight="bold"), command=self.sel_p, fg_color="#27272A", hover_color="#3F3F46", text_color="#FFFFFF", height=55, width=100, corner_radius=12)
        btn_browse.pack(side="right")
        
        btn_build = ctk.CTkButton(card, text="⚡ Khởi Tạo App Phân Phối", font=ctk.CTkFont(family="Inter", size=16, weight="bold"), fg_color="#10B981", hover_color="#059669", text_color="#FFFFFF", height=60, corner_radius=16, command=self.pack_mac)
        btn_build.pack(pady=(40, 20), padx=50, fill="x")

    def sel_p(self):
        pths = filedialog.askopenfilenames(filetypes=[("PPTX", "*.pptx")])
        if pths: self.filepath_var.set(";".join(pths))

    def pack_mac(self):
        p_pths = self.filepath_var.get().split(';')
        if not p_pths or not p_pths[0]: return messagebox.showerror("Lỗi", "Chưa chọn file!")
        try:
            mz = io.BytesIO()
            manifest = {}
            with zipfile.ZipFile(mz, 'w', zipfile.ZIP_DEFLATED) as zf:
                for idx, p_pth in enumerate(p_pths):
                    orig_name = os.path.basename(p_pth)
                    safe_name = f"lesson_{idx}.pptx"
                    zf.write(p_pth, safe_name)
                    manifest[safe_name] = orig_name
                zf.writestr("manifest.json", json.dumps(manifest, ensure_ascii=False).encode('utf-8'))
                zf.write("revocations.json", "revocations.json") if os.path.exists("revocations.json") else zf.writestr("revocations.json", "{}")
            
            aesgcm = AESGCM(b"12345678901234567890123456789012")
            nonce = os.urandom(12)
            enc = aesgcm.encrypt(nonce, mz.getvalue(), None)
            with open("baigiang.khoa", "wb") as f: f.write(nonce + enc)
            
            if os.path.exists("SlideLock.app"):
                counter = 1
                out_name = "KhoaHoc_Mac_1.zip"
                while os.path.exists(out_name):
                    counter += 1
                    out_name = f"KhoaHoc_Mac_{counter}.zip"
                    
                with zipfile.ZipFile(out_name, 'w', zipfile.ZIP_DEFLATED) as zf:
                    base_folder = "KhoaHoc_Mac/"
                    # Create base folder and SlideLock.app dir
                    for d_path in [base_folder, base_folder + "SlideLock.app/"]:
                        z_info_dir = zipfile.ZipInfo(d_path)
                        z_info_dir.create_system = 3
                        z_info_dir.external_attr = (0x41ED) << 16
                        zf.writestr(z_info_dir, "")
                    
                    # Store baigiang.khoa next to the app, NOT inside it
                    z_info_file = zipfile.ZipInfo(f"{base_folder}baigiang.khoa")
                    z_info_file.create_system = 3
                    z_info_file.external_attr = (0x81A4) << 16
                    with open("baigiang.khoa", "rb") as f_in: zf.writestr(z_info_file, f_in.read())
                    
                    if os.path.exists("MoKhoaHoc.command"):
                        z_info_cmd = zipfile.ZipInfo(f"{base_folder}MoKhoaHoc.command")
                        z_info_cmd.create_system = 3
                        z_info_cmd.external_attr = (0x81ED) << 16 # executable
                        with open("MoKhoaHoc.command", "rb") as f_in: zf.writestr(z_info_cmd, f_in.read())
                    
                    
                    # Zip the untampered SlideLock.app preserving its exact signature
                    for r, d, fs in os.walk("SlideLock.app"):
                        for folder in d:
                            dp = os.path.join(r, folder)
                            arcname_dir = os.path.relpath(dp, ".").replace("\\", "/") + "/"
                            z_info = zipfile.ZipInfo(base_folder + arcname_dir)
                            z_info.create_system = 3
                            z_info.external_attr = (0x41ED) << 16 # drwxr-xr-x
                            zf.writestr(z_info, "")
                            
                        for f in fs:
                            fp = os.path.join(r, f)
                            arcname = os.path.relpath(fp, ".").replace("\\", "/")
                            z_info = zipfile.ZipInfo.from_file(fp, base_folder + arcname)
                            z_info.create_system = 3
                            if "Contents/MacOS/" in arcname and not arcname.endswith(".plist") and not arcname.endswith(".txt"):
                                z_info.external_attr = (0x81ED) << 16 # +x executable
                            else:
                                z_info.external_attr = (0x81A4) << 16 # rw-r--r--
                            with open(fp, "rb") as f_in: zf.writestr(z_info, f_in.read())
                os.remove("baigiang.khoa")
                messagebox.showinfo("Thành Công", f"Đã xuất xong gói {out_name} siêu bảo mật!")
            else:
                messagebox.showwarning("Cảnh Báo", "Phiên bản này chỉ xuất file .khoa vì chưa có thư mục app vỏ hệ thống.")
        except Exception as e: messagebox.showerror("Lỗi", str(e))

    def _generate_hmac_key(self, u):
        raw = f"{u}".encode('utf-8')
        sig = hmac.new(b"12345678901234567890123456789012", raw, hashlib.sha256).digest()
        num = int.from_bytes(sig[:8], byteorder='big')
        code = str(num % 1000000000000).zfill(12)
        return f"{code[:4]}-{code[4:8]}-{code[8:12]}"

    def init_t2(self):
        card = self.build_card(self.frames["tab2"], "Cấp Quyền Truy Cập", "Sinh khóa duy nhất cho 1 máy tính đích.")
        self.eu = ctk.CTkEntry(card, height=55, placeholder_text="Nhập Machine ID của máy Apple...", font=ctk.CTkFont(family="Inter", size=15), fg_color="#09090B", border_color="#27272A", border_width=2, corner_radius=12, justify="center")
        self.eu.pack(pady=10, padx=60, fill="x")
        ctk.CTkButton(card, text="TẠO CHÌA KHÓA DUY NHẤT", font=ctk.CTkFont(family="Inter", size=16, weight="bold"), fg_color="#4F46E5", hover_color="#4338CA", command=lambda: self.txt_key.set(self._generate_hmac_key(self.eu.get().strip())), height=55, corner_radius=14).pack(pady=20, padx=60, fill="x")
        self.txt_key = ctk.StringVar()
        ctk.CTkEntry(card, textvariable=self.txt_key, height=65, font=ctk.CTkFont(family="Consolas", size=19, weight="bold"), justify='center', state='readonly', fg_color="#09090B", text_color="#10B981", border_color="#10B981", border_width=2, corner_radius=12).pack(pady=10, padx=60, fill="x")

    def init_t3(self):
        card = self.build_card(self.frames["tab3"], "Ngăn Chặn Cố Ý", "Tước quyền sử dụng của những máy tính vi phạm.")
        self.eb = ctk.CTkEntry(card, height=55, placeholder_text="Paste Machine ID vi phạm vào đây...", font=ctk.CTkFont(family="Inter", size=15), fg_color="#09090B", text_color="#F87171", border_color="#27272A", border_width=2, corner_radius=12, justify="center")
        self.eb.pack(pady=10, padx=60, fill="x")
        
        def ban_it():
            u = self.eb.get().strip()
            if u:
                db = self.get_db()
                db[u] = 1 # Marking as banned
                self.save_db(db)
                messagebox.showinfo("Thành Công", f"Đã cấm vĩnh viễn thiết bị '{u}' khỏi toàn bộ hệ thống!")
                
        ctk.CTkButton(card, text="TIÊU DIỆT THIẾT BỊ NÀY", font=ctk.CTkFont(family="Inter", size=16, weight="bold"), fg_color="#E11D48", hover_color="#BE123C", command=ban_it, height=55, corner_radius=14).pack(pady=20, padx=60, fill="x")

    def init_t4(self):
        card = self.build_card(self.frames["tab4"], "Thẻ Bài Ân Xá", "Tháo gỡ án phạt trong sổ đen cho máy tính.")
        self.eau = ctk.CTkEntry(card, height=55, placeholder_text="Nhập Machine ID đang bị cấm...", font=ctk.CTkFont(family="Inter", size=15), fg_color="#09090B", border_color="#27272A", border_width=2, justify="center", corner_radius=12)
        self.eau.pack(pady=10, padx=60, fill="x")
        
        def pardon_it():
            u = self.eau.get().strip()
            if u:
                db = self.get_db()
                if u in db:
                    del db[u]
                    self.save_db(db)
                self.tak.set(self._generate_hmac_key(u))
                messagebox.showinfo("Ân Xá", f"Đã gỡ án tử hình cho '{u}'. Khách hàng có thể tiếp tục sử dụng đúng cái Key gốc lúc đầu (bên dưới) để vào học lại.")
                
        ctk.CTkButton(card, text="GỠ PHẠT & XUẤT LẠI KEY GỐC", font=ctk.CTkFont(family="Inter", size=16, weight="bold"), fg_color="#EA580C", hover_color="#C2410C", command=pardon_it, height=55, corner_radius=14).pack(pady=20, padx=60, fill="x")
        self.tak = ctk.StringVar()
        ctk.CTkEntry(card, textvariable=self.tak, height=65, font=ctk.CTkFont(family="Consolas", size=19, weight="bold"), justify='center', state='readonly', fg_color="#09090B", text_color="#F97316", border_color="#F97316", border_width=2, corner_radius=12).pack(pady=10, padx=60, fill="x")

if __name__ == "__main__":
    AuthorApp().mainloop()
