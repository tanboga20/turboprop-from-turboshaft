' rollers.vbs - roller set of one full-complement planet bearing (CATIA V5 R19, step 3.1).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\rollers.vbs <repo cad folder>
' Reads cad\params\rollers.txt (calc/assembly/as_export): n rollers on the pitch circle between the pin
' (inner race) and the planet bore (outer race), step 2.5; the roller diameter is 0.01 mm under size so
' that the rollers touch neither race in the clash check. z = 0 is the planet face. Saves
' cad\parts\planet_rollers.CATPart and cad\step\planet_rollers.stp. Source: Phase 3 report, Section 3.1.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, pd, ref, n, v
Set p = LoadParams(cadDir & "\params\rollers.txt")
n = Pv(p, "n")
Set doc = NewPart("RGB-PLANET-ROLLERS", "Planet bearing roller set, " & n & " rollers " & FormatNumber(2 * Pv(p, "r_roller"), 2) & _
                  " x " & Pv(p, "L") & " mm, full complement")
Set part = doc.Part
Set body = part.MainBody
Set pd = PadCircleZ(part, body, Pv(p, "r_pitch"), 0, Pv(p, "r_roller"), Pv(p, "z0"), Pv(p, "z0") + Pv(p, "L"))
Set ref = part.CreateReferenceFromObject(part.OriginElements.PlaneXY)
part.InWorkObject = body
part.ShapeFactory.AddNewCircPattern pd, 1, n, 0, 360 / n, 1, 1, ref, ref, True, 0, True
part.Update
HideGeometricalSets doc
v = BodyVolume(doc, body)
SaveParts doc, cadDir, "planet_rollers"
doc.Close
WScript.Echo "planet_rollers: volume " & FormatNumber(v, 0, , , 0) & " mm3"
