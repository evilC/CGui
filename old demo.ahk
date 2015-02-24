CGui_Demo_Running := 1	; any test code in CGui main file should see this and not run.
BorderState := 1

main := new _CGui(0,"+Resize")
main.Show("w300 h300 y0", "CGui Demo - " main._hwnd)
Menu, Menu1, Add, Border, ToggleBorder
Menu, Menu1, Add, Destroy, DestroyChild
Gui, Menu, Menu1

;main.FocusTest := new _Cgui(main, BoolToSgn(BorderState) "Border +Resize +Parent" main._hwnd)
main.FocusTest := main.Gui("new", BoolToSgn(BorderState) "Border +Resize +Parent" main._hwnd)
main._DebugWindows := 0
main.FocusTest._DebugWindows := main._DebugWindows
main.name := "main"
main.FocusTest.name := "Child"

main.FocusTest.Show("w150 h150 x00 y00", main.FocusTest._hwnd)

main.VGTest := main.Gui("new", "-Border +Resize +Parent" main._hwnd)
main.VGTest.Show("x200 y200")
main.VGTest.myText := main.VGTest.Gui("Add", "Text", "x0 y0 w100", main.VGTest._hwnd " (" Format("{:i}",main.VGTest._hwnd) ")" )
main.VGTest.name := "Child2"
main.VGTest._DebugWindows := main._DebugWindows

if (main._DebugWindows || main.FocusTest._DebugWindows){
	Gui, New, hwndhDebug
	Gui, % hDebug ":Show", w300 h180 x0 y0
	Gui, % hDebug ":Add", Text, % "hwndhDebugOuter w400 h400" ,
}

Loop 8 {
	main.FocusTest.Gui("Add", "Edit", "w300", "Item " A_Index)
}
if (main._DebugWindows || main.FocusTest._DebugWindows){
	UpdateDebug()
}
return

UpdateDebug() {
	global main
	global hDebug, hDebugOuter
	str := ""
	str .= "PARENT hwnd: `t`t" main._hwnd "   (" Format("{:i}",main._hwnd) ")"
	str .= "`nCHILD hwnd: `t`t" main.FocusTest._hwnd "   (" Format("{:i}",main.FocusTest._hwnd) ")"
	str .= "`n`nOuter WINDOW: `t" main._SerializeRECT(main._WindowRECT)
	str .= "`nOuter PAGE: `t`t" main._SerializeRECT(main._PageRECT)
	str .= "`nOuter RANGE: `t`t" main._SerializeRECT(main._RangeRECT)
	str .= "`n`nInner WINDOW: `t: " main._SerializeRECT(main.FocusTest._WindowRECT)
	str .= "`nInner PAGE: `t`t: " main._SerializeRECT(main.FocusTest._PageRECT)
	str .= "`nInner RANGE: `t`t: " main._SerializeRECT(main.FocusTest._RangeRECT)
	str .= "`n`nCHILD2 WINDOW: `t: " main._SerializeRECT(main.VGTest._WindowRECT)
	;str .= "`n`nTest RECT: `t`t: " main._SerializeRECT(main.FocusTest._TestRECT)
	GuiControl, % hDebug ":", % hDebugOuter, % str
	Sleep 100
}

BoolToSgn(bool){
	if (bool){
		return "+"
	} else {
		return "-"
	}
}

ToggleBorder:
	BorderState := !BorderState
	Gui, % main.FocusTest._hwnd ":" BoolToSgn(BorderState) "Border"
	
	return

DestroyChild:
	main.VGTest.Destroy()
	main.VGTest := ""
	return

#include CGui.ahk
