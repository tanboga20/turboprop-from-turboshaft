' gen_gear.vbs - starter-generator drive gear of the accessory drives (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\gen_gear.vbs <repo cad folder>
' Reads cad\params\gen_gear.txt (calc/cad_export): helical teeth (right hand) in mesh with the
' first-stage gear, a solid disc as wide as the teeth (step 2.6: a thin web had a mode in the mesh
' band, 1.33 kg), 16 mm bore for the drive shaft with its shear neck. Saves cad\parts\gen_gear.CATPart,
' cad\step\gen_gear.stp and a picture. Source: Phase 2 report, Section 2.9.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, z, mn, beta, x, b, an, g, rt, rh, rbo, hl, mass
Set p = LoadParams(cadDir & "\params\gen_gear.txt")
z = Pv(p, "z") : mn = Pv(p, "mn") : beta = Pv(p, "beta") : x = Pv(p, "x") : b = Pv(p, "b") : an = Pv(p, "alpha_n")
g = GearData(z, mn, beta, an, x, False)
rt = g(2) : rh = Pv(p, "hub_d") / 2 : rbo = Pv(p, "bore") / 2 : hl = b         ' hub as wide as the teeth (step 2.6 mass)

Set doc = NewPart("AGB-GEN-GEAR", "Starter-generator drive gear, z " & z & ", mn " & mn & ", beta " & beta & " deg right hand, b " & b & " mm, solid disc")
Set part = doc.Part
Set body = part.MainBody
RevolveRZ part, body, Array(rbo, (b - hl) / 2, rh, (b - hl) / 2, rh, 0, rt, 0, rt, b, rh, b, rh, (b + hl) / 2, rbo, (b + hl) / 2)
CutHelicalTeeth doc, body, z, mn, beta, Pv(p, "hand_right") = 1, an, x, b
HideGeometricalSets doc
mass = BodyMassKg(doc, body, 7830)
SaveParts doc, cadDir, "gen_gear"
Capture cadDir & "\img\gen_gear_iso.jpg", "iso"
doc.Close
WScript.Echo "gen_gear: mass " & FormatNumber(mass, 3) & " kg"
