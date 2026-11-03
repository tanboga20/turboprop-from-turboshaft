' pinion.vbs - first-stage pinion, cut on the input shaft (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\pinion.vbs <repo cad folder>
' Reads cad\params\pinion.txt (calc/cad_export): helical teeth (right hand) between the bearing
' journals of the hollow input shaft (step 2.5, bore 24): 45 mm seats for the NU 2209 roller bearings,
' the QJ 209 and its nut, then the 40 mm shaft end to the diaphragm coupling (step 3.1 lengths).
' Saves cad\parts\pinion.CATPart, cad\step\pinion.stp and a picture. Source: Phase 2 report,
' Section 2.9; Phase 3 report, Section 3.1.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, z, mn, beta, x, b, an, rt, rbo, rs, re, lf, lr, ls, mass
Set p = LoadParams(cadDir & "\params\pinion.txt")
z = Pv(p, "z") : mn = Pv(p, "mn") : beta = Pv(p, "beta") : x = Pv(p, "x") : b = Pv(p, "b") : an = Pv(p, "alpha_n")
rt = Pv(p, "d_tip") / 2 : rbo = Pv(p, "bore") / 2
rs = Pv(p, "r_seat") : re = Pv(p, "r_end")
lf = Pv(p, "lj_f") : lr = Pv(p, "lj_r") : ls = Pv(p, "lj_seat")

Set doc = NewPart("RGB-PINION", "First-stage pinion on the input shaft, z " & z & ", mn " & mn & ", beta " & beta & " deg right hand, b " & b & " mm")
Set part = doc.Part
Set body = part.MainBody
RevolveRZ part, body, Array(rbo, -lr, re, -lr, re, -ls, rs, -ls, rs, 0, rt, 0, rt, b, rs, b, rs, b + lf, rbo, b + lf)
CutHelicalTeeth doc, body, z, mn, beta, Pv(p, "hand_right") = 1, an, x, b
HideGeometricalSets doc
mass = BodyMassKg(doc, body, 7830)
SaveParts doc, cadDir, "pinion"
Capture cadDir & "\img\pinion_iso.jpg", "iso"
doc.Close
WScript.Echo "pinion: mass " & FormatNumber(mass, 3) & " kg"
