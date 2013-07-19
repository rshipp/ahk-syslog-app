; Uses MySQL to retrieve logs from a server, and parses them according
; to rules defined in another file. Entries that match the rules are
; shown in a popup.
#NoEnv
SetWorkingDir %A_ScriptDir%
#Include <DBA>
OnExit, ExitSub

; Objects
lastTime := {}
thisTime := {}
record := {}
rules := {}

; Read Settings
IniRead, connectionString, settings.ini, Server, connectionString
IniRead, lastTime_date, settings.ini, Last, date, 0
IniRead, lastTime_time, settings.ini, Last, time, 0
IniRead, localZone, settings.ini, Last, localzone, 0
IniRead, sleeptime, settings.ini, Settings, sleep, 5
IniRead, rulesFile, settings.ini, Settings, rules, rules.conf
lastTime.date := lastTime_date
lastTime.time := lastTime_time

; Make sure the ini was there/valid, and the rules file exists
if (connectionString = "ERROR")
{
    msgbox, 16,, No valid settings.ini found. Exiting.
    ExitApp
}
else if not FileExist(rulesFile)
{
    msgbox, 16,, No rules file found. Exiting.
    ExitApp
}

; Read rules
Loop, Read, %rulesFile%
{
    if not RegexMatch(A_LoopReadLine, "^#")
    {
        StringSplit, param, A_LoopReadLine, =
        rules[param1] := param2
    }
}

; Connect
db := DBA.DataBaseFactory.OpenDataBase("MySQL", connectionString)

; Start timer/loop
Loop
{
    display := ""
    query := "Select * from logs where date >= '" . lastTime.date . "' and time >= '" . lastTime.time . "'"

    utc_Hour := A_Hour - localZone, hours
    thisTime.date := A_YYYY . "-" . A_MM . "-" . A_DD
    thisTime.time := utc_Hour . ":" . A_Min . ":" . A_Sec

    rs := db.OpenRecordSet(query)

    while (!rs.EOF) 
    {
        record.host := rs["host"]
        record.msg := rs["msg"]
        record.date := rs["date"]
        record.time := rs["time"]

        for rule, regex in rules 
        {
            if RegExMatch(record.msg, regex) 
            {
                display := display . "Rule: " . rule . "`nHost: " . record.host . "`nTime: " . record.date . " " . record.time . "`nMessage: " . record.msg . "`n `n"
            }
        }
        rs.MoveNext()
    }
    rs.Close()

    if (display != "")
    {
        Gui, New
        Gui, Add, Edit, ReadOnly h200 w500 x0 y0, % display
        Gui, Margin, 0, 0
        Gui, Show,, Syslog Alert
    }

    lastTime.date := thisTime.date
    lastTime.time := thisTime.time
    sleepMSec := sleepTime * 60 * 1000
    sleep, %sleepMSec%
}

; Save time/date and exit
ExitSub:
if (lastTime.date != 0 and lastTime.time != 0)
{
    lastTime_date := lastTime.date
    lastTime_time := lastTime.time
    IniWrite, %lastTime_date%, settings.ini, Last, date
    IniWrite, %lastTime_time%, settings.ini, Last, time
}
ExitApp
