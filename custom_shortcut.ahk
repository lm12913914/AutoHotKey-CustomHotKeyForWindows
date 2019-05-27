;;; globals
current_gui := ""
selected_action := ""
class MyHotKey
{
	action := {}
	hwnd := ""
	window_title := ""
}
myhotkeys := {}
	
;;; functions
switch_and_runwait(hotkey)
{
	global
	
	target_hwnd := myhotkeys[hotkey].hwnd
	target_action := myhotkeys[hotkey].action
    WinGet, current_hwnd, ID, A
    MouseGetPos, origin_x, origin_y

    WinActivate, ahk_id %target_hwnd%
    if (target_action.HasKey("ahk"))
    {
        RunWait, % target_action.ahk
    }
    else if (target_action.HasKey("mouse"))
    {
        start_time := 0
        For index, pos in target_action.mouse
        {
            current_time := A_TickCount
			Sleep, 50
			MouseMove, % pos.x, % pos.y
			Sleep, 50
            if (start_time != 0)
            {
                ; this script may be slow, so we substract the elapsed time between iterations
                wait_tick := pos.tick - (current_time - start_time)
                Sleep, %wait_tick%
            }
            MouseClick
			
            start_time := current_time
        }
    }

    WinActivate, ahk_id %current_hwnd%
    MouseMove, %origin_x%, %origin_y%
    return
}

record_mouse_clicks(record_tick)
{
    CoordMode, Mouse, Window
    global recording_clicks, recording, recording_tick, recording_record_tick
    recording_clicks := []
    recording := true
    recording_tick := 0
	recording_record_tick := record_tick

    HotKey, Esc, RecordMouseClick, On
    HotKey, ~LButton, RecordMouseClick, On
	x := 0
	y := 0
	Loop
	{
		MouseGetPos, _x, _y
		if (_x != x or _y != y)
		{
			ToolTip, Press Esc to finish
			x := _x
			y := _y
		}
		Sleep 20
	}
	Until recording != true
	ToolTip
	HotKey, ~LButton, ,Off
    HotKey, Esc, ,Off

    return recording_clicks
}

register_hotkey(hotkey)
{
	global
	
    WinGetTitle, title, A
    WinGet, hwnd, ID, A
    MsgBox, Register for window "%title%"
	myhotkeys[hotkey] := new MyHotKey()
	myhotkeys[hotkey].hwnd := hwnd
	myhotkeys[hotkey].window_title := title
	
	selected_action := ""
	current_gui := "register"
	Gui, Add, ListView, w300 r10 gSelectScript AltSubmit, Name
    LV_Add("Focus Select", "___clicks___")
    LV_Add("", "___mouse___")
	Loop, *.ahk
		LV_Add("", A_LoopFileName)

	Gui, Add, Button, w300 Default gListViewOKButton, OK
	Gui, Show, , Select a script as action
	
	Loop
	{
	}
	Until selected_action != ""
	
    if (selected_action = "___cancel___")
    {
        MsgBox, register cancelled
    }
    else if (selected_action = "___mouse___")
    {
        WinActivate, % myhotkeys[hotkey].hwnd
        myhotkeys[hotkey].action["mouse"] := record_mouse_clicks(true)
        MsgBox, register Completed, select "%selected_action%" as action
        HotKey, %hotkey%, HotKeyDispatch
    }
    else if (selected_action = "___clicks___")
    {
        WinActivate, % myhotkeys[hotkey].hwnd
        myhotkeys[hotkey].action["mouse"] := record_mouse_clicks(false)
        MsgBox, register Completed, select "%selected_action%" as action
        HotKey, %hotkey%, HotKeyDispatch
    }
    else
    {
        myhotkeys[hotkey].action["ahk"] := selected_action
        MsgBox, register Completed, select "%selected_action%" as action
		HotKey, %hotkey%, HotKeyDispatch
    }
	return
}

;;; main
; usage
MsgBox, ,Usage, Alt+Shift+F1~F12 to register.`n`nAlt+F1~F12 to trigger.`n`nAlt+Shift+Enter to show all.`n`nAdd .ahk files at the same directory to extend optable actions.
; register registering hotkeys
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
Loop, 11
{
	hotkey := "+!F" A_Index
	Hotkey, %hotkey%, RegisterHotKey
}
return

;;; LABELS
SelectScript:
    if (A_GuiEvent = "I")
    {
        selected := A_EventInfo
    }
    return

ListViewOKButton:
	LV_GetText(row, selected)
	selected_action := row
	Gui, Destroy
	return

GuiEscape:
GuiClose:
	if (current_gui = "register")
	{
		if (selected_action = "")
		{
			selected_action := "___cancel___"
		}
	}
	Gui, Destroy
    return

HotKeyDispatch:
	BlockInput, MouseMove
	switch_and_runwait(A_ThisHotKey)
	BlockInput, MouseMoveOff
	return
	
RegisterHotKey:
	register_hotkey(SubStr(A_ThisHotKey, 2))

RecordMouseClick:
    if (A_ThisHotKey = "Esc")
    {
        recording := false
        return
    }

    current_time := A_TickCount
    MouseGetPos, x, y
	if (recording_record_tick = true)
	{
		recording_clicks.Push({"x": x, "y": y, "tick": current_time - recording_tick})
	}
	else
	{
		recording_clicks.Push({"x": x, "y": y, "tick": 100})
	}
    recording_tick := current_time

;;; remappings
!+Enter::
	current_gui := ""
	Gui, Add, ListView, w300 r10 gSelectScript AltSubmit, Hotkey|Action|Window
	for index, hotkey in myhotkeys
	{
		for action_name, action in hotkey.action
		{
			if (action_name = "ahk")
			{
				LV_Add("", index, action, SubStr(hotkey.window_title, 1, 30))
			}
			else
			{
				LV_Add("", index, action_name, SubStr(hotkey.window_title, 1, 30))
			}
			break
		}
	}

	Gui, Add, Button, w300 Default gListViewOKButton, OK
	LV_ModifyCol() ; auto adjust column size
	Gui, Show, , Registered actions
	return
