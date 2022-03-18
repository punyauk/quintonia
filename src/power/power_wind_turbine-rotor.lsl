// power_wind_turbine-rotor.lsl

float vel = 1.0;
vector rotDir = <0,1,0>;

default
{
    state_entry()
    {
       llTargetOmega(rotDir, vel, 1.0);
    }

    link_message(integer sender_num, integer num, string str, key id)
    {
        if (str == "VELOCITY")
        {
            vel = (num * 5);
            vel = vel / 100;
            llTargetOmega(rotDir, vel, 1.0);
        }
        else if (str == "DIR")
        {
            if (num == 1) rotDir = <0,1,0>; else rotDir = <0,-1,0>;
            llTargetOmega(rotDir, vel, 1.0);
        }
    }
}
