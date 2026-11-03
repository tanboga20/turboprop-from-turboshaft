' capture_all.vbs - pictures of the saved parts for the reports (CATIA V5 R19).
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\scripts\capture_all.vbs <repo cad folder> [part ...]
' Opens each cad\parts\<part>.CATPart (all parts if none are named), saves an iso picture in cad\img
' and closes it; crop the pictures with cad\scripts\crop_img.py. Source: Phase 2 report, Section 2.9.

Option Explicit
Dim cadDir, fso, names, i, doc
cadDir = WScript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
ExecuteGlobal fso.OpenTextFile(cadDir & "\scripts\catlib.vbs").ReadAll
If WScript.Arguments.Count > 1 Then
    ReDim names(WScript.Arguments.Count - 2)
    For i = 1 To WScript.Arguments.Count - 1
        names(i - 1) = WScript.Arguments(i)
    Next
Else
    names = Array("planet", "sun", "ring", "carrier", "gear2", "pinion", "case")
End If
For i = 0 To UBound(names)
    Set doc = CATIA.Documents.Open(cadDir & "\parts\" & names(i) & ".CATPart")
    Capture cadDir & "\img\" & names(i) & "_iso.jpg", "iso"
    If names(i) = "case" Then Capture cadDir & "\img\case_back.jpg", "back"
    doc.Close
    WScript.Echo names(i)
Next
