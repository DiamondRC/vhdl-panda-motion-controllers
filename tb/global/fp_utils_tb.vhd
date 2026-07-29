--------------------------------------------------------------------------------
--  File:   fp_utils_tb.vhd
--  Desc:   Standalone checks for fixed-point utilies.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

use work.num_utils.all;
use work.fp_utils.all;


entity fp_utils_td is
end entity fp_utils_td;

architecture rtl of fp_utils_td is
    -- Test items
    signal fail : std_logic := '0';

    -- Test helpers
    function sv(v : integer; w : natural) return signed is
        -- Build a signed input concisely.
    begin
        return to_signed(v, w);
    end function;

    function as_real(code : signed; frac : natural) return real is
        -- Render a raw code at Q(.frac) as a real
        -- (Makes visualisation/life easier.)
    begin
        return to_real (
            to_sfixed (
                std_logic_vector(code),
                code'length - 1 - frac, -frac
            )
        );
    end function;

    -- Test definitions
    procedure check (
        -- Requantise raw Q in_frac down to Q out_frac.
        constant name     : in    string;
        constant raw      : in    signed;
        constant in_frac  : in    natural;
        constant out_frac : in    natural;
        constant mode     : in    round_mode;
        constant exp      : in    signed;
        variable fail_o   : inout std_logic
    ) is
        variable got : signed(exp'length - 1 downto 0);
    begin
        got := requantize(raw, in_frac - out_frac, exp'length, mode);

        if got /= exp then
            fail_o := '1';
            report name &
                ": in " & real'image(as_real(raw, in_frac)) &
                " got " & real'image(as_real(got, out_frac)) &
                ", expected " & real'image(as_real(exp, out_frac))
            severity error;
        end if;
    end procedure;

    procedure sat_check (
        -- Clamp-only check for saturate.
        constant name   : in    string;
        constant s_in   : in    signed;
        constant exp    : in    signed;
        variable fail_o : inout std_logic
    ) is
        variable got : signed(exp'length - 1 downto 0);
    begin
        got := saturate(s_in, exp'length);

        if got /= exp then
            fail_o := '1';
            report name &
                ": got " & integer'image(to_integer(got)) &
                ", expected " & integer'image(to_integer(exp))
            severity error;
        end if;
    end procedure;

begin

    stim : process
        variable failed : std_logic := '0';
    begin
        -- Round half away from zero (Q?.4 -> integer, 8-bit out)
        check("away  0.5", sv(  8, 12), 4, 0, HALF_AWAY, sv( 1, 8), failed);
        check("away -0.5", sv( -8, 12), 4, 0, HALF_AWAY, sv(-1, 8), failed);
        check("away  1.5", sv( 24, 12), 4, 0, HALF_AWAY, sv( 2, 8), failed);
        check("away -1.5", sv(-24, 12), 4, 0, HALF_AWAY, sv(-2, 8), failed);
        check("away  2.5", sv( 40, 12), 4, 0, HALF_AWAY, sv( 3, 8), failed);
        check("away .437", sv(  7, 12), 4, 0, HALF_AWAY, sv( 0, 8), failed);
        check("away .687", sv( 11, 12), 4, 0, HALF_AWAY, sv( 1, 8), failed);

        -- Round half to even (ties break to the even neighbour)
        check("even  0.5", sv(  8, 12), 4, 0, HALF_EVEN, sv( 0, 8), failed);
        check("even  1.5", sv( 24, 12), 4, 0, HALF_EVEN, sv( 2, 8), failed);
        check("even  2.5", sv( 40, 12), 4, 0, HALF_EVEN, sv( 2, 8), failed);
        check("even  3.5", sv( 56, 12), 4, 0, HALF_EVEN, sv( 4, 8), failed);
        check("even -0.5", sv( -8, 12), 4, 0, HALF_EVEN, sv( 0, 8), failed);
        check("even -1.5", sv(-24, 12), 4, 0, HALF_EVEN, sv(-2, 8), failed);
        check("even -2.5", sv(-40, 12), 4, 0, HALF_EVEN, sv(-2, 8), failed);
        check("even .750", sv( 12, 12), 4, 0, HALF_EVEN, sv( 1, 8), failed);

        -- Saturation (4-bit out => codes [-8, 7])
        check("sat  12.5", sv( 200, 12), 4, 0, HALF_AWAY, sv( 7, 4), failed);
        check("sat -12.5", sv(-200, 12), 4, 0, HALF_AWAY, sv(-8, 4), failed);
        check("sat   7.5", sv( 120, 12), 4, 0, HALF_AWAY, sv( 7, 4), failed);
        check("sat  -8.5", sv(-136, 12), 4, 0, HALF_AWAY, sv(-8, 4), failed);
        check("sat   7.0", sv( 112, 12), 4, 0, HALF_AWAY, sv( 7, 4), failed);
        check("sat  -8.0", sv(-128, 12), 4, 0, HALF_AWAY, sv(-8, 4), failed);

        -- Passthrough FRAC_DIFF = 0 still saturates
        check("pass  5.0", sv( 20, 8), 2, 2, HALF_AWAY, sv(20, 8), failed);
        check("pass clmp+", sv( 20, 8), 2, 2, HALF_AWAY, sv( 7, 4), failed);
        check("pass clmp-", sv(-20, 8), 2, 2, HALF_AWAY, sv(-8, 4), failed);

        -- Lone saturate()
        sat_check("clamp hi", sv( 300, 16), sv( 127, 8), failed);
        sat_check("clamp lo", sv(-300, 16), sv(-128, 8), failed);
        sat_check("in range", sv(  50, 16), sv(  50, 8), failed);
        sat_check("edge hi",  sv( 127, 16), sv( 127, 8), failed);
        sat_check("over hi",  sv( 128, 16), sv( 127, 8), failed);
        sat_check("edge lo",  sv(-128, 16), sv(-128, 8), failed);

        -- Report the overall result
        fail <= failed;
        if failed = '0' then
            report "FP UTILS TESTS PASS" severity note;
        else
            report "FP UTILS TESTS FAILED" severity failure;
        end if;

        wait;
    end process;

end architecture rtl;
