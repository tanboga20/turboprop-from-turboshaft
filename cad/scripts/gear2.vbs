' gear2.vbs - first-stage gear on the intermediate shaft (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\gear2.vbs <repo cad folder>
' Reads cad\params\gear2.txt (calc/cad_export): helical teeth (left hand), rim of 3.5 modules under
' the root, central web, hub on the 50 mm intermediate shaft (step 2.5). Saves cad\parts\gear2.CATPart,
' cad\step\gear2.stp and a picture. Source: Phase 2 report, Section 2.9.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, z, mn, beta, x, b, an, rt, rr, rh, rbo, w, hl, mass
Set p = LoadParams(cadDir & "\params\gear2.txt")
z = Pv(p, "z") : mn = Pv(p, "mn") : beta = Pv(p, "beta") : x = Pv(p, "x") : b = Pv(p, "b") : an = Pv(p, "alpha_n")
rt = Pv(p, "d_tip") / 2
rr = Pv(p, "d_root") / 2 - Pv(p, "rim")          ' rim inside radius
rh = Pv(p, "hub_d") / 2 : rbo = Pv(p, "bore") / 2
w = Pv(p, "web") : hl = Pv(p, "hub_len")

Set doc = NewPart("RGB-GEAR2", "First-stage gear, z " & z & ", mn " & mn & ", beta " & beta & " deg left hand, b " & b & " mm, Pyrowear 53")
Set part = doc.Part
Set body = part.MainBody
RevolveRZ part, body, Array(rbo, (b - hl) / 2, rh, (b - hl) / 2, rh, (b - w) / 2, rr, (b - w) / 2, rr, 0, rt, 0, _
                            rt, b, rr, b, rr, (b + w) / 2, rh, (b + w) / 2, rh, (b + hl) / 2, rbo, (b + hl) / 2)
CutHelicalTeeth doc, body, z, mn, beta, Pv(p, "hand_right") = 1, an, x, b
HideGeometricalSets doc
mass = BodyMassKg(doc, body, 7830)
SaveParts doc, cadDir, "gear2"
Capture cadDir & "\img\gear2_iso.jpg", "iso"
doc.Close
WScript.Echo "gear2: mass " & FormatNumber(mass, 3) & " kg"
