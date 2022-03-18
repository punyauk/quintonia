vector  OFF = <0.522, 0.078, 0.294>;
vector  ON = <0.180, 0.800, 0.251>;
integer FACE = 1;

default
{
    state_entry()
    {
       llSetColor(OFF, FACE);
       llSetPrimitiveParams([PRIM_FULLBRIGHT, FACE, 0]);
    }
    
    on_rez(integer params)
    {
        llResetScript();
    }

    link_message(integer sender_num, integer num, string str, key id)
    {
        if (str == "ENDCOOKING")
        {
            // STOP
           llSetColor(OFF, FACE);
           llSetPrimitiveParams([PRIM_FULLBRIGHT, FACE, 0]);
        }
        else if (str == "STARTCOOKING")
        {
            // START
           llSetColor(ON, FACE);
           llSetPrimitiveParams([PRIM_FULLBRIGHT, FACE, 1]);
        }
    }
}
