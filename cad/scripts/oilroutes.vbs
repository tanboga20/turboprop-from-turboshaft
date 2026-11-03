' oilroutes.vbs - oil routes of the RGB oil system: external tubes and drillings (CATIA V5 R19, step 3.2).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\oilroutes.vbs <repo cad folder> [name ...]
' Reads cad\params\oil_routes.txt (calc/oil_system/os_export): one part per branch, each a union of rods
' (x1 y1 z1 x2 y2 z2 r) in RGB coordinates: a cylinder surface along the rod, closed into a solid. The
' rods are the oil volume of the tubes and of the drillings in the castings (cut into the case drawings in
' step 3.9). Saves cad\parts\<name>.CATPart and cad\step\<name>.stp. Source: Phase 3 report, Section 3.2.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, names, i, nm, doc, part, body, hsf, sf, hb, r, k, pt, dr, cy, L, v, cs, sel
Set p = LoadParams(cadDir & "\params\oil_routes.txt")
If WScript.Arguments.Count > 1 Then
    ReDim names(WScript.Arguments.Count - 2)
    For i = 1 To WScript.Arguments.Count - 1
        names(i - 1) = WScript.Arguments(i)
    Next
Else
    names = Split(Ps(p, "names"), " ")
End If
For Each nm In names
    Set doc = NewPart(UCase(nm), Ps(p, nm & ".desc"))
    Set part = doc.Part
    Set body = part.MainBody
    Set hsf = part.HybridShapeFactory
    Set sf = part.ShapeFactory
    Set hb = part.HybridBodies.Add()
    hb.Name = "Rod surfaces"
    For k = 1 To Pv(p, nm & ".n")
        r = Pa(p, nm & ".rod" & k)
        L = Sqr((r(3) - r(0)) ^ 2 + (r(4) - r(1)) ^ 2 + (r(5) - r(2)) ^ 2)
        Set pt = hsf.AddNewPointCoord(r(0), r(1), r(2))
        hb.AppendHybridShape pt
        Set dr = hsf.AddNewDirectionByCoord(r(3) - r(0), r(4) - r(1), r(5) - r(2))
        Set cy = hsf.AddNewCylinder(part.CreateReferenceFromObject(pt), r(6), L, 0, dr)   ' first length along dr
        hb.AppendHybridShape cy
        part.Update
        part.InWorkObject = body
        Set cs = sf.AddNewCloseSurface(part.CreateReferenceFromObject(cy))
        On Error Resume Next
        part.Update
        If Err.Number <> 0 Then
            ' a rod CATIA cannot merge (nearly coincident with another): remove it and report
            Err.Clear
            Set sel = doc.Selection
            sel.Clear
            sel.Add cs
            sel.Delete
            part.Update
            WScript.Echo nm & ": rod " & k & " skipped (could not be merged)"
        End If
        On Error GoTo 0
    Next
    HideGeometricalSets doc
    v = BodyVolume(doc, body)
    SaveParts doc, cadDir, nm
    If doc.Saved Then doc.Close                      ' an unsaved document stays open (no save question)
    WScript.Echo nm & ": " & Pv(p, nm & ".n") & " rods, volume " & FormatNumber(v, 0, , , 0) & " mm3"
Next
