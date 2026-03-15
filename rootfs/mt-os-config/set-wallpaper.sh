#!/bin/bash
python3 -c "
try:
    from PIL import Image,ImageDraw
    W,H=1920,1080
    img=Image.new('RGB',(W,H),(3,3,10))
    d=ImageDraw.Draw(img)
    for x in range(0,W,40): d.line([(x,0),(x,H)],fill=(0,40,20),width=1)
    for y in range(0,H,40): d.line([(0,y),(W,y)],fill=(0,40,20),width=1)
    cx,hy=W//2,H//2
    for i in range(0,W,60): d.line([(i,H),(cx+(i-cx)//4,hy)],fill=(0,80,40),width=1)
    d.line([(0,hy),(W,hy)],fill=(0,255,136),width=2)
    import os; p=os.path.expanduser('~/.mt-wallpaper.png')
    img.save(p)
except Exception as e: print(e)
"
feh --bg-fill ~/.mt-wallpaper.png 2>/dev/null || xsetroot -solid "#030308"
