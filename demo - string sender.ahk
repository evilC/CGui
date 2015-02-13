; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802
; Example Script using CGui ===============================================

; Currently DOES NOT WORK.
; Context bad when hotkey gets called? Bad bind?

#SingleInstance force
#include <CGui>
#include sample inihandler.ahk

MyClass := new MyClass()
return

Esc::
GuiClose:
	ExitApp

; An example instance of a CGui class to show how to use it.
Class MyClass extends CWindow {
	__New(){
		base.__New()
		this.GUI_WIDTH := 200
		this.Gui("Margin",5,5)
		this.Gui("Add", "Text", "Center xm ym w" this.GUI_WIDTH, "String to Send on F12")
		this.myedit := this.Gui("Add", "Edit","xm yp+20 w" this.GUI_WIDTH,"ChangeMe")
		this.myedit.MakePersistent("string1")
		;this.GuiControl("+g", this.myedit, this.EditChanged)
		
		fn := Bind(this.SendMyString, this)
		hotkey, ~F12, % fn, On
		
		this.Gui("Show",,"String Sender")
	}
	
	SendMyString(){
		MsgBox % this.myedit.value
		;Send % this.myedit.value
	}
	
	EditChanged(){
		; just for debugging at the moment
		this.ToolTip(this.myedit.value, 2000)
	}
}
