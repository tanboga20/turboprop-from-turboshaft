' boxcase.vbs - first-stage case and accessory cover, A357-T6 sand castings (CATIA V5 R19, step 3.1).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\boxcase.vbs <repo cad folder> fs_case|acc_cover
' Reads cad\params\<name>.txt (calc/assembly/as_export): the outline (convex hull of the circles round
' the propeller, PT, generator and OSG axes, or round the propeller and PCU axes) padded over its z
' range, the cavity (the same hull shrunk by the wall) pocketed, then the pads (bearing bosses,
' flanges), the pockets (bearing seats, cartridge bores) and the bolt hole patterns. Built at its
' place in the RGB (z = 0 the attachment flange face of the planetary case). Saves cad\parts\<name>
' .CATPart, cad\step\<name>.stp and a picture. Source: Phase 3 report, Section 3.1.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim nm, p, doc, part, body, zo, zc, i, r, v, desc
nm = WScript.Arguments(1)
Set p = LoadParams(cadDir & "\params\" & nm & ".txt")
If nm = "fs_case" Then
    desc = "First-stage case: offset gear pair, generator and OSG drives; A357-T6 sand casting"
Else
    desc = "Accessory cover: PCU drive and pump pack; A357-T6 sand casting"
End If
Set doc = NewPart(UCase(nm), desc)
Set part = doc.Part
Set body = part.MainBody
zo = Pa(p, "z_out") : zc = Pa(p, "z_cav")
PadSegsZ part, body, Pa(p, "out"), zo(0), zo(1)
PocketSegsZ part, body, Pa(p, "cav"), zc(0), zc(1)
For i = 1 To Pv(p, "n_pads")
    r = Pa(p, "pad" & i)                               ' x y r z1 z2 r_in: r_in > 0 makes an annulus
    If r(5) > 0 Then
        PadRingZ part, body, r(0), r(1), r(5), r(2), r(3), r(4)
    Else
        PadCircleZ part, body, r(0), r(1), r(2), r(3), r(4)
    End If
Next
For i = 1 To Pv(p, "n_pockets")
    r = Pa(p, "pocket" & i)
    PocketCircleZ part, body, r(0), r(1), r(2), r(3), r(4)
Next
For i = 1 To Pv(p, "n_holes")
    r = Pa(p, "holes" & i)
    HolesAt part, body, r(0), r(1), r(2), r(3), r(4), r(5), r(6)
Next
HideGeometricalSets doc
v = BodyVolume(doc, body)
SaveParts doc, cadDir, nm
Capture cadDir & "\img\" & nm & "_iso.jpg", "iso"
Capture cadDir & "\img\" & nm & "_back.jpg", "back"
doc.Close
WScript.Echo nm & ": volume " & FormatNumber(v, 0, , , 0) & " mm3, mass " & FormatNumber(v * 2680e-9, 3) & " kg (A357)"
