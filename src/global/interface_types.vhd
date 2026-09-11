--------------------------------------------------------------------------------
-- interface_types : Taken straight from the PandA for our testbenches.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package interface_types is

    -- FMC Block Record declarations

    type FMC_interface is
      record
        FMC_PRSNT       : std_logic_vector(1 downto 0);
        FMC_LA_P        : std_logic_vector(33 downto 0);
        FMC_LA_N        : std_logic_vector(33 downto 0);
        FMC_CLK0_M2C_P  : std_logic;
        FMC_CLK0_M2C_N  : std_logic;
        FMC_CLK1_M2C_P  : std_logic;
        FMC_CLK1_M2C_N  : std_logic;
        FMC_I2C_SDA_in  : std_logic;
        FMC_I2C_SDA_out : std_logic;
        FMC_I2C_SDA_tri : std_logic;
        FMC_I2C_SCL_in  : std_logic;
        FMC_I2C_SCL_out : std_logic;
        FMC_I2C_SCL_tri : std_logic;
      end record FMC_interface;

    view FMC_Module of FMC_interface is
        FMC_PRSNT       : in;
        FMC_LA_P        : inout;
        FMC_LA_N        : inout;
        FMC_CLK0_M2C_P  : inout;
        FMC_CLK0_M2C_N  : inout;
        FMC_CLK1_M2C_P  : in;
        FMC_CLK1_M2C_N  : in;
        FMC_I2C_SDA_in  : out;
        FMC_I2C_SDA_out : in;
        FMC_I2C_SDA_tri : in;
        FMC_I2C_SCL_in  : out;
        FMC_I2C_SCL_out : in;
        FMC_I2C_SCL_tri : in;

    end view FMC_Module;

    constant FMC_init : FMC_interface;

    type FMC_array is array (natural range <>) of FMC_interface;

    type FMC_ARR_REC is record
        FMC_ARR : FMC_array;
    end record FMC_ARR_REC;

    view FMC_MOD_ARR of FMC_ARR_REC is
        FMC_ARR: view (FMC_Module);
    end view;

    -- SFP Block Record declarations

    type MGT_interface is
      record
        SFP_LOS     : std_logic;
        GTREFCLK    : std_logic;
        RXN_IN      : std_logic;
        RXP_IN      : std_logic;
        TXN_OUT     : std_logic;
        TXP_OUT     : std_logic;
        MGT_REC_CLK : std_logic;
        LINK_UP     : std_logic;
        TS_SEC      : std_logic_vector(31 downto 0);
        TS_TICKS    : std_logic_vector(31 downto 0);
        MAC_ADDR    : std_logic_vector(47 downto 0);
        MAC_ADDR_WS : std_logic;
      end record MGT_interface;

    view MGT_Module of MGT_interface is
        SFP_LOS     : in;
        GTREFCLK    : in;
        RXN_IN      : in;
        RXP_IN      : in;
        TXN_OUT     : out;
        TXP_OUT     : out;
        MGT_REC_CLK : out;
        LINK_UP     : out;
        TS_SEC      : out;
        TS_TICKS    : out;
        MAC_ADDR    : in;
        MAC_ADDR_WS : in;
    end view MGT_Module;

    constant MGT_init : MGT_interface;

    type MGT_array is array (natural range <>) of MGT_interface;

    type MGT_ARR_REC is record
        MGT_ARR : MGT_array;
    end record MGT_ARR_REC;

    view MGT_MOD_ARR of MGT_ARR_REC is
        MGT_ARR: view (MGT_Module);
    end view;

    -- ACP master interface (LQR state export -> PS7 S_AXI_ACP).
    -- Flat leaves (not nested mosi/miso): a view-port selected name must stay
    -- one level deep -- Vivado 2023.2 synth won't drill two levels into a view.
    type acp_interface is record
        -- master-driven
        awvalid : std_logic;
        awaddr  : std_logic_vector(31 downto 0);
        awid    : std_logic_vector(2 downto 0);
        awlen   : std_logic_vector(3 downto 0);
        awsize  : std_logic_vector(2 downto 0);
        awburst : std_logic_vector(1 downto 0);
        awcache : std_logic_vector(3 downto 0);
        awuser  : std_logic_vector(4 downto 0);
        awprot  : std_logic_vector(2 downto 0);
        awlock  : std_logic_vector(1 downto 0);
        awqos   : std_logic_vector(3 downto 0);
        wvalid  : std_logic;
        wid     : std_logic_vector(2 downto 0);
        wdata   : std_logic_vector(63 downto 0);
        wstrb   : std_logic_vector(7 downto 0);
        wlast   : std_logic;
        bready  : std_logic;
        -- slave-driven
        awready : std_logic;
        wready  : std_logic;
        bvalid  : std_logic;
        bresp   : std_logic_vector(1 downto 0);
        bid     : std_logic_vector(2 downto 0);
    end record;

    view acp_module of acp_interface is
        awvalid : out; awaddr : out; awid : out; awlen : out; awsize : out;
        awburst : out; awcache : out; awuser : out; awprot : out; awlock : out;
        awqos : out; wvalid : out; wid : out; wdata : out; wstrb : out;
        wlast : out; bready : out;
        awready : in; wready : in; bvalid : in; bresp : in; bid : in;
    end view;

    constant acp_init : acp_interface;

    type acp_array is array (natural range <>) of acp_interface;

    type acp_ARR_REC is record
        acp_ARR : acp_array;
    end record acp_ARR_REC;

    view acp_MOD_ARR of acp_ARR_REC is
        acp_ARR: view (acp_module);
    end view;
end;

package body interface_types is

    constant FMC_init : FMC_interface := (  FMC_PRSNT => "00",
                                            FMC_LA_P => (others => 'Z'),
                                            FMC_LA_N => (others => 'Z'),
                                            FMC_CLK0_M2C_P => 'Z',
                                            FMC_CLK0_M2C_N => 'Z',
                                            FMC_CLK1_M2C_P => '0',
                                            FMC_CLK1_M2C_N => '0',
                                            FMC_I2C_SDA_in => '0',
                                            FMC_I2C_SDA_out => '0',
                                            FMC_I2C_SDA_tri => '1',
                                            FMC_I2C_SCL_in => '0',
                                            FMC_I2C_SCL_out => '0',
                                            FMC_I2C_SCL_tri => '1');

    constant MGT_init : MGT_interface := (  SFP_LOS => '0',
                                            GTREFCLK => '0',
                                            RXN_IN => '0',
                                            RXP_IN => '0',
                                            TXN_OUT => 'Z',
                                            TXP_OUT => 'Z',
                                            MGT_REC_CLK => '0',
                                            LINK_UP => '0',
                                            TS_SEC => (others => '0'),
                                            TS_TICKS => (others => '0'),
                                            MAC_ADDR => (others => '0'),
                                            MAC_ADDR_WS => '0');

    constant acp_init : acp_interface := (
        awvalid => '0',
        awaddr => (others => '0'),
        awid => (others => '0'),
        awlen => (others => '0'),
        awsize => (others => '0'),
        awburst => (others => '0'),
        awcache => (others => '0'),
        awuser => (others => '0'),
        awprot => (others => '0'),
        awlock => (others => '0'),
        awqos => (others => '0'),

        wvalid => '0',
        wid => (others => '0'),
        wdata => (others => '0'),
        wstrb => (others => '0'),
        wlast => '0',

        bready => '0',
        awready => '0',
        wready => '0',
        bvalid => '0',
        bresp => (others => '0'),
        bid => (others => '0')
    );

end;
