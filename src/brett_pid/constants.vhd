library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package global_constants is
    ---------------------------- PandA -----------------------------

    -- constant VEL_CONST         : natural := 125000000;
    constant PANDA_PORT_SIZE   : natural := 32;
    constant MASTER_CLK_PERIOD : time    := 8 ns; -- 125 MHz clk

    ---------------------------- Inputs ----------------------------

    constant DT_INT       : natural := 6 + 1;
    constant DT_FRAC      : natural := 25;
    constant DT_I_INT     : natural := 22 + 1;
    constant DT_I_FRAC    : natural := 9;

    constant KP_I_INT     : natural := 6 + 1; -- includes signed
    constant KP_I_FRAC    : natural := 25;
    constant KV_I_INT     : natural := 6 + 1; -- includes signed
    constant KV_I_FRAC    : natural := 25;
    constant KI_I_INT     : natural := 6 + 1; -- includes signed
    constant KI_I_FRAC    : natural := 25;
    constant KD_I_INT     : natural := 6 + 1; -- includes signed
    constant KD_I_FRAC    : natural := 25;

    constant KVFF_I_INT   : natural := 6 + 1; -- includes signed
    constant KVFF_I_FRAC  : natural := 25;
    constant KAFF_I_INT   : natural := 11 + 1; -- includes signed
    constant KAFF_I_FRAC  : natural := 20;
    constant KP1FF_I_INT  : natural := 6 + 1; -- includes signed
    constant KP1FF_I_FRAC : natural := 25;
    constant KP0FF_I_INT  : natural := 6 + 1; -- includes signed
    constant KP0FF_I_FRAC : natural := 25;

    -- unfortunately must duplicate, fragile
    type nat_array_t is array (natural range <>) of natural;
    constant frac_widths  : nat_array_t := (
        DT_FRAC,
        DT_I_FRAC,
        KP_I_FRAC,
        KV_I_FRAC,
        KI_I_FRAC,
        KD_I_FRAC,
        KVFF_I_FRAC,
        KAFF_I_FRAC,
        KP1FF_I_FRAC,
        KP0FF_I_FRAC
    );

    function max_nat(a    : nat_array_t) return natural;

    constant MAX_FRAC     : natural := max_nat(frac_widths);

    ---------------------------- DT ------------------------------

    constant DT_SIZE   : natural := DT_INT + DT_FRAC;
    constant DT_I_SIZE : natural := DT_I_INT + DT_I_FRAC;

    ---------------------------- Error -----------------------------

    constant POS_ERR_SIZE : natural := 32;
    constant D_ERR_SIZE   : natural := POS_ERR_SIZE;

    ---------------------------- P term ----------------------------

    constant KP_I_SIZE      : natural := KP_I_INT + KP_I_FRAC;
    constant P_MUL_SIZE     : natural := KP_I_SIZE + POS_ERR_SIZE;

    -- Pad the difference in fractional size to the result
    constant P_SCALED_WIDTH : natural := DT_FRAC - KP_I_FRAC;
    constant P_SCALED_SIZE  : natural := P_MUL_SIZE +
                                         P_SCALED_WIDTH;

    ---------------------------- V term ----------------------------

    constant V_DES_SIZE      : natural := PANDA_PORT_SIZE;
    constant PREV_V_DES_SIZE : natural := V_DES_SIZE;

    constant KV_I_SIZE       : natural := KV_I_INT + KV_I_FRAC;
    constant VEL_SIZE        : natural := PANDA_PORT_SIZE + DT_I_SIZE;
    constant V_MUL_SIZE      : natural := KV_I_SIZE + VEL_SIZE;
    constant V_SCALED_SIZE   : natural := V_MUL_SIZE - DT_I_FRAC;
    constant V_SCA_FRAC      : natural := KV_I_FRAC + 
                                          DT_I_FRAC -
                                          MAX_FRAC;

    ---------------------------- I term ----------------------------

    constant KI_I_SIZE      : natural := KI_I_INT + KI_I_FRAC;
    constant I_MUL_DT_SIZE  : natural := KI_I_SIZE + DT_SIZE;
    constant I_MUL_ERR_SIZE : natural := POS_ERR_SIZE + 
                                         I_MUL_DT_SIZE;
    constant I_SCA_PRT_SIZE : natural := KI_I_SIZE + POS_ERR_SIZE;

    -- Number of bits to assign to addition.
    -- Should fine tune.   
    constant I_ACCUM_BUFFER : natural := 8;   
    constant MAX_I_SIZE     : natural := PANDA_PORT_SIZE +
                                         DT_FRAC;
    constant I_SCALED_SIZE  : natural := I_ACCUM_BUFFER +
                                         I_SCA_PRT_SIZE;
    constant I_SCA_FRAC     : natural := DT_FRAC + 
                                         KI_I_FRAC -
                                         MAX_FRAC;

    ---------------------------- D term ----------------------------

    constant KD_I_SIZE      : natural := KD_I_INT + KD_I_FRAC;
    constant D_MUL_DT_SIZE  : natural := KD_I_SIZE + DT_I_SIZE;
    constant D_MUL_ERR_SIZE : natural := D_MUL_DT_SIZE + D_ERR_SIZE;
    constant D_SCALED_SIZE  : natural := D_MUL_ERR_SIZE - DT_I_FRAC;
    constant D_SCA_FRAC     : natural := DT_I_FRAC + 
                                         KD_I_FRAC -
                                         MAX_FRAC;

    ---------------------------- FF term ---------------------------

    constant KVFF_I_SIZE     : natural := KVFF_I_INT + KVFF_I_FRAC;
    constant KAFF_I_SIZE     : natural := KAFF_I_INT + KAFF_I_FRAC;
    constant KP1FF_I_SIZE    : natural := KP1FF_I_INT + KP1FF_I_FRAC;
    constant KP0FF_I_SIZE    : natural := KP0FF_I_INT + KP0FF_I_FRAC;

    constant V_DES_CAL_SIZE  : natural := PANDA_PORT_SIZE + DT_I_SIZE;

    constant V_DES_MUL_SIZE  : natural := KVFF_I_SIZE + V_DES_CAL_SIZE;
    constant V_DES_SCA_SIZE  : natural := V_DES_MUL_SIZE - DT_I_SIZE;
    constant V_FF_SCA_FRAC   : natural := KVFF_I_FRAC + 
                                          DT_I_FRAC -
                                          MAX_FRAC;

    constant A_DES_SUB_SIZE  : natural := V_DES_CAL_SIZE;
    constant A_DES_MUL_SIZE  : natural := KAFF_I_SIZE +
                                          A_DES_SUB_SIZE;
    constant A_DES_SCA_SIZE  : natural := A_DES_MUL_SIZE - DT_I_SIZE;
    constant A_SCA_FRAC      : natural := KAFF_I_FRAC + 
                                          DT_I_FRAC -
                                          MAX_FRAC;

    constant P1_DES_MUL_SIZE : natural := KP1FF_I_SIZE +
                                          PANDA_PORT_SIZE;
    constant P1_DES_SCA_SIZE : natural := P1_DES_MUL_SIZE;  
    
    constant P0_DES_ABS_SIZE : natural := KP0FF_I_SIZE +
                                          PANDA_PORT_SIZE;
    constant P0_DES_MUL_SIZE : natural := P0_DES_ABS_SIZE + 
                                          PANDA_PORT_SIZE;
    constant P0_DES_SCA_SIZE : natural := P0_DES_MUL_SIZE;

    constant FF_SCALED_SIZE  : natural := 1;

    ---------------------------- Sum -------------------------------
    type natural_vector is array (natural range <>) of natural;
    function ceil_log2(n : natural) return natural;
    function sum_signed_width(sizes : natural_vector) return natural;

    constant widths : natural_vector(0 to 7) := (
        P_SCALED_SIZE,
        V_SCALED_SIZE,
        I_SCALED_SIZE,
        D_SCALED_SIZE,
        V_DES_SCA_SIZE,
        A_DES_SCA_SIZE,
        P0_DES_SCA_SIZE,
        P1_DES_SCA_SIZE
    );
    constant SUM_SCALED_SIZE : natural := sum_signed_width(widths);

    -- Remove global fraction  
    constant SUM_INT_SIZE : natural := SUM_SCALED_SIZE -
                                       DT_FRAC;

end package global_constants;


package body global_constants is

    function ceil_log2(n : natural) return natural is
        variable v : natural := n - 1;
        variable r : natural := 0;
    begin
        while v > 0 loop
            v := v / 2;
            r := r + 1;
        end loop;
        return r;
    end function;

    function sum_signed_width(sizes : natural_vector) return natural is
        variable max_width : natural := 0;
        variable acc_width  : natural := 0;
        begin
            for k in sizes'range loop
                if sizes(k) > max_width then
                    max_width := sizes(k);
                end if;
            end loop;

            -- conservative estimate
            return max_width + ceil_log2(sizes'length) + 1;

    end function;

    function max_nat(a : nat_array_t) return natural is
        variable m : natural := a(a'low);
        begin
            for i in a'range loop
                if a(i) > m then
                    m := a(i);
                end if;
            end loop;

            return m;

    end function;

end package body global_constants;




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