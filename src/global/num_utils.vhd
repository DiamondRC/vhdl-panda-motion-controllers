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
    function num_chunks(W : natural; P : natural) return natural;
    function max_s(w : natural) return signed;
    function min_s(w : natural) return signed;

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


    -- Number of =< P-bit DSP chunks a W-bit signed operand requires.
    function num_chunks(W : natural; P : natural) return natural is
        --
    begin
        if W <= P then
            return 1;
        else
            -- (W - 2)/(P - 1) = ceil((W - P)/(P - 1))
            return 1 + (W - 2) / (P - 1);
        end if;
    
    end function;


    -- Largest positive value of a w-bit signed (0 followed by ones).
    function max_s(w : natural) return signed is
        variable r : signed(w - 1 downto 0) := (others => '1');
    begin
        r(w - 1) := '0';
        return r;
    end function;


    -- Most negative value of a w-bit signed (1 followed by zeros).
    function min_s(w : natural) return signed is
        variable r : signed(w - 1 downto 0) := (others => '0');
    begin
        r(w - 1) := '1';
        return r;
    end function;

end package body num_utils;