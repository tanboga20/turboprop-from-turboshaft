' carrier.vbs - planet carrier with the propeller shaft (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\carrier.vbs <repo cad folder>
' Reads cad\params\carrier.txt and layout.txt (calc/cad_export). Rear and front plates joined by
' four posts between the planets, four planet pins (the inner raceway of the full-complement planet
' bearings, step 2.5) and the propeller shaft from the front plate (carrier = propeller shaft, PDR
' baseline), 120/100 mm, to the face of the placeholder propeller flange (a separate part since step
' 3.1, PIF-01 TBD); the plate rims are lightened by circular scallops between pins and posts (step
' 3.1), and the planet pins are hollow (step 3.1). z = 0 is the rear face of the rear plate (z 15 in the case). Saves cad\parts\carrier.CATPart,
' cad\step\carrier.stp and a picture. Source: Phase 2 report, Section 2.9; Phase 3 report, Section 3.1.

Option Explicit
Dim cadDir, fso
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll

Dim p, doc, part, body, hsf, sf, hb, pl, sk, f2, pad, pat, ref, mass
Dim a, t, lp, pw, pr, dp, rpl, rb, ze, c, s, r1, r2, i, px(3), py(3), pts(3), ln
Set p = LoadParams(cadDir & "\params\carrier.txt")
a = Pv(p, "a") : t = Pv(p, "plate_t") : lp = Pv(p, "L_pin")
pw = Pv(p, "post_w") : pr = Pv(p, "post_t") : dp = Pv(p, "d_pin")
rpl = Pv(p, "plate_d") / 2
rb = 50                                            ' plate and shaft bore: propeller shaft 120/100 (step 2.5)
ze = Pv(p, "ze")                                   ' shaft end at the propeller flange face (PIF-01 TBD)

Set doc = NewPart("RGB-CARRIER", "Planet carrier and propeller shaft, " & Pv(p, "n_planets") & " planets on a " & a & _
                  " mm radius, pins " & dp & " mm; shaft 120/100 mm")
Set part = doc.Part
Set body = part.MainBody
Set hsf = part.HybridShapeFactory
Set sf = part.ShapeFactory
RevolveRZ part, body, Array(rb, 0, rpl, 0, rpl, t, rb, t)
RevolveRZ part, body, Array(rb, t + lp, rpl, t + lp, rpl, 2 * t + lp, 60, 2 * t + lp, 60, ze, rb, ze)
' posts (between the planets, at 45 deg) and pins, from the rear plate to the front plate
Set hb = part.HybridBodies.Add()
hb.Name = "Construction"
Set pl = hsf.AddNewPlaneOffset(part.CreateReferenceFromObject(part.OriginElements.PlaneXY), t, False)
hb.AppendHybridShape pl
part.Update
part.InWorkObject = body
Set sk = body.Sketches.Add(pl)
Set f2 = sk.OpenEdition()
c = Cos(PI / 4) : s = Sin(PI / 4)
r1 = a - pr / 2 : r2 = a + pr / 2
px(0) = r1 * c + pw / 2 * s : py(0) = r1 * s - pw / 2 * c
px(1) = r2 * c + pw / 2 * s : py(1) = r2 * s - pw / 2 * c
px(2) = r2 * c - pw / 2 * s : py(2) = r2 * s + pw / 2 * c
px(3) = r1 * c - pw / 2 * s : py(3) = r1 * s + pw / 2 * c
For i = 0 To 3
    Set pts(i) = f2.CreatePoint(px(i), py(i))
Next
For i = 0 To 3
    Set ln = f2.CreateLine(px(i), py(i), px((i + 1) Mod 4), py((i + 1) Mod 4))
    ln.StartPoint = pts(i)
    ln.EndPoint = pts((i + 1) Mod 4)
Next
f2.CreateClosedCircle a, 0, dp / 2
sk.CloseEdition
Set pad = sf.AddNewPad(sk, lp)
part.Update
Set ref = part.CreateReferenceFromObject(part.OriginElements.PlaneXY)
Set pat = sf.AddNewCircPattern(pad, 1, 4, 0, 90, 1, 1, ref, ref, True, 0, True)
part.Update
' plate rim scallops, through both plates, midway between pins and posts
For i = 0 To Pv(p, "n_sc") - 1
    c = (i + 0.5) * 2 * PI / Pv(p, "n_sc")
    PocketCircleZ part, body, Pv(p, "r_sc") * Cos(c), Pv(p, "r_sc") * Sin(c), Pv(p, "R_sc"), -1, 2 * t + lp + 1
Next
' hollow planet pins through both plates (SYS-06; the bore can feed the planet bearing oil, step 3.2)
For i = 0 To Pv(p, "n_planets") - 1
    c = i * 2 * PI / Pv(p, "n_planets")
    PocketCircleZ part, body, a * Cos(c), a * Sin(c), Pv(p, "pin_bore") / 2, -1, 2 * t + lp + 1
Next
HideGeometricalSets doc
mass = BodyMassKg(doc, body, 7830)
SaveParts doc, cadDir, "carrier"
Capture cadDir & "\img\carrier_iso.jpg", "iso"
doc.Close
WScript.Echo "carrier: mass " & FormatNumber(mass, 3) & " kg"
