----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/24/2023 07:51:44 PM
-- Design Name: 
-- Module Name: Sharpened_Filter - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Complementary_FIR_Filter is
    Generic (
        FILTER_TAPS  : integer := 41;                   -- Must be an Odd value!
        PIPELINING   : integer := 5;                    -- Amount of pipelining stages (registers) in the prototype filter.
        NOTCH_ENABLE : boolean := false;
        DATA_WIDTH   : integer range 8 to 25 := 24; 
        COEFF_WIDTH  : integer range 8 to 18 := 16
--        OUTPUT_WIDTH : integer range 8 to 43 := 24      -- This should be < (Input+Coeff width-1) 
    );
    Port ( 
        clk    : in STD_LOGIC;
        reset  : in STD_LOGIC;
        enable : in STD_LOGIC;
        data_i : in STD_LOGIC_VECTOR  (DATA_WIDTH-1 downto 0);
        data_o : out STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
        cmpl_o : out STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0)
       );
end Complementary_FIR_Filter;

architecture Behavioral of Complementary_FIR_Filter is

-------------------------------------------------------------------------------
-- FIR Filter Instantiation 
-------------------------------------------------------------------------------
component Parallel_FIR_Filter is
    Generic (
        FILTER_TAPS  : integer := 21;
        INPUT_WIDTH  : integer range 8 to 25 := 24; 
        COEFF_WIDTH  : integer range 8 to 18 := 16;
        OUTPUT_WIDTH : integer range 8 to 43 := 24    -- This should be < (Input+Coeff width-1) 
    );
    Port ( 
        clk    : in STD_LOGIC;
        reset  : in STD_LOGIC;
        enable : in STD_LOGIC;
        data_i : in STD_LOGIC_VECTOR (INPUT_WIDTH-1 downto 0);
        data_o : out STD_LOGIC_VECTOR (OUTPUT_WIDTH-1 downto 0)
       );
end component;


-------------------------------------------------------------------------------
-- Internal signals
-------------------------------------------------------------------------------
constant DELAY_AMOUNT : integer := (FILTER_TAPS-1)/2 + PIPELINING;
type delay_line is array(0 to DELAY_AMOUNT-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
signal dline : delay_line := (others=>(others=>'0'));

signal proto_data_i : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
signal proto_data_o : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
signal proto_data_s : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);

signal s1_data_i : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
signal s1_data_o : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);

signal s2_data_i : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);
signal s2_data_o : STD_LOGIC_VECTOR (DATA_WIDTH-1 downto 0);



begin

------------------------------------------------------------
-- Filter Instantiations
------------------------------------------------------------
Proto_Inst: Parallel_FIR_Filter
generic map (
  INPUT_WIDTH  => DATA_WIDTH,  
  OUTPUT_WIDTH => DATA_WIDTH,  
  FILTER_TAPS  => FILTER_TAPS, 
  COEFF_WIDTH  => COEFF_WIDTH 
)
port map ( 
  clk    => clk,
  reset  => reset,
  enable => enable,
  data_i => data_i,
  data_o => proto_data_o
);  
   



process(clk)

variable data_a : signed(DATA_WIDTH downto 0);
variable data_b : signed(DATA_WIDTH downto 0);
variable diff   : signed(DATA_WIDTH downto 0);

begin

    if rising_edge(clk) then
    
        if enable = '1' then
            -- Delay Line
            for i in 0 to DELAY_AMOUNT-1 loop
                if i > 0 then
                    dline(i) <= dline(i-1);
                else
                    dline(i) <= data_i;
                end if;
            end loop;
            
            proto_data_s <= proto_data_o;
            data_o <= proto_data_s;
    
            -- Signal Mixing
            data_a := signed(dline(DELAY_AMOUNT-1)(DATA_WIDTH-1) & dline(DELAY_AMOUNT-1));
            if NOTCH_ENABLE = true then
                data_b := signed(proto_data_s & proto_data_s(0)); 
            else
                data_b := signed(proto_data_s(DATA_WIDTH-1) & proto_data_s);
            end if;
            diff := data_a - data_b;         
        
            -- Saturation
            if diff(DATA_WIDTH downto DATA_WIDTH-1) = "01" then             -- Overflow
                cmpl_o(DATA_WIDTH-1) <= '0';    
                cmpl_o(DATA_WIDTH-2 downto 0) <= (others=>'1');
            elsif diff(DATA_WIDTH downto DATA_WIDTH-1) = "10" then          -- Underflow
                cmpl_o(DATA_WIDTH-1) <= '1';    
                cmpl_o(DATA_WIDTH-2 downto 0) <= (others=>'0');   
            else                                                            
                cmpl_o <= std_logic_vector(diff(DATA_WIDTH-1 downto 0));
            end if;

        end if;
        
    end if;

end process;


end Behavioral;
