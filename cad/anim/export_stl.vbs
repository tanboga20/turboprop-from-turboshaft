' export_stl.vbs <parts folder> <out folder> <name> [<name> ...]: open each CATPart, write an STL, close.
' The parts are only read, so no "save changes?" question can stop the run (see cad/README.md):
'   C:\Windows\SysWOW64\cscript.exe //nologo cad\anim\export_stl.vbs <full path>\cad\parts <full path>\cad\anim\stl
'       planet sun ring carrier gear2 pinion gen_gear case
Option Explicit
Dim c, i, d, p, o, fso, t
Set fso = CreateObject("Scripting.FileSystemObject")
Set c = GetObject(, "CATIA.Application")
c.DisplayFileAlerts = False
p = WScript.Arguments(0) : o = WScript.Arguments(1)
For i = 2 To WScript.Arguments.Count - 1
    t = Timer
    Set d = c.Documents.Open(p & "\" & WScript.Arguments(i) & ".CATPart")
    If fso.FileExists(o & "\" & WScript.Arguments(i) & ".stl") Then fso.DeleteFile o & "\" & WScript.Arguments(i) & ".stl", True
    d.ExportData o & "\" & WScript.Arguments(i) & ".stl", "stl"
    WScript.Echo WScript.Arguments(i) & " exported in " & Round(Timer - t, 1) & " s, saved flag " & d.Saved
    d.Close
Next
c.DisplayFileAlerts = True
