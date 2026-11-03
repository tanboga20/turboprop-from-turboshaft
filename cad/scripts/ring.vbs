' ring.vbs - fixed ring gear of the RGB planetary stage (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\ring.vbs <repo cad folder>
' Reads cad\params\ring.txt (calc/cad_export): internal spur teeth with the tip shortened to
' 0.9 module (step 2.4), rim of 4 modules under the root; the outside diameter is the case bore.
' Saves cad\parts\ring.CATPart, cad\step\ring.stp and a picture in cad\img.
' Source: Phase 2 report, Section 2.9.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, z, m, x, b, an, ri, ro, mass
Set p = LoadParams(cadDir & "\params\ring.txt")
z = Pv(p, "z") : m = Pv(p, "m") : x = Pv(p, "x") : b = Pv(p, "b") : an = Pv(p, "alpha_n")
ri = Pv(p, "d_tip") / 2
ro = Pv(p, "d_root") / 2 + Pv(p, "rim")

Set doc = NewPart("RGB-RING", "Ring gear, z " & z & ", m " & m & ", b " & b & " mm, nitrided 32CrMoV13; OD " & 2 * ro & " mm")
Set part = doc.Part
Set body = part.MainBody
RevolveRZ part, body, Array(ri, 0, ro, 0, ro, b, ri, b)
CutSpurTeeth doc, body, z, m, an, x, b, True
HideGeometricalSets doc
mass = BodyMassKg(doc, body, 7830)
SaveParts doc, cadDir, "ring"
Capture cadDir & "\img\ring_iso.jpg", "iso"
doc.Close
WScript.Echo "ring: mass " & FormatNumber(mass, 3) & " kg"
