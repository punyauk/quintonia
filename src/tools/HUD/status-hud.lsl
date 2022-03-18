// --------------------------------------------------
//  QUINTONIA FARM HUD - Indicator
//   status-hud.lsl
// --------------------------------------------------
// Optional item to wear so others can see your status info
float VERSION = 5.3;        //  17 March 2022

// Set the next depending upon if for avatar or baby
string NAME = "SFQ Status-HUD";
//string NAME = "BabyStatusHUD";

integer DEBUGMODE = TRUE;
debug(string text)
{
    if (DEBUGMODE == TRUE) llOwnerSay("DEBUG:\n" + llToUpper(llGetScriptName()) + " " + text +"\n");
}

integer FARM_CHANNEL = -911201;
integer listenerFarm;
string  PASSWORD = "*";
key     hudKey;
key     ownerID;
float   textAlpha = 1.0;
integer dirty;
integer visible;
//string  rainPrim = "prim_rain";
//vector  rainSize = <50.00000, 50.00000, 35.97878>;
//integer rainTs = -1;
//string  brollyPrim = "umbrella";
//vector  brollySize = <1.26326, 1.10766, 1.26326>;

integer getLinkNum(string name)
{
    integer i;
    for (i=1; i <=llGetNumberOfPrims(); i++)
        if (llGetLinkName(i) == name) return i;
    return -1;
}

particles(integer intensity, key k, string texture, string sound)
{
    if (intensity <1) intensity = 1;
    if (intensity > 0) llLoopSound(sound, 0.5); else llStopSound();
     llParticleSystem(
                [
                    // PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_ANGLE,
                    PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_ANGLE_CONE,
                    PSYS_SRC_BURST_RADIUS,1,
                    PSYS_SRC_ANGLE_BEGIN,PI/2,
                    PSYS_SRC_ANGLE_END,PI/2+.3,
                    PSYS_SRC_TARGET_KEY, (key) k,
                    PSYS_PART_START_COLOR,<1.000000,1.00000,0.800000>,
                    PSYS_PART_END_COLOR,<1.000000,1.00000,0.800000>,

                    PSYS_PART_START_ALPHA,1.,
                    PSYS_PART_END_ALPHA,0.3,
                    PSYS_PART_START_GLOW,0,
                    PSYS_PART_END_GLOW,0,
                    PSYS_PART_BLEND_FUNC_SOURCE,PSYS_PART_BF_SOURCE_ALPHA,
                    PSYS_PART_BLEND_FUNC_DEST,PSYS_PART_BF_ONE_MINUS_SOURCE_ALPHA,

                    PSYS_PART_START_SCALE,<0.070000,0.070000,0.000000>,
                    PSYS_PART_END_SCALE,<.0700000,.07000000,0.000000>,
                    PSYS_SRC_TEXTURE,texture,
                    PSYS_SRC_MAX_AGE,0,
                    PSYS_PART_MAX_AGE,3,
                    PSYS_SRC_BURST_RATE, 1.0,
                    PSYS_SRC_BURST_PART_COUNT, intensity,
                    PSYS_SRC_ACCEL,<0.000000,0.000000,.5000000>,
                    PSYS_SRC_OMEGA,<0.000000,0.000000,2.000000>,
                    PSYS_SRC_BURST_SPEED_MIN, .1,
                    PSYS_SRC_BURST_SPEED_MAX, 2,
                    PSYS_PART_FLAGS,
                        0 |
                        PSYS_PART_EMISSIVE_MASK |
                        PSYS_PART_TARGET_POS_MASK|
                        PSYS_PART_INTERP_COLOR_MASK |PSYS_PART_WIND_MASK |
                        PSYS_PART_INTERP_SCALE_MASK |
                        PSYS_PART_FOLLOW_VELOCITY_MASK
                ]);

}

showText(string msg, vector colour)
{
    if (visible == TRUE) llSetText(msg, colour, textAlpha); else llSetText("", ZERO_VECTOR, 0.0);
}

setAlpha()
{
    if (visible == FALSE)
    {
        llSetPrimitiveParams([ PRIM_TEXT, "", ZERO_VECTOR, 0.0,
                               PRIM_GLOW, ALL_SIDES, 0.0]);
        llSetAlpha(0.0, ALL_SIDES);
    }
    else
    {
        llSetPrimitiveParams([ PRIM_TEXT, "|", <1,1,1>, 1.0,
                               PRIM_GLOW, ALL_SIDES, 0.1]);
        llSetAlpha(1.0, ALL_SIDES);
    }
}

default
{
    on_rez(integer start_param)
    {
        llResetScript();
    }

    state_entry()
    {
        llSetObjectName(NAME);
        key hudKey = NULL_KEY;
        ownerID = llGetOwner();
        showText("...", <1,1,1>);
        llStopSound();
        llParticleSystem([]);
        dirty = FALSE;
        listenerFarm = llListen(FARM_CHANNEL, "", "", "");
        llSetTimerEvent(30);
    }

    listen(integer channel, string name, key id, string msg)
    {
        debug("listen: " + msg);
        list tk = llParseStringKeepNulls(msg, ["|"], []);
        string cmd = llList2String(tk, 0);
        if ((cmd == "PING") && (llList2String(tk, 2) == "QSFHUD") && (llList2Key(tk, 3) == llGetOwner()))
        {
            if (hudKey != id)
            {
                PASSWORD = llList2String(tk, 1);
                showText("---", <1,1,1>);
                llSay(FARM_CHANNEL, "INDICATOR_INIT|" + (string)llGetOwner());
                showText("..   ..", <1,1,1>);
            }
        }
    }

    touch_end(integer index)
    {
        if (llDetectedKey(0) == ownerID)
        {
            llRegionSay(FARM_CHANNEL, "INDICATOR_HELLO|"+PASSWORD+"|"+(string)llGetKey());
        }
    }

    dataserver(key query_id, string msg)
    {
        list tk = llParseStringKeepNulls(msg, ["|"], []);
        string cmd = llList2String(tk, 0);
        debug("dataserver: " + msg + "  (cmd=" +cmd +")");
        if (cmd == "INIT")
        {
            PASSWORD = llList2String(tk, 1);
            hudKey = llList2Key(tk, 2);
            llListenRemove(listenerFarm);
            llSetText("",ZERO_VECTOR,0.0);
            llSetColor(<1,1,1>, ALL_SIDES);
            setAlpha();
        }
        else
        {
            // Check password okay
            if (llList2String(tk, 1) == PASSWORD)
            {
                if (cmd == "TEXT")
                {
                    showText(llList2String(tk,2), llList2Vector(tk, 3));
                    llSetColor(llList2Vector(tk, 3), ALL_SIDES);
                }
                else if (cmd == "DIRTY")
                {
                    particles(llList2Integer(tk,2), llGetOwner(), "fly", "flies");
                    dirty = TRUE;
                }
                else if (cmd == "CLEAN")
                {
                    llParticleSystem([]);
                    llStopSound();
                    dirty = FALSE;
                }
                else if (cmd == "BURSTING")
                {
                    particles(llList2Integer(tk,2), llGetOwner(), "mist", "anxiety");
                }
                else if (cmd == "RELIEVED")
                {
                    llParticleSystem([]);
                    if (dirty == TRUE) particles(1, llGetOwner(), "fly", "flies");
                }
                else if (cmd == "OFF")
                {
                    llParticleSystem([]);
                    llStopSound();
                    llSetText("", ZERO_VECTOR, 0.0);
                    llSetAlpha(0.0, ALL_SIDES);
                    hudKey = NULL_KEY;
                }
                else if (cmd == "VISIBILITY")
                {
                    visible = llList2Integer(tk, 2);
                    setAlpha();
                }
            }
        }
    }

    timer()
    {
        if (hudKey != NULL_KEY)
        {
            if (llGetListLength(llGetObjectDetails(hudKey, [OBJECT_NAME])) == 0)
            {
                hudKey = NULL_KEY;
            }
        }
        else
        {
            showText(" ", <1,1,1>);
            if (visible == TRUE) llSetAlpha(0.5, ALL_SIDES); else llSetAlpha(0.0, ALL_SIDES);
            llStopSound();
            llParticleSystem([]);
            listenerFarm = llListen(FARM_CHANNEL, "", "", "");
        }
    }

        link_message(integer sender_num, integer num, string msg, key id)
        {
             debug("link_message:" +msg +"  num="+(string)num);
            list tk = llParseStringKeepNulls(msg , ["|"], []);
            string cmd = llList2String(tk, 0);
            if (cmd == "VERSION-REQUEST")
            {
                llMessageLinked(LINK_SET, (integer)(10*VERSION), "VERSION-REPLY|"+NAME, "");
            }
        }

}
