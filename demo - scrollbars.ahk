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
		base.__New(0, "+Resize")
		this.Gui("Show", "w400 h400","Scroll Demo")
		this.Gui("Margin",5,5)

		this.Gui("Add", "Text", "Center xm ym w100% ", "HWND: " this._hwnd)
		this.ChildWindow1 := new CWindow(this, "-Border").GuiOption("+Parent", this)
		this.ChildWindow1.Gui("Show", "x100 y100 w50% h50%")
		this.Gui("Add", "Text", "Center x0 y30 w100%", "HWND: " this.ChildWindow1._hwnd)
		Loop 20 {
			this.ChildWindow1.Gui("Add", "Text", "Center xm w100%", "Text " A_Index)
		}
		;this.AdjustToChild()
	}
	
	SendMyString(){
		Send % this.myedit.value
	}
}
