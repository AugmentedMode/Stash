#!/usr/bin/env python3
"""Generate matching SVG masters and native PDF vectors. Requires reportlab."""
from pathlib import Path
from contextlib import contextmanager
from html import escape
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor

ROOT = Path(__file__).resolve().parents[1]
LAV = '#C1BEFF'
INK = '#36384F'
MID = '#565875'
LIGHT = '#777899'
WHITE = '#EBE9FF'

class Artwork:
    def __init__(self, name):
        self.name = name
        self.svg = []
        self.pdf = canvas.Canvas(str(ROOT / 'Sources/Stash/Resources/CategoryArt' / (name + '.pdf')), pagesize=(160, 120), invariant=1)
        self.pdf.setTitle('Stash — ' + name)
        self.pdf.translate(0, 120)
        self.pdf.scale(1, -1)

    def style(self, fill, stroke, width, opacity):
        self.pdf.setFillColor(HexColor(fill or '#000000'))
        self.pdf.setStrokeColor(HexColor(stroke or '#000000'))
        self.pdf.setFillAlpha(opacity)
        self.pdf.setStrokeAlpha(opacity)
        self.pdf.setLineWidth(width)
        self.pdf.setLineCap(1)
        self.pdf.setLineJoin(1)
        return f'fill="{fill or "none"}" stroke="{stroke or "none"}" stroke-width="{width}" opacity="{opacity}" stroke-linecap="round" stroke-linejoin="round"'

    def rect(self, x, y, w, h, r=0, fill=INK, stroke=None, width=1, opacity=1):
        attrs = self.style(fill, stroke, width, opacity)
        self.svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" {attrs}/>')
        self.pdf.roundRect(x, y, w, h, r, fill=bool(fill), stroke=bool(stroke))

    def ellipse(self, x, y, rx, ry, fill=LAV, opacity=1):
        attrs = self.style(fill, None, 1, opacity)
        self.svg.append(f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" {attrs}/>')
        self.pdf.ellipse(x-rx, y-ry, x+rx, y+ry, fill=1, stroke=0)

    def path(self, commands, fill=None, stroke=LAV, width=2, opacity=1):
        attrs = self.style(fill, stroke, width, opacity)
        d = ' '.join(op + ' ' + ' '.join(map(str, args)) for op, *args in commands)
        self.svg.append(f'<path d="{d}" {attrs}/>')
        p = self.pdf.beginPath()
        for op, *v in commands:
            if op == 'M': p.moveTo(*v)
            elif op == 'L': p.lineTo(*v)
            elif op == 'C': p.curveTo(*v)
            elif op == 'Z': p.close()
        self.pdf.drawPath(p, fill=bool(fill), stroke=bool(stroke))

    @contextmanager
    def rotate(self, degrees, x=80, y=60):
        self.svg.append(f'<g transform="rotate({degrees} {x} {y})">')
        self.pdf.saveState()
        self.pdf.translate(x, y)
        self.pdf.rotate(degrees)
        self.pdf.translate(-x, -y)
        yield
        self.pdf.restoreState()
        self.svg.append('</g>')

    def glint(self, x, y, size=4):
        self.path([('M',x-size,y),('L',x+size,y),('M',x,y-size),('L',x,y+size)], width=1.3, opacity=.65)

    def paper(self, x=49, y=18, w=64, h=82, fill=MID):
        self.path([('M',x+7,y),('L',x+w-16,y),('L',x+w,y+16),('L',x+w,y+h-7),('C',x+w,y+h,x+w,y+h,x+w-7,y+h),('L',x+7,y+h),('C',x,y+h,x,y+h,x,y+h-7),('L',x,y+7),('C',x,y,x,y,x+7,y),('Z',)],fill=fill,stroke='#9290BC',width=.8)
        self.path([('M',x+w-16,y+1),('L',x+w-16,y+11),('C',x+w-16,y+16,x+w-12,y+16,x+w-10,y+16),('L',x+w-1,y+16),('Z',)],fill=LAV,stroke=None,opacity=.8)

    def lines(self, x, y, lengths=(33,25,30)):
        for i, length in enumerate(lengths): self.rect(x,y+i*9,length,3,1.5,fill=LAV,opacity=.85 if i==0 else .4)

    def finish(self):
        content = '\n'.join(self.svg)
        (ROOT / 'Assets/CategoryArt' / (self.name + '.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="160" height="120" viewBox="0 0 160 120" role="img" aria-label="{escape(self.name)}">\n{content}\n</svg>\n')
        self.pdf.showPage()
        self.pdf.save()

for name in ['all','pinned','text','link','image','screenshot','file','video','email','color','search']:
    a = Artwork(name)
    a.ellipse(80,105,44,5,fill='#171923',opacity=.22)
    if name in ['all','text','pinned','search']:
        with a.rotate(-13): a.rect(39,24,64,77,9,fill=INK,stroke='#68678A',width=.7)
        if name == 'all':
            with a.rotate(10): a.rect(58,18,64,78,9,fill='#44465F',stroke='#8582AD',width=.7)
        a.paper()
        if name == 'pinned':
            a.lines(61,71,(28,21))
            with a.rotate(24,82,44):
                a.path([('M',82,53),('L',82,69)],stroke=WHITE,width=2)
                a.path([('M',73,28),('L',91,28),('L',89,43),('L',96,50),('L',68,50),('L',75,43),('Z',)],fill=LAV,stroke=WHITE,width=.8)
                a.rect(72,25,20,5,2,fill=WHITE)
        elif name == 'search':
            a.lines(60,36,(27,20))
            a.ellipse(99,75,17,17,fill=INK)
            a.ellipse(99,75,12,12,fill='#696C94')
            a.path([('M',111,88),('L',125,102)],stroke=LAV,width=6)
            a.path([('M',94,68),('C',97,64,102,65,104,68)],stroke=WHITE,width=1.5)
        else:
            a.rect(61,39,17,5,2,fill=WHITE)
            a.lines(61,55,(37,27,32,20))
    elif name == 'link':
        with a.rotate(-34):
            a.rect(33,40,60,34,17,fill=INK,stroke='#8A8EBB',width=7)
            a.rect(67,40,60,34,17,fill=None,stroke=LAV,width=7)
            a.path([('M',61,57),('L',99,57)],stroke=WHITE,width=5)
            a.path([('M',86,43),('L',105,43)],stroke=WHITE,width=1.5,opacity=.8)
    elif name == 'image':
        with a.rotate(-10): a.rect(30,25,92,73,8,fill=INK,stroke='#727499')
        with a.rotate(6):
            a.rect(39,21,92,78,8,fill='#D2CEEE')
            a.rect(45,27,80,58,4,fill='#414B70')
            a.ellipse(104,42,8,8,fill='#E8D6B5')
            a.path([('M',45,77),('L',68,49),('L',97,85),('L',45,85),('Z',)],fill='#858DB9',stroke=None)
            a.path([('M',77,85),('L',104,59),('L',125,78),('L',125,85),('Z',)],fill='#A8B9CA',stroke=None)
            a.rect(70,90,29,2,1,fill='#77738F')
    elif name == 'screenshot':
        a.rect(38,29,85,62,8,fill=INK,stroke='#73759D')
        a.rect(44,35,73,8,3,fill=MID)
        for x in [50,56,62]: a.ellipse(x,39,1.3,1.3,fill=LAV)
        a.rect(45,49,25,34,4,fill='#777FA9')
        a.lines(77,54,(31,23,28))
        for x,y,dx,dy in [(27,19,15,15),(133,19,-15,15),(27,101,15,-15),(133,101,-15,-15)]:
            a.path([('M',x,y+dy),('L',x,y),('L',x+dx,y)],stroke=LAV,width=2.5)
        a.path([('M',98,74),('L',103,97),('L',109,90),('L',118,89),('Z',)],fill=WHITE,stroke=INK,width=1)
    elif name == 'file':
        a.path([('M',29,40),('L',29,31),('C',29,26,32,24,37,24),('L',64,24),('L',74,34),('L',125,34),('C',130,34,132,36,132,42),('L',128,96),('L',29,96),('Z',)],fill=INK,stroke='#767698',width=1)
        with a.rotate(7): a.paper(54,18,52,67,fill='#9897BD')
        a.path([('M',27,50),('L',67,50),('L',76,43),('L',128,43),('C',134,43,136,47,134,53),('L',126,97),('L',35,97),('Z',)],fill=MID,stroke='#A19DCB',width=1)
        a.rect(44,65,26,4,2,fill=LAV)
        a.rect(44,75,17,3,1.5,fill=LAV,opacity=.4)
    elif name == 'video':
        a.rect(32,38,99,60,8,fill=INK,stroke='#8584AC')
        a.rect(38,45,87,46,4,fill=MID)
        with a.rotate(-9,32,35):
            a.rect(32,24,99,16,4,fill=LAV)
            for x in [46,70,94,118]:
                a.path([('M',x,24),('L',x-9,40)],stroke=INK,width=8)
        a.path([('M',73,55),('L',94,68),('L',73,81),('Z',)],fill=WHITE,stroke=None)
    elif name == 'email':
        a.path([('M',30,49),('L',78,18),('L',130,49),('L',130,97),('L',30,97),('Z',)],fill=INK,stroke='#7D7EA6',width=1)
        a.rect(48,28,64,63,6,fill='#B6B1D8')
        a.rect(58,41,28,4,2,fill='#585878')
        a.rect(58,51,43,3,1.5,fill='#777493')
        a.path([('M',30,49),('L',80,79),('L',130,49),('L',130,96),('L',30,96),('Z',)],fill=MID,stroke='#9691BE',width=1)
        a.path([('M',31,96),('L',67,71),('M',129,96),('L',93,71)],stroke=LAV,width=1,opacity=.5)
        a.ellipse(116,35,9,9,fill=LAV)
        a.ellipse(116,35,3,3,fill=WHITE)
    elif name == 'color':
        for angle,fill,swatches in [(-27,INK,['#6C82A9','#9DBCD3','#D5E6ED']),(0,MID,['#7779AD','#ABA6DD','#D9D1F6']),(27,'#76738E',['#AC849C','#D3ACBB','#EFDBDF'])]:
            with a.rotate(angle,80,91):
                a.rect(59,19,42,83,7,fill=fill,stroke='#ACA5CD',width=.8)
                for i,c in enumerate(swatches): a.rect(66,26+i*19,28,15,3,fill=c)
                a.ellipse(80,91,3,3,fill=WHITE)
    a.glint(21,39,3)
    a.glint(139,75,4)
    a.ellipse(130,15,1.6,1.6,opacity=.5)
    a.finish()
print('Generated 11 SVG masters and matching PDF vectors.')
