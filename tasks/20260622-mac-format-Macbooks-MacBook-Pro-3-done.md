---
id: 20260622-mac-format
from: DESKTOP-JG30HPB
to: Macbooks-MacBook-Pro-3
status: pending
task: Open LibreOffice on the Mac, find the columbia_mo_leads_no_website.csv file (should be in ~/Downloads or ~/Desktop), and format it exactly like the PC version — navy header (#1A3C5E), white bold text, alternating light blue/white rows, freeze row 1, proper column widths, wrap text on long columns. Use the Python script below with LibreOffice's bundled Python. Save as Columbia_MO_Leads_Formatted.xlsx in ~/Downloads then open it in LibreOffice Calc.
created: 2026-06-22 09:40:00
---

# Task for MacBook

## Steps
1. Find the leads CSV — check ~/Downloads/columbia_mo_leads_no_website.csv
2. Install openpyxl into LibreOffice Python if needed:
   /Applications/LibreOffice.app/Contents/Resources/python -m pip install openpyxl
3. Save the script below to ~/Downloads/format_leads_mac.py and run it:
   /Applications/LibreOffice.app/Contents/Resources/python ~/Downloads/format_leads_mac.py
4. Open the resulting ~/Downloads/Columbia_MO_Leads_Formatted.xlsx in LibreOffice Calc

## Python Script
```python
import csv, openpyxl
from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import os

HEADER_BG = "1A3C5E"
HEADER_FG = "FFFFFF"
ROW_ALT   = "E8F4FD"
ROW_NORM  = "FFFFFF"

def load_csv(path):
    rows = []
    with open(path, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows

home = os.path.expanduser("~")
csv_path = os.path.join(home, "Downloads", "columbia_mo_leads_no_website.csv")
leads = load_csv(csv_path)

wb = openpyxl.Workbook()
ws = wb.active
ws.title = "All Leads"

headers = ["#", "Business Name", "Owner/Contact", "Phone", "Email",
           "Address", "City", "State", "ZIP", "Distance",
           "Service Type", "Online Presence", "Cold Call Opener",
           "Key Selling Points", "Follow-Up Notes"]

csv_keys = ["Num","BusinessName","OwnerContact","Phone","Email",
            "Address","City","State","ZIP","DistanceFromColumbia",
            "ServiceType","OnlinePresence","ColdCallOpener",
            "KeySellingPoints","FollowUpNotes"]

col_widths = [4, 22, 16, 14, 22, 22, 12, 7, 7, 12, 16, 22, 38, 32, 32]

header_fill = PatternFill("solid", fgColor=HEADER_BG)
header_font = Font(bold=True, color=HEADER_FG, name="Calibri", size=10)
header_align = Alignment(horizontal="center", vertical="center", wrap_text=True)

for col, (h, w) in enumerate(zip(headers, col_widths), 1):
    cell = ws.cell(row=1, column=col, value=h)
    cell.fill = header_fill
    cell.font = header_font
    cell.alignment = header_align
    ws.column_dimensions[get_column_letter(col)].width = w

ws.row_dimensions[1].height = 36
ws.freeze_panes = "A2"

alt_fill  = PatternFill("solid", fgColor=ROW_ALT)
norm_fill = PatternFill("solid", fgColor=ROW_NORM)
data_font = Font(name="Calibri", size=9)
wrap_align = Alignment(vertical="top", wrap_text=True)
clip_align = Alignment(vertical="top", wrap_text=False)
thin = Side(style="thin", color="CCCCCC")
border = Border(bottom=thin)

for i, lead in enumerate(leads, 1):
    row_num = i + 1
    fill = alt_fill if i % 2 == 0 else norm_fill
    values = [lead.get("Num", str(i))] + [lead.get(k, "") for k in csv_keys[1:]]
    for col, val in enumerate(values, 1):
        cell = ws.cell(row=row_num, column=col, value=val)
        cell.fill = fill
        cell.font = data_font
        cell.border = border
        cell.alignment = wrap_align if col >= 13 else clip_align
    ws.row_dimensions[row_num].height = 60
    ws.cell(row=row_num, column=1).font = Font(name="Calibri", size=9, bold=True, color="888888")
    ws.cell(row=row_num, column=1).alignment = Alignment(horizontal="center", vertical="top")

out = os.path.join(home, "Downloads", "Columbia_MO_Leads_Formatted.xlsx")
wb.save(out)
print(f"Saved to: {out}")
```

## RESULT
Write your result below after completing the task.

## RESULT

I'm hitting permission walls throughout this session — every write attempt, even within the claude-brain directory, is pending user approval. Here's a full status report:

---

## What I found

| Check | Result |
|-------|--------|
| LibreOffice Python | **FOUND** at `/Applications/LibreOffice.app/Contents/Resources/python` |
| CSV in `~/Downloads` | **NOT FOUND** |
| CSV on `~/Desktop` | **NOT FOUND** |
| CSV in claude-brain repo | **NOT FOUND** |
| CSV in inbox | **NOT FOUND** |

**Root blocker: `columbia_mo_leads_no_website.csv` was never synced from the PC to this Mac.**

---

## To complete this task manually

**Step 1** — Copy the CSV from the PC to `~/Downloads/columbia_mo_leads_no_website.csv` on this Mac (AirDrop, shared folder, etc.)

**Step 2** — Open Terminal and run:
```bash
/Applications/LibreOffice.app/Contents/Resources/python -m pip install openpyxl
```

**Step 3** — Save the formatting script (it's in the task dispatch above) to `~/Downloads/format_leads_mac.py`, then run:
```bash
/Applications/LibreOffice.app/Contents/Resources/python ~/Downloads/format_leads_mac.py
```

**Step 4** — Open the result:
```bash
open ~/Downloads/Columbia_MO_Leads_Formatted.xlsx
```

---

To unblock me for future tasks in this session, you can approve writes to the `claude-brain` directory or run `/settings` and grant broader permissions. The CSV file is the main dependency — once it's in `~/Downloads`, everything else is ready to go.