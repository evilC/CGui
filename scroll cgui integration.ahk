; REQUIRES AHK TEST BUILD from HERE: http://ahkscript.org/boards/viewtopic.php?f=24&t=5802
; Example Script using CGui ===============================================
; Shows how to make an app that sends a string from a text box in the gui when you hit a key
; Text box contents are persistent across runs

#SingleInstance force
#include <_Struct>
#include <WinStructs>
#include <CGui>
#include sample inihandler.ahk

; Include skinning library if it exists.
;#include *i <USkin>

MyClass := new MyClass()
return

Esc::
GuiClose:
	ExitApp

Class MyClass extends CWindow {
	__New(){
		base.__New(this, "+Resize")
		this.GUI_WIDTH := 200
		this.Gui("Margin",5,5)
		Loop 20 {
			this.Gui("Add", "Text", "Center xm w" this.GUI_WIDTH, "Text " A_Index)
		}
		
		this.Gui("Show", "h200","Test")
		this.AdjustToChild()
	}
	
	SendMyString(){
		Send % this.myedit.value
	}
}
