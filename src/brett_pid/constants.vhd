library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package global_constants is
    ---------------------------- PandA -----------------------------

    constant VEL_CONST : natural := 125000000;
    constant PANDA_PORT_SIZE : natural := 32;

    ---------------------------- Inputs ----------------------------

    constant KP_I_INT : natural := 10 + 1; -- includes signed
    constant KP_I_FRAC : natural := 21;

    ---------------------------- Misc ------------------------------

    constant MAX_FRAC_SIZE : natural := 25;

    ---------------------------- Error -----------------------------

    constant POS_ERR_SIZE : natural := 32;

    ---------------------------- Velocity --------------------------

    constant VEL_SIZE : natural := 32 + 32;

    ---------------------------- P term ----------------------------

    constant KP_I_SIZE : natural := KP_I_INT + KP_I_FRAC;
    constant P_MUL_SIZE : natural := KP_I_SIZE + POS_ERR_SIZE;
    -- Pad the difference in fractional size to the result
    constant P_SCALED_WIDTH : natural := MAX_FRAC_SIZE - KP_I_FRAC;
    constant P_SCALED_SIZE : natural := P_MUL_SIZE + P_SCALED_WIDTH;

    ---------------------------- V term ----------------------------

    constant V_SCALED_SIZE : natural := 1;

    ---------------------------- I term ----------------------------

    constant I_SCALED_SIZE : natural := 1;

    ---------------------------- D term ----------------------------

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
                                       MAX_FRAC_SIZE;

end package global_constants;

package global_subtypes is
    use work.global_constants.all;

    subtype panda_port is std_logic_vector(PANDA_PORT_SIZE - 1 downto 0);
end package global_subtypes;

package global_enums is
    type pid_state is (
        IDLE,
        STAGE_2,
        STAGE_3,
        STAGE_4,
        DONE
    );

end package global_enums;