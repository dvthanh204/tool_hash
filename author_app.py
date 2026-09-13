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
        self.title("SlideLock Admin Dashboard")
        self.geometry("900x600")
        self.configure(fg_color="#0F172A")
        
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)
        
        # --- SIDEBAR ---
        self.sidebar_frame = ctk.CTkFrame(self, fg_color="#1E293B", width=220, corner_radius=0)
        self.sidebar_frame.grid(row=0, column=0, sticky="nsew")
        self.sidebar_frame.grid_rowconfigure(5, weight=1)
        
        ctk.CTkLabel(self.sidebar_frame, text="🛡 SLIDELOCK", font=ctk.CTkFont(family="Inter", size=22, weight="bold"), text_color="#38BDF8").pack(pady=(30, 5))
        ctk.CTkLabel(self.sidebar_frame, text="Mac DRM Panel", font=ctk.CTkFont(family="Inter", size=12), text_color="#94A3B8").pack(pady=(0, 30))
        
        self.nav_btns = []
        def nav_btn(text, cmd):
            btn = ctk.CTkButton(self.sidebar_frame, text=text, font=ctk.CTkFont(family="Inter", size=14, weight="bold"), fg_color="transparent", text_color="#CBD5E1", hover_color="#334155", anchor="w", height=45, corner_radius=8, command=cmd)
            btn.pack(pady=5, padx=20, fill="x")
            self.nav_btns.append(btn)
            return btn
            
        nav_btn("📦 1. Đóng Gói (Mã Hóa)", lambda: self.select_menu("tab1"))
        nav_btn("🔑 2. Cấp Key Mới", lambda: self.select_menu("tab2"))
        nav_btn("🔒 3. Sổ Đen Khóa Máy", lambda: self.select_menu("tab3"))
        nav_btn("🔓 4. Ân Xá (Cấp Lại)", lambda: self.select_menu("tab4"))
        
        # --- MAIN CONTENT ---
        self.main_frame = ctk.CTkFrame(self, fg_color="#0F172A", corner_radius=0)
        self.main_frame.grid(row=0, column=1, sticky="nsew", padx=30, pady=30)
        
        self.frames = {}
        self.frames["tab1"] = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.frames["tab2"] = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.frames["tab3"] = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.frames["tab4"] = ctk.CTkFrame(self.main_frame, fg_color="transparent")

        self.init_t1(); self.init_t2(); self.init_t3(); self.init_t4()
        self.select_menu("tab1")

    def get_db(self):
        return json.load(open("revocations.json", "r")) if os.path.exists("revocations.json") else {}

    def save_db(self, d):
        json.dump(d, open("revocations.json", "w"), indent=4)

    def select_menu(self, menu_id):
        for btn in self.nav_btns:
            btn.configure(fg_color="transparent", text_color="#CBD5E1")
        idx = ["tab1", "tab2", "tab3", "tab4"].index(menu_id)
        self.nav_btns[idx].configure(fg_color="#38BDF8", text_color="#0F172A")
        for f in self.frames.values(): f.pack_forget()
        self.frames[menu_id].pack(fill="both", expand=True)

    def build_card(self, parent, title, desc):
        card = ctk.CTkFrame(parent, fg_color="#1E293B", corner_radius=16, border_width=1, border_color="#334155")
        card.pack(fill="both", expand=True, pady=10)
        ctk.CTkLabel(card, text=title, font=ctk.CTkFont(family="Inter", size=20, weight="bold"), text_color="#F8FAFC").pack(pady=(30, 5), anchor="w", padx=40)
        ctk.CTkLabel(card, text=desc, font=ctk.CTkFont(family="Inter", size=13), text_color="#94A3B8").pack(pady=(0, 20), anchor="w", padx=40)
        return card

    def init_t1(self):
        card = self.build_card(self.frames["tab1"], "Đóng Gói Bài Giảng", "Mã hóa và nhúng DRM vào các file slide PPTX cho Mac.")
        self.filepath_var = ctk.StringVar()
        entry_file = ctk.CTkEntry(card, textvariable=self.filepath_var, height=45, placeholder_text="Chọn đường dẫn file .pptx...", font=ctk.CTkFont(family="Inter", size=13), fg_color="#0F172A", border_color="#475569")
        entry_file.pack(padx=40, fill="x", pady=10)
        btn_browse = ctk.CTkButton(card, text="📂 Duyệt File", font=ctk.CTkFont(family="Inter", size=13, weight="bold"), command=self.sel_p, fg_color="#334155", hover_color="#475569", height=40)
        btn_browse.pack(padx=40, anchor="e")
        btn_build = ctk.CTkButton(card, text="🛡 MÃ HÓA BẢN QUYỀN", fg_color="#10B981", hover_color="#059669", font=ctk.CTkFont(family="Inter", size=15, weight="bold"), command=self.pack_mac, height=50)
        btn_build.pack(pady=40, padx=40, fill="x")

    def sel_p(self):
        pths = filedialog.askopenfilenames(filetypes=[("PPTX", "*.pptx")])
        if pths: self.filepath_var.set(";".join(pths))

    def pack_mac(self):
        p_pths = self.filepath_var.get().split(';')
        if not p_pths or not p_pths[0]: return messagebox.showerror("Lỗi", "Chưa chọn file!")
        try:
            mz = io.BytesIO()
            with zipfile.ZipFile(mz, 'w', zipfile.ZIP_DEFLATED) as zf:
                for p_pth in p_pths: zf.write(p_pth, os.path.basename(p_pth))
                zf.write("revocations.json", "revocations.json") if os.path.exists("revocations.json") else zf.writestr("revocations.json", "{}")
            
            aesgcm = AESGCM(b"12345678901234567890123456789012")
            nonce = os.urandom(12)
            enc = aesgcm.encrypt(nonce, mz.getvalue(), None)
            with open("baigiang.khoa", "wb") as f: f.write(nonce + enc)
            
            if os.path.exists("SlideLock.app"):
                with zipfile.ZipFile("KhoaHoc_Mac.zip", 'w', zipfile.ZIP_DEFLATED) as zf:
                    zf.write("baigiang.khoa", "SlideLock.app/Contents/Resources/baigiang.khoa")
                    for r, d, fs in os.walk("SlideLock.app"):
                        for f in fs:
                            fp = os.path.join(r, f)
                            arcname = os.path.relpath(fp, ".").replace("\\", "/")
                            z_info = zipfile.ZipInfo.from_file(fp, arcname)
                            if "Contents/MacOS/" in arcname: z_info.external_attr = (0x81ED) << 16
                            else: z_info.external_attr = (0x81A4) << 16
                            with open(fp, "rb") as f_in: zf.writestr(z_info, f_in.read())
                os.remove("baigiang.khoa")
                messagebox.showinfo("Thành Công", "Mã hóa xong vào KhoaHoc_Mac.zip!")
            else:
                messagebox.showwarning("Thiếu Thư Mục Tương Thích", "Chưa thấy thư mục SlideLock.app, chỉ xuất file .khoa")
        except Exception as e: messagebox.showerror("Lỗi", str(e))

    def _generate_hmac_key(self, u):
        v = self.get_db().get(u, 0) + 1
        raw = f"{u}_{v}".encode('utf-8')
        sig = hmac.new(b"12345678901234567890123456789012", raw, hashlib.sha256).digest()
        return f"V{v}-" + base64.b64encode(sig).decode('utf-8')

    def init_t2(self):
        card = self.build_card(self.frames["tab2"], "Cấp Mật Khẩu Mới", "Tạo mã kích hoạt cho Học viên dựa trên Mac ID.")
        self.eu = ctk.CTkEntry(card, height=45, placeholder_text="Nhập Machine ID...", font=ctk.CTkFont(family="Inter", size=14), fg_color="#0F172A", border_color="#475569")
        self.eu.pack(pady=10, padx=40, fill="x")
        ctk.CTkButton(card, text="🔑 TẠO MẬT KHẨU", font=ctk.CTkFont(family="Inter", size=14, weight="bold"), fg_color="#2563EB", hover_color="#1D4ED8", command=lambda: self.txt_key.set(self._generate_hmac_key(self.eu.get().strip())), height=45).pack(pady=15, padx=40, fill="x")
        self.txt_key = ctk.StringVar()
        ctk.CTkEntry(card, textvariable=self.txt_key, height=50, font=ctk.CTkFont(family="Consolas", size=16), justify='center', state='readonly', fg_color="#0F172A", text_color="#10B981", border_color="#10B981").pack(pady=10, padx=40, fill="x")

    def init_t3(self):
        card = self.build_card(self.frames["tab3"], "Thu Hồi (Sổ Đen)", "Đưa một ID vào sổ đen để tước quyền ở khóa học.")
        self.eb = ctk.CTkEntry(card, height=45, placeholder_text="Nhập ID cần cấm...", font=ctk.CTkFont(family="Inter", size=14), fg_color="#0F172A", text_color="#EF4444", border_color="#475569")
        self.eb.pack(pady=10, padx=40, fill="x")
        
        def ban_it():
            u = self.eb.get().strip()
            if u:
                db = self.get_db()
                db[u] = db.get(u, 0) + 1
                self.save_db(db)
                messagebox.showinfo("OK", f"Đã khóa máy {u} (v{db[u]})")
                
        ctk.CTkButton(card, text="🔒 CHẶN MÁY NÀY", font=ctk.CTkFont(family="Inter", size=14, weight="bold"), fg_color="#EF4444", hover_color="#DC2626", command=ban_it, height=45).pack(pady=25, padx=40, fill="x")

    def init_t4(self):
        card = self.build_card(self.frames["tab4"], "Gỡ Cấm & Phục Hồi", "Cấp một chìa khóa đặc quyền để gỡ khóa.")
        self.eau = ctk.CTkEntry(card, height=45, placeholder_text="Nhập Machine ID ân xá...", font=ctk.CTkFont(family="Inter", size=14), fg_color="#0F172A", border_color="#475569")
        self.eau.pack(pady=10, padx=40, fill="x")
        ctk.CTkButton(card, text="🔓 GỠ KHÓA & SINH MÃ MỚI", font=ctk.CTkFont(family="Inter", size=14, weight="bold"), fg_color="#F59E0B", hover_color="#D97706", command=lambda: self.tak.set(self._generate_hmac_key(self.eau.get().strip())), height=45).pack(pady=15, padx=40, fill="x")
        self.tak = ctk.StringVar()
        ctk.CTkEntry(card, textvariable=self.tak, height=50, font=ctk.CTkFont(family="Consolas", size=16), justify='center', state='readonly', fg_color="#0F172A", text_color="#F59E0B", border_color="#F59E0B").pack(pady=10, padx=40, fill="x")

if __name__ == "__main__":
    AuthorApp().mainloop()
