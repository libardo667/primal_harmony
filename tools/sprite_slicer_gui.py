import tkinter as tk
from tkinter import filedialog, ttk, simpledialog, messagebox
from PIL import Image, ImageTk
import os
from pathlib import Path

# Try to find the assets directory relatively
base_dir = Path(__file__).resolve().parent.parent / "assets" / "sprites"
if not base_dir.exists():
    base_dir = Path.cwd() # Fallback if run elsewhere

class SpriteSlicerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Primal Harmony Slicer & Labeler")
        
        # State
        self.image_path = None
        self.original_image = None
        self.display_image = None # scaled image
        self.photo = None
        self.bg_color = None
        
        self.zoom_factor = 1.0
        
        # Drawing state
        self.rect_id = None
        self.start_x = None
        self.start_y = None
        self.current_rect = None # (x0, y0, x1, y1) in scaled coordinates

        # Config state
        self.fixed_size_var = tk.BooleanVar(value=True)
        self.fixed_width_var = tk.IntVar(value=64)
        self.fixed_height_var = tk.IntVar(value=64)

        # Build UI
        self.build_ui()

    def build_ui(self):
        # Toolbar Top
        toolbar = tk.Frame(self.root, bd=1, relief=tk.RAISED)
        toolbar.pack(side=tk.TOP, fill=tk.X)
        
        btn_load = tk.Button(toolbar, text="Load Sprite Sheet", command=self.load_image)
        btn_load.pack(side=tk.LEFT, padx=2, pady=2)
        
        tk.Label(toolbar, text="Category:").pack(side=tk.LEFT, padx=(10, 2))
        self.category_var = tk.StringVar(value="npcs")
        self.category_combo = ttk.Combobox(toolbar, textvariable=self.category_var, values=["npcs", "player", "items", "overworld", "other"], state="readonly", width=10)
        self.category_combo.pack(side=tk.LEFT, padx=2, pady=2)
        
        # Fixed box settings
        chk_fixed = tk.Checkbutton(toolbar, text="Fixed Box Size", variable=self.fixed_size_var)
        chk_fixed.pack(side=tk.LEFT, padx=(15, 2))
        
        tk.Label(toolbar, text="W:").pack(side=tk.LEFT)
        ent_w = tk.Entry(toolbar, textvariable=self.fixed_width_var, width=4)
        ent_w.pack(side=tk.LEFT)
        
        tk.Label(toolbar, text="H:").pack(side=tk.LEFT, padx=(5, 0))
        ent_h = tk.Entry(toolbar, textvariable=self.fixed_height_var, width=4)
        ent_h.pack(side=tk.LEFT)

        self.lbl_info = tk.Label(toolbar, text="Mouse Wheel to Zoom. Draw box to slice.")
        self.lbl_info.pack(side=tk.RIGHT, padx=10)

        # Canvas with Scrollbars
        frame = tk.Frame(self.root)
        frame.pack(fill=tk.BOTH, expand=True)

        self.canvas = tk.Canvas(frame, bg="gray", cursor="cross")
        self.hbar = tk.Scrollbar(frame, orient=tk.HORIZONTAL, command=self.canvas.xview)
        self.hbar.pack(side=tk.BOTTOM, fill=tk.X)
        self.vbar = tk.Scrollbar(frame, orient=tk.VERTICAL, command=self.canvas.yview)
        self.vbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.canvas.configure(xscrollcommand=self.hbar.set, yscrollcommand=self.vbar.set)

        # Mouse Events
        self.canvas.bind("<ButtonPress-1>", self.on_press)
        self.canvas.bind("<B1-Motion>", self.on_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_release)
        self.canvas.bind("<ButtonPress-3>", self.on_right_click)
        
        # Zoom Events (Windows/Linux and Mac)
        self.canvas.bind("<MouseWheel>", self.on_mousewheel)
        self.canvas.bind("<Button-4>", self.on_mousewheel)
        self.canvas.bind("<Button-5>", self.on_mousewheel)

    def load_image(self):
        filepath = filedialog.askopenfilename(filetypes=[("PNG Images", "*.png"), ("All Files", "*.*")])
        if not filepath: return
        
        self.image_path = filepath
        self.original_image = Image.open(filepath).convert("RGBA")
        self.zoom_factor = 1.0
        self.bg_color = self.original_image.getpixel((0, 0))
        
        self.update_display()
        self.lbl_info.config(text=f"BG Detected: {self.bg_color}. Scroll to zoom.")

    def update_display(self):
        if not self.original_image: return
        
        w = int(self.original_image.width * self.zoom_factor)
        h = int(self.original_image.height * self.zoom_factor)
        
        # NEAREST allows for crisp pixel art scaling
        self.display_image = self.original_image.resize((w, h), Image.NEAREST)
        self.photo = ImageTk.PhotoImage(self.display_image)
        
        self.canvas.delete("all")
        self.canvas.create_image(0, 0, image=self.photo, anchor="nw")
        self.canvas.config(scrollregion=self.canvas.bbox("all"))
        
        # Clear selection on resize
        if self.rect_id:
            self.canvas.delete(self.rect_id)
            self.rect_id = None
            self.current_rect = None

    def on_mousewheel(self, event):
        if not self.original_image: return
        # Windows: event.delta is usually 120 or -120
        # Linux/Mac: event.num is 4 or 5
        zoom_in = False
        if hasattr(event, "delta") and event.delta != 0:
            zoom_in = event.delta > 0
        elif hasattr(event, "num"):
            zoom_in = event.num == 4
            
        if zoom_in:
            self.zoom_factor *= 1.2
        else:
            self.zoom_factor /= 1.2
            if self.zoom_factor < 0.1: self.zoom_factor = 0.1
            
        self.update_display()

    def get_real_coords(self, canvas_x, canvas_y):
        # Convert visual canvas coordinate to actual image coordinate
        x = int(canvas_x / self.zoom_factor)
        y = int(canvas_y / self.zoom_factor)
        return x, y

    def on_right_click(self, event):
        if not self.original_image: return
        cx = self.canvas.canvasx(event.x)
        cy = self.canvas.canvasy(event.y)
        x, y = self.get_real_coords(cx, cy)
        
        if 0 <= x < self.original_image.width and 0 <= y < self.original_image.height:
            self.bg_color = self.original_image.getpixel((x, y))
            self.lbl_info.config(text=f"New BG Picked: {self.bg_color}")

    def on_press(self, event):
        if not self.original_image: return
        self.start_x = self.canvas.canvasx(event.x)
        self.start_y = self.canvas.canvasy(event.y)
        if self.rect_id:
            self.canvas.delete(self.rect_id)
            
        if self.fixed_size_var.get():
            w = self.fixed_width_var.get() * self.zoom_factor
            h = self.fixed_height_var.get() * self.zoom_factor
            # Draw from top-left where clicked
            self.rect_id = self.canvas.create_rectangle(
                self.start_x, self.start_y, 
                self.start_x + w, self.start_y + h, 
                outline="red", width=2
            )
        else:
            self.rect_id = self.canvas.create_rectangle(
                self.start_x, self.start_y, self.start_x, self.start_y, 
                outline="red", width=2
            )

    def on_drag(self, event):
        if not self.original_image or not self.rect_id: return
        cur_x = self.canvas.canvasx(event.x)
        cur_y = self.canvas.canvasy(event.y)
        
        if self.fixed_size_var.get():
            w = self.fixed_width_var.get() * self.zoom_factor
            h = self.fixed_height_var.get() * self.zoom_factor
            self.canvas.coords(self.rect_id, cur_x, cur_y, cur_x + w, cur_y + h)
        else:
            self.canvas.coords(self.rect_id, self.start_x, self.start_y, cur_x, cur_y)

    def on_release(self, event):
        if not self.original_image or not self.rect_id: return
        
        coords = self.canvas.coords(self.rect_id)
        if not coords or len(coords) < 4: return
        
        x0, y0, x1, y1 = coords
        
        # Convert scaled Box back to original image space
        real_x0, real_y0 = self.get_real_coords(x0, y0)
        real_x1, real_y1 = self.get_real_coords(x1, y1)
        
        # Bounds check
        real_x0, real_y0 = max(0, real_x0), max(0, real_y0)
        real_x1, real_y1 = min(self.original_image.width, real_x1), min(self.original_image.height, real_y1)
        
        if real_x1 - real_x0 < 4 or real_y1 - real_y0 < 4:
            self.canvas.delete(self.rect_id)
            self.rect_id = None
            return
            
        self.current_rect = (real_x0, real_y0, real_x1, real_y1)
        self.prompt_and_save()

    def prompt_and_save(self):
        category = self.category_var.get()
        name = simpledialog.askstring("Slice Sprite", f"Enter name for {category} sprite:")
        
        if name:
            box = self.current_rect
            print(f"Slicing box: {box} mapping to {name}.png")
            cropped = self.original_image.crop(box)
            
            # Apply Transparency
            if self.bg_color:
                data = cropped.getdata()
                new_data = []
                for item in data:
                    if item[0:3] == self.bg_color[0:3]: 
                        new_data.append((item[0], item[1], item[2], 0))
                    else:
                        new_data.append(item)
                cropped.putdata(new_data)
            
            target_folder = base_dir / category
            target_folder.mkdir(parents=True, exist_ok=True)
            
            save_path = target_folder / f"{name}.png"
            cropped.save(save_path, "PNG")
            self.lbl_info.config(text=f"Saved: {save_path.name}")
            
        self.canvas.delete(self.rect_id)
        self.rect_id = None
        self.current_rect = None

if __name__ == "__main__":
    root = tk.Tk()
    root.geometry("1000x800")
    app = SpriteSlicerApp(root)
    root.mainloop()
