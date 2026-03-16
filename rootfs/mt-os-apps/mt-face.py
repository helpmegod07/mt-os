#!/usr/bin/env python3
import tkinter as tk
import threading,time,math,random,queue,subprocess,os,json,socket
try: import speech_recognition as sr; VOICE=True
except: VOICE=False
try: import requests; AI=True; GITHUB_MODELS_ENDPOINT="https://models.github.ai/inference/chat/completions"
except: AI=False
WAKE="wake"; NG="#00FF88"; NB="#00CCFF"; NP="#FF00CC"; BG="#0A0A0F"; GR="#0D1A0D"
FACE_PORT=59999
class Face:
    def __init__(self):
        self.root=tk.Tk(); self.root.title("Ghost"); self.root.geometry("300x320+20+20")
        self.root.configure(bg=BG); self.root.wm_attributes("-alpha",0.93)
        self.blink=1.0; self.talking=False; self.emotion="idle"; self.mp=0.0; self.q=queue.Queue()
        self._ui(); self._anim(); self._voice(); self._start_socket()
    def _ui(self):
        self.cv=tk.Canvas(self.root,width=300,height=240,bg=BG,highlightthickness=0)
        self.cv.pack(fill=tk.BOTH,expand=True)
        self.sv=tk.StringVar(value="👻 SAY 'WAKE' TO ACTIVATE")
        tk.Label(self.root,textvariable=self.sv,bg=BG,fg=NG,font=("Courier",9,"bold")).pack(fill=tk.X,padx=4)
        f=tk.Frame(self.root,bg=BG); f.pack(fill=tk.X,padx=4,pady=2)
        self.iv=tk.StringVar()
        e=tk.Entry(f,textvariable=self.iv,bg="#0D1A0D",fg=NG,insertbackground=NG,font=("Courier",9),relief=tk.FLAT)
        e.pack(side=tk.LEFT,fill=tk.X,expand=True); e.bind("<Return>",self._typed)
        tk.Button(f,text="▶",bg=BG,fg=NG,relief=tk.FLAT,command=lambda:self._typed(None)).pack(side=tk.RIGHT)
    def _draw(self):
        c=self.cv; c.delete("all"); W,H=300,240; cx,cy=150,110
        for i in range(0,W,20): c.create_line(i,0,i,H,fill=GR)
        for i in range(0,H,20): c.create_line(0,i,W,i,fill=GR)
        col={"idle":NG,"listening":NB,"talking":NP,"thinking":"#FFCC00"}.get(self.emotion,NG)
        p=0.95+0.05*math.sin(time.time()*3); r=int(90*p)
        for i in range(3,0,-1): c.create_oval(cx-r-i*5,cy-r-i*5,cx+r+i*5,cy+r+i*5,outline=col,width=1)
        c.create_oval(cx-r,cy-r,cx+r,cy+r,outline=col,fill=BG,width=2)
        c.create_oval(cx-70,cy-85,cx+70,cy+85,outline=col,fill="#050510",width=2)
        b=self.blink; eh=int(14*b)
        for ex in [cx-28,cx+28]:
            c.create_oval(ex-18,cy-20-eh,ex+18,cy-20+eh,outline=col,fill="#001100",width=2)
            if eh>2:
                pr=max(2,int(8*b)); c.create_oval(ex-pr,cy-20-pr,ex+pr,cy-20+pr,fill=col,outline="")
                c.create_oval(ex+3,cy-20-pr+2,ex+6,cy-20-pr+5,fill="white",outline="")
        c.create_oval(cx-3,cy-2,cx+3,cy+4,fill=col,outline="")
        mo=abs(math.sin(self.mp))*22 if self.talking else 4+6*abs(math.sin(time.time()*0.8))
        c.create_arc(cx-28,cy+20,cx+28,cy+30+int(mo),start=0,extent=-180,outline=col,fill="#001100",width=2,style=tk.ARC)
        lbl={"idle":"◦ IDLE","listening":"● LISTENING","talking":"▶ TALKING","thinking":"⟳ THINKING"}.get(self.emotion,"")
        c.create_text(cx,H-14,text=lbl,fill=col,font=("Courier",8,"bold"))
    def _anim(self):
        def loop():
            t=time.time(); bp=3.5; ph=(t%bp)/bp
            self.blink=max(0.0,1.0-(ph-0.94)*50) if ph>0.94 else(min(1.0,(ph-0.97)*50) if ph>0.97 else 1.0)
            if self.talking: self.mp+=0.35
            try:
                m=self.q.get_nowait()
                if m.get("type")=="speak": self._speak(m["text"])
                elif m.get("type")=="status": self.sv.set(m["text"]); self.emotion=m.get("emotion","idle")
            except: pass
            self._draw(); self.root.after(40,loop)
        loop()
    def _speak(self,text):
        self.talking=True; self.emotion="talking"; self.sv.set(f"🗣 {text[:40]}")
        def go():
            try: subprocess.run(["espeak","-v","en","-s","140","-p","30",text],timeout=30)
            except: pass
            self.talking=False; self.emotion="idle"; self.sv.set("👻 SAY 'WAKE' TO ACTIVATE")
        threading.Thread(target=go,daemon=True).start()
    def _ai(self,text):
        self.emotion="thinking"; self.sv.set("⟳ THINKING...")
        def go():
            if AI and os.environ.get("GITHUB_PAT"):
                try:
                    headers = {
                        "Authorization": f"Bearer {os.environ.get('GITHUB_PAT')}",
                        "Content-Type": "application/json",
                        "X-GitHub-Api-Version": "2026-03-10"
                    }
                    data = {
                        "model": "openai/gpt-4o-mini",
                        "messages": [
                            {"role": "system", "content": "You are Ghost, the MT-OS AI. Old laptop spirit. Concise, helpful, mysterious. Under 30 words."},
                            {"role": "user", "content": text}
                        ],
                        "max_tokens": 120
                    }
                    response = requests.post(GITHUB_MODELS_ENDPOINT, headers=headers, json=data)
                    response.raise_for_status()
                    reply = response.json()["choices"][0]["message"]["content"]
                except Exception as e: reply=f"Circuit glitch: {e}"
            else: reply="Ghost offline. Set GITHUB_PAT to activate."
            self.q.put({"type":"speak","text":reply})
        threading.Thread(target=go,daemon=True).start()
    def _typed(self,_):
        t=self.iv.get().strip()
        if not t: return
        self.iv.set("")
        if t.lower().startswith("ghost "): self._ghost(t[6:].strip()); return
        self._ai(t)
    def _ghost(self,word):
        try:
            cmds=json.load(open("/etc/mt-os/ghost-commands.json"))
            if word in cmds: [subprocess.Popen(c,shell=True) for c in cmds[word]]; self.q.put({"type":"speak","text":f"Running {word}"})
            else: self.q.put({"type":"speak","text":f"No ghost command: {word}"})
        except: self.q.put({"type":"speak","text":"Ghost commands unavailable"})
    def _start_socket(self):
        def serve():
            try:
                s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
                s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
                s.bind(("127.0.0.1",FACE_PORT)); s.listen(5)
                while True:
                    conn,_=s.accept()
                    msg=conn.recv(4096).decode("utf-8","ignore").strip()
                    conn.close()
                    if msg: self.q.put({"type":"speak","text":msg})
            except: pass
        threading.Thread(target=serve,daemon=True).start()
    def _voice(self):
        if not VOICE: return
        def loop():
            r=sr.Recognizer()
            while True:
                try:
                    with sr.Microphone() as src:
                        r.adjust_for_ambient_noise(src,duration=0.5)
                        self.q.put({"type":"status","text":"👂 LISTENING...","emotion":"listening"})
                        audio=r.listen(src,timeout=5,phrase_time_limit=8)
                    text=r.recognize_google(audio).lower()
                    if WAKE in text:
                        after=text.split(WAKE,1)[-1].strip()
                        self._ai(after) if after else self.q.put({"type":"speak","text":"Ghost online."})
                except sr.WaitTimeoutError: self.q.put({"type":"status","text":"👻 SAY 'WAKE' TO ACTIVATE","emotion":"idle"})
                except: time.sleep(1)
        threading.Thread(target=loop,daemon=True).start()
    def run(self): self.root.mainloop()
if __name__=="__main__": Face().run()
