// language_plugin.lsl    or lang_plugin_rezzer.lsl  if in animal rezzer
/**
 This script is used to install and upgrade language notecards.
 On startup it records the version and language of notecards in the object.
 It responds to the LANGUAGE-CHECK command from the language manager.
**/

float VERSION = 2.1;  // 18 February 2022
integer RSTATE = 1;   // RSTATE: 1=release, 0=beta, -1=RC

integer DEBUGMODE = FALSE;
debug(string text)
{
    if (DEBUGMODE == TRUE) llOwnerSay("DEBUG:" + llToUpper(llGetScriptName()) + " " + text);
}

string  TXT_CLOSE = "X";
string  TXT_SELECT = "*";
string  TXT_TIMED_OUT = "timed out";

integer VERSION;
string  PASSWORD;
key     user;
list    langSuffixes = [];   // eg: [ B1       B1       B1      B1      P1     ]
list    langNames    = [];   // eg: [ de-DE    en-GB    es-ES   r-FR    en-GB  ]
list    langVers     = [];   // eg: [ 2        2        2       2       1      ]

string SUFFIX = "*";

integer checkNcExists(string name)
{
    integer result = FALSE;
    if (llGetInventoryType(name) == INVENTORY_NOTECARD) result = TRUE;
    return result;
}

getLangInfo()
{
    if (checkNcExists("sfp") == TRUE) PASSWORD = llStringTrim(osGetNotecard("sfp"), STRING_TRIM);
    langSuffixes = [];
    langNames = [];
    langVers  = [];
    string  langName;
    integer langVer;
    string tmpName;
    list lines = [];
    string cmd;
    string val;
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
                integer i;
                for (i=0; i < llGetListLength(lines); i++)
                {
                    list tok = llParseString2List(llList2String(lines,i), ["="], []);
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
    debug("Suffixes:\n" +"\nLangNames:\n"+llDumpList2String(langNames, "\t") +"\nLanVers:\n"+llDumpList2String(langVers, "\t"));
}


integer chan(key u)
{
    return -1 - (integer)("0x" + llGetSubString( (string) u, -6, -1) )-393;
}

integer listener=-1;
integer listenTs;

startListen()
{
    if (listener<0)
    {
        listener = llListen(chan(llGetKey()), "", "", "");
        listenTs = llGetUnixTime();
    }
}

checkListen()
{
    if (listener > 0 && llGetUnixTime() - listenTs > 300)
    {
        llListenRemove(listener);
        listener = -1;
        llTextBox(user, TXT_TIMED_OUT, chan(llGetKey()));
    }
}

integer startOffset=0;

multiPageMenu(key id, string message, list opt)
{
    integer l = llGetListLength(opt);
    integer ch = chan(llGetKey());
    if (l < 12)
    {
        llDialog(id, message, opt+[TXT_CLOSE], ch);
        return;
    }
    if (startOffset >= l) startOffset = 0;
    list its = llList2List(opt, startOffset, startOffset + 9);
    llDialog(id, message, [TXT_CLOSE]+its+[">>"], ch);
}

default
{

    state_entry()
    {
        // Don't run the language_plugin.lsl script if in the animal rezzer since that has a copy called lang_plugin_rezzer 
        if (llGetScriptName() != "lang_plugin_rezzer")
        {
            if (llSubStringIndex(llGetObjectName(), "Update")>=0 || llSubStringIndex(llGetObjectName(), "Rezzer")>=0)
            {
                llSetScriptState(llGetScriptName(), FALSE); 
            }
        }
        getLangInfo();
        debug("langInfo:\n" + llDumpList2String(langNames, "\t") + "\n" +llDumpList2String(langVers, "\t"));
    }

    listen(integer c, string nm, key id, string m)
    {
        debug("listen: " + m);
        user = id;
        if (m == TXT_CLOSE)
        {
            //;
        }
        else if (m ==">>")
        {
            startOffset += 10;
            multiPageMenu(id, TXT_SELECT, langNames);
        }
        else
        {
            // change language
            llMessageLinked(LINK_SET, 1, "SET-LANG|"+m, id);
            llListenRemove(listener);
            listener = -1;
        }
    }

    dataserver(key id, string m)
    {
        debug("dataserver: " +m);
        list tk = llParseStringKeepNulls(m, ["|"], []);
        if (llList2String(tk, 1) != PASSWORD) return;
        string lang;
        string cmd = llList2String(tk,0);
        key managerKey = llList2Key(tk, 2);

        if (cmd == "DO-UPDATE")
        {
            // Update available for an existing notecard
            if (llGetOwnerKey(id) != llGetOwner())
            {
                osMessageObject(managerKey, "UPDATE-FAILED");
            }
            else
            {
                lang = llList2String(tk, 3);
                if (checkNcExists(lang +"-lang") == TRUE)
                {
                    llRemoveInventory(lang +"-lang");
                    llSleep(1.0);
                }
                osMessageObject(managerKey, "UPDATE-REPLY|" + PASSWORD + "|" + (string)llGetKey() + "|" + lang);
            }
        }
        else if (cmd == "LANGUAGE-CHECK")
        {
            // First check suffix matches our language cards  CMD|PASSWORD|SENDERID|SUFFIX
            if (llList2String(tk, 3) == SUFFIX)
            {
                // Send back LANGUAGE-REPLY|PASSWORD|ourID|SUFFIX|[langnames]|[langvers]
                lang = llList2String(tk, 3);
                string answer = "LANGUAGE-REPLY|" + PASSWORD + "|" + (string)llGetKey() + "|" + SUFFIX +"|" +llDumpList2String(langNames, "|") +"|" +llDumpList2String(langVers, "|");
                osMessageObject(managerKey, answer);
                debug("dataserver_reply: " + answer);
            }
        }
        else if (cmd == "DO-LANG-UPDATE")
        {
            // DO-LANG-UPDATE|PASSWORD|KEY|llDumpList2String(toSend, "|")
            // This tells us what lang notecards are out of date so we can delete them ready to then receive new ones
            string result;
            integer length = llGetListLength(tk);
            list returnInfo = [];
            integer i;
            for (i = 3; i < length; i++)
            {
                // en-GB-langP1
                result = llList2String(tk, i) +"-lang" +SUFFIX;
                if (checkNcExists(result) == TRUE)
                {
                    llRemoveInventory(result);
                    llSleep(0.5);
                    returnInfo += llList2String(tk, i);
                }
            }
            // Send back list of lang notecards we need updates of
            osMessageObject(managerKey, "LANGUAGE-READY|" +PASSWORD +"|" +(string)llGetKey() +"|" +SUFFIX +"|" +llDumpList2String(returnInfo, "|"));
        }
        else if (cmd == "ADD-CHECK")
        {
            // ADD-CHECK|PASSWORD|KEY|names
            integer result = TRUE;
            string name;
            integer length = llGetListLength(tk);
            integer i;
            for (i = 3; i < length; i++)
            {
                // check that the new notecards are here
                name = llList2String(tk, i);
                if (checkNcExists(name) != TRUE) result = FALSE;
            }
            if (result == TRUE)
            {
                osMessageObject(managerKey, "LANG-UPDATE-OK|" +PASSWORD +"|" +(string)llGetKey() +"|" +SUFFIX);
            }
            else
            {
                osMessageObject(managerKey, "LANG-UPDATE-FAILED|" +PASSWORD +"|" +(string)llGetKey() +"|" +SUFFIX);
            }
        }
    }

    link_message(integer sender_num, integer num, string msg, key id)
    {
        //debug("link_message: " +msg +"  Num:"+(string)num);
        list tk = llParseString2List(msg, ["|"], []);
        string cmd = llList2String(tk, 0);

        if (cmd == "MENU_LANGS")
        {
            debug("link_message: " + msg + "  Num="+(string)num +" From:" + (string)sender_num);
            list suffixLangs = [];
            // MENU_LANGS|languageCode|SUFFIX, id
            //PREFIX = llList2String(tk, 1);
            SUFFIX = llList2String(tk, 2);
            integer i;
            integer count = llGetListLength(langSuffixes);
            for (i = 0; i < count; i++)
            {
                if (llList2String(langSuffixes, i) == SUFFIX) suffixLangs += llList2String(langNames, i);
            }
            string str = TXT_SELECT;
            if (RSTATE == 0) str += " (-B-)"; else if (RSTATE == -1) str += " (-RC-)";
            startListen();
            multiPageMenu(id, str, suffixLangs);
            llSetTimerEvent(1000);
        }
/*
        // Previous behaviour - changed Feb. 2022
        if (cmd == "LANG_MENU")
        {
            string str = TXT_SELECT;
            if (RSTATE == 0) str += " (-B-)"; else if (RSTATE == -1) str += " (-RC-)";
            startListen();
            multiPageMenu(id, str, langNames);
            llSetTimerEvent(1000);
        }
*/
        else if (cmd == "CMD_DEBUG")
        {
            DEBUGMODE = llList2Integer(tk, 2);
            return;
        }
        else if (cmd == "RESET") llResetScript();
    }

    timer()
    {
        checkListen();
    }

    changed(integer change)
    {
        if (change & CHANGED_INVENTORY) llResetScript();
    }

}
