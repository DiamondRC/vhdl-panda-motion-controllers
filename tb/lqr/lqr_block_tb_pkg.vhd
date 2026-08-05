--------------------------------------------------------------------------------
--  File:   lqr_block_tb_pkg.vhd
--  Desc:   Shared items for the LQR block TBs (register + DMA variants).
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.matrix_consts.all;
use work.num_utils.all;
use work.lqr_consts.all;
use work.cond_consts.all;

package lqr_block_tb_pkg is

    -- Block shape
    constant AXES : positive := 3;
    constant M : positive := 3;
    constant N : positive := cond_width(AXES, true, false, false); -- no velocity
    constant NI : positive := n_int(N, M, 0, true, true, false);
    constant GAIN_CNT : positive := M * NI;
    constant INTER_SCALE : real := 0.256;

    -- Column bases in the assembled input [ pos_nm | u_prev | sp_nm ]
    constant UPREV_BASE : natural := N;
    constant SP_BASE : natural := N + M;

    -- Flat gain memory (row-major, one Q7.25 word per entry)
    type word_vec is array (natural range <>) of std_logic_vector(31 downto 0);

    -- Servo result: DAC output + the fed-back u_prev
    type servo_res is record
        u : lqr_out_vec(0 to M - 1);
        unext : mac_data_vec(0 to M - 1);
    end record;

    function kg(r : real) return signed; -- real -> gain Q7.25
    function pv(v : integer) return signed; -- raw position/setpoint counts

    function nm_gold(c : signed) return signed; -- counts -> nm (mirrors to_nm)
    function round_sat(acc : signed; fd : natural; w : natural) return signed;
    function flatten(k : mac_gain_mat) return word_vec; -- row-major

    function servo(
        pc : mac_data_vec; -- position counts
        sp : mac_data_vec; -- setpoint counts
        k : mac_gain_mat;
        uprev : mac_data_vec
    ) return servo_res;

    -- K and its flat image
    constant K : mac_gain_mat(0 to M - 1, 0 to NI - 1);
    constant GAINS_FLAT : word_vec(0 to GAIN_CNT - 1);

end package;


package body lqr_block_tb_pkg is

    function kg(r : real) return signed is
    begin
        return to_signed(integer(round(r * 2.0 ** GAIN_F)), LANE_B_W);
    end function;

    function pv(v : integer) return signed is
    begin
        return to_signed(v, LANE_A_W);
    end function;

    -- Golden counts -> nm (independent of the DUT fixed-point path).
    function floor_shr(x : integer; f : natural) return integer is
        constant d : integer := 2 ** f;
    begin
        if x >= 0 then
            return x / d;
        else
            return -((-x + d - 1) / d); -- floor, not trunc
        end if;
    end function;

    function nm_gold(c : signed) return signed is
        constant SC : integer := integer(INTER_SCALE * real(2 ** PV_FRAC));
        variable prod : integer := to_integer(c) * SC;
        variable bias : integer := 2 ** (FRAC_DIFF - 1); -- half-away
    begin
        if prod < 0 then
            bias := bias - 1;
        end if;
        return to_signed(floor_shr(prod + bias, FRAC_DIFF), LANE_A_W);
    end function;

    function round_sat(acc : signed; fd : natural; w : natural) return signed is
        -- Magnitude round-half-away then saturate (independent of fp_utils).
        variable mag : signed(acc'length + 1 downto 0);
        variable r : signed(acc'length + 1 downto 0);
    begin
        if fd = 0 then
            r := resize(acc, r'length);
        else
            mag := abs(resize(acc, mag'length));
            mag := mag + shift_left(to_signed(1, mag'length), fd - 1);
            r := shift_right(mag, fd);

            if acc(acc'high) = '1' then
                r := -r;
            end if;
        end if;

        if r > max_s(w) then
            return max_s(w);
        elsif r < min_s(w) then
            return min_s(w);
        else
            return resize(r, w);
        end if;
    end function;

    function flatten(k : mac_gain_mat) return word_vec is
        constant NC : natural := k'length(2);
        variable w : word_vec(0 to k'length(1) * NC - 1);
    begin
        for r in 0 to k'high(1) loop
            for c in 0 to k'high(2) loop
                w(r * NC + c) := std_logic_vector(k(r, c));
            end loop;
        end loop;
        return w;
    end function;

    function servo(
        pc : mac_data_vec;
        sp : mac_data_vec;
        k : mac_gain_mat;
        uprev : mac_data_vec
    ) return servo_res is
        variable x : mac_data_vec(0 to NI - 1);
        variable acc : mac_acc_vec(0 to M - 1);
        variable res : servo_res;
    begin
        -- [ pos_nm | u_prev | sp_nm ]  (no velocity in this block config)
        x := (others => (others => '0'));
        for ax in 0 to N - 1 loop
            x(ax) := nm_gold(pc(ax));
        end loop;
        for r in 0 to M - 1 loop
            x(UPREV_BASE + r) := uprev(r);
        end loop;
        for c in 0 to N - 1 loop
            x(SP_BASE + c) := nm_gold(sp(c));
        end loop;

        for r in 0 to M - 1 loop
            acc(r) := (others => '0');
            for c in 0 to NI - 1 loop
                acc(r) := acc(r) + resize(k(r, c) * x(c), acc(r)'length);
            end loop;
            res.u(r) := round_sat(acc(r), PROD_F - OUT_F, OUT_W);
            res.unext(r) := round_sat(acc(r), PROD_F - STATE_F, LANE_A_W);
        end loop;
        return res;
    end function;

    -- K = [ K_pos | K_uprev | K_sp ] : u = pos + 0.5*u_prev - sp
    constant K : mac_gain_mat(0 to M - 1, 0 to NI - 1) := (
        (
            kg(1.0), kg(0.0), kg(0.0),
            kg(0.5), kg(0.0), kg(0.0),
            kg(-1.0), kg(0.0), kg(0.0)
        ),
        (
            kg(0.0), kg(1.0), kg(0.0),
            kg(0.0), kg(0.5), kg(0.0),
            kg(0.0), kg(-1.0), kg(0.0)
        ),
        (
            kg(0.0), kg(0.0), kg(1.0),
            kg(0.0), kg(0.0), kg(0.5),
            kg(0.0), kg(0.0), kg(-1.0)
        )
    );

    constant GAINS_FLAT : word_vec(0 to GAIN_CNT - 1) := flatten(K);

end package body;
