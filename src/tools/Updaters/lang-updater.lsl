//  lang-updater.lsl
/**
This script is used to update the language notecards in Quintonia SatyrFarm items.
It scans for upgradeable items nearby 96m radius
#Configuration Notecards:
 sfp            = SatyrFarm Password
 upgradeables   = List of objects that will be checked to see if lang notecard can be upgraded, one per line
**/

// Version 1.0     5 February 2022

integer DEBUGMODE = FALSE;
debug(string text)
{
    if (DEBUGMODE == TRUE) llOwnerSay("DEBUG:" + llToUpper(llGetScriptName()) + "\n " + text);
}

integer VERSION;
string  PASSWORD;
list    UPGRADEABLES = [];

list    langSuffixes = [];   // eg: [ B1     B2      B1      B2      B1      B2      B1      B2      B1      B2    ]
list    langNames    = [];   // eg: [ de-DE  de-DE   en-GB   en-GB   es-ES   es-ES   r-FR    fr-FR   pt-PT   pt-PT ]
list    langVers     = [];   // eg: [ 2      2       2       2       2       2       2       2       2       2     ]

string  SUFFIX = "*";

integer scan;
list    clients;
integer counter;
integer counter_none;
integer counter_scan;


integer checkNcExists(string name)
{
    integer result = FALSE;
    if (llGetInventoryType(name) == INVENTORY_NOTECARD) result = TRUE;
    return result;
}

integer loadConfig()
{
    integer i;
    string name;
    list lines = [];
    list tok = [];
    string cmd;
    string  val;
    integer retVal = FALSE;

    //config notecards
    if (llGetInventoryType("sfp") == INVENTORY_NONE || llGetInventoryType("upgradeables") == INVENTORY_NONE)
    {
        llOwnerSay("No upgradeables and/or password notecard in inventory. Can't work like that!");
    }
    else
    {
        PASSWORD = llStringTrim(osGetNotecard("sfp"), STRING_TRIM);

        if (llGetInventoryType("upgradeables") != INVENTORY_NONE)
        {
            UPGRADEABLES = llParseString2List(osGetNotecard("upgradeables"), ["\n"], []);
        }

        // Make a list of all language notecards      en-GB-langP1 etc
        string tmpName;
        string  langName;
        integer langVer;
        integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
        integer j;
        for (j = 0; j < count; j++)
        {
            if (llGetSubString(llGetInventoryName(INVENTORY_NOTECARD, j), -7, -3) == "-lang")
            {
                SUFFIX = llGetSubString(llGetInventoryName(INVENTORY_NOTECARD, j), -2, -1);
                langName = llGetSubString(llGetInventoryName(INVENTORY_NOTECARD, j), 0, 4);
                langVer = 0;
                tmpName = langName+"-lang"+SUFFIX;
                if (checkNcExists(tmpName) == TRUE)
                {
                    lines = llParseString2List(osGetNotecard(tmpName), ["\n"], []);
                    for (i=0; i < llGetListLength(lines); i++)
                    {
                        tok = llParseString2List(llList2String(lines,i), ["="], []);
                        if (llList2String(tok,1) != "")
                        {
                            cmd=llStringTrim(llList2String(tok, 0), STRING_TRIM);
                            if (cmd == "@VER") langVer = llList2Integer(tok, 1);
                        }
                    }
                    langSuffixes += SUFFIX;
                    langNames += [langName];
                    langVers  += [langVer];
                }
            }
        }
        retVal = TRUE;
    }
    return retVal;
}


setText(string msg, vector colour)
{
    llSetLinkPrimitiveParamsFast(2, [PRIM_TEXT, msg, colour, 1.0]);
}

scanNext()
{
    string target = llList2String(UPGRADEABLES, scan);
    if (target == "")
    {
        string tmpStr = "Update finished.\nScanned for " + (string)counter_scan + " objects.\nUpdated " + (string)counter + " items.\n";
        if (counter_none !=0 ) tmpStr += "Update not done on " + (string)counter_none + " objects.\n" ;
        llOwnerSay(tmpStr);
        llResetScript();
        return;
    }
    llOwnerSay("Scanning for " + target);
    setText("Talking to " + target + "...", <1.0,0.0,0.8>);
    ++scan;
    llSensor(target, "", SCRIPTED, 96, PI);
}

string FormatDecimal(float number, integer precision)
{
    float roundingValue = llPow(10, -precision)*0.5;
    float rounded;
    if (number < 0) rounded = number - roundingValue;
    else            rounded = number + roundingValue;

    if (precision < 1) // Rounding integer value
    {
        integer intRounding = (integer)llPow(10, -precision);
        rounded = (integer)rounded/intRounding*intRounding;
        precision = -1; // Don't truncate integer value
    }

    string strNumber = (string)rounded;
    return llGetSubString(strNumber, 0, llSubStringIndex(strNumber, ".") + precision);
}


default
{
    state_entry()
    {
        llSetColor(<1.0, 1.0, 1.0>, 4);
        llSetColor(<0.0, 0.0, 0.0>, 0);
        llSetTextureAnim(FALSE, ALL_SIDES, 0, 0, 0.0, 0.0, 1.0);
        if (loadConfig() == FALSE)
        {
            llOwnerSay("ERROR with configuration!");
            setText("ERROR!\nPlease check configuration", <1,0,0>);
        }
        else
        {
            string verText;
            if (VERSION != -1) verText = FormatDecimal((float)VERSION/10, 2); else verText = "ALL";
            string minVerText;
            setText("Language updater \n" , <0.25, 0.75,0.25>);
        }
    }

    touch_start(integer n)
    {
        if (llDetectedKey(0) != llGetOwner())
        {
            llSay(0, "Sorry, you are not my owner");
            return;
        }
        state update;
    }

    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            llResetScript();
        }
    }
}


state update
{
    state_entry()
    {
        setText("Update Running...", <0.0,1.0,0.2>);
        llSetColor(<0.0, 1.0, 0.75>, 4);
        llSetColor(<1.0, 1.0, 1.0>, 0);
        llSetTextureAnim(ANIM_ON | LOOP, 0, 8, 6, 0.0, 48.0, 10.0);
        counter = 0;
        counter_none = 0;
        counter_scan = 0;
        scan = 0;
        scanNext();
    }

    sensor(integer n)
    {
        clients = [];
        key owner = llGetOwner();
        while (n--)
        {
            key det = llDetectedKey(n);
            if (owner == llGetOwnerKey(det))
            {
                clients += [det];
            }
        }
        llSetTimerEvent(1.0);
    }

    timer()
    {
        llSetTimerEvent(0.0);
        if (clients == [])
        {
            scanNext();
            return;
        }
        key target = llList2Key(clients, 0);
        clients = llDeleteSubList(clients, 0, 0);
        llOwnerSay(" \n-------------\nChecking " + llKey2Name(target) + " [" + (string)target + "]" );
        llSetTimerEvent(3.0);
        ++counter_scan;
        // Request version info for lang notecards
        osMessageObject(target, "LANGUAGE-CHECK|" + PASSWORD + "|" + (string)llGetKey() +"|" + SUFFIX);
    }

    no_sensor()
    {
        llOwnerSay("No item found");
        scanNext();
    }

    dataserver(key k, string m)
    {
        debug("dataserver: " + m);
        list tk = llParseString2List(m, ["|"], []);
        string command = llList2String(tk, 0);

        if (llList2String(tk,1) == PASSWORD)
        {
            if (command == "LANGUAGE-REPLY")
            {
                // Get back LANGUAGE-REPLY|PASSWORD|ourID|SUFFIX|[langnames]|[langvers]
                if (llList2String(tk, 3) == SUFFIX)
                {
                    // Find the split point between langames list and langvers list
                    integer split = llRound((llGetListLength(tk) -4) * 0.5);
                    split += 3;
                    list toSend = [];
                    list theirLangs = llList2List(tk, 4, split);
                    list theirVers  = llList2List(tk, split+1, -1);
                    integer result;
                    integer i;
                    integer length = llGetListLength(theirLangs);
                    for (i = 0; i < length; i++)
                    {
                        // langNames  eg: [ de-DE  de-DE   en-GB   en-GB   es-ES   es-ES   r-FR    fr-FR   pt-PT   pt-PT ]
                        // langVers   eg: [ 2      2       2       2       2       2       2       2       2       2     ]

                        result = llListFindList(langNames, [llList2String(theirLangs, i)]);
                        if (result != -1)
                        {
                            if (llList2Integer(langVers, result) > llList2Integer(theirVers, result)) toSend += llList2String(theirLangs, result);
                        }
                    }
                    // Send them the list of newer notecards so they can delete the existing ones
                    osMessageObject(llList2Key(tk, 2), "DO-LANG-UPDATE|"+PASSWORD+"|"+(string)llGetKey()+"|"+llDumpList2String(toSend, "|"));           
                }
            }
            else if (command == "LANGUAGE-READY")
            {
                // LANGUAGE-READY|PASSWORD|llGetKey|SUFFIX|returnInfo
                if (llList2String(tk, 3) == SUFFIX)
                {
                    llOwnerSay("Update for: \n    " +llKey2Name(llList2Key(tk, 2)) + "\n-----------");
                    string name;
                    list names = [];
                    key  kobject = llList2Key(tk, 2);
                    list litems  = llList2List(tk, 4, -1);
                    integer length = llGetListLength(litems);
                    integer i;
                    for (i = 0; i < length; i++)
                    {
                        name = llList2String(litems, i)+"-lang"+SUFFIX; 
                        if (checkNcExists(name) == TRUE)
                        {
                            llGiveInventory(kobject, name);
                            llOwnerSay("Sending language update: " + name);
                            llSleep(0.2);
                            names += name;
                        }
                    }
                    // Send 'all done' message
                    osMessageObject(kobject, "ADD-CHECK|" +PASSWORD +"|" +(string)llGetKey() +"|" +llDumpList2String(names, "|"));
                    llOwnerSay("Updated items: \n    " +llKey2Name(llList2String(tk,2)) + "\n-----------");
                    llSetTimerEvent(1.0);
                }
            }
            else if (command == "LANG-UPDATE-OK")
            {
                ++counter;
            }            
        }
        else
        {
            llOwnerSay("sfp match error!");
        }
    }
}
