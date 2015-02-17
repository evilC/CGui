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
;#include *i <SkinSharp>

mc := new MyClass()
return

Esc::
GuiClose:
	ExitApp

Class MyClass extends CWindow {
	__New(){
		base.__New(0, "+Resize")
		this.Gui("Margin",5,5).Gui("Show", "w500 h500","Scroll Demo")

		this.Gui("Add", "Text", "Center xm ym w100% ", "HWND: " this._hwnd)

		this.ChildWindow1 := new CWindow(this, "-Border").GuiOption("+Parent", this)
		this.ChildWindow1.Gui("Show", "x0 y50 w45% h200")
		this.Gui("Add", "Text", "Center x0 y30 w45%", "HWND: " this.ChildWindow1._hwnd)
		Loop 20 {
			this.ChildWindow1.Gui("Add", "Text", "Center xm w50%", "Text " A_Index)
		}

		this.ChildWindow2 := new CWindow(this, "-Border").GuiOption("+Parent", this)
		this.ChildWindow2.Gui("Show", "x55% y50 w45% h200")
		this.Gui("Add", "Text", "Center x50% y30 w50%", "HWND: " this.ChildWindow2._hwnd)
		Loop 30 {
			this.ChildWindow2.Gui("Add", "Text", "Center x0 w100%", "Text " A_Index)
		}
	}
}
