// storage_xfer.lsl
//
// Process is:
// Touch this box to initiate a scan for nearest item
// Send command to item for it to initiate the transfer sequence
// Uset either touches the item to confirm or touches this to abort

  float VERSION = 2.0;    // BETA 15 March 2022
integer RSTATE  = 0;      // RSTATE = 1 for release, 0 for beta, -1 for Release candidate
//
integer DEBUGMODE = FALSE;    // Set this if you want to force startup in debug mode
debug(string text)
{
    if (DEBUGMODE == TRUE) llOwnerSay("DB_" + llToUpper(llGetScriptName()) + " " + text);
}

//
// config notecard can overide the following:
string  storeName = "SF Store Barrel";    // STORE_NAME=SF Store Barrel
integer EMBEDDED = 1;                     // Set to 0 if this is a stand-alone item (xfer box) or 1 if part of another item that handles touch events
string  languageCode = "en-GB";           // LANG=en-GB
//
// Multilingual support
string TXT_XFER = "Transfer";
string TXT_ABORT_XFER = "Abort";
string TXT_TRYING = "Touch store to confirm";
string TXT_ABORT = "Touch me to abort";
string TXT_NOT_FOUND = "Not found";
string TXT_INFO = "Transfer stored items";
string TXT_CANCELLED = "Cancelled";
string TXT_FAILED = "Something went wrong, aborting";
string TXT_PHASE2 = "Remove old store then bring new store and this close together";
string TXT_TOUCH_START = "Touch me to start transfer";
string TXT_RETRY  = "Please bring new store closer together";
string TXT_COMPLETE = "Transfer complete!";
string TXT_LANGUAGE="@";
//
string  SUFFIX = "U1";
string  PASSWORD="*";
string  STORAGENC = "storagenc";
vector  BLUE = <0.224, 0.800, 0.800>;
integer scanRange = 10;
string  status;
key     storeID;
integer tryCount =0;
string  txtMessage;
vector  txtColour;


loadConfig()
{
    //sfp Notecard
    PASSWORD = llStringTrim(osGetNotecard("sfp"), STRING_TRIM);
    //config Notecard
    if (llGetInventoryType("config") == INVENTORY_NOTECARD)
    {
        list lines = llParseString2List(osGetNotecard("config"), ["\n"], []);
        string line;
        list tok;
        string cmd;
        string val;
        integer i;
        for (i=0; i < llGetListLength(lines); i++)
        {
            line = llStringTrim(llList2String(lines, i), STRING_TRIM);
            if (llGetSubString(line, 0, 0) != "#")
            {
                tok = llParseStringKeepNulls(line, ["="], []);
                cmd = llList2String(tok, 0);
                val = llList2String(tok, 1);
                     if (cmd == "STORE_NAME") storeName = val;
                else if (cmd == "EMBEDDED") EMBEDDED = (integer)val;    // Set to 0 if this is a stand-alone item (xfer box) or 1 if part of another item that handles touch events
                else if (cmd == "LANG") languageCode = val;
            }
        }
    }
}

loadLanguage(string langCode)
{
    // optional language notecard
    string languageNC = langCode + "-lang" + SUFFIX;
    debug("loadLanguage asked for " + TXT_LANGUAGE + " " +languageNC);
    if (llGetInventoryType(languageNC) == INVENTORY_NOTECARD)
    {
        list lines = llParseStringKeepNulls(osGetNotecard(languageNC), ["\n"], []);
        integer i;
        for (i=0; i < llGetListLength(lines); i++)
        {
            string line = llList2String(lines, i);
            if (llGetSubString(line, 0, 0) != "#")
            {
                list tok = llParseString2List(line, ["="], []);
                if (llList2String(tok,1) != "")
                {
                    string cmd=llStringTrim(llList2String(tok, 0), STRING_TRIM);
                    string val=llStringTrim(llList2String(tok, 1), STRING_TRIM);
                    // Remove start and end " marks
                    val = llGetSubString(val, 1, -2);
                    // Now check for language translations
                         if (cmd == "TXT_TRYING")   TXT_TRYING = val;
                    else if (cmd == "TXT_ABORT")    TXT_ABORT = val;
                    else if (cmd == "TXT_NOT_FOUND")   TXT_NOT_FOUND = val;
                    else if (cmd == "TXT_INFO")  TXT_INFO = val;
                    else if (cmd == "TXT_CANCELLED")  TXT_CANCELLED = val;
                    else if (cmd == "TXT_FAILED") TXT_FAILED  = val;
                    else if (cmd == "TXT_PHASE2")  TXT_PHASE2 = val;
                    else if (cmd == "TXT_TOUCH_START") TXT_TOUCH_START  = val;
                    else if (cmd == "TXT_RETRY") TXT_RETRY  = val;
                    else if (cmd == "TXT_COMPLETE") TXT_COMPLETE  = val;
                    else if (cmd == "TXT_XFER") TXT_XFER = val;
                    else if (cmd == "TXT_ABORT_XFER") TXT_ABORT_XFER = val;
                    else if (cmd == "TXT_LANGUAGE") TXT_LANGUAGE = val;
                }
            }
        }
    }
}

psys(key k)
{
     llParticleSystem(
                [
                    PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_ANGLE,
                    PSYS_SRC_ANGLE_BEGIN, 0.0,
                    PSYS_SRC_ANGLE_END, 0.0,

                    PSYS_SRC_TARGET_KEY, k,
                    PSYS_PART_TARGET_LINEAR_MASK, 1,

                    PSYS_PART_START_COLOR,<1.0, 0.8, 0.8>,
                    PSYS_PART_END_COLOR,<1.0, 1.0, 1.0>,

                    PSYS_PART_START_ALPHA,0.5,
                    PSYS_PART_END_ALPHA,1.0,

                    PSYS_PART_START_GLOW,0.05,
                    PSYS_PART_END_GLOW,0.1,

                    PSYS_PART_BLEND_FUNC_SOURCE,PSYS_PART_BF_SOURCE_ALPHA,
                    PSYS_PART_BLEND_FUNC_DEST,PSYS_PART_BF_ONE_MINUS_SOURCE_ALPHA,

                    PSYS_PART_START_SCALE,<0.20, 0.20, 0>,
                    PSYS_PART_END_SCALE,<0.75, 0.75, 0>,

                    PSYS_SRC_TEXTURE,"fx",

                    PSYS_SRC_MAX_AGE, 0.5,
                    PSYS_PART_MAX_AGE, 2,
                    PSYS_SRC_BURST_RATE, 0.1,
                    PSYS_SRC_BURST_PART_COUNT, 3,
                    PSYS_SRC_BURST_SPEED_MIN, 2.0,
                    PSYS_SRC_BURST_SPEED_MAX, 2.0,

                    PSYS_SRC_ACCEL,<0.00, 0.10, 0.00>,
                    PSYS_SRC_OMEGA,<0.00, 0.00, 0.00>,
                    PSYS_PART_FLAGS,
                        0 |
                        PSYS_PART_EMISSIVE_MASK |
                       PSYS_PART_TARGET_POS_MASK|
                        PSYS_PART_INTERP_COLOR_MASK |
                        PSYS_PART_INTERP_SCALE_MASK
                ]);
}

messageObj(key objId, string msg)
{
    list check = llGetObjectDetails(objId, [OBJECT_NAME]);
    if (llList2String(check, 0) != "") osMessageObject(objId, msg); else debug("messageObj failed sending " + msg + " to:"+(string)objId);
}

showIdleText(string msg, vector colour)
{
    if (RSTATE == 0) msg += "\n-B-"; else if (RSTATE == -1) msg += "\n-RC-";
    if (EMBEDDED == FALSE) llSetText(msg, colour, 1.0);
}

doTouch(key userID)
{
    debug("touch:status="+status +" (storeName="+storeName+")");
    if (EMBEDDED == FALSE)
    {
        if (status == "idle")
        {
            if (llGetOwner() == userID)
            {
                status = "phase1start";
                llSensor(storeName, "", SCRIPTED, scanRange, PI);
            }
        }
        else if (status == "waitTargetConfirm")
        {
            // touched so abort!
            messageObj(storeID, "REQUEST-INV-ABORT|" +PASSWORD);
            txtMessage = TXT_CANCELLED;
            txtColour = <1,1,1>;
            llSetText(txtMessage, txtColour, 1.0);
            llSleep(2.0);
            llMessageLinked(LINK_SET, 1, "SETSTATUS", "");
            llResetScript();
        }
        else if (status == "phase2start")
        {
            llSensor(storeName, "", SCRIPTED, scanRange, PI);
        }
        else if (status == "waitGiveConfirm")
        {
            // touched so abort!
            messageObj(storeID, "REQUEST-INV-ABORT|" +PASSWORD);
            status = "phase2start";
            txtMessage = TXT_PHASE2 +"\n" +TXT_TOUCH_START;
            txtColour = <1,1,1>;
            llSetText(txtMessage, txtColour, 1.0);
        }
    }
    else
    {
        if (status == "idle")
        {
            if (llGetOwner() == userID)
            {
                status = "phase1start";
                llSensor(storeName, "", SCRIPTED, scanRange, PI);
            }
        }

        else if (status == "waitTargetConfirm")
        {
            // ABORT
        }

    }
}


default
{

    timer()
    {
        llSetTimerEvent(0);
        llParticleSystem([]);
        status = "idle";
        showIdleText("", ZERO_VECTOR);
    }

    touch_end(integer index)
    {
        if (EMBEDDED == FALSE) doTouch(llDetectedKey(0));
    }

    state_entry()
    {
        llParticleSystem([]);
        loadConfig();
        loadLanguage(languageCode);
        llMessageLinked(LINK_SET, 1, "ADD_MENU_OPTION|"+TXT_XFER, "");
        status = "idle";
        showIdleText(TXT_INFO +"\n" +storeName, <1,1,1>);
    }

    on_rez(integer n)
    {
        llResetScript();
    }

    link_message(integer sender_num, integer num, string str, key id)
    {
        debug("link_message: " + str +" num="+(string)num);
        list tk = llParseString2List(str, ["|"], []);
        string cmd = llList2String(tk, 0);
        if (cmd == "MENU_OPTION")
        {
            if (llList2String(tk, 1) == TXT_XFER)
            {
                doTouch(id);
            }
        }
        else if ((cmd == "HARDRESET") || (cmd == "RESET"))
        {
            llResetScript();
        }
        else if (cmd == "SET-LANG")
        {
            languageCode = llList2String(tk, 1);
            loadLanguage(languageCode);
            if (EMBEDDED == FALSE) llSetText(TXT_INFO +"\n" +storeName, <1,1,1>, 1.0);
        }
    }

    sensor(integer n)
    {
        debug("sensor:status="+status +"  Detected="+llDetectedKey(0));
        if (status == "phase1start")
        {
            storeID = llDetectedKey(0);
            messageObj(storeID, "REQUEST-INV-START|" +PASSWORD);
            status = "waitTargetConfirm";
            llSetText(TXT_TRYING+"\n"+TXT_ABORT, <1.000, 0.522, 0.106>,1.0);
        }
        else if (status == "phase2start")
        {
            storeID = llDetectedKey(0);
            messageObj(storeID, "STOCK-XFER-CHECK|" +PASSWORD);
            txtMessage = TXT_TRYING +"\n" + TXT_ABORT;
            txtColour = <0.180, 0.800, 0.251>;
            llSetText(txtMessage, txtColour, 1.0);
            llSetColor(BLUE, ALL_SIDES);
            status = "waitGiveConfirm";
        }
    }

    no_sensor()
    {
        if (status == "phase1start")
        {
            llOwnerSay(TXT_NOT_FOUND);
            llSetTimerEvent(15);
        }
        else
        {
            llOwnerSay(TXT_RETRY +"\n" +TXT_TOUCH_START);
        }
    }

    dataserver(key id, string m)
    {
        debug("dataserver:"+m);
        list tk = llParseString2List(m, ["|"], []);
        if (llList2String(tk,1) == PASSWORD)
        {
            string cmd = llList2String(tk, 0);
            key kobject = llList2Key(tk, 2);

            if (cmd == "CMD_COLLECTOR")
            {
                llMessageLinked(LINK_SET, 1, "WAS_TOUCHED", llList2Key(tk, 2));
            }
            else if (cmd == "REQUEST-INV-OKAY")
            {
                txtMessage = "";
                txtColour = ZERO_VECTOR;
                llSetText(txtMessage, txtColour, 1.0);
                status = "";
                storeID = id;
                if (EMBEDDED == FALSE)
                {
                    if (llGetInventoryType(STORAGENC) == INVENTORY_NOTECARD) llRemoveInventory(STORAGENC);
                    messageObj(storeID, "REQUEST-INV-CONFIRM|" +PASSWORD);
                }
                else
                {
                    // tell the storage unit we are not going to give it a new storage notecard since we will send stock directly
                    messageObj(storeID, "REQUEST-INV-ABORT|" +PASSWORD);
                    status = "";
                    // read values from our storagenc notecard and send directly to the storage
                    list storageNC = [];
                    if (llGetInventoryType(STORAGENC) == INVENTORY_NOTECARD)
                    {
                        storageNC = llParseString2List(llStringTrim(osGetNotecard(STORAGENC), STRING_TRIM), [";"], []);
                    }
                    list products = llParseString2List(llList2String(storageNC,1), [","], []);
                    list levels   = llParseString2List(llList2String(storageNC,2), [","], []);
                    integer productCount = llGetListLength(products);
                    integer levelsCount;
                    integer i;
                    integer j;
                    for (i=0; i < productCount; i++)
                    {
                        levelsCount = llList2Integer(levels, i);
                        for (j = 0; j < levelsCount; j++)
                        {
                            messageObj(storeID, llToUpper(llList2String(products, i)) +"|"+PASSWORD);
                            llSleep(0.2);
                        }
                    }
                    // Now we have sent inventory to other storage, clear from here
                    if (llGetInventoryType(STORAGENC) == INVENTORY_NOTECARD) llRemoveInventory(STORAGENC);
                    llSetText(TXT_COMPLETE, <1,1,0>, 1.0);
                    llSetColor(<1,1,1>, ALL_SIDES);
                    llSetTimerEvent(10);
                }
            }
            else if (cmd == "REQUEST-INV-SENT")
            {
                llSleep(1.0);
                if (llGetInventoryType(STORAGENC) != INVENTORY_NOTECARD)
                {
                    llSleep(3.0);
                    if (llGetInventoryType(STORAGENC) != INVENTORY_NOTECARD)
                    {
                        messageObj(storeID, "REQUEST-INV-ABORT|" +PASSWORD);
                        txtMessage = TXT_FAILED;
                        txtColour = <1,0,0>;
                        llSetText(txtMessage, txtColour, 1.0);
                        llSleep(5);
                        llResetScript();
                    }
                }
                messageObj(storeID, "REQUEST-INV-DONE|" +PASSWORD);
                // now give notecard to new store
                status = "phase2start";
                txtMessage = TXT_PHASE2+ "\n"+TXT_TOUCH_START;
                txtColour = <1,1,1>;
                llSetText(txtMessage, txtColour, 1.0);
            }
            else if (cmd == "REQUEST-INV-FAIL")
            {
                llOwnerSay(TXT_NOT_FOUND);
                txtMessage = TXT_NOT_FOUND;
                txtColour = <1,0,0>;
                llSetText(txtMessage, txtColour, 1.0);
                llSleep(2);
                llResetScript();
            }
            else if (cmd == "XFER-READY")
            {
                txtMessage = "...";
                txtColour = <1,1,1>;
                llSetText(txtMessage, txtColour, 1.0);
                storeID = id;
                llGiveInventory(storeID, STORAGENC);
                llSleep(1);
                messageObj(storeID, "REQUEST-XFER-CONFIRM|" +PASSWORD);
                status = "waitXferConfirm";
            }
            else if (cmd == "XFER-CONFIRM-OKAY")
            {
                txtMessage = TXT_COMPLETE;
                txtColour = <1,1,1>;
                llSetText(txtMessage, txtColour, 1.0);
                if (llGetInventoryType(STORAGENC) == INVENTORY_NOTECARD) llRemoveInventory(STORAGENC);
                llSetColor(<1,1,1>, ALL_SIDES);
                llSetTimerEvent(10);
            }
            else if (cmd == "XFER-CONFIRM-FAIL")
            {
                llSleep(2);
                tryCount +=1;
                if (tryCount > 3)
                {
                    llGiveInventory(storeID, STORAGENC);
                    llSleep(2);
                    messageObj(storeID, "REQUEST-XFER-CONFIRM|" +PASSWORD);
                }
                else
                {
                    txtMessage = TXT_FAILED;
                    txtColour = <1,0,0>;
                    llSetText(txtMessage, txtColour, 1.0);
                    llSleep(2);
                    llResetScript();
                }
            }
        }
    }

    changed(integer change)
    {
        if (change & CHANGED_INVENTORY)
        {
            loadConfig();
            loadLanguage(languageCode);
            showIdleText(txtMessage, txtColour);
        }
        if (change & CHANGED_OWNER) llResetScript();
    }

}
