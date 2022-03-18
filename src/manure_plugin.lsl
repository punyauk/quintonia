// manure_plugin.lsl
// Version 1.0  5 March 2022

float age = 3;                      // Life of each particle
float maxSpeed = 0.1;               // Max speed each particle is spit out at
float minSpeed = 0.1;               // Min speed each particle is spit out at
float startAlpha = 0.1;             // Start alpha (transparency) value
float endAlpha = 0.01;              // End alpha (transparency) value
vector startColor = <1,1,1>;        // Start color of particles <R,G,B>
vector endColor = <1,1,1>;          // End color of particles <R,G,B> (if interpColor == TRUE)
vector startSize = <0.5, 0.5, 1>;   // Start size of particles
vector endSize = <0.1, 0.1, 1>;     // End size of particles (if interpSize == TRUE)
vector push = <0, 0, 0.1>;          // Force pushed on particles
float rate = 0.1;                   // How fast (rate) to emit particles
float radius = 0.1;                 // Radius to emit particles for BURST pattern
integer count = 10;                 // How many particles to emit per BURST
float outerAngle = 1.54;            // Outer angle for all ANGLE patterns
float innerAngle = 1.55;            // Inner angle for all ANGLE patterns
vector omega = <0, 0, 10>;          // Rotation of ANGLE patterns around the source
float life = 0;                     // Life in seconds for the system to make particles


default
{

    state_entry()
    {
        integer flags;
        flags = 0;
        flags = flags | PSYS_PART_EMISSIVE_MASK;
        flags = flags | PSYS_PART_BOUNCE_MASK;
        flags = flags | PSYS_PART_INTERP_COLOR_MASK;
        flags = flags | PSYS_PART_INTERP_SCALE_MASK;
        flags = flags | PSYS_PART_FOLLOW_SRC_MASK;
        flags = flags | PSYS_PART_FOLLOW_VELOCITY_MASK;

         llLinkParticleSystem(2, [
                        PSYS_PART_MAX_AGE,age,
                        PSYS_PART_FLAGS,flags,
                        PSYS_PART_START_COLOR, startColor,
                        PSYS_PART_END_COLOR, endColor,
                        PSYS_PART_START_SCALE,startSize,
                        PSYS_PART_END_SCALE,endSize,
                        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
                        PSYS_SRC_BURST_RATE,rate,
                        PSYS_SRC_ACCEL, push,
                        PSYS_SRC_BURST_PART_COUNT,count,
                        PSYS_SRC_BURST_RADIUS,radius,
                        PSYS_SRC_BURST_SPEED_MIN,minSpeed,
                        PSYS_SRC_BURST_SPEED_MAX,maxSpeed,
                        PSYS_SRC_TARGET_KEY,"",
                        PSYS_SRC_INNERANGLE,innerAngle,
                        PSYS_SRC_OUTERANGLE,outerAngle,
                        PSYS_SRC_OMEGA, omega,
                        PSYS_SRC_MAX_AGE, life,
                        PSYS_SRC_TEXTURE, "fx",
                        PSYS_PART_START_ALPHA, startAlpha,
                        PSYS_PART_END_ALPHA, endAlpha
                        ]);
    }

    dataserver(key kk, string m)
    {
        list tk = llParseStringKeepNulls(m , ["|"], []);
        string cmd = llList2String(tk,0);
        if (cmd == "MANUINIT")
        {
            //  MANUINIT|PASSWORD|SURFACE|NAME
            string prodName = llList2String(tk, 3);
            if (prodName != "") llSetObjectName(prodName);
            if (llToLower(llList2String(tk, 2)) == "ground")
            {
                vector vTarget = llGetPos();
                vTarget.z = llGround(ZERO_VECTOR);
                llSetRegionPos(vTarget);
            }
        }
    }


}
