; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802
; Example Script using CGui ===============================================
; Shows how to make an app that sends a string from a text box in the gui when you hit a key
; Text box contents are persistent across runs

#SingleInstance force
#include CGui.ahk
#include sample inihandler.ahk

; Include skinning library if it exists.
#include *i <USkin>

MyClass := new MyClass()
return

Esc::
GuiClose:
	ExitApp

Class MyClass extends CWindow {
	__New(){
		base.__New(0)
		this.GUI_WIDTH := 200
		this.Gui("Margin",5,5)
		this.Gui("Add", "Text", "Center xm ym w" this.GUI_WIDTH, "String to Send on F12")
		this.myedit := this.Gui("Add", "Edit","xm yp+20 w" this.GUI_WIDTH,"ChangeMe")
		this.myedit.MakePersistent("string1")
		
		fn := Bind(this.SendMyString, this)
		hotkey, F12, % fn, On
		
		this.Gui("Show", "y0 w210 h75","String Sender")
	}
	
	SendMyString(){
		Send % this.myedit.value
	}
}
