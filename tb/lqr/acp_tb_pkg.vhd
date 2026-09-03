--------------------------------------------------------------------------------
--  File:   acp_tb_pkg.vhd
--  Desc:   Shared types for the state_export / mock ACP testbench.
--  Author: richard.cunningham@diamond.ac.uk
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package acp_tb_pkg is
    -- 64-bit ACP beats (backing store) and 32-bit burst addresses (log).
    type word64_vec is array (natural range <>) of std_logic_vector(63 downto 0);
    type addr_vec   is array (natural range <>) of std_logic_vector(31 downto 0);
end package;
