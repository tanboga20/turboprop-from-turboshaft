' assembly.vbs - the complete RGB in three modules plus customer equipment (CATIA V5 R19, step 3.1).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\assembly.vbs <repo cad folder> [noclash]
' Reads cad\params\assembly.txt (calc/assembly/as_layout via cx_export): every instance with its part,
' module, rotation about its own Z axis and position. Axis Z is the propeller axis, z = 0 the
' attachment flange face of the planetary case, the propeller at +z; the PT axis is a_s1 below. Gear
' phases come from as_layout (a tooth of one gear in a space of the other on each line of centres).
' The modules of MNT-01 are separate products: mod_planetary (case, ring, carrier and propeller
' shaft, sun and quill, planets with their roller sets, propeller bearings and nose parts),
' mod_first_stage (first-stage case, gear pair, intermediate shaft, their bearings and nuts),
' mod_accessories (accessory cover, generator, OSG and PCU drives, pump pack, quills) and
' mod_equipment (generator, OSG and PCU envelopes, the oil tank; TBD, not RGB mass) and, since step 3.2,
' mod_lubrication (jets, galleries as oil volumes, transfer sleeve, pitch oil tube, valves, filter, chip
' detectors, oil debris monitor; cad\params\oil_assembly.txt from calc/oil_system) and mod_lub07_mist
' (the emergency air-oil mist system of LUB-07, Hamit's decision). Saves them and
' cad\assy\rgb_assembly.CATProduct with a STEP copy (cad\step\rgb_assembly.stp), pictures, and runs
' the CATIA clash analysis (contact and clash between all parts) into cad\assy\clash_report.csv.
' Source: Phase 2 report, Section 2.9; Phase 3 report, Section 3.1.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, n, k, f, mods, m, docs(5), i, top, tprods, sel, t0, doClash, po, fl, src
doClash = True
If WScript.Arguments.Count > 1 Then doClash = (WScript.Arguments(1) <> "noclash")
Set p = LoadParams(cadDir & "\params\assembly.txt")
n = Pv(p, "n")
mods = Array("planetary", "first_stage", "accessories", "equipment", "lubrication", "lub07_mist")
If Not fso.FolderExists(cadDir & "\assy") Then fso.CreateFolder cadDir & "\assy"

' ---------------------------------------------------------------- modules
For m = 0 To 5
    Set docs(m) = CATIA.Documents.Add("Product")
    docs(m).Product.PartNumber = "RGB-MOD-" & UCase(mods(m))
    docs(m).Product.DescriptionRef = "RGB module " & mods(m) & " (MNT-01)"
Next
' the instances of step 3.1 (assembly.txt) and of the oil system of step 3.2 (oil_assembly.txt, with axes)
src = Array("assembly", "oil_assembly")
For fl = 0 To 1
    If fso.FileExists(cadDir & "\params\" & src(fl) & ".txt") Then
        Set po = LoadParams(cadDir & "\params\" & src(fl) & ".txt")
        For k = 1 To Pv(po, "n")
            f = Split(Ps(po, "i" & k), " ")             ' part module rot x y z [X Y Z axes]
            For m = 0 To 5
                If mods(m) = f(1) Then Place docs(m).Product.Products, f, 1000 * fl + k
            Next
        Next
    End If
Next
For m = 0 To 5
    docs(m).Product.Update
    If fso.FileExists(cadDir & "\assy\mod_" & mods(m) & ".CATProduct") Then fso.DeleteFile cadDir & "\assy\mod_" & mods(m) & ".CATProduct", True
    SafeSaveAs docs(m), cadDir & "\assy\mod_" & mods(m) & ".CATProduct"
    WScript.Echo "module " & mods(m) & ": " & docs(m).Product.Products.Count & " components"
Next
For m = 5 To 0 Step -1
    docs(m).Close
Next

' ---------------------------------------------------------------- top product
Set top = CATIA.Documents.Add("Product")
top.Product.PartNumber = "RGB-ASSEMBLY"
top.Product.DescriptionRef = "Turboprop RGB, three modules (MNT-01) and the accessory envelopes"
Set tprods = top.Product.Products
For m = 0 To 5
    tprods.AddComponentsFromFiles Array(cadDir & "\assy\mod_" & mods(m) & ".CATProduct"), "All"
Next
top.Product.Update
If fso.FileExists(cadDir & "\assy\rgb_assembly.CATProduct") Then fso.DeleteFile cadDir & "\assy\rgb_assembly.CATProduct", True
SafeSaveAs top, cadDir & "\assy\rgb_assembly.CATProduct"
If fso.FileExists(cadDir & "\step\rgb_assembly.stp") Then fso.DeleteFile cadDir & "\step\rgb_assembly.stp", True
top.ExportData cadDir & "\step\rgb_assembly.stp", "stp"
WScript.Echo "STEP written"

' pictures: whole RGB, then without the customer equipment, then the gear trains alone
Capture cadDir & "\img\rgb3_iso.jpg", "iso"
Capture cadDir & "\img\rgb3_back.jpg", "back"
Set sel = top.Selection
sel.Clear
sel.Add tprods.Item(4)
sel.VisProperties.SetShow 1
sel.Clear
Capture cadDir & "\img\rgb3_noequip_iso.jpg", "iso"
Capture cadDir & "\img\rgb3_noequip_back.jpg", "back"
Capture cadDir & "\img\rgb3_noequip_front.jpg", "front"
Capture cadDir & "\img\rgb3_noequip_side.jpg", "side"
HideCases tprods, True
Capture cadDir & "\img\rgb3_internals_iso.jpg", "iso"
Capture cadDir & "\img\rgb3_internals_back.jpg", "back"
Capture cadDir & "\img\rgb3_internals_side.jpg", "side"
HideCases tprods, False
sel.Add tprods.Item(4)
sel.VisProperties.SetShow 0
sel.Clear

' ---------------------------------------------------------------- clash analysis
If doClash Then
    Dim cls, cl, cf, out, j, ty
    t0 = Timer
    Set cls = top.Product.GetTechnologicalObject("Clashes")
    Set cl = cls.Add
    cl.ComputationType = 0                             ' catClashComputationTypeBetweenAll
    cl.InterferenceType = 0                            ' catClashInterferenceTypeContact: contacts and clashes
    cl.Compute
    Set out = fso.CreateTextFile(cadDir & "\assy\clash_report.csv", True)
    out.WriteLine "first,second,type,value_mm"
    For j = 1 To cl.Conflicts.Count
        Set cf = cl.Conflicts.Item(j)
        Select Case cf.Type
            Case 0: ty = "clash"
            Case 1: ty = "contact"
            Case Else: ty = "clearance"
        End Select
        out.WriteLine cf.FirstProduct.Name & "," & cf.SecondProduct.Name & "," & ty & "," & FormatNumber(cf.Value, 3, , , 0)
    Next
    out.Close
    WScript.Echo "clash analysis: " & cl.Conflicts.Count & " conflicts in " & Round(Timer - t0) & " s"
    cls.Remove 1
End If
SafeSave top
top.Close
WScript.Echo "assembly saved"

Sub Place(prods, f, k)
    ' one instance of cad\parts\<f(0)>.CATPart, named i<k>_<name>: turned by f(2) degrees about its own Z
    ' axis and moved to (f(3), f(4), f(5)); with 15 fields, f(6..14) are its X, Y and Z axes in the RGB frame
    Dim comp, r, j, a(11)
    prods.AddComponentsFromFiles Array(cadDir & "\parts\" & f(0) & ".CATPart"), "All"
    Set comp = prods.Item(prods.Count)
    comp.Name = "i" & k & "_" & f(0)
    If UBound(f) >= 14 Then
        For j = 0 To 8
            a(j) = CDbl(f(6 + j))
        Next
    Else
        r = Rad(CDbl(f(2)))
        a(0) = Cos(r) : a(1) = Sin(r) : a(2) = 0 : a(3) = -Sin(r) : a(4) = Cos(r) : a(5) = 0
        a(6) = 0 : a(7) = 0 : a(8) = 1
    End If
    For j = 0 To 2
        a(9 + j) = CDbl(f(3 + j))
    Next
    comp.Move.Apply a
End Sub

Sub HideCases(tprods, hide)
    ' show or hide the castings, the carrier and the nose housing (by instance name) in every module
    Dim m, j, c, s, nm
    Set s = top.Selection
    s.Clear
    For m = 1 To tprods.Count
        For j = 1 To tprods.Item(m).Products.Count
            Set c = tprods.Item(m).Products.Item(j)
            nm = c.Name
            If InStr(nm, "_case") > 0 Or InStr(nm, "_fs_case") > 0 Or InStr(nm, "acc_cover") > 0 Or _
               InStr(nm, "_carrier") > 0 Or InStr(nm, "qj_housing") > 0 Or InStr(nm, "gen_cartridge") > 0 Then s.Add c
        Next
    Next
    If s.Count > 0 Then
        If hide Then s.VisProperties.SetShow 1 Else s.VisProperties.SetShow 0
    End If
    s.Clear
End Sub
