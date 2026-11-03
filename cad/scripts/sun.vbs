' sun.vbs - floating sun gear of the RGB planetary stage (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\sun.vbs <repo cad folder>
' Reads cad\params\sun.txt (calc/cad_export). The bore carries the internal spline of the quill
' shaft (step 2.5), drawn here as its plain bore. Saves cad\parts\sun.CATPart, cad\step\sun.stp.
' Source: Phase 2 report, Section 2.9.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, z, m, x, b, an, rb, rt, mass
Set p = LoadParams(cadDir & "\params\sun.txt")
z = Pv(p, "z") : m = Pv(p, "m") : x = Pv(p, "x") : b = Pv(p, "b") : an = Pv(p, "alpha_n")
rb = Pv(p, "bore") / 2
rt = Pv(p, "d_tip") / 2

Set doc = NewPart("RGB-SUN", "Sun gear, z " & z & ", m " & m & ", b " & b & " mm, Pyrowear 53; bore = quill spline")
Set part = doc.Part
Set body = part.MainBody
RevolveRZ part, body, Array(rb, 0, rt, 0, rt, b, rb, b)
CutSpurTeeth doc, body, z, m, an, x, b, False
HideGeometricalSets doc
mass = BodyMassKg(doc, body, 7830)
SaveParts doc, cadDir, "sun"
Capture cadDir & "\img\sun_iso.jpg", "iso"
doc.Close
WScript.Echo "sun: mass " & FormatNumber(mass, 3) & " kg"
