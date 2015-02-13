# CGui
A wrapper for AHK's GUI functionality, Experimental!

Inspired by Fincs' AFC.  
Made possible by the recent test builds of AHK.  

Please ensure you have a test build of AHK from [this thread](http://ahkscript.org/boards/viewtopic.php?f=24&t=5802).  
To make swapping between builds of ahk, you can use [AHK-EXE-Swapper](https://github.com/ahkscript/AHK-EXE-Swapper).  

##What?
#####Does it do?
A Class that you extend to allow you to turn a Gui or GuiControl into an object (Class).  
#####Are the objectives?
* To simplify the syntax of AHK, whilst maintining it's functionality.
* To provide extra Gui-Related features on top of what AHK normally offers. 

#####Are the current features?
* Add, Edit Guis and GuiControls as objects
* Pass objects as parameters, instead of HWNDs etc.
* Persistent settings systems catered for, sample basic IniRead/Write based system included.
* Example script demonstrating features

##How?
#####Do I use it?
* Include the script.
* Derive any classes you wish to alter them.
* instantiate your first window class `MyClass := new MyClass()`
* Put `base.__New()` at the start of the `__New()` constructor for your class.
* Access Gui functions through `this.GUI()`, using the same syntax.  
eg `Gui, Add, Edit, x0 y0 w100, Text`
would become `this.Gui("Add", "Edit", "x0 y0 w100", "Text")`  
* When adding a Gui item that you will wish to interrogate later, store a reference, like so:  
`this.myedit := this.Gui("Add", "Edit", "x0 y0 w100", "Text")`  
* Do not pass *vLabels* or *gLabels* in Option strings  
* Use `GuiControl` method to manipulate GuiControls
* Set *gLabels* with `this.GuiContol("+g", <control>, <method>)`  
eg `this.GuiControl("+g", this.myedit, this.EditChanged)`  
* *vLabels* are not required - Get / Set Control properties with <control>.value, eg `myedit.value`.  
* To manipulate GuiControls, use `GuiControl()` eg:  
`this.myedit.Guicontrol
* Use `GuiOption` to set gui options, pass objects instead of HWNDs, eg:  
```
this.ChildWindow := new CWindow(this, "-Border")
this.ChildWindow.GuiOption("+Parent", this)
```
* Functions can sometimes be chained, like so:  
`this.ChildWindow := new CWindow(this, "-Border").GuiOption("+Parent", this)`
* An object's *HWND* is always available via it's `_hwnd` property.
* An object's parent is available via it's `_parent` property.

##Why?
Because it allows you to write powerful, easy to understand code, like this - 15 commands to set up a Gui with an edit box that saves between runs, plus a couple of *gLabels* that call class methods, and not a *HWND* in sight.
```
		; Call base method of class to create window
		base.__New()
		this.GUI_WIDTH := 200
		; Start using GUI commands
		this.Gui("Margin",5,5)
		; Add some text, dont bother storing result
		this.Gui("Add", "Text", "Center xm ym w" this.GUI_WIDTH, "Persistent (Remembered on Reload)")
		
		; Add an Edit box, store a reference on this
		this.myedit := this.Gui("Add", "Edit","xm yp+20 w" this.GUI_WIDTH,"ChangeMe")
		; Call custom INI routine to tie this Edit box to a settings value.
		; This command is likely to be unique to your implementation
		; It sets the current value of the control to the value from the settings file, and sets up an event to write settings as they change.
		this.myedit.MakePersistent("somename")
		; Also set a g-label for this Edit box. Note that this is independent of the Persistence system
		this.GuiControl("+g", this.myedit, this.EditChanged)

		; Add a Button
		this.mybtn := this.Gui("Add","Button","xm yp+30 w" this.GUI_WIDTH,"v Copy v")
		; Wire up the button
		this.GuiControl("+g", this.mybtn, this.Test)	; pass object to bind g-label to, and method to bind to
		
		; Add an edit box, but don't make it persistent
		this.Gui("Add", "Text", "Center xm yp+30 w" this.GUI_WIDTH, "Not Persistent (Lost on Reload)")
		this.myoutput := this.Gui("Add","Edit","xm yp+20 w" this.GUI_WIDTH,"")
		
		; Add a child window
		; Use GuiOption method to set parent, so we can pass the object instead of the HWND
		; Note that we can chain commands.
		this.ChildWindow := new CWindow(this, "-Border").GuiOption("+Parent", this)
		this.ChildWindow.Gui("Add","Text", "Center x0 y40 w" this.GUI_WIDTH, "CHILD GUI")
		this.ChildWindow.Gui("Show", "x2 y150 w" this.GUI_WIDTH " h100")
		
		; Show the main Gui
		this.Gui("Show", "h260","Class Test")
```

