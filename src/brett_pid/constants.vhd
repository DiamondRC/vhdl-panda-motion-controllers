library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package global_constants is
    ---------------------------- PandA -----------------------------

    constant VEL_CONST         : natural := 125000000;
    constant PANDA_PORT_SIZE   : natural := 32;
    constant MASTER_CLK_PERIOD : time    := 8 ns; -- 125 MHz clk

    ---------------------------- Inputs ----------------------------

    constant DT_INT    : natural := 10 + 1;
    constant DT_FRAC   : natural := 21;     -- 5e-6 @ 10% error
    constant KP_I_INT  : natural := 10 + 1; -- includes signed
    constant KP_I_FRAC : natural := 21;
    constant KI_I_INT  : natural := 10 + 1; -- includes signed
    constant KI_I_FRAC : natural := 21;
    constant KD_I_INT  : natural := 10 + 1; -- includes signed
    constant KD_I_FRAC : natural := 21;

    ---------------------------- Misc ------------------------------

    constant DT_SIZE : natural := DT_INT + DT_FRAC;

    ---------------------------- Error -----------------------------

    constant POS_ERR_SIZE : natural := 32;

    ---------------------------- Velocity --------------------------

    constant VEL_SIZE : natural := 32 + 32;

    ---------------------------- P term ----------------------------

    constant KP_I_SIZE      : natural := KP_I_INT + KP_I_FRAC;
    constant P_MUL_SIZE     : natural := KP_I_SIZE + POS_ERR_SIZE;

    -- Pad the difference in fractional size to the result
    constant P_SCALED_WIDTH : natural := DT_FRAC - KP_I_FRAC;
    constant P_SCALED_SIZE  : natural := P_MUL_SIZE +
                                         P_SCALED_WIDTH;

    ---------------------------- V term ----------------------------

    constant V_SCALED_SIZE : natural := 1;

    ---------------------------- I term ----------------------------

    constant KI_I_SIZE      : natural := KI_I_INT + KI_I_FRAC;
    constant I_MUL_DT_SIZE  : natural := KI_I_SIZE + DT_SIZE;
    constant I_MUL_ERR_SIZE : natural := POS_ERR_SIZE + 
                                         I_MUL_DT_SIZE;
    constant I_SCA_PRT_SIZE : natural := KI_I_INT +
                                         POS_ERR_SIZE +
                                         DT_SIZE;

    -- Number of bits to assign to addition.
    -- Should fine tune.   
    constant I_ACCUM_BUFFER : natural := 8;   
    constant MAX_I_SIZE     : natural := PANDA_PORT_SIZE +
                                         DT_FRAC;
    constant I_SCALED_SIZE  : natural := I_ACCUM_BUFFER +
                                         I_SCA_PRT_SIZE;

    ---------------------------- D term ----------------------------

    constant KD_I_SIZE     : natural := KD_I_INT + KD_I_FRAC;
    constant D_SCALED_SIZE : natural := 1;

    ---------------------------- FF term ---------------------------

    constant FF_SCALED_SIZE : natural := 1;

    ---------------------------- Sum -------------------------------
    constant SUM_SCALED_SIZE : natural := P_SCALED_SIZE +
                                          V_SCALED_SIZE +
                                          I_SCALED_SIZE +
                                          D_SCALED_SIZE +
                                          FF_SCALED_SIZE;
    -- Remove global fraction  
    constant SUM_INT_SIZE : natural := SUM_SCALED_SIZE -
                                       DT_FRAC;

end package global_constants;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package global_subtypes is
    use work.global_constants.all;

    subtype panda_port is std_logic_vector(PANDA_PORT_SIZE - 1 downto 0);
end package global_subtypes;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package global_enums is

    type pid_state is (
        IDLE,
        STAGE_2,
        STAGE_3,
        STAGE_4,
        STAGE_5,
        STAGE_6,
        DONE
    );

end package global_enums;