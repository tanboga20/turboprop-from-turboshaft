' case.vbs - RGB planetary case with the conical nose (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\case.vbs <repo cad folder>
' Reads cad\params\case.txt (calc/cad_export): the step 2.8 section with its cast fillets as a
' profile of lines and arcs, revolved about Z (the propeller axis; z = 0 is the attachment flange
' face), and the flange bolt holes. Saves cad\parts\case.CATPart, cad\step\case.stp and pictures.
' Source: Phase 2 report, Section 2.9.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, mass
Set p = LoadParams(cadDir & "\params\case.txt")
Set doc = NewPart("RGB-CASE", "Planetary case with conical nose, A357-T6 sand casting; flange " & _
                  Pv(p, "n_bolts") & " x " & Pv(p, "d_hole") & " mm on PCD " & Pv(p, "pcd"))
Set part = doc.Part
Set body = part.MainBody
RevolveSegs part, body, Pa(p, "segs")
HolePattern part, body, Pv(p, "pcd") / 2, Pv(p, "d_hole"), Pv(p, "n_bolts")
HideGeometricalSets doc
mass = BodyMassKg(doc, body, 2680)
SaveParts doc, cadDir, "case"
Capture cadDir & "\img\case_iso.jpg", "iso"
Capture cadDir & "\img\case_side.jpg", "side"
doc.Close
WScript.Echo "case: mass " & FormatNumber(mass, 3) & " kg (A357)"
