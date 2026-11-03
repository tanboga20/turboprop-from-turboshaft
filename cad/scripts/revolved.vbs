' revolved.vbs - the revolved parts of the complete RGB model (CATIA V5 R19, step 3.1).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\revolved.vbs <repo cad folder> [@file] [name ...]
' Reads cad\params\revolved.txt (or cad\params\<file>.txt with @file, e.g. @oil_revolved for the oil
' system hardware of step 3.2) (calc/cad_export, calc/assembly/as_export): for every part (or only
' the names given) a closed (r, z) polyline revolved about Z, optional spur teeth over a z range
' (pinions cut on shafts, accessory gears with their shafts) and optional bolt holes. Bearings, nuts
' and seals are solid envelopes of their catalogue sizes; accessory units are envelopes of customer
' equipment. Saves cad\parts\<name>.CATPart and cad\step\<name>.stp; prints the volumes.
' Source: Phase 3 report, Section 3.1.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, names, i, nm, doc, part, body, t, h, v, zmin, zmax, rz, k, pf, a0
pf = "revolved" : a0 = 1
If WScript.Arguments.Count > 1 Then
    If Left(WScript.Arguments(1), 1) = "@" Then pf = Mid(WScript.Arguments(1), 2) : a0 = 2
End If
Set p = LoadParams(cadDir & "\params\" & pf & ".txt")
If WScript.Arguments.Count > a0 Then
    ReDim names(WScript.Arguments.Count - 1 - a0)
    For i = a0 To WScript.Arguments.Count - 1
        names(i - a0) = WScript.Arguments(i)
    Next
Else
    names = Split(Ps(p, "names"), " ")
End If

For Each nm In names
    Set doc = NewPart(UCase(nm), Ps(p, nm & ".desc"))
    Set part = doc.Part
    Set body = part.MainBody
    rz = Pa(p, nm & ".rz")
    RevolveRZ part, body, rz
    If p.Exists(nm & ".teeth") Then
        t = Pa(p, nm & ".teeth")                       ' z m x z0 b
        CutSpurTeethZ doc, body, t(0), t(1), 20, t(2), t(3), t(4)
    End If
    If p.Exists(nm & ".holes") Then
        h = Pa(p, nm & ".holes")                       ' n pcd d, through the part
        zmin = rz(1) : zmax = rz(1)
        For k = 1 To UBound(rz) Step 2
            If rz(k) < zmin Then zmin = rz(k)
            If rz(k) > zmax Then zmax = rz(k)
        Next
        HolesAt part, body, 0, 0, h(1), h(2), h(0), zmin - 1, zmax + 1
    End If
    HideGeometricalSets doc
    v = BodyVolume(doc, body)
    SaveParts doc, cadDir, nm
    doc.Close
    WScript.Echo nm & ": volume " & FormatNumber(v, 0, , , 0) & " mm3"
Next
