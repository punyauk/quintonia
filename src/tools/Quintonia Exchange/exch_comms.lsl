// --------------------------------------------------------------
//  QUINTONIA FARM - Handles communication with Quintonia server
//  exch_comms.lsl
// --------------------------------------------------------------

integer DEBUGMODE = FALSE;
debug(string text)
{
    if (DEBUGMODE == TRUE) llOwnerSay("DEBUG:" + llToUpper(llGetScriptName()) + "\n " + text);
}

// Server URL (sent from main script)
string BASEURL = "";

vector GREEN       = <0.180, 0.800, 0.251>;
vector WHITE       = <1.0, 1.0, 1.0>;

key farmHTTP = NULL_KEY;
key ratingReqId;
key owner;
key toucher;
string  regionName;                         // Region name  e.g. Mintor
string  slurl;                              // Full slurl  e.g. worlds.quintonia.net:8002:mintor
vector  position;                           // Location of this exchange
string  rating;                             // Region rating is PG, MATURE, ADULT, UNKNOWN
integer avatars;                            // Number of avatars in region on last scan
integer minsSinceLast = -1;
string  status = "";
integer refreshInterval = 50;               // Keep this around 60 seconds or more unless testing             

// These are passed from main script. They are values read from config notecard
string  exchangeType = "grocery";           // TYPE=Grocery         can be 'grocery', 'bazaar', 'hardware' or 'concessions'   [bazaar is grocery minus concessions items]
integer offset = 0;                         // Offset from UTC
integer allowRegister = TRUE;               // REGEX=1              Set to 0 if this exchange box should't be registered on server
// Other variables passed from main script
string  farmName = "*";
string  farmDescription = "";
string  exchangeID = "*";                   // Unique key for registering this exchange on the server
integer accessMode = 0;                     // 0=Everyone, 1=Group, 2=Local residents
integer opMode = 1;                         // 0=Only items sold to this exchange can be purchased, 1=Normal operation
integer totalSold = 0;                      // How many sales recorded this month
integer totalPurchased = 0;                 // How many purchases recorded this month
string  PASSWORD = "*";
integer VERSION = 0;                        // Set to 0 until we get link message of actual version
integer RSTATE = 0;                         // RSTATE = 1 for release, 0 for beta, -1 for Release candidate
integer joomlaID = 0;

list exchData = [];
// exchData [exchangeID, owner, farmName, regionName, slurl, position, rating, exchangeType, accessMode, opMode, avatars, totalSold, totalPurchased, farmDescription]
// Database structure on server
/*
    `exchID` INT(11)            // Exchage ID
    `joomlaID` INT(11)          // Joomla ID of owner
    `opensimID` CHAR(36)        // OpenSim ID of owner
    `created` DATE              // Date first registered in the database
    `farmname` CHAR(128)        // Name of the farm, stored in exchange
    `region` CHAR(128)          // Region name  e.g. Mintor
    `slurl` CHAR(128)           // Full slurl  e.g. worlds.quintonia.net:8002:mintor
    `position` CHAR(128)        // X, Y, Z location fo this exchange
    `online` INT(11)            // Is region online?  [how to check this? as if offline we won't hear from it so need to check current time with last time via a scan?]
    `rating` CHAR(4)            // Rating is PG, MATURE, ADULT, UNKNOWN
    `exchtype` CHAR(128)        // Exchange Type  e.g. "grocery"
    `access` INT(11)            // Who can use this exchage   0=Everyone, 1=Group, 2=Local residents
    `opmode` INT(11)            // Operation mode  0=Only items sold to this exchange can be purchased, 1=Normal operation
    `lastheard_date` DATE       // Last heard from exchange on this date
    `lastheard_time` TIME       // Last heard from exchange at this time
    `avatars` TINYINT           // Number of avatars in the region (on last report)
    `num_sold` INT(11)          // Number of sales this month
    `num_purchase` INT(11)      // Number of purchases this month
    `farmDescription` CHAR(250) // Description of the farm stored, in exchange
*/

postMessage(string msg)
{
    debug("postMessage: " + msg +" to:"+BASEURL); 
    if ( (allowRegister == TRUE) && (msg != "") )
    {
        if (BASEURL != "") farmHTTP = llHTTPRequest(BASEURL, [HTTP_METHOD,"POST",HTTP_MIMETYPE,"application/x-www-form-urlencoded"], msg);
    }
}

string qsFixPrecision(float input, integer precision)
{
    precision = precision - 7 - (precision < 1);
    if(precision < 0)
        return llGetSubString((string)input, 0, precision);
    return (string)input;
}

checkBeacon()
{
    regionName = llGetRegionName();
    integer nNew = 0;
    list avis = llGetAgentList(AGENT_LIST_REGION | AGENT_LIST_EXCLUDENPC, []);
    integer howmany = llGetListLength(avis);
    integer i;
    for ( i = 0; i < howmany; i++ )
    {
        if ( !osIsNpc(llList2Key(avis, i)) )
        {
            nNew++;
        }
    }
    // If we don't yet have all data, re-request it
    if (joomlaID == 0 || exchangeID == "*" || farmName == "*" || VERSION == 0) 
    {
        llMessageLinked(LINK_SET, 1, "EXCH_RESEND", "");                
    }
    else
    {
        integer timx = llGetUnixTime() - minsSinceLast;
        // Check every ~15 minutes or if number of avatars in region has changed
        if ( nNew != avatars || timx > 900 || status == "forceRefresh")
        {
            if (exchangeID != "*")
            {
                avatars = nNew;
                string exdata = "task=updtex&data1=" +(string)exchangeID +"&data2="; 
                exdata +=
                                owner+"|"+
                                farmName+"|"+
                                regionName+"|"+
                                llEscapeURL(slurl)+"|"+
                                llEscapeURL((string)position)+"|"+
                                rating+"|"+
                                exchangeType+"|"+
                                (string)accessMode+"|"+
                                (string)opMode+"|"+
                                (string)avatars+"|"+
                                (string)totalSold+"|"+
                                (string)totalPurchased+"|"+
                                (string)exchangeID+"|"+
                                (string)VERSION+"|"+
                                (string)RSTATE+"|"+
                                (string)joomlaID+"|"+
                                farmDescription;
                // send data to Quintonia server
                postMessage(exdata);
                debug(exdata);
                minsSinceLast = llGetUnixTime();
            }
            else
            {
                //qex 'exchange id' notecard
                if (llGetInventoryType("qex") == INVENTORY_NOTECARD)
                {
                    // Read in the exchange ID
                exchangeID = osGetNotecardLine("qex", 0);
                }
            }
        }
        debug("checkBeacon - farmName:" + farmName + "  joomlaID:|" +(string)joomlaID + "|  exchangeID:" +exchangeID +"  Version:" +(string)VERSION); 
    }
}

// --- STATE DEFAULT -- //

default
{

    on_rez(integer n)
    {
        llResetScript();
    }

    state_entry()
    {
        owner = llGetOwner();
        llPassTouches(1);
        regionName = llGetRegionName();
        slurl = osGetGridLoginURI();
        position = llGetPos(); 
        status = "init";
        // Request rating for this region
        ratingReqId = llRequestSimulatorData( llGetRegionName(), DATA_SIM_RATING );
        // Ask server for the Joomla ID of the owner so we can store in database
        postMessage("task=chkuser&data1=" + (string)owner);
    }

    timer()
    {
        if (status == "update")
        {
            // We are in the process of applying an update so stop sending data to server until update complete
            llSetTimerEvent(0);
        }
        else
        {
            checkBeacon();
        }
    }

    link_message(integer sender_num, integer num, string msg, key id)
    {
        debug("link_message: " + msg +"  Num="+(string)num);
        list tk = llParseStringKeepNulls(msg, ["|"], []);
        string cmd = llList2String(tk,0);

        if (cmd == "CMD_INIT")
        {
            // PASSWORD|VERSION|RSTATE|ExchangeID|joomlaID|BASEURL 
            PASSWORD   = llList2String(tk, 1);
            VERSION    = llList2Integer(tk, 2); // store in database as x10  i.e.  ver 5.5  would be stored as 55
            RSTATE     = llList2Integer(tk, 3);
            exchangeID = llList2String(tk, 4);
            joomlaID   = llList2Integer(tk, 5);
            BASEURL    = llList2String(tk, 6);
        }

        if (cmd == "EXCH_VALUES")
        {
            VERSION         = llList2Integer(tk, 1);  // store in database as x10  i.e.  ver 5.5  would be stored as 55
            RSTATE          = llList2Integer(tk, 2);
            exchangeID      = llList2String(tk, 3);
            exchangeType    = llList2String(tk, 4);
            offset          = llList2Integer(tk, 5);
            allowRegister   = llList2Integer(tk, 6);
            farmName        = llList2String(tk, 7);
            accessMode      = llList2Integer(tk, 8);
            opMode          = llList2Integer(tk, 9);
            joomlaID        = llList2Integer(tk, 10);
            farmDescription = llList2String(tk, 11);
        }
        else if (cmd == "SOLD_UPDATE")
        {
            totalSold = llList2Integer(tk,1);
            checkBeacon();
        }
        else if (cmd == "PURCHASE_UPDATE")
        {
            totalPurchased = llList2Integer(tk,1);
            checkBeacon(); 
        }
        else if (cmd == "FARM_NAME")
        {
            farmName = llList2String(tk, 1);
        }
        else if (cmd == "FARM_DESC")
        {
            farmDescription = llList2String(tk, 1);
        }
        else if (cmd == "CMD_REFRESH")
        {
            status = "forceRefresh";
            checkBeacon();
        }
        else if (cmd == "SETHTTPS")
        {
            BASEURL = llList2String(tk,1);
        }
        else if (cmd == "RESET")
        {
            llResetScript();
        }
    }

    http_response(key request_id, integer Status, list metadata, string body)
    {
        debug("http_response - Status: " + Status + "\nbody: " + body);
        if (request_id == farmHTTP)
        {
            llSetColor(WHITE, 4);
            list tok = llParseStringKeepNulls(body, ["|"], []);
            string cmd = llList2String(tok, 0);

            if (cmd == "USERINFO")
            {
                joomlaID = llList2Integer(tok, 1);
            }     
            else
            {
              debug(" http_response unknown: "+llList2String(tok,1));
            }
        }
        else
        {
            // Response not for this script
        }
    }

    dataserver( key id, string m)
    {
        debug("id: " + (string)id +" ["+(string)ratingReqId +"]" +"  dataserver: " +m);
        if (id == ratingReqId)
        {
            rating = m;
            status = "active";
            llSetTimerEvent(refreshInterval);
            minsSinceLast = llGetUnixTime();
        }
        else
        {
            list tk = llParseStringKeepNulls(m, ["|"], []);
            string cmd = llList2String(tk,0);
            integer i;
            //for updates
            if (cmd == "VERSION-CHECK")
            {
                string answer = "VERSION-REPLY|" + PASSWORD + "|";
                answer += (string)llGetKey() + "|" + (string)((integer)(VERSION*10)) + "|";
                integer len = llGetInventoryNumber(INVENTORY_OBJECT);
                while (len--)
                {
                    answer += llGetInventoryName(INVENTORY_OBJECT, len) + ",";
                }
                len = llGetInventoryNumber(INVENTORY_SCRIPT);
                string me = llGetScriptName();
                while (len--)
                {
                    string item = llGetInventoryName(INVENTORY_SCRIPT, len);
                    if (item != me)
                    {
                        answer += item + ",";
                    }
                }
                answer += me;
                osMessageObject(llList2Key(tk, 2), answer);
            }
            else if (cmd == "DO-UPDATE")
            {
                status = "update";
                if (llGetOwnerKey(id) != llGetOwner())
                {
                    llMessageLinked(LINK_SET, 0, "UPDATE-FAILED", "");
                    return;
                }
                string me = llGetScriptName();
                string sRemoveItems = llList2String(tk, 3);
                list lRemoveItems = llParseString2List(sRemoveItems, [","], []);
                integer delSelf = FALSE;
                integer d = llGetListLength(lRemoveItems);
                while (d--)
                {
                    string item = llList2String(lRemoveItems, d);
                    if (item == me) delSelf = TRUE;
                    else if (llGetInventoryType(item) != INVENTORY_NONE)
                    {
                        llRemoveInventory(item);
                    }
                }
                integer pin = llRound(llFrand(1000.0));
                llSetRemoteScriptAccessPin(pin);
                osMessageObject(llList2Key(tk, 2), "DO-UPDATE-REPLY|"+PASSWORD+"|"+(string)llGetKey()+"|"+(string)pin+"|"+sRemoveItems);
                if (delSelf)
                {
                    llRemoveInventory(me);
                }
                llSleep(10.0);
                status = "";
                llResetScript();
            }
        }
    }


}
