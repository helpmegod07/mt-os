#!/usr/bin/env python3
import tkinter as tk
from tkinter import scrolledtext
import subprocess,threading,os,queue,json,socket,re
try: import requests; AI=True; GITHUB_MODELS_ENDPOINT="https://models.github.ai/inference/chat/completions"
except: AI=False
NG="#00FF88"; NP="#FF00CC"; NB="#00CCFF"; BG="#030308"; TC="#AAFFCC"
FACE_PORT=59999
SYS="You are Ghost Terminal AI on MT-OS on an old 32-bit laptop. If a command has a typo say TYPO: then FIX: with the correction. If a command fails explain in 1-2 sentences and suggest a fix. If asked a question answer briefly. Never more than 3 sentences."
TYPOS=[(r'^pyhton','python'),(r'^pytohn','python'),(r'^pyton','python'),(r'^suod','sudo'),(r'^sduo','sudo'),(r'^grpe','grep'),(r'^gerp','grep'),(r'^caht','cat'),(r'^cta\b','cat'),(r'^gti\b','git'),(r'^sl\b','ls'),(r'^LS\b','ls'),(r'--hlep','--help'),(r'--hep\b','--help'),(r'instal\b','install')]
def speak_to_face(text):
    try:
        s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
        s.settimeout(1); s.connect(("127.0.0.1",FACE_PORT))
        s.send(text.encode("utf-8")); s.close()
    except: pass
    threading.Thread(target=lambda:subprocess.run(["espeak","-v","en","-s","140","-p","30",text[:200]],capture_output=True,timeout=20),daemon=True).start()
def check_typo(cmd):
    for pat,fix in TYPOS:
        if re.search(pat,cmd,re.IGNORECASE):
            return re.sub(pat,fix,cmd,flags=re.IGNORECASE)
    return None
class Term:
    def __init__(self):
        self.root=tk.Tk(); self.root.title("Ghost Terminal"); self.root.geometry("380x240+900+540")
        self.root.configure(bg=BG); self.root.wm_attributes("-alpha",0.93)
        self.cwd=os.path.expanduser("~"); self.hist=[]; self.hi=0; self.q=queue.Queue(); self._last_fix=None
        self._ui(); self._pq()
    def _ui(self):
        tk.Label(self.root,text="👻 GHOST TERMINAL",bg="#050510",fg=NG,font=("Courier",8,"bold")).pack(fill=tk.X)
        self.out=scrolledtext.ScrolledText(self.root,bg=BG,fg=TC,font=("Courier",8),insertbackground=NG,relief=tk.FLAT,bd=0,height=12,state=tk.DISABLED,wrap=tk.WORD)
        self.out.pack(fill=tk.BOTH,expand=True,padx=2)
        for t,c in [("error",NP),("ai",NB),("ok",NG),("prompt","#FFCC00"),("sys","#888888"),("typo","#FF8800")]:
            self.out.tag_config(t,foreground=c)
        f=tk.Frame(self.root,bg=BG); f.pack(fill=tk.X,padx=2,pady=2)
        self.pl=tk.Label(f,text="$ ",bg=BG,fg=NG,font=("Courier",8,"bold")); self.pl.pack(side=tk.LEFT)
        self.iv=tk.StringVar()
        self.entry=tk.Entry(f,textvariable=self.iv,bg=BG,fg=NG,insertbackground=NG,font=("Courier",8),relief=tk.FLAT)
        self.entry.pack(side=tk.LEFT,fill=tk.X,expand=True)
        self.entry.bind("<Return>",self._enter); self.entry.bind("<Up>",self._hu); self.entry.bind("<Down>",self._hd); self.entry.bind("<Tab>",self._tab); self.entry.focus()
        self._p("👻 Ghost Terminal — AI watches for typos and explains errors.\n","sys")
        self._p("Prefix 'ai ' to ask Ghost anything.\n","sys")
    def _p(self,t,tag=""):
        self.out.config(state=tk.NORMAL)
        self.out.insert(tk.END,t,tag) if tag else self.out.insert(tk.END,t)
        self.out.see(tk.END); self.out.config(state=tk.DISABLED)
    def _enter(self,_=None):
        cmd=self.iv.get().strip()
        if not cmd: return
        self.hist.append(cmd); self.hi=len(self.hist); self.iv.set("")
        self._p(f"$ {cmd}\n","prompt")
        fix=check_typo(cmd)
        if fix and fix!=cmd:
            self._p(f"⚠ Typo detected. Did you mean: {fix}\n","typo")
            self._p("↳ Press Tab to use fix\n","typo")
            speak_to_face(f"Typo detected. Did you mean {fix}?")
            self._last_fix=fix; return
        if cmd.lower().startswith("ghost "): self._ghost(cmd[6:]); return
        if cmd.lower().startswith("ai "): self._ask(cmd[3:]); return
        if cmd.startswith("cd "):
            try: os.chdir(os.path.expanduser(cmd[3:])); self.cwd=os.getcwd(); self.pl.config(text=f"{self.cwd.split('/')[-1]}$ ")
            except Exception as e: self._p(f"{e}\n","error"); self._explain(cmd,str(e))
            return
        if cmd=="clear": self.out.config(state=tk.NORMAL); self.out.delete("1.0",tk.END); self.out.config(state=tk.DISABLED); return
        if cmd=="ghost-list": self._glist(); return
        threading.Thread(target=self._run,args=(cmd,),daemon=True).start()
    def _tab(self,_):
        if self._last_fix: self.iv.set(self._last_fix); self._last_fix=None
        return "break"
    def _run(self,cmd):
        try:
            r=subprocess.run(cmd,shell=True,capture_output=True,text=True,cwd=self.cwd,timeout=60)
            if r.stdout: self.q.put(("p",r.stdout,""))
            if r.returncode==0: self.q.put(("p","[OK]\n","ok"))
            else:
                if r.stderr: self.q.put(("p",r.stderr,"error"))
                self._explain(cmd,r.stderr or f"exit {r.returncode}")
        except subprocess.TimeoutExpired: self.q.put(("p","Timeout\n","error"))
        except Exception as e: self.q.put(("p",f"Failed: {e}\n","error"))
    def _explain(self,cmd,err):
        if not AI or not os.environ.get("GITHUB_PAT"): return
        def go():
            try:
                headers = {
                    "Authorization": f"Bearer {os.environ.get("GITHUB_PAT")}",
                    "Content-Type": "application/json",
                    "X-GitHub-Api-Version": "2026-03-10"
                }
                data = {
                    "model": "openai/gpt-4o-mini", # Using a free model from GitHub Models
                    "messages": [
                        {"role": "system", "content": SYS},
                        {"role": "user", "content": f"Command: {cmd}\nError: {err}"}
                    ],
                    "max_tokens": 120
                }
                response = requests.post(GITHUB_MODELS_ENDPOINT, headers=headers, json=data)
                response.raise_for_status()
                text = response.json()["choices"][0]["message"]["content"]
                self.q.put(("p",f"🤖 {text}\n","ai"))
                speak_to_face(text)
            except Exception as e: self.q.put(("p",f"AI error: {e}\n","error"))
        threading.Thread(target=go,daemon=True).start()
    def _ask(self,question):
        if not AI or not os.environ.get("GITHUB_PAT"): self._p("AI unavailable. Set GITHUB_PAT to activate.\n","error"); return
        def go():
            try:
                headers = {
                    "Authorization": f"Bearer {os.environ.get("GITHUB_PAT")}",
                    "Content-Type": "application/json",
                    "X-GitHub-Api-Version": "2026-03-10"
                }
                data = {
                    "model": "openai/gpt-4o-mini", # Using a free model from GitHub Models
                    "messages": [
                        {"role": "system", "content": SYS},
                        {"role": "user", "content": question}
                    ],
                    "max_tokens": 150
                }
                response = requests.post(GITHUB_MODELS_ENDPOINT, headers=headers, json=data)
                response.raise_for_status()
                text = response.json()["choices"][0]["message"]["content"]
                self.q.put(("p",f"🤖 {text}\n","ai"))
                speak_to_face(text)
            except Exception as e: self.q.put(("p",f"AI error: {e}\n","error"))
        threading.Thread(target=go,daemon=True).start()
    def _ghost(self,word):
        try:
            cmds=json.load(open("/etc/mt-os/ghost-commands.json"))
            w=word.strip()
            if w == "pull":
                self._p("Pulling latest changes from repository...\n", "ai")
                threading.Thread(target=self._run, args=("git pull",), daemon=True).start()
            elif w == "push":
                self._p("Pushing changes to repository...\n", "ai")
                threading.Thread(target=self._run, args=("git push",), daemon=True).start()
            elif w == "status":
                self._p("Checking repository status...\n", "ai")
                threading.Thread(target=self._run, args=("git status",), daemon=True).start()
            elif w in cmds:
                for c in cmds[w]: self._p(f"▶ {c}\n","ok"); subprocess.Popen(c,shell=True,cwd=self.cwd)
                speak_to_face(f"Running ghost command {w}")
            else: self._p(f"No ghost command: {w}\n","error"); speak_to_face(f"No ghost command named {w}")
        except: self._p("Ghost unavailable\n","error")
    def _glist(self):
        try:
            cmds=json.load(open("/etc/mt-os/ghost-commands.json"))
            if cmds: [self._p(f"  ghost {k:15s} → {' | '.join(v)}\n","ai") for k,v in cmds.items()]
            else: self._p("No ghost commands saved.\n","sys")
        except: self._p("Error\n","error")
    def _hu(self,_):
        if self.hist and self.hi>0: self.hi-=1; self.iv.set(self.hist[self.hi])
    def _hd(self,_):
        if self.hi<len(self.hist)-1: self.hi+=1; self.iv.set(self.hist[self.hi])
        else: self.hi=len(self.hist); self.iv.set("")
    def _pq(self):
        while True:
            try: i=self.q.get_nowait(); self._p(i[1],i[2])
            except: break
        self.root.after(50,self._pq)
    def run(self): self.root.mainloop()
if __name__=="__main__": Term().run()
