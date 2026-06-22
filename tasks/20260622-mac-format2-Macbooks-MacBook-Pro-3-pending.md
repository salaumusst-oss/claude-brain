---
id: 20260622-mac-format2
from: DESKTOP-JG30HPB
to: Macbooks-MacBook-Pro-3
status: pending
task: Install openpyxl into LibreOffice Python on Mac, then build a formatted leads spreadsheet and open it.
created: 2026-06-22 09:55:00
---

## Your job

Run these commands in order using bash_tool or by writing a shell script:

**Step 1 — Install openpyxl:**
`
/Applications/LibreOffice.app/Contents/Resources/python -m pip install openpyxl
`

**Step 2 — Run this Python script** (save to ~/Downloads/fmt.py then run it):
`python
import csv, openpyxl, os
from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
HEADER_BG,HEADER_FG,ROW_ALT="1A3C5E","FFFFFF","E8F4FD"
home=os.path.expanduser("~")
leads=list(csv.DictReader(open(os.path.join(home,"Downloads","columbia_mo_leads_no_website.csv"),encoding="utf-8-sig")))
wb=openpyxl.Workbook(); ws=wb.active; ws.title="All Leads"
headers=["#","Business Name","Owner/Contact","Phone","Email","Address","City","State","ZIP","Distance","Service Type","Online Presence","Cold Call Opener","Key Selling Points","Follow-Up Notes"]
csv_keys=["Num","BusinessName","OwnerContact","Phone","Email","Address","City","State","ZIP","DistanceFromColumbia","ServiceType","OnlinePresence","ColdCallOpener","KeySellingPoints","FollowUpNotes"]
col_widths=[4,22,16,14,22,22,12,7,7,12,16,22,38,32,32]
hf=PatternFill("solid",fgColor=HEADER_BG); hfont=Font(bold=True,color=HEADER_FG,name="Calibri",size=10)
for col,(h,w) in enumerate(zip(headers,col_widths),1):
    c=ws.cell(row=1,column=col,value=h); c.fill=hf; c.font=hfont; c.alignment=Alignment(horizontal="center",vertical="center",wrap_text=True); ws.column_dimensions[get_column_letter(col)].width=w
ws.row_dimensions[1].height=36; ws.freeze_panes="A2"
af=PatternFill("solid",fgColor=ROW_ALT); nf=PatternFill("solid",fgColor="FFFFFF"); df=Font(name="Calibri",size=9); b=Border(bottom=Side(style="thin",color="CCCCCC"))
for i,lead in enumerate(leads,1):
    r=i+1; fill=af if i%2==0 else nf
    for col,val in enumerate([lead.get(k,"") for k in csv_keys],1):
        c=ws.cell(row=r,column=col,value=val); c.fill=fill; c.font=df; c.border=b; c.alignment=Alignment(vertical="top",wrap_text=col>=13)
    ws.row_dimensions[r].height=60
out=os.path.join(home,"Downloads","Columbia_MO_Leads_Formatted.xlsx")
wb.save(out); print("Done:",out)
`

**Step 3 — Open the file:**
`
open ~/Downloads/Columbia_MO_Leads_Formatted.xlsx
`

## RESULT
Write result here after completing.
