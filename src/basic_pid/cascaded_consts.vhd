library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package global_constants is

    function ceil_log2(n : natural) return natural;

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
    constant KI_I_INT     : natural := 6 + 1; -- includes signed
    constant KI_I_FRAC    : natural := 25;
    constant KD_I_INT     : natural := 6 + 1; -- includes signed
    constant KD_I_FRAC    : natural := 25;

    -- unfortunately must duplicate, fragile
    type nat_array_t is array (natural range <>) of natural;
    constant frac_widths  : nat_array_t := (
        DT_FRAC,
        DT_I_FRAC,
        KP_I_FRAC,
        KI_I_FRAC,
        KD_I_FRAC,
    );

    function max_nat(a    : nat_array_t) return natural;

    constant MAX_FRAC     : natural := max_nat(frac_widths);

    --------------------- Input Conversion ----------------------

    -- constant PV_FRAC       : natural := 10; -- 0.05% err
    constant PV_FRAC       : natural := 15; -- 0.05% err
    constant DES_FRAC      : natural := 10;
    constant PV_SCALE      : natural := natural(0.256 * real(2**PV_FRAC));
    constant PV_SCALE_SIZE : natural := ceil_log2(PV_SCALE) + 1;
    constant PM_MUL_SIZE   : natural := PANDA_PORT_SIZE + PV_SCALE_SIZE;
    constant PM_SCA_FRAC   : natural := PV_FRAC -
                                        DES_FRAC;
    constant RI_NM_SIZE    : natural := PM_MUL_SIZE - PM_SCA_FRAC;

    ---------------------------- DT ------------------------------

    constant DT_SIZE   : natural := DT_INT + DT_FRAC;
    constant DT_I_SIZE : natural := DT_I_INT + DT_I_FRAC;

    ---------------------------- Error -----------------------------

    constant POS_ERR_SIZE : natural := RI_NM_SIZE;
    constant D_ERR_SIZE   : natural := POS_ERR_SIZE;

    ---------------------------- P term ----------------------------

    constant KP_I_SIZE      : natural := KP_I_INT + KP_I_FRAC;
    constant P_MUL_SIZE     : natural := KP_I_SIZE + POS_ERR_SIZE;

    constant P_SCA_FRAC     : natural := KP_I_FRAC +
                                         DES_FRAC -
                                         MAX_FRAC;
    constant P_SCALED_SIZE  : natural := P_MUL_SIZE -
                                         P_SCA_FRAC;

    ---------------------------- I term ----------------------------

    constant KI_I_SIZE      : natural := KI_I_INT + KI_I_FRAC;
    constant I_MUL_DT_SIZE  : natural := KI_I_SIZE + DT_SIZE;
    constant I_MUL_ERR_SIZE : natural := POS_ERR_SIZE + 
                                         I_MUL_DT_SIZE;
    constant I_SCA_FRAC     : natural := DT_FRAC + 
                                         KI_I_FRAC +
                                         DES_FRAC -
                                         MAX_FRAC;
    constant I_SCA_PRT_SIZE : natural := I_MUL_ERR_SIZE - I_SCA_FRAC;

    -- Number of bits to assign to addition.
    -- Should fine tune.   
    constant I_ACCUM_BUFFER : natural := 8;   
    constant I_SCALED_SIZE  : natural := I_ACCUM_BUFFER +
                                         I_SCA_PRT_SIZE;
    constant MAX_I_SIZE     : natural := PANDA_PORT_SIZE +
                                         MAX_FRAC;

    ---------------------------- D term ----------------------------

    constant KD_I_SIZE      : natural := KD_I_INT + KD_I_FRAC;
    constant D_MUL_DT_SIZE  : natural := KD_I_SIZE + DT_I_SIZE;
    constant D_MUL_ERR_SIZE : natural := D_MUL_DT_SIZE + D_ERR_SIZE;
    constant D_SCA_FRAC     : natural := DT_I_FRAC + 
                                         KD_I_FRAC -
                                         MAX_FRAC;
    constant D_SCALED_SIZE  : natural := D_MUL_ERR_SIZE - D_SCA_FRAC;

    ---------------------------- Sum -------------------------------
    type natural_vector is array (natural range <>) of natural;
    function sum_signed_width(sizes : natural_vector) return natural;

    constant widths : natural_vector(0 to 7) := (
        P_SCALED_SIZE,
        I_SCALED_SIZE,
        D_SCALED_SIZE,
    );
    constant SUM_SCALED_SIZE : natural := sum_signed_width(widths);

    -- Remove global fraction  
    constant SUM_INT_SIZE : natural := SUM_SCALED_SIZE -
                                       MAX_FRAC;



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
        INITIAL,
        STAGE_2,
        STAGE_3,
        STAGE_4,
        STAGE_5,
        STAGE_6,
        STAGE_7,
        DONE
    );

end package global_enums;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fp_utils is
    -- Signature
    function round_sym(
        s_in        : signed;
        FRAC_DIFF   : natural;
        OUT_LEN     : natural
    ) return signed;

    function pad_signed(
        s_in        : signed;
        PAD_BITS    : natural;
        OUT_LEN     : natural
    ) return signed;
end package fp_utils;

package body fp_utils is
    -- Bodies
    function round_sym(
        s_in      : signed;
        FRAC_DIFF : natural;
        OUT_LEN   : natural
    ) return signed is
        variable v_round_const : signed(FRAC_DIFF downto 0);
        variable v_res         : signed(s_in'length downto 0);
    begin
        v_round_const := (others => '0');
        
        if FRAC_DIFF > 0 then
            v_round_const(FRAC_DIFF - 1) := '1';
        end if;

        if s_in(s_in'high) = '1' then
             v_round_const(FRAC_DIFF-1) := '0'; 
        end if;

        v_res := resize(s_in, v_res'length) + v_round_const;

        return resize(shift_right(v_res(s_in'length-1 downto 0), FRAC_DIFF), OUT_LEN);
    end function;

    function pad_signed(
        s_in        : signed;
        PAD_BITS    : natural;
        OUT_LEN     : natural
    ) return signed is

    begin
        if PAD_BITS /= 0 then
            return shift_left(resize(s_in, OUT_LEN), PAD_BITS);
        else
            return resize(s_in, OUT_LEN);
        end if;
    end function;

end package body fp_utils;