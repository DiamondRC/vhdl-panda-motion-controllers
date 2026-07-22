--------------------------------------------------------------------------------
-- num_utils : integer / bit-width helper math.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package num_utils is

    type nat_array_t is array (natural range <>) of natural;

    function ceil_log2(n : natural) return natural;
    function max_nat(a : nat_array_t) return natural;
    function sum_signed_width(sizes : nat_array_t) return natural;

end package num_utils;



package body num_utils is

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

    -- Conservative worst-case width for the signed sum of N terms,
    -- widest term + ceil_log2(N) growth + 1 sign guard.
    function sum_signed_width(sizes : nat_array_t) return natural is
        variable max_width : natural := 0;
    begin
        for k in sizes'range loop
            if sizes(k) > max_width then
                max_width := sizes(k);
            end if;
        end loop;
        return max_width + ceil_log2(sizes'length) + 1;
    end function;

end package body num_utils;