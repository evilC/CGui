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

mc := new MyClass()
return

Esc::
GuiClose:
	ExitApp

Class MyClass extends CWindow {
	__New(){
		base.__New(0, "+Resize")
		this.GUI_WIDTH := 200
		this.GUI_MAX_WIDTH := 500
		this.GUI_COLUMN_2 := 300
		this.Gui("Margin",5,5)
		
		this.Gui("Add", "Text", "Center xm ym w" this.GUI_MAX_WIDTH, "HWND: " this._hwnd)

		this.ChildWindow1 := new CWindow(this, "-Border").GuiOption("+Parent", this)
		this.Gui("Add", "Text", "Center xm y30 w" this.GUI_WIDTH, "HWND: " this.ChildWindow1._hwnd)
		Loop 20 {
			;this.ChildWindow1.Gui("Add", "Text", "Center xm w" this.GUI_WIDTH, "Text " A_Index)
			this.ChildWindow1.Gui("Add", "Text", "Center xm", "Text " A_Index)
		}
		this.ChildWindow1.Gui("Show", "x0 y50 w" this.GUI_WIDTH " h200")
		this.ChildWindow1.AdjustToChild()
		
		this.ChildWindow2 := new CWindow(this, "-Border").GuiOption("+Parent", this)
		this.Gui("Add", "Text", "Center x" this.GUI_COLUMN_2 " y30 w" this.GUI_WIDTH, "HWND: " this.ChildWindow2._hwnd)
		Loop 30 {
			this.ChildWindow2.Gui("Add", "Text", "Center xm w" this.GUI_WIDTH, "Text " A_Index)
		}
		this.ChildWindow2.Gui("Show", "x" this.GUI_COLUMN_2 " y50 w" this.GUI_WIDTH " h200")
		this.ChildWindow2.AdjustToChild()
		
		
		this.Gui("Show", "w500 h150","Scroll Demo")
	}
	
	SendMyString(){
		Send % this.myedit.value
	}
}
