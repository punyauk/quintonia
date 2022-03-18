// quincom.lsl
//
float version = 5.4;   //  17 March 2022
//

string  URL = "quintonia.net/index.php?option=com_quinty&format=raw&";
string  BASEURL;
integer useHTTPS;

integer DEBUGMODE = FALSE;
debug(string text)
{
    if (DEBUGMODE == TRUE) llOwnerSay("DEBUG_" + llToUpper(llGetScriptName()) + " " + text);
}

key farmHTTP = NULL_KEY;
key callerID = NULL_KEY;

postMessage(string msg)
{
    debug("postMessage:"+msg +"\nTO " +BASEURL);
    if (BASEURL != "")
    {
        farmHTTP = llHTTPRequest(BASEURL, [HTTP_METHOD,"POST",HTTP_MIMETYPE,"application/x-www-form-urlencoded", HTTP_BODY_MAXLENGTH, 16384], msg);
    }
    else
    {
        llOwnerSay("QUINCOM ERROR!");
    }
}

loadConfig()
{
    if (llGetInventoryType("config") == INVENTORY_NOTECARD)
    {
        list lines = llParseString2List(osGetNotecard("config"), ["\n"], []);
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
                         if (cmd == "DEBUG")           DEBUGMODE = (integer)val;
                    else if (cmd == "USE_HTTPS")       useHTTPS = (integer)val;
                }
            }
        }
    }
}



default
{
    state_entry()
    {
        loadConfig();
        if (useHTTPS == TRUE) BASEURL = "https://"+URL; else BASEURL = "http://"+URL;

    }

    link_message(integer sender_num, integer num, string msg, key id)
    {
        list tk = llParseStringKeepNulls(msg, ["|"], []);
        string cmd = llList2String(tk,0);

        if ( (cmd == "CMD_POST") || (cmd == "SETHTTPS")) debug("link_message:" + msg);

        if (cmd == "CMD_POST")
        {
            callerID = id;
            postMessage(llList2String(tk,1));
        }
        else if (cmd == "SETHTTPS")
        {
            if (num == 1)
            {
                BASEURL = "https://"+URL;
                useHTTPS = TRUE;
            }
            else
            {
                BASEURL = "http://"+URL;
                useHTTPS = FALSE;
            }
        }
    }

    http_response(key request_id, integer Status, list metadata, string body)
    {
        debug("http:_response:" + body);
        if (request_id == farmHTTP)
        {
            llMessageLinked(LINK_SET, 1, "HTTP_RESPONSE|"+body, callerID);
        }
        else
        {
            // IGNORE!
        }
    }

}
