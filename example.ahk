#SingleInstance force
#include <CGui>
#include sample inihandler.ahk

; Include skinning library if it exists.
;#include *i <SkinSharp>

MyClass := new MyClass()
return

Esc::
GuiClose:
	ExitApp

; An example instance of a CGui class to show how to use it.
Class MyClass extends CWindow {
	__New(){
		; Call base method of class to create window
		base.__New()
		; Show the main Gui
		this.Gui("Show", "w200 h260","Class Test")

		this.GUI_WIDTH := 200
		; Start using GUI commands
		this.Gui("Margin",5,5)
		; Add some text, dont bother storing result
		this.Gui("Add", "Text", "Center xm ym w200 ", "HWND: " this._hwnd)
		this.Gui("Add", "Text", "Center xm y20 w" this.GUI_WIDTH, "Persistent (Remembered on Reload)")
		
		; Add an Edit box, store a reference on this
		this.myedit := this.Gui("Add", "Edit","xm yp+20 w" this.GUI_WIDTH,"ChangeMe")
		; Call custom INI routine to tie this Edit box to a settings value.
		; This command is likely to be unique to your implementation
		; It sets the current value of the control to the value from the settings file, and sets up an event to write settings as they change.
		this.myedit.MakePersistent("somename")
		; Also set a g-label for this Edit box. Note that this is independent of the Persistence system
		;this.GuiControl("+g", this.myedit, this.EditChanged)

		; Add a Button
		this.mybtn := this.Gui("Add","Button","xm yp+30 w" this.GUI_WIDTH,"v Copy v")
		this.GuiControl("+g", this.mybtn, this.Test)	; pass object to bind g-label to, and method to bind to
		this.Gui("Add","Text", "Center xm yp+30 w" this.GUI_WIDTH,"( Button is " this.mybtn._hwnd " )")
		; Wire up the button
		
		; Add an edit box, but don't make it persistent
		this.Gui("Add", "Text", "Center xm yp+30 w" this.GUI_WIDTH, "Not Persistent (Lost on Reload)")
		this.myoutput := this.Gui("Add","Edit","xm yp+20 w" this.GUI_WIDTH,"")
		
		; Add a child window
		; Use GuiOption method to set parent, so we can pass the object instead of the HWND
		; Note that we can chain commands.
		this.ChildWindow := new CWindow(this, "-Border")
		this.ChildWindow.GuiOption("+Parent", this)
		this.ChildWindow.Gui("Show", "x2 y150 w" this.GUI_WIDTH " h100")
		this.ChildWindow.Gui("Add","Text", "Center x0 y40 w" this.GUI_WIDTH, "CHILD GUI")
		
	}
	
	Test(){
		SoundBeep
		; Copy contents of one edit box to another
		this.myoutput.value := this.myedit.value
	}
	
	EditChanged(){
		; Pull contents of edit box with .value
		this.ToolTip(this.myedit.value, 2000)
	}
}
