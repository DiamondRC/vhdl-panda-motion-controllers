--------------------------------------------------------------------------------
--  File:   linear_lqr.vhd
--  Desc:   Implementation of a linear LQR controller.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.fixed_pkg.all;

-- Custom packages
use work.lqr_constants.all;
use work.global_subtypes.all;
use work.state_enum.all;

entity linear_lqr is
    generic (
        -- Number of DSPs to use per cycle
        K_CHUNK     : natural := 3  
    );
    port (
        clk_i          : in std_logic;
        init_i         : in std_logic;

        lqr_period_i   : in panda_port  := (others => '0');

        x_in_i         : in panda_port  := (others => '0'); -- Measured x value
        y_in_i         : in panda_port  := (others => '0'); -- Measured y value
        z_in_i         : in panda_port  := (others => '0'); -- Measured z value

        sp_x_i         : in panda_port  := (others => '0'); -- Desired x value
        sp_y_i         : in panda_port  := (others => '0'); -- Desired y value
        sp_z_i         : in panda_port  := (others => '0'); -- Desired z value

        max_x_out_i    : in panda_port  := (others => '0'); -- Max x out
        max_y_out_i    : in panda_port  := (others => '0'); -- Max y out
        max_z_out_i    : in panda_port  := (others => '0'); -- Max z out

        ctrl_x_o       : out panda_port := (others => '0'); -- Controller x out
        ctrl_y_o       : out panda_port := (others => '0'); -- Controller y out
        ctrl_z_o       : out panda_port := (others => '0')  -- Controller z out
    );
end entity linear_lqr;

architecture main of linear_lqr is
    -- PID clock
    -- 625 is ~200kHz
    signal clk_count   : unsigned(PANDA_PORT_SIZE - 1 downto 0)
        := (others => '0');
    signal trigger     : std_logic
        := '0';

    -- System
    signal do_work     : std_logic := '0';
    signal state       : lqr_state := INITIAL;

    -- Master
    signal nm_x_in_mul : sfixed(PANDA_PORT_SIZE - 1 downto -(PV_FRAC));
    signal nm_y_in_mul : sfixed(PANDA_PORT_SIZE - 1 downto -(PV_FRAC));
    signal nm_z_in_mul : sfixed(PANDA_PORT_SIZE - 1 downto -(PV_FRAC));

    -- Error
    signal error_vals  : err_row(0 to N_ERR - 1)

    -- TODO - Gain signal array
    signal gain_matrix : gain_mat(0 to N_OUT - 1)(0 to N_ERR - 1);
    signal coeff_i     : natural range 0 to N_ERR - 1 := 0;
    signal row_i       : natural range 0 to N_OUT - 1 := 0;

    -- Calculation
    signal term_idx    : natural := '0';

begin
    process(clk_i)
    -- Creates a local clock which is some
    -- number of ticks slower than the master
    -- PandA clock.
    begin
        if rising_edge(clk_i) then
            if init_i = '1' then
                trigger <= '0';
                clk_count <= (others => '0');
            else
                if clk_count = unsigned(lqr_period_i) - 1 then
                    trigger <= '1';
                    clk_count <= (others => '0');
                else
                    trigger <= '0';
                    clk_count <= clk_count + 1;
                end if; -- Update count
            end if; -- Process reset
        end if; -- Clock
    end process;

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            -- Encoders read in units of 256pm.
            -- Must convert into units of 1nm.
            -- => multiply by * 256/1000 = 0.256.
            nm_x_in_mul <= resize(
                to_sfixed(
                    signed(x_in_i),
                    nm_x_in_mul'high,
                    nm_x_in_mul'low
                ) * PV_SCALE,
                nm_x_in_mul'high,
                nm_x_in_mul'low
            );

            nm_y_in_mul <= resize(
                to_sfixed(
                    signed(y_in_i),
                    nm_y_in_mul'high,
                    nm_y_in_mul'low
                ) * PV_SCALE,
                nm_y_in_mul'high,
                nm_y_in_mul'low
            );

            nm_z_in_mul <= resize(
                to_sfixed(
                    signed(z_in_i),
                    nm_z_in_mul'high,
                    nm_z_in_mul'low
                ) * PV_SCALE,
                nm_z_in_mul'high,
                nm_z_in_mul'low
            );

            if init_i = '1' then
                -- System
                do_work  <= '0';

                -- Output
                ctrl_x_o <= (others => '0');
                ctrl_y_o <= (others => '0');
                ctrl_z_o <= (others => '0');

                -- Error
                x_err    <= (others => '0');
                y_err    <= (others => '0');
                z_err    <= (others => '0');

            elsif trigger = '1' then
                -- Start logic next master clock.
                do_work <= '1';

            elsif do_work = '1' then
                case state is
                    when INITIAL   =>
                        -- Assign error values.
                        -- Prepare error for 
                        -- control matrix.
                        error_vals(0) <= nm_x_in_mul -
                            to_sfixed(
                                signed(sp_x_i),
                                nm_x_in_mul'high,
                                nm_x_in_mul'low
                            );

                        error_vals(1) <= nm_y_in_mul -
                            to_sfixed(
                                signed(sp_y_i),
                                nm_y_in_mul'high,
                                nm_y_in_mul'low
                            );

                        error_vals(2) <= nm_z_in_mul -
                            to_sfixed(
                                signed(sp_z_i),
                                nm_z_in_mul'high,
                                nm_z_in_mul'low
                            );

                        state   <= INITIAL;

                    when COMPUTE =>
                        -- TODO
                        -- connect to MAC file.

                        state   <= DONE;

                    when DONE =>
                        ctrl_x_o <= TODO;
                        ctrl_y_o <= TODO;
                        ctrl_z_o <= TODO;

                        state   <= INITIAL;
                        do_work <= '0';

                    when others =>
                        state   <= INITIAL;
                        do_work <= '0';
                    
                end case;
            end if;

        end if;  -- Clock
    end process; -- Main logic
end main;
