' planet.vbs - planet gear of the RGB planetary stage (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\planet.vbs <repo cad folder>
' Reads cad\params\planet.txt (calc/cad_export). The bore is the outer race of the full-complement
' roller bearing (step 2.5), so the blank is a plain ring from the bore to the tip circle; spur teeth
' from catlib. Saves cad\parts\planet.CATPart, cad\step\planet.stp and an iso picture in cad\img.
' Source: Phase 2 report, Section 2.9.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, z, m, x, b, an, rb, rt, mass
Set p = LoadParams(cadDir & "\params\planet.txt")
z = Pv(p, "z") : m = Pv(p, "m") : x = Pv(p, "x") : b = Pv(p, "b") : an = Pv(p, "alpha_n")
rb = Pv(p, "bore") / 2
rt = Pv(p, "d_tip") / 2

Set doc = NewPart("RGB-PLANET", "Planet gear, z " & z & ", m " & m & ", b " & b & " mm; bore = bearing outer race")
Set part = doc.Part
Set body = part.MainBody
RevolveRZ part, body, Array(rb, 0, rt, 0, rt, b, rb, b)
CutSpurTeeth doc, body, z, m, an, x, b, False
HideGeometricalSets doc
mass = BodyMassKg(doc, body, 7830)
SaveParts doc, cadDir, "planet"
Capture cadDir & "\img\planet_iso.jpg", "iso"
doc.Close
WScript.Echo "planet: mass " & FormatNumber(mass, 3) & " kg"
