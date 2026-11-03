' drawing.vbs - first drawing of a part: views, a data table and the title block (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\drawing.vbs <repo cad folder> <part>
' Opens cad\parts\<part>.CATPart, makes an A3 ISO sheet with the end view (along the axis) and the
' section through the axis, a table of the design data from cad\params\<part>.txt and a title
' block in English and Turkish, and saves cad\drawings\<part>.CATDrawing and <part>.pdf. Detail
' dimensions, tolerances and surface symbols are added in Phase 3. Source: Phase 2 report, Section 2.9.

Option Explicit
Dim cadDir, fso, name
cadDir = WScript.Arguments(0)
name = WScript.Arguments(1)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, partDoc, drw, sheet, views, front, sect, gb, bg, sc, rows, title, mat, mass, i, f, ox, oy, rcut
Set p = LoadParams(cadDir & "\params\" & name & ".txt")
If Not fso.FolderExists(cadDir & "\drawings") Then fso.CreateFolder cadDir & "\drawings"
Set partDoc = CATIA.Documents.Open(cadDir & "\parts\" & name & ".CATPart")
mass = 0
Select Case name
    Case "planet"
        title = "PLANET GEAR / PLANET DISLISI" : mat = "Pyrowear 53 (AMS 6308), carburized / sementasyon" : sc = 1
        rcut = Pv(p, "d_tip") / 2 + 6
        rows = Array("Number of teeth / Dis sayisi z", Pv(p, "z"), "Module / Modul m (mm)", Pv(p, "m"), _
                     "Pressure angle / Basinc acisi (deg)", Pv(p, "alpha_n"), "Profile shift / Profil kaydirma x", Pv(p, "x"), _
                     "Face width / Dis genisligi b (mm)", Pv(p, "b"), "Tip diameter / Dis cap (mm)", Pv(p, "d_tip"), _
                     "Root diameter / Taban capi (mm)", Pv(p, "d_root"), "Bore = outer race / Delik = dis bilezik (mm)", Pv(p, "bore"), _
                     "Mating gears / Eslenik", "sun z45, ring z119", "Flank finish / Yuzey", "superfinish Rz 0.8 (step 2.4)")
    Case "sun"
        title = "SUN GEAR / GUNES DISLISI" : mat = "Pyrowear 53 (AMS 6308), carburized / sementasyon" : sc = 1
        rcut = Pv(p, "d_tip") / 2 + 6
        rows = Array("Number of teeth / Dis sayisi z", Pv(p, "z"), "Module / Modul m (mm)", Pv(p, "m"), _
                     "Pressure angle / Basinc acisi (deg)", Pv(p, "alpha_n"), "Profile shift / Profil kaydirma x", Pv(p, "x"), _
                     "Face width / Dis genisligi b (mm)", Pv(p, "b"), "Tip diameter / Dis cap (mm)", Pv(p, "d_tip"), _
                     "Root diameter / Taban capi (mm)", Pv(p, "d_root"), "Bore, quill spline / Delik, kamali mil (mm)", Pv(p, "bore"), _
                     "Mating gears / Eslenik", "4 planets z37", "Flank finish / Yuzey", "superfinish Rz 0.8 (step 2.4)")
    Case "ring"
        title = "RING GEAR / HALKA DISLI" : mat = "32CrMoV13, nitrided / nitrurlenmis" : sc = 0.5
        rcut = Pv(p, "d_root") / 2 + Pv(p, "rim") + 8
        rows = Array("Number of teeth / Dis sayisi z", Pv(p, "z"), "Module / Modul m (mm)", Pv(p, "m"), _
                     "Pressure angle / Basinc acisi (deg)", Pv(p, "alpha_n"), "Profile shift / Profil kaydirma x", Pv(p, "x"), _
                     "Tip height / Dis basi yuksekligi", Pv(p, "ha") & " m (shortened / kisaltilmis)", "Face width / Dis genisligi b (mm)", Pv(p, "b"), _
                     "Tip diameter / Dis cap, ic (mm)", Pv(p, "d_tip"), "Root diameter / Taban capi (mm)", Pv(p, "d_root"), _
                     "OD = case bore / Dis cap = govde deligi (mm)", Pv(p, "d_root") + 2 * Pv(p, "rim"), _
                     "Mating gears / Eslenik", "4 planets z37")
    Case "gear2"
        title = "FIRST-STAGE GEAR / BIRINCI KADEME DISLISI" : mat = "Pyrowear 53 (AMS 6308), carburized / sementasyon" : sc = 0.5
        rcut = Pv(p, "d_tip") / 2 + 8
        rows = Array("Number of teeth / Dis sayisi z", Pv(p, "z"), "Normal module / Normal modul (mm)", Pv(p, "mn"), _
                     "Helix angle / Helis acisi (deg)", Pv(p, "beta") & " left hand / sol", "Pressure angle / Basinc acisi (deg)", Pv(p, "alpha_n"), _
                     "Profile shift / Profil kaydirma x", Pv(p, "x"), "Face width / Dis genisligi b (mm)", Pv(p, "b"), _
                     "Tip diameter / Dis cap (mm)", Pv(p, "d_tip"), "Root diameter / Taban capi (mm)", Pv(p, "d_root"), _
                     "Web / Govde (mm)", Pv(p, "web"), "Hub / Gobek (mm)", Pv(p, "hub_d") & " x " & Pv(p, "hub_len") & ", bore / delik " & Pv(p, "bore"), _
                     "Mating gear / Eslenik", "pinion z31, a 145.974")
    Case "case"
        title = "PLANETARY CASE / PLANET GOVDESI" : mat = "A357-T6 sand casting / kum dokum (WE43-T6 alternative)" : sc = 0.25
        rcut = 170
        rows = Array("Attachment flange / Baglanti flansi", "OD 307, " & Pv(p, "n_bolts") & " x d" & Pv(p, "d_hole") & " on PCD " & Pv(p, "pcd"), _
                     "Ring gear bore / Halka disli yuvasi (mm)", 259, "Inner prop. bearing seat / Ic rulman yuvasi", "d180 x 28, z 132-160", _
                     "Outer prop. bearing seat / Dis rulman yuvasi", "d180 x 34, z 412-446", _
                     "Conical nose wall / Konik burun duvari (mm)", "8 radial / radyal", "Cast fillets / Dokum radyuslari (mm)", "R5 at re-entrant corners", _
                     "Outer seat stiffness / Dis yuva direngenligi", "9.5e7 N/m (FE step 2.8)")
    Case "carrier"
        title = "PLANET CARRIER AND PROPELLER SHAFT / TASIYICI VE PERVANE MILI" : mat = "AISI 4340 (TBR)" : sc = 0.25
        rcut = 130
        rows = Array("Planets / Planet sayisi", Pv(p, "n_planets"), "Planet radius / Planet yaricapi (mm)", Pv(p, "a"), _
                     "Pin = inner race / Pim = ic bilezik (mm)", Pv(p, "d_pin"), "Pin length / Pim boyu (mm)", Pv(p, "L_pin"), _
                     "Posts / Kolonlar (mm)", Pv(p, "post_w") & " x " & Pv(p, "post_t") & " x " & Pv(p, "L_pin"), _
                     "Plates / Plakalar (mm)", "d" & Pv(p, "plate_d") & " x " & Pv(p, "plate_t"), _
                     "Propeller shaft / Pervane mili (mm)", "120 / 100", "Propeller flange / Pervane flansi", "interface TBR / arayuz TBR")
    Case Else
        title = UCase(name) : mat = "-" : sc = 1 : rcut = 100
        rows = Array("-", "-")
End Select

Set drw = CATIA.Documents.Add("Drawing")
drw.Standard = 2                                    ' ISO
Set sheet = drw.Sheets.ActiveSheet
sheet.PaperSize = 5                                 ' A3 (420 x 297 mm)
sheet.Orientation = 1                               ' landscape
sheet.Scale = 1
Set views = sheet.Views

' End view, looking along the axis
Set front = views.Add("End view")
Set gb = front.GenerativeBehavior
gb.Document = partDoc.Product
gb.DefineFrontView 1, 0, 0, 0, 1, 0
front.x = 100 : front.y = 185 : front.Scale = sc
gb.Update
' Section through the axis, on the cutting line along the end view's horizontal axis
Set sect = views.Add("Section")
sect.GenerativeBehavior.Document = partDoc.Product    ' without this link the section stays empty
On Error Resume Next
sect.GenerativeBehavior.DefineSectionView Array(CDbl(-rcut), CDbl(0), CDbl(rcut), CDbl(0)), "SectionView", "Offset", 0, gb
If Err.Number <> 0 Then
    WScript.Echo "section view not available (" & Err.Description & "), side view instead"
    Err.Clear
    sect.GenerativeBehavior.Document = partDoc.Product
    sect.GenerativeBehavior.DefineFrontView 0, 0, 1, 1, 0, 0
End If
On Error GoTo 0
sect.x = 255 : sect.y = 185 : sect.Scale = sc
sect.GenerativeBehavior.Update

' Design data table and title block in the background view (activated first, as CATIA's own
' title block macros do)
views.Item("Background View").Activate
Set bg = views.ActiveView
Set f = bg.Factory2D
Box f, 10, 10, 410, 287                             ' frame
ox = 22 : oy = 100
Tx bg, "DESIGN DATA / TASARIM VERILERI", ox, oy, 3
For i = 0 To UBound(rows) Step 2
    Tx bg, rows(i), ox, oy - 7 - 2.5 * i, 2.5
    Tx bg, CStr(rows(i + 1)), ox + 128, oy - 7 - 2.5 * i, 2.5
Next
Box f, 212, 12, 408, 50
Tx bg, title, 216, 43, 3.5
Tx bg, "Part / Parca: RGB-" & UCase(name), 216, 37, 2.5
Tx bg, "Material / Malzeme: " & mat, 216, 32, 2.5
Tx bg, "Scale / Olcek 1:" & FormatNumber(1 / sc, 0) & "   mm   ISO 2768-m unless noted / aksi belirtilmedikce", 216, 27, 2.5
Tx bg, "Turboprop RGB, Phase 2 detail design (CDR) / Faz 2 detay tasarim", 216, 22, 2.5
Tx bg, "Hamit Tanboga   preliminary / on taslak (tolerances in Phase 3)", 216, 17, 2.5
views.Item("Main View").Activate
drw.Update
If fso.FileExists(cadDir & "\drawings\" & name & ".CATDrawing") Then fso.DeleteFile cadDir & "\drawings\" & name & ".CATDrawing", True
drw.SaveAs cadDir & "\drawings\" & name & ".CATDrawing"
If fso.FileExists(cadDir & "\drawings\" & name & ".pdf") Then fso.DeleteFile cadDir & "\drawings\" & name & ".pdf", True
drw.ExportData cadDir & "\drawings\" & name & ".pdf", "pdf"
drw.Close
partDoc.Close
WScript.Echo name & ": drawing saved"

Sub Tx(v, s, x, y, h)
    Dim t
    Set t = v.Texts.Add(s, x, y)
    t.SetFontSize 0, 0, h
End Sub

Sub Box(f, x1, y1, x2, y2)
    f.CreateLine x1, y1, x2, y1
    f.CreateLine x2, y1, x2, y2
    f.CreateLine x2, y2, x1, y2
    f.CreateLine x1, y2, x1, y1
End Sub
