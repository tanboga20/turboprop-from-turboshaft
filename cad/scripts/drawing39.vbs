' drawing39.vbs - step 3.9 representative drawing: views, the tables of cad\params\dwg39_<sheet>.txt, title block.
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\drawing39.vbs <repo cad folder> <sheet>
' Reads the sheet file written by cad/scripts/make_dwg39.py (TITLE, PARTNO, MAT, SOURCE part:<name> or
' product:<name>, SCALE, PAPER, then TABLE and ROW lines), opens the part or product, makes the end view (along the
' axis) and the section through the axis, places the tables in columns (GD&T frames are given as the callout table,
' which R19 scripting cannot place as frames) and the title block in English and Turkish, and saves
' cad\drawings\<sheet>_39.CATDrawing and <sheet>_39.pdf. Source: Phase 3 report, Section 3.9.

Option Explicit
Dim cadDir, fso, key
cadDir = WScript.Arguments(0)
key = WScript.Arguments(1)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim ts, ln, parts, hd, lines(), n, doc, drw, sheet, views, front, sect, gb, bg, f, sc, Wd, Ht, th, dy
Dim cols, ci, x, y, yTop, yBot, i, rcut, src
Set hd = CreateObject("Scripting.Dictionary")
ReDim lines(400) : n = 0
Dim dims(), nd, dv, dp1, dp2, dd, dk
ReDim dims(40) : nd = 0
Set ts = CreateObject("ADODB.Stream")              ' the sheet file is UTF-8
ts.Type = 2 : ts.Charset = "utf-8" : ts.Open : ts.LoadFromFile cadDir & "\params\dwg39_" & key & ".txt"
Dim allText : allText = ts.ReadText : ts.Close
For Each ln In Split(Replace(allText, vbCr, ""), vbLf)
    If Len(ln) > 0 And Left(ln, 1) <> "#" Then
        parts = Split(ln, "|", 2)
        If parts(0) = "TABLE" Or parts(0) = "ROW" Then
            lines(n) = ln : n = n + 1
        ElseIf parts(0) = "DIM" Then
            dims(nd) = parts(1) : nd = nd + 1
        Else
            hd(parts(0)) = parts(1)
        End If
    End If
Next

src = Split(hd("SOURCE"), ":")
If src(0) = "part" Then
    Set doc = CATIA.Documents.Open(cadDir & "\parts\" & src(1) & ".CATPart")
Else
    Set doc = CATIA.Documents.Open(cadDir & "\assy\" & src(1) & ".CATProduct")
End If
sc = CDbl(hd("SCALE"))
Set drw = CATIA.Documents.Add("Drawing")
drw.Standard = 2                                    ' ISO
Set sheet = drw.Sheets.ActiveSheet
sheet.PaperSize = CInt(hd("PAPER"))                 ' 4 = A2, 3 = A1
sheet.Orientation = 1                               ' landscape
sheet.Scale = 1
If CInt(hd("PAPER")) = 3 Then
    Wd = 841 : Ht = 594 : th = 2.4 : dy = 3.6
Else
    Wd = 594 : Ht = 420 : th = 2.0 : dy = 3.1
End If
Set views = sheet.Views
rcut = 170
If hd.Exists("RCUT") Then rcut = CDbl(hd("RCUT"))     ' cutting line half-length [mm]
Set front = views.Add("End view")
Set gb = front.GenerativeBehavior
gb.Document = doc.Product
gb.DefineFrontView 1, 0, 0, 0, 1, 0
front.x = 0.15 * Wd : front.y = 0.72 * Ht : front.Scale = sc
gb.Update
Set sect = views.Add("Section")
sect.GenerativeBehavior.Document = doc.Product
On Error Resume Next
sect.GenerativeBehavior.DefineSectionView Array(CDbl(-rcut), CDbl(0), CDbl(rcut), CDbl(0)), "SectionView", "Offset", 0, gb
If Err.Number <> 0 Then
    WScript.Echo "section view not available (" & Err.Description & "), side view instead"
    Err.Clear
    sect.GenerativeBehavior.Document = doc.Product
    sect.GenerativeBehavior.DefineFrontView 0, 0, 1, 1, 0, 0
End If
On Error GoTo 0
sect.x = 0.38 * Wd : sect.y = 0.72 * Ht : sect.Scale = sc
sect.GenerativeBehavior.Update

' main dimensions driven by the model: two points at model coordinates in the view, a distance dimension
' between them, the diameter symbol where asked
For i = 0 To nd - 1
    dk = Split(dims(i), "|")
    If dk(0) = "end" Then Set dv = front Else Set dv = sect
    dv.Activate
    Set dp1 = dv.Factory2D.CreatePoint(CDbl(dk(1)), CDbl(dk(2)))
    Set dp2 = dv.Factory2D.CreatePoint(CDbl(dk(3)), CDbl(dk(4)))
    Set dd = dv.Dimensions.Add(0, Array(dp1, dp2), Array(CDbl(dk(1)), CDbl(dk(2)), CDbl(dk(3)), CDbl(dk(4))), 0)
    If dk(5) = "1" Then dd.GetValue.SetBaultText 1, ChrW(216), "", "", ""
Next
views.Item("Background View").Activate
Set bg = views.ActiveView
Set f = bg.Factory2D
Box f, 10, 10, Wd - 4, Ht - 4
' table columns: two on the right above the title block, then the lower left
cols = Array(Array(Wd * 0.55, Ht - 15, 62), Array(Wd * 0.55 + 0.225 * Wd + 3, Ht - 15, 62), _
             Array(15, Ht * 0.47, 15), Array(15 + 0.225 * Wd + 3, Ht * 0.47, 15))
ci = 0 : x = cols(0)(0) : y = cols(0)(1) : yBot = cols(0)(2)
For i = 0 To n - 1
    parts = Split(lines(i), "|", 2)
    If y - dy < yBot Or (parts(0) = "TABLE" And y - 3 * dy < yBot) Then
        ci = ci + 1
        If ci > UBound(cols) Then Exit For
        x = cols(ci)(0) : y = cols(ci)(1) : yBot = cols(ci)(2)
    End If
    If parts(0) = "TABLE" Then
        If y < cols(ci)(1) Then y = y - 0.6 * dy
        Tx bg, parts(1), x, y, th * 1.15
        y = y - 1.3 * dy
    Else
        Tx bg, parts(1), x, y, th
        y = y - dy
    End If
Next
If i < n Then WScript.Echo "WARNING: " & (n - i) & " rows did not fit"
Box f, Wd - 200, 12, Wd - 6, 55
Tx bg, hd("TITLE"), Wd - 196, 49, 2.6
Tx bg, "Part / Parca: " & hd("PARTNO"), Wd - 196, 43, 2.5
Tx bg, "Material / Malzeme: " & hd("MAT"), Wd - 196, 38, 2
Tx bg, "Scale / Olcek " & ScaleText(sc) & "   mm   ISO 2768-m unless noted; ASME Y14.5-2018", Wd - 196, 33, 2
Tx bg, "Turboprop RGB, step 3.9 representative drawing / adim 3.9 temsili resim", Wd - 196, 28, 2
Tx bg, "Hamit Tanboga   values: manufacturing/drawing_checklist_v1.csv", Wd - 196, 23, 2
Tx bg, "Sheet / Pafta 1/1   GD&T as the callout table (tolerances_v1.csv)", Wd - 196, 18, 2
views.Item("Main View").Activate
drw.Update
If fso.FileExists(cadDir & "\drawings\" & key & "_39.CATDrawing") Then fso.DeleteFile cadDir & "\drawings\" & key & "_39.CATDrawing", True
drw.SaveAs cadDir & "\drawings\" & key & "_39.CATDrawing"
If fso.FileExists(cadDir & "\drawings\" & key & "_39.pdf") Then fso.DeleteFile cadDir & "\drawings\" & key & "_39.pdf", True
drw.ExportData cadDir & "\drawings\" & key & "_39.pdf", "pdf"
drw.Close
doc.Close
WScript.Echo key & ": drawing saved (" & n & " table lines)"

Sub Tx(v, s, x, y, h)
    Dim t
    Set t = v.Texts.Add(s, x, y)
    t.SetFontSize 0, 0, h
End Sub

Function ScaleText(s)
If s >= 1 Then ScaleText = FormatNumber(s, 0) & ":1" Else ScaleText = "1:" & FormatNumber(1 / s, 0)
End Function

Sub Box(f, x1, y1, x2, y2)
    f.CreateLine x1, y1, x2, y1
    f.CreateLine x2, y1, x2, y2
    f.CreateLine x2, y2, x1, y2
    f.CreateLine x1, y2, x1, y1
End Sub
