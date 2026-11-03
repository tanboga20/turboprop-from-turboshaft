' catlib.vbs - CATIA V5 R19 automation helpers for the turboprop RGB parts.
'
' Loaded by the part scripts with
'   ExecuteGlobal CreateObject("Scripting.FileSystemObject").OpenTextFile(libPath).ReadAll
' and run with the 32-bit script host (CATIA V5 R19 is a 32-bit program):
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\<part>.vbs
'
' Conventions: millimetres and degrees as CATIA shows them (angles in the 2D sketch
' factory are radians); a gear's axis is the part's Z axis and its teeth run from
' z = 0 to z = b. The script runs under the US English locale (SetLocale below), so that
' CDbl reads the "." decimal point of the MATLAB files; the PC runs a Turkish locale,
' where CDbl("1.5") would give 15.
'
' Source: Phase 2 report, Section 2.9 ("CATIA models").

Const PI = 3.14159265358979
SetLocale 1033

Dim CATIA
On Error Resume Next
Set CATIA = GetObject(, "CATIA.Application")
If Err.Number <> 0 Then
    WScript.Echo "CATIA is not running or not answering: start CATIA V5 (no document needed) and run the script again."
    WScript.Quit 2
End If
On Error GoTo 0
CATIA.DisplayFileAlerts = False

Function Acos(x)
    If x >= 1 Then
        Acos = 0
    ElseIf x <= -1 Then
        Acos = PI
    Else
        Acos = Atn(-x / Sqr(-x * x + 1)) + 2 * Atn(1)
    End If
End Function

Function Inv(a)
    ' involute function tan(a) - a
    Inv = Tan(a) - a
End Function

Function Rad(d)
    Rad = d * PI / 180
End Function

Function Atan2(y, x)
    If x > 0 Then
        Atan2 = Atn(y / x)
    ElseIf x < 0 Then
        If y >= 0 Then Atan2 = Atn(y / x) + PI Else Atan2 = Atn(y / x) - PI
    ElseIf y > 0 Then
        Atan2 = PI / 2
    ElseIf y < 0 Then
        Atan2 = -PI / 2
    Else
        Atan2 = 0
    End If
End Function

' ---------------------------------------------------------------- parameters
Function LoadParams(path)
    ' key = value lines written by MATLAB (calc/cad_export); # starts a comment
    Dim fso, f, line, k, d
    Set d = CreateObject("Scripting.Dictionary")
    Set fso = CreateObject("Scripting.FileSystemObject")
    Set f = fso.OpenTextFile(path, 1)
    Do While Not f.AtEndOfStream
        line = Trim(f.ReadLine)
        If Len(line) > 0 And Left(line, 1) <> "#" Then
            k = InStr(line, "=")
            If k > 0 Then d(Trim(Left(line, k - 1))) = Trim(Mid(line, k + 1))
        End If
    Loop
    f.Close
    Set LoadParams = d
End Function

Function Pv(d, key)
    If Not d.Exists(key) Then Err.Raise 1001, "catlib", "missing parameter " & key
    Pv = CDbl(d(key))
End Function

Function Pa(d, key)
    ' space separated list of numbers, as an array of doubles
    Dim s, i, a()
    If Not d.Exists(key) Then Err.Raise 1001, "catlib", "missing parameter " & key
    s = Split(d(key), " ")
    ReDim a(UBound(s))
    For i = 0 To UBound(s)
        a(i) = CDbl(s(i))
    Next
    Pa = a
End Function

Function Ps(d, key)
    If Not d.Exists(key) Then Err.Raise 1001, "catlib", "missing parameter " & key
    Ps = d(key)
End Function

' ---------------------------------------------------------------- documents
Function NewPart(partNumber, description)
    Dim doc
    Set doc = CATIA.Documents.Add("Part")
    doc.Product.PartNumber = partNumber
    doc.Product.DescriptionRef = description
    Set NewPart = doc
End Function

Sub SaveParts(doc, cadDir, fileBase)
    ' native file in cad/parts, STEP AP214 copy in cad/step; the origin planes are hidden first, so
    ' that later pictures need no change to the document (a changed document asks to be saved when
    ' it closes, and that question would stop an unattended script). The volume of the main body goes
    ' to cad/assy/part_volumes.csv for the mass roll-up (calc/assembly/as_mass, step 3.1).
    Dim fso
    Set fso = CreateObject("Scripting.FileSystemObject")
    RecordVolume cadDir, fileBase, BodyVolume(doc, doc.Part.MainBody)
    HideOrigin doc
    If fso.FileExists(cadDir & "\parts\" & fileBase & ".CATPart") Then fso.DeleteFile cadDir & "\parts\" & fileBase & ".CATPart", True
    SafeSaveAs doc, cadDir & "\parts\" & fileBase & ".CATPart"
    If fso.FileExists(cadDir & "\step\" & fileBase & ".stp") Then fso.DeleteFile cadDir & "\step\" & fileBase & ".stp", True
    doc.ExportData cadDir & "\step\" & fileBase & ".stp", "stp"
End Sub

Sub HideOrigin(doc)
    Dim sel, oe
    Set oe = doc.Part.OriginElements
    Set sel = doc.Selection
    sel.Clear
    sel.Add oe.PlaneXY
    sel.Add oe.PlaneYZ
    sel.Add oe.PlaneZX
    sel.VisProperties.SetShow 1
    sel.Clear
End Sub

Function BodyMassKg(doc, body, rho)
    ' volume from the SPA workbench (it reports mass at 1000 kg/m^3) times the density
    Dim spa
    Set spa = doc.GetWorkbench("SPAWorkbench")
    BodyMassKg = spa.Inertias.Add(body).Mass * rho / 1000
End Function

Sub Capture(path, mode)
    ' JPEG of the active window on a white background, geometry only: mode iso, front (along -Z),
    ' side (along -X) or back (iso from the engine side)
    ' Changes only the window and the viewer, never the document.
    Dim viewer, vp, s(2), u(2)
    On Error Resume Next
    CATIA.Width = 1400
    CATIA.Height = 1000
    CATIA.ActiveWindow.WindowState = 0      ' maximised, so that every capture has the same size
    CATIA.ActiveWindow.Layout = 1           ' geometry only (catWindowGeomOnly), no specification tree
    On Error GoTo 0
    Set viewer = CATIA.ActiveWindow.ActiveViewer
    viewer.PutBackgroundColor Array(1, 1, 1)
    viewer.RenderingMode = 1                ' shading with edges, hidden edges not drawn
    Set vp = viewer.Viewpoint3D
    Select Case mode
        Case "front"
            s(0) = 0 : s(1) = 0 : s(2) = -1 : u(0) = 0 : u(1) = 1 : u(2) = 0
        Case "side"
            s(0) = -1 : s(1) = 0 : s(2) = 0 : u(0) = 0 : u(1) = 0 : u(2) = 1
        Case "back"
            s(0) = -0.577 : s(1) = -0.577 : s(2) = 0.577 : u(0) = 0.408 : u(1) = 0.408 : u(2) = 0.816
        Case Else
            s(0) = -0.577 : s(1) = -0.577 : s(2) = -0.577 : u(0) = -0.408 : u(1) = -0.408 : u(2) = 0.816
    End Select
    vp.PutSightDirection s
    vp.PutUpDirection u
    viewer.Reframe
    viewer.Update
    viewer.CaptureToFile 5, path
End Sub

Sub HideGeometricalSets(doc)
    Dim sel, i
    Set sel = doc.Selection
    sel.Clear
    For i = 1 To doc.Part.HybridBodies.Count
        sel.Add doc.Part.HybridBodies.Item(i)
    Next
    If sel.Count > 0 Then sel.VisProperties.SetShow 1
    sel.Clear
End Sub

' ---------------------------------------------------------------- revolved bodies
Function RevolveRZ(part, body, rz)
    ' Shaft feature about Z from a closed polyline of (r, z) pairs, rz = Array(r1, z1, r2, z2, ...).
    ' The sketch sits on the ZX plane: sketch H = global Z, sketch V = global X (radius).
    Dim sk, f2, n, i, p(), ln, ax
    Set sk = body.Sketches.Add(part.OriginElements.PlaneZX)
    Set f2 = sk.OpenEdition()
    n = (UBound(rz) + 1) / 2
    ReDim p(n - 1)
    For i = 0 To n - 1
        Set p(i) = f2.CreatePoint(rz(2 * i + 1), rz(2 * i))
    Next
    For i = 0 To n - 1
        Set ln = f2.CreateLine(rz(2 * i + 1), rz(2 * i), rz(2 * ((i + 1) Mod n) + 1), rz(2 * ((i + 1) Mod n)))
        ln.StartPoint = p(i)
        ln.EndPoint = p((i + 1) Mod n)
    Next
    Set ax = f2.CreateLine(-10, 0, 10, 0)
    sk.CenterLine = ax
    sk.CloseEdition
    part.InWorkObject = body
    Set RevolveRZ = part.ShapeFactory.AddNewShaft(sk)
    part.Update
End Function

Function RevolveSegs(part, body, sg)
    ' Shaft feature about Z from a closed profile of lines and arcs: sg = Array of rows
    ' (type, r1, z1, r2, z2, cr, cz) flattened, type 0 a line, 1 an arc about (cr, cz) (calc/cad_export).
    ' Sketch on the ZX plane as RevolveRZ: H = global Z, V = global X (radius).
    Dim sk, f2, n, i, j, p(), ln, ax, a1, a2, d, rr, b
    Set sk = body.Sketches.Add(part.OriginElements.PlaneZX)
    Set f2 = sk.OpenEdition()
    n = (UBound(sg) + 1) / 7
    ReDim p(n - 1)
    For i = 0 To n - 1
        Set p(i) = f2.CreatePoint(sg(7 * i + 2), sg(7 * i + 1))
    Next
    For i = 0 To n - 1
        j = (i + 1) Mod n
        b = 7 * i
        If sg(b) = 0 Then
            Set ln = f2.CreateLine(sg(b + 2), sg(b + 1), sg(b + 4), sg(b + 3))
            ln.StartPoint = p(i)
            ln.EndPoint = p(j)
        Else
            rr = Sqr((sg(b + 1) - sg(b + 5)) ^ 2 + (sg(b + 2) - sg(b + 6)) ^ 2)
            a1 = Atan2(sg(b + 1) - sg(b + 5), sg(b + 2) - sg(b + 6))
            a2 = Atan2(sg(b + 3) - sg(b + 5), sg(b + 4) - sg(b + 6))
            d = a2 - a1
            If d > PI Then d = d - 2 * PI
            If d <= -PI Then d = d + 2 * PI
            If d > 0 Then
                Set ln = f2.CreateCircle(sg(b + 6), sg(b + 5), rr, a1, a1 + d)
                ln.StartPoint = p(i)
                ln.EndPoint = p(j)
            Else
                Set ln = f2.CreateCircle(sg(b + 6), sg(b + 5), rr, a2, a2 - d)
                ln.StartPoint = p(j)
                ln.EndPoint = p(i)
            End If
        End If
    Next
    Set ax = f2.CreateLine(-10, 0, 10, 0)
    sk.CenterLine = ax
    sk.CloseEdition
    part.InWorkObject = body
    Set RevolveSegs = part.ShapeFactory.AddNewShaft(sk)
    part.Update
End Function

Function HolePattern(part, body, rPcd, dHole, nHoles)
    ' Through holes parallel to Z on a pitch circle: one pocket from the XY plane up to the last face,
    ' patterned about Z
    Dim sk, f2, pk, axisRef, pat
    part.InWorkObject = body
    Set sk = body.Sketches.Add(part.OriginElements.PlaneXY)
    Set f2 = sk.OpenEdition()
    f2.CreateClosedCircle rPcd, 0, dHole / 2
    sk.CloseEdition
    Set pk = part.ShapeFactory.AddNewPocket(sk, 20)
    pk.FirstLimit.LimitMode = 2
    part.Update
    Set axisRef = part.CreateReferenceFromObject(part.OriginElements.PlaneXY)
    Set pat = part.ShapeFactory.AddNewCircPattern(pk, 1, nHoles, 0, 360 / nHoles, 1, 1, axisRef, axisRef, True, 0, True)
    part.Update
    Set HolePattern = pat
End Function

' ---------------------------------------------------------------- involute teeth
Sub SpaceProfile(f2, rb, rf, rtop, eta, alphat, internal)
    ' Closed transverse tooth-space profile centred on the sketch +V axis.
    ' External gear: space half-angle at radius rho = eta - inv(alpha_t) + inv(alpha_rho), from the
    ' root circle rf up to rtop (beyond the tip). Internal gear: the space has the shape of an
    ' external tooth, half-angle eta + inv(alpha_t) - inv(alpha_rho), from rtop (inside the tip
    ' circle) out to the root circle rf.
    Dim n, i, rho, phi, rs, ptsR(), ptsL(), lnR, lnL, arcR, arcT, phi0, phiT, pR, pL, sgn
    n = 12
    ReDim ptsR(n), ptsL(n)
    sgn = 1
    If internal Then sgn = -1
    If internal Then
        rs = rtop
        If rs < rb Then rs = rb
    Else
        rs = rb
        If rf > rb Then rs = rf
    End If
    For i = 0 To n
        If internal Then
            rho = rs + (rf - rs) * i / n
        Else
            rho = rs + (rtop - rs) * i / n
        End If
        If rho < rb Then rho = rb
        phi = eta - sgn * Inv(alphat) + sgn * Inv(Acos(rb / rho))
        Set ptsR(i) = f2.CreateControlPoint(rho * Sin(phi), rho * Cos(phi))
        Set ptsL(i) = f2.CreateControlPoint(-rho * Sin(phi), rho * Cos(phi))
    Next
    f2.CreateSpline ptsR
    f2.CreateSpline ptsL
    If internal Then
        ' inner end (inside the tip circle) and outer end (root circle)
        phi0 = eta - sgn * Inv(alphat) + sgn * Inv(Acos(rb / rs))
        If rtop < rs Then
            Set pR = f2.CreatePoint(rtop * Sin(phi0), rtop * Cos(phi0))
            Set pL = f2.CreatePoint(-rtop * Sin(phi0), rtop * Cos(phi0))
            Set lnR = f2.CreateLine(rtop * Sin(phi0), rtop * Cos(phi0), rs * Sin(phi0), rs * Cos(phi0))
            lnR.StartPoint = pR : lnR.EndPoint = ptsR(0)
            Set lnL = f2.CreateLine(-rtop * Sin(phi0), rtop * Cos(phi0), -rs * Sin(phi0), rs * Cos(phi0))
            lnL.StartPoint = pL : lnL.EndPoint = ptsL(0)
        Else
            Set pR = ptsR(0) : Set pL = ptsL(0)
        End If
        Set arcT = f2.CreateCircle(0, 0, rtop, PI / 2 - phi0, PI / 2 + phi0)
        arcT.StartPoint = pR : arcT.EndPoint = pL
        phiT = eta - sgn * Inv(alphat) + sgn * Inv(Acos(rb / rf))
        Set arcR = f2.CreateCircle(0, 0, rf, PI / 2 - phiT, PI / 2 + phiT)
        arcR.StartPoint = ptsR(n) : arcR.EndPoint = ptsL(n)
    Else
        phi0 = eta - Inv(alphat) + Inv(Acos(rb / rs))
        If rf < rb Then
            Set pR = f2.CreatePoint(rf * Sin(phi0), rf * Cos(phi0))
            Set pL = f2.CreatePoint(-rf * Sin(phi0), rf * Cos(phi0))
            Set lnR = f2.CreateLine(rf * Sin(phi0), rf * Cos(phi0), rs * Sin(phi0), rs * Cos(phi0))
            lnR.StartPoint = pR : lnR.EndPoint = ptsR(0)
            Set lnL = f2.CreateLine(-rf * Sin(phi0), rf * Cos(phi0), -rs * Sin(phi0), rs * Cos(phi0))
            lnL.StartPoint = pL : lnL.EndPoint = ptsL(0)
        Else
            Set pR = ptsR(0) : Set pL = ptsL(0)
        End If
        Set arcR = f2.CreateCircle(0, 0, rf, PI / 2 - phi0, PI / 2 + phi0)
        arcR.StartPoint = pR : arcR.EndPoint = pL
        phiT = eta - Inv(alphat) + Inv(Acos(rb / rtop))
        Set arcT = f2.CreateCircle(0, 0, rtop, PI / 2 - phiT, PI / 2 + phiT)
        arcT.StartPoint = ptsR(n) : arcT.EndPoint = ptsL(n)
    End If
End Sub

Function GearData(z, mn, betaDeg, alphanDeg, x, internal)
    ' Transverse data of a gear without tip shortening: Array(r, rb, ra, rf, eta, alpha_t)
    Dim beta, alphat, mt, r, rb, ra, rf, eta
    beta = Rad(betaDeg)
    alphat = Atn(Tan(Rad(alphanDeg)) / Cos(beta))
    mt = mn / Cos(beta)
    r = mt * z / 2
    rb = r * Cos(alphat)
    If internal Then
        ra = r - mn * (1 - x)
        rf = r + mn * (1.25 + x)
        eta = PI / (2 * z) + 2 * x * Tan(Rad(alphanDeg)) / z
    Else
        ra = r + mn * (1 + x)
        rf = r - mn * (1.25 - x)
        eta = PI / (2 * z) - 2 * x * Tan(Rad(alphanDeg)) / z
    End If
    GearData = Array(r, rb, ra, rf, eta, alphat)
End Function

Function CutSpurTeeth(doc, body, z, mn, alphanDeg, x, b, internal)
    ' Spur teeth: one tooth-space pocket through the blank (z = 0 ... b) and a circular pattern
    Dim part, g, sk, f2, pk, rtop, pat, axisRef
    Set part = doc.Part
    g = GearData(z, mn, 0, alphanDeg, x, internal)
    If internal Then
        rtop = g(2) - 0.6 * mn
    Else
        rtop = g(2) + 0.6 * mn
    End If
    part.InWorkObject = body
    Set sk = body.Sketches.Add(part.OriginElements.PlaneXY)
    Set f2 = sk.OpenEdition()
    SpaceProfile f2, g(1), g(3), rtop, g(4), g(5), internal
    sk.CloseEdition
    Set pk = part.ShapeFactory.AddNewPocket(sk, b + 1)
    pk.FirstLimit.LimitMode = 2
    part.Update
    Set axisRef = part.CreateReferenceFromObject(part.OriginElements.PlaneXY)
    Set pat = part.ShapeFactory.AddNewCircPattern(pk, 1, z, 0, 360 / z, 1, 1, axisRef, axisRef, True, 0, True)
    part.Update
    Set CutSpurTeeth = pat
End Function

Function CutHelicalTeeth(doc, body, z, mn, betaDeg, rightHand, alphanDeg, x, b)
    ' Helical teeth: the transverse tooth-space profile swept along the pitch helix with the gear
    ' axis as pulling direction (an exact helicoid), closed into a solid in a tool body,
    ' patterned and removed from the blank. Right hand: the teeth turn clockwise going away
    ' from the viewer along +Z.
    Dim part, hsf, sf, g, hb, pl, sk, f2, ptO, dirZ, axisLn, ptS, hx, sw, tool, cs, pat, rem1, lead, rtop
    Set part = doc.Part
    Set hsf = part.HybridShapeFactory
    Set sf = part.ShapeFactory
    g = GearData(z, mn, betaDeg, alphanDeg, x, False)
    rtop = g(2) + 0.6 * mn
    lead = 2 * PI * g(0) / Tan(Rad(betaDeg))
    Set hb = part.HybridBodies.Add()
    hb.Name = "Tooth construction"
    Set pl = hsf.AddNewPlaneOffset(part.CreateReferenceFromObject(part.OriginElements.PlaneXY), -2, False)
    hb.AppendHybridShape pl
    Set ptO = hsf.AddNewPointCoord(0, 0, 0)
    Set dirZ = hsf.AddNewDirectionByCoord(0, 0, 1)
    Set axisLn = hsf.AddNewLinePtDir(ptO, dirZ, -2, b + 2, False)
    hb.AppendHybridShape axisLn
    Set ptS = hsf.AddNewPointCoord(0, g(0), -2)
    hb.AppendHybridShape ptS
    Set hx = hsf.AddNewHelix(part.CreateReferenceFromObject(axisLn), False, part.CreateReferenceFromObject(ptS), _
                             lead, b + 4, Not rightHand, 0, 0, False)
    hb.AppendHybridShape hx
    part.Update
    part.InWorkObject = body
    Set sk = body.Sketches.Add(pl)
    Set f2 = sk.OpenEdition()
    SpaceProfile f2, g(1), g(3), rtop, g(4), g(5), False
    sk.CloseEdition
    Set sw = hsf.AddNewSweepExplicit(part.CreateReferenceFromObject(sk), part.CreateReferenceFromObject(hx))
    sw.SubType = 3
    sw.PullingDirection = dirZ
    hb.AppendHybridShape sw
    part.Update
    Set tool = part.Bodies.Add()
    tool.Name = "Tooth spaces"
    part.InWorkObject = tool
    Set cs = sf.AddNewCloseSurface(part.CreateReferenceFromObject(sw))
    part.Update
    Set pat = sf.AddNewCircPattern(cs, 1, z, 0, 360 / z, 1, 1, part.CreateReferenceFromObject(axisLn), _
                                   part.CreateReferenceFromObject(axisLn), True, 0, True)
    part.Update
    part.InWorkObject = body
    Set rem1 = sf.AddNewRemove(tool)
    part.Update
    Set CutHelicalTeeth = rem1
End Function

' ---------------------------------------------------------------- prismatic features (step 3.1)
' Conventions checked in R19: a pad's first limit runs along the sketch normal (+Z for planes parallel
' to XY), a pocket's first limit against it. The helpers below take absolute z ranges.

Function PlaneZ(part, z)
    ' plane parallel to XY at height z, in a geometrical set "Construction planes"
    Dim hb, pl, i
    Set hb = Nothing
    For i = 1 To part.HybridBodies.Count
        If part.HybridBodies.Item(i).Name = "Construction planes" Then Set hb = part.HybridBodies.Item(i)
    Next
    If hb Is Nothing Then
        Set hb = part.HybridBodies.Add()
        hb.Name = "Construction planes"
    End If
    Set pl = part.HybridShapeFactory.AddNewPlaneOffset(part.CreateReferenceFromObject(part.OriginElements.PlaneXY), z, False)
    hb.AppendHybridShape pl
    part.Update
    Set PlaneZ = pl
End Function

Sub DrawSegsXY(f2, sg)
    ' closed outline in the XY plane: rows (type, x1, y1, x2, y2, cx, cy) flattened, type 0 a line,
    ' 2 a counter-clockwise arc about (cx, cy), 3 a full circle (cx = x1, cy = y1, radius = x2)
    Dim n, i, j, b, p(), ln, rr, a1, a2
    n = (UBound(sg) + 1) / 7
    If sg(0) = 3 Then
        f2.CreateClosedCircle sg(1), sg(2), sg(3)
        Exit Sub
    End If
    ReDim p(n - 1)
    For i = 0 To n - 1
        Set p(i) = f2.CreatePoint(sg(7 * i + 1), sg(7 * i + 2))
    Next
    For i = 0 To n - 1
        j = (i + 1) Mod n
        b = 7 * i
        If sg(b) = 0 Then
            Set ln = f2.CreateLine(sg(b + 1), sg(b + 2), sg(b + 3), sg(b + 4))
        Else
            rr = Sqr((sg(b + 1) - sg(b + 5)) ^ 2 + (sg(b + 2) - sg(b + 6)) ^ 2)
            a1 = Atan2(sg(b + 2) - sg(b + 6), sg(b + 1) - sg(b + 5))
            a2 = Atan2(sg(b + 4) - sg(b + 6), sg(b + 3) - sg(b + 5))
            If a2 <= a1 Then a2 = a2 + 2 * PI
            Set ln = f2.CreateCircle(sg(b + 5), sg(b + 6), rr, a1, a2)
        End If
        ln.StartPoint = p(i)
        ln.EndPoint = p(j)
    Next
End Sub

Function SketchZ(part, body, z)
    ' the plane first: adding it makes its geometrical set the object in work
    Dim pl
    Set pl = PlaneZ(part, z)
    part.InWorkObject = body
    Set SketchZ = body.Sketches.Add(pl)
End Function

Function PadSegsZ(part, body, sg, z1, z2)
    Dim sk, f2, pd
    Set sk = SketchZ(part, body, z1)
    Set f2 = sk.OpenEdition()
    DrawSegsXY f2, sg
    sk.CloseEdition
    Set pd = part.ShapeFactory.AddNewPad(sk, z2 - z1)
    part.Update
    Set PadSegsZ = pd
End Function

Function PocketSegsZ(part, body, sg, z1, z2)
    Dim sk, f2, pk
    Set sk = SketchZ(part, body, z2)
    Set f2 = sk.OpenEdition()
    DrawSegsXY f2, sg
    sk.CloseEdition
    Set pk = part.ShapeFactory.AddNewPocket(sk, z2 - z1)
    part.Update
    Set PocketSegsZ = pk
End Function

Function PadCircleZ(part, body, x, y, r, z1, z2)
    Set PadCircleZ = PadSegsZ(part, body, Array(3, x, y, r, 0, 0, 0), z1, z2)
End Function

Function PocketCircleZ(part, body, x, y, r, z1, z2)
    Set PocketCircleZ = PocketSegsZ(part, body, Array(3, x, y, r, 0, 0, 0), z1, z2)
End Function

Function AxisZ(part, x, y)
    ' a line parallel to Z through (x, y), for circular patterns about an axis off the origin
    Dim hsf, hb, pt, ln
    Set hsf = part.HybridShapeFactory
    Set hb = part.HybridBodies.Add()
    hb.Name = "Pattern axis"
    Set pt = hsf.AddNewPointCoord(x, y, 0)
    hb.AppendHybridShape pt
    Set ln = hsf.AddNewLinePtDir(pt, hsf.AddNewDirectionByCoord(0, 0, 1), -10, 10, False)
    hb.AppendHybridShape ln
    part.Update
    Set AxisZ = ln
End Function

Function HolesAt(part, body, cx, cy, pcd, d, n, z1, z2)
    ' n holes of diameter d on a pitch circle about (cx, cy), from z1 to z2
    Dim pk, ax, ref, pat
    Set pk = PocketCircleZ(part, body, cx + pcd / 2, cy, d / 2, z1, z2)
    Set ax = AxisZ(part, cx, cy)
    Set ref = part.CreateReferenceFromObject(ax)
    part.InWorkObject = body
    Set pat = part.ShapeFactory.AddNewCircPattern(pk, 1, n, 0, 360 / n, 1, 1, ref, ref, True, 0, True)
    part.Update
    Set HolesAt = pat
End Function

Function CutSpurTeethZ(doc, body, z, mn, alphanDeg, x, z0, b)
    ' external spur teeth from z0 to z0 + b only (the rest of a shaft keeps its journals): one bounded
    ' tooth-space pocket and a circular pattern about Z
    Dim part, g, sk, f2, pk, pat, axisRef
    Set part = doc.Part
    g = GearData(z, mn, 0, alphanDeg, x, False)
    Set sk = SketchZ(part, body, z0 + b + 0.5)
    Set f2 = sk.OpenEdition()
    SpaceProfile f2, g(1), g(3), g(2) + 0.6 * mn, g(4), g(5), False
    sk.CloseEdition
    Set pk = part.ShapeFactory.AddNewPocket(sk, b + 1)
    part.Update
    Set axisRef = part.CreateReferenceFromObject(part.OriginElements.PlaneXY)
    part.InWorkObject = body
    Set pat = part.ShapeFactory.AddNewCircPattern(pk, 1, z, 0, 360 / z, 1, 1, axisRef, axisRef, True, 0, True)
    part.Update
    Set CutSpurTeethZ = pat
End Function

Function BodyVolume(doc, body)
    ' mm^3, from the SPA workbench (mass at 1000 kg/m^3)
    BodyVolume = doc.GetWorkbench("SPAWorkbench").Inertias.Add(body).Mass * 1e6
End Function

Sub RecordVolume(cadDir, name, v)
    ' replace or add the line "name,volume" in cad/assy/part_volumes.csv
    Dim fso, path, f, lines, line, out, found
    Set fso = CreateObject("Scripting.FileSystemObject")
    If Not fso.FolderExists(cadDir & "\assy") Then fso.CreateFolder cadDir & "\assy"
    path = cadDir & "\assy\part_volumes.csv"
    out = "part,volume_mm3" & vbCrLf
    found = False
    If fso.FileExists(path) Then
        Set f = fso.OpenTextFile(path, 1)
        Do While Not f.AtEndOfStream
            line = f.ReadLine
            If Len(line) > 0 And line <> "part,volume_mm3" Then
                If Split(line, ",")(0) = name Then
                    line = name & "," & FormatNumber(v, 1, , , 0)
                    found = True
                End If
                out = out & line & vbCrLf
            End If
        Loop
        f.Close
    End If
    If Not found Then out = out & name & "," & FormatNumber(v, 1, , , 0) & vbCrLf
    Set f = fso.CreateTextFile(path, True)
    f.Write out
    f.Close
End Sub

Function PadRingZ(part, body, x, y, rIn, rOut, z1, z2)
    ' annulus about (x, y) from z1 to z2
    Dim sk, f2, pd
    Set sk = SketchZ(part, body, z1)
    Set f2 = sk.OpenEdition()
    f2.CreateClosedCircle x, y, rOut
    f2.CreateClosedCircle x, y, rIn
    sk.CloseEdition
    Set pd = part.ShapeFactory.AddNewPad(sk, z2 - z1)
    part.Update
    Set PadRingZ = pd
End Function

Sub SafeSaveAs(doc, path)
    ' SaveAs that checks its own result: after some failed runs R19 raises an error on every SaveAs although
    ' the file is written; the save counts when the document is marked saved and the file
    ' exists
    Dim fso, n, d
    Set fso = CreateObject("Scripting.FileSystemObject")
    On Error Resume Next
    doc.SaveAs path
    n = Err.Number : d = Err.Description
    On Error GoTo 0
    If n <> 0 Then
        If Not (doc.Saved And fso.FileExists(path)) Then Err.Raise n, "SafeSaveAs", d & " (" & path & ")"
    End If
End Sub

Sub SafeSave(doc)
    Dim n, d
    On Error Resume Next
    doc.Save
    n = Err.Number : d = Err.Description
    On Error GoTo 0
    If n <> 0 And Not doc.Saved Then Err.Raise n, "SafeSave", d
End Sub
