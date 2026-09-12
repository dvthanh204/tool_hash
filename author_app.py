import customtkinter as ctk
from tkinter import filedialog, messagebox
import json, os, zipfile, io, base64
from cryptography.fernet import Fernet

FERNET_KEY = base64.urlsafe_b64encode(b'12345678901234567890123456789012')

class AuthorApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Course DRM Admin - macOS")
        self.geometry("600x550")
        
        self.tabview = ctk.CTkTabview(self)
        self.tabview.pack(expand=True, fill="both", padx=10, pady=10)
        self.tab1 = self.tabview.add("Đóng gói (.khoa)")
        self.tab2 = self.tabview.add("Cấp Key")
        self.tab3 = self.tabview.add("Sổ Đen")
        self.tab4 = self.tabview.add("Ân Xá")
        
        self.init_t1(); self.init_t2(); self.init_t3(); self.init_t4()

    def get_db(self):
        return json.load(open("revocations.json", "r")) if os.path.exists("revocations.json") else {}

    def save_db(self, d):
        json.dump(d, open("revocations.json", "w"), indent=4)

    def init_t1(self):
        self.p_pth = self.a_pth = None
        ctk.CTkButton(self.tab1, text="Chọn .pptx", command=self.sel_p).pack(pady=5)
        self.l_p = ctk.CTkLabel(self.tab1, text="Chưa chọn")
        self.l_p.pack()
        ctk.CTkButton(self.tab1, text="Chọn SlideLock.app", command=self.sel_a).pack(pady=5)
        self.l_a = ctk.CTkLabel(self.tab1, text="Chưa chọn")
        self.l_a.pack()
        ctk.CTkButton(self.tab1, text="Đóng Gói", command=self.pack, fg_color="green").pack(pady=20)
        
    def sel_p(self):
        self.p_pth = filedialog.askopenfilename(filetypes=[("PPTX", "*.pptx")])
        if self.p_pth: self.l_p.configure(text=os.path.basename(self.p_pth))

    def sel_a(self):
        self.a_pth = filedialog.askdirectory(title="Chọn app")
        if self.a_pth: self.l_a.configure(text=os.path.basename(self.a_pth))

    def pack(self):
        if not self.p_pth or not self.a_pth: return messagebox.showerror("Lỗi", "Chưa chọn file")
        try:
            mz = io.BytesIO()
            with zipfile.ZipFile(mz, 'w', zipfile.ZIP_DEFLATED) as zf:
                zf.write(self.p_pth, "presentation.pptx")
                zf.write("revocations.json", "revocations.json") if os.path.exists("revocations.json") else zf.writestr("revocations.json", "{}")
            enc = Fernet(FERNET_KEY).encrypt(mz.getvalue())
            with open("baigiang.khoa", "wb") as f: f.write(enc)
            
            with zipfile.ZipFile("KhoaHoc_Mac.zip", 'w', zipfile.ZIP_DEFLATED) as zf:
                zf.write("baigiang.khoa", "baigiang.khoa")
                p_dir = os.path.dirname(self.a_pth)
                for r, d, fs in os.walk(self.a_pth):
                    for f in fs:
                        fp = os.path.join(r, f)
                        zf.write(fp, os.path.relpath(fp, p_dir))
            os.remove("baigiang.khoa")
            messagebox.showinfo("OK", "Đóng gói xong vào KhoaHoc_Mac.zip")
        except Exception as e: messagebox.showerror("Lỗi", str(e))

    def init_t2(self):
        self.eu = ctk.CTkEntry(self.tab2, width=350, placeholder_text="UUID")
        self.eu.pack(pady=5)
        self.ee = ctk.CTkEntry(self.tab2, width=200, placeholder_text="YYYY-MM-DD")
        self.ee.pack(pady=5)
        ctk.CTkButton(self.tab2, text="Tạo Key", command=self.gk).pack()
        self.tk = ctk.CTkTextbox(self.tab2, height=120, width=450)
        self.tk.pack(pady=5)

    def gk(self):
        u, e = self.eu.get().strip(), self.ee.get().strip()
        if u and e:
            k = Fernet(FERNET_KEY).encrypt(json.dumps({"u":u, "e":e, "v":1}).encode()).decode()
            self.tk.delete("0.0", "end"); self.tk.insert("0.0", k)

    def init_t3(self):
        self.eb = ctk.CTkEntry(self.tab3, width=350, placeholder_text="UUID cần cấm")
        self.eb.pack(pady=10)
        ctk.CTkButton(self.tab3, text="Cấm", fg_color="red", command=self.ban).pack()

    def ban(self):
        u = self.eb.get().strip()
        if u:
            db = self.get_db()
            db[u] = db.get(u, 0) + 1
            self.save_db(db)
            messagebox.showinfo("OK", f"Cấm {u} version {db[u]}")

    def init_t4(self):
        self.eau = ctk.CTkEntry(self.tab4, width=350, placeholder_text="UUID ân xá")
        self.eau.pack(pady=5)
        self.eae = ctk.CTkEntry(self.tab4, width=200, placeholder_text="YYYY-MM-DD")
        self.eae.pack(pady=5)
        ctk.CTkButton(self.tab4, text="Tạo Key Ân Xá", fg_color="orange", command=self.pa).pack()
        self.tak = ctk.CTkTextbox(self.tab4, height=120, width=450)
        self.tak.pack(pady=5)

    def pa(self):
        u, e = self.eau.get().strip(), self.eae.get().strip()
        if u and e:
            nv = self.get_db().get(u, 0) + 1
            k = Fernet(FERNET_KEY).encrypt(json.dumps({"u":u, "e":e, "v":nv}).encode()).decode()
            self.tak.delete("0.0", "end"); self.tak.insert("0.0", k)

if __name__ == "__main__":
    AuthorApp().mainloop()
