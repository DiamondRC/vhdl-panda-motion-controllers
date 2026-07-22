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

    constant K_TOT_I_INT  : natural := 1 + 1; -- includes signed
    constant K_TOT_I_FRAC : natural := 30;

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

    ---------------------------- V term ----------------------------

    constant V_DES_SIZE      : natural := PANDA_PORT_SIZE;
    constant PREV_V_DES_SIZE : natural := V_DES_SIZE;

    constant KV_I_SIZE       : natural := KV_I_INT + KV_I_FRAC;
    constant VEL_SIZE        : natural := RI_NM_SIZE + DT_I_SIZE;
    constant V_MUL_SIZE      : natural := KV_I_SIZE + VEL_SIZE;
    constant V_SCA_FRAC      : natural := KV_I_FRAC + 
                                          DT_I_FRAC +
                                          DES_FRAC -
                                          MAX_FRAC;
    constant V_SCALED_SIZE   : natural := V_MUL_SIZE - V_SCA_FRAC;

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

    ---------------------------- FF term ---------------------------

    constant KVFF_I_SIZE     : natural := KVFF_I_INT + KVFF_I_FRAC;
    constant KAFF_I_SIZE     : natural := KAFF_I_INT + KAFF_I_FRAC;
    constant KP1FF_I_SIZE    : natural := KP1FF_I_INT + KP1FF_I_FRAC;
    constant KP0FF_I_SIZE    : natural := KP0FF_I_INT + KP0FF_I_FRAC;

    constant V_DES_CAL_SIZE  : natural := RI_NM_SIZE + DT_I_SIZE;

    constant V_DES_MUL_SIZE  : natural := KVFF_I_SIZE + V_DES_CAL_SIZE;
    constant V_FF_SCA_FRAC   : natural := KVFF_I_FRAC + 
                                          DT_I_FRAC +
                                          DES_FRAC -
                                          MAX_FRAC;
    constant V_DES_SCA_SIZE  : natural := V_DES_MUL_SIZE - V_FF_SCA_FRAC;

    constant A_DES_SUB_SIZE  : natural := V_DES_CAL_SIZE;
    constant A_DES_MUL_SIZE  : natural := KAFF_I_SIZE +
                                          A_DES_SUB_SIZE;
    constant A_SCA_FRAC      : natural := DES_FRAC + 
                                          KAFF_I_FRAC + 
                                          DT_I_FRAC -
                                          MAX_FRAC;
    constant A_DES_SCA_SIZE  : natural := A_DES_MUL_SIZE - A_SCA_FRAC;

    constant P1_DES_MUL_SIZE : natural := KP1FF_I_SIZE +
                                          RI_NM_SIZE;                                          
    constant P1_DES_SCA_FRAC : natural := KP1FF_I_FRAC +
                                          DES_FRAC -
                                          MAX_FRAC;
    constant P1_DES_SCA_SIZE : natural := P1_DES_MUL_SIZE -
                                          P1_DES_SCA_FRAC;
    
    constant P0_DES_ABS_SIZE : natural := KP0FF_I_SIZE +
                                          RI_NM_SIZE;
    constant P0_DES_MUL_SIZE : natural := P0_DES_ABS_SIZE + 
                                          RI_NM_SIZE;
    constant P0_DES_SCA_FRAC : natural := KP0FF_I_FRAC +
                                          DES_FRAC -
                                          MAX_FRAC;    
    constant P0_DES_SCA_SIZE : natural := P0_DES_MUL_SIZE;

    constant FF_SCALED_SIZE  : natural := 1;

    ---------------------------- Sum -------------------------------
    type natural_vector is array (natural range <>) of natural;
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
                                       MAX_FRAC;

    ---------------------------- Outputs ---------------------------

    constant K_TOT_I_SIZE     : natural := K_TOT_I_INT + K_TOT_I_FRAC;
    constant SCALE_MUL_SIZE   : natural := K_TOT_I_SIZE + 
                                           SUM_INT_SIZE;
    constant SCALE_OUT_SIZE   : natural := SCALE_MUL_SIZE - 
                                           K_TOT_I_FRAC;
    constant SCA_OUT_SCA_FRAC : natural := K_TOT_I_FRAC;
    constant MAX_OUT_SIZE     : natural := PANDA_PORT_SIZE +
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
        STAGE_8,
        STAGE_9,
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

---

package body fp_utils is
    -- function round_sym(
    --     s_in      : signed;
    --     FRAC_DIFF : natural;
    --     OUT_LEN   : natural
    -- ) return signed is
    --     variable v_round_const : signed(FRAC_DIFF downto 0);
    --     variable v_res         : signed(s_in'length downto 0);
    -- begin
    --     report "FRAC_DIFF is: " & natural'image(FRAC_DIFF) severity note;
    --     -- Place '0' in the MSB for pos and '1' for neg
    --     v_round_const := '0' & to_signed(2**(FRAC_DIFF-1) - 1, FRAC_DIFF);
    --     v_round_const(FRAC_DIFF-1) := not s_in(s_in'high); 

    --     -- Single adder path
    --     v_res := resize(s_in, v_res'length) + v_round_const;

    --     -- Shift and resize to output
    --     return resize(shift_right(v_res(s_in'length-1 downto 0), FRAC_DIFF), OUT_LEN);
    -- end function;

    function round_sym(
        s_in      : signed;
        FRAC_DIFF : natural;
        OUT_LEN   : natural
    ) return signed is
        variable v_round_const : signed(FRAC_DIFF downto 0);
        variable v_res         : signed(s_in'length downto 0);
    begin
        -- 1. Initialize to zero (all bits 0)
        v_round_const := (others => '0');
        
        -- 2. Set the bit at position FRAC_DIFF-1 to '1'
        -- This is equivalent to 2**(FRAC_DIFF-1)
        if FRAC_DIFF > 0 then
            v_round_const(FRAC_DIFF - 1) := '1';
        end if;

        -- 3. Adjust based on the sign of the input
        -- If positive, we might want to subtract 1 to handle the 'round to nearest' 
        -- logic correctly for symmetric rounding.
        if s_in(s_in'high) = '1' then
             -- For negative numbers, your logic differs; 
             -- ensure this matches your specific rounding requirement.
             v_round_const(FRAC_DIFF-1) := '0'; 
        end if;

        -- Single adder path
        v_res := resize(s_in, v_res'length) + v_round_const;

        -- Shift and resize to output
        return resize(shift_right(v_res(s_in'length-1 downto 0), FRAC_DIFF), OUT_LEN);
    end function;

    function pad_signed(
        s_in        : signed;
        PAD_BITS    : natural;
        OUT_LEN     : natural
    ) return signed is

    begin
        if PAD_BITS /= 0 then
            -- return resize(
            --     s_in &
            --     (PAD_BITS - 1 downto 0 => '0'),
            --     OUT_LEN
            -- );
            return shift_left(resize(s_in, OUT_LEN), PAD_BITS);
        else
            return resize(s_in, OUT_LEN);
        end if;
    end function;

end package body fp_utils;