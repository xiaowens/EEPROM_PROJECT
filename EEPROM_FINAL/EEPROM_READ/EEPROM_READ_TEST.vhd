----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:22:09 07/29/2011 
-- Design Name: 
-- Module Name:    EEPROM_READ_TEST - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 	A testing module for EEPROM_I2C_INTERFACE_READ Module. 
--						It will read out # of bytes(could be set by the input switchers on the Spartan-3 board) 
--							and show them through the LEDs.  
--
-- Dependencies: 	EEPROM_I2C_INTERFACE_READ and I2C Module
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
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
--================================================================================================
entity EEPROM_READ_TEST is
	port(
		bclk_50MHz			: IN		STD_LOGIC;
		SCL			: INOUT	STD_LOGIC;
		SDA			: INOUT	STD_LOGIC;
		VCC_PIN		: OUT		STD_LOGIC;		--PROVIDE POWER FOR THE EEPROM
		WP_PIN		: OUT		STD_LOGIC;		--WHEN IT'S '1', WRITE PROTECT ARE ENABLED. READ ONLY
		mon			: out		std_logic_vector(10 downto 0);
		switcher		: in		std_logic_vector(3 downto 0);
		btn_show_index	: in		std_logic;
		LED			: out		std_logic_vector(7 downto 0)
		
		);
end EEPROM_READ_TEST;
--================================================================================================
architecture Behavioral of EEPROM_READ_TEST is
--================================================================================================
	----------------------------------------------------------------------------------------
	COMPONENT EEPROM_I2C_INTERFACE_READ is
	generic(
		PAGE_SIZE			: integer := 32
		);
	port(
		CLK		: IN	STD_LOGIC;
		ADDRESS		: IN	STD_LOGIC_VECTOR(12 DOWNTO 0);
		COMMAND		: IN	STD_LOGIC_VECTOR(2 DOWNTO 0);
		----------------------------------------------
		--total # of bytes to read from EEPROM
		--it will be the index of bytes when transfer out the data 
		NUM_OF_BYTES	: IN	STD_LOGIC_VECTOR(5 DOWNTO 0);	
		----------------------------------------------
		EXECUTE		: IN	STD_LOGIC;
		state_I2C	: OUT	STD_LOGIC_VECTOR(2 DOWNTO 0);	--for debugging
		COMMAND_RUNNING	: OUT	STD_LOGIC_VECTOR(2 DOWNTO 0);
		INDEX_OF_BYTES	: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);	--MAX # OF BYTES => 2^5=32 BYTES
		DATA_OUT_BYTE	: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		SCL	: INOUT STD_LOGIC;
		SDA	: INOUT STD_LOGIC
		);
	end COMPONENT;
	----------------------------------------------------------------------------------
	-------------------------------------signal-------------------------------------
	SIGNAL COMMAND_TEST					: STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL ADDRESS_TEST					: STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL NUM_OF_BYTES_TEST			: STD_LOGIC_VECTOR(5 DOWNTO 0);
	SIGNAL COMMAND_RUNNING_TEST		: STD_LOGIC_vector(2 downto 0);
	signal state_I2C_test				: STD_LOGIC_VECTOR(2 DOWNTO 0);	--for debugging
	SIGNAL INDEX_OF_BYTES_TEST			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL EXECUTE_TEST					: STD_LOGIC := '0'; 
	SIGNAL SCL_TEST						: STD_LOGIC;
	SIGNAL SDA_TEST						: STD_LOGIC;
	SIGNAL CLK_COUNTER					: UNSIGNED(9 DOWNTO 0) := x"00"&"00";
	
	signal DATA_OUT_BYTE_TEST			: std_logic_vector(7 downto 0);
	
--================================================================================================	
	
	
	
begin

	--********************************************************
	VCC_PIN <= '1';
	WP_PIN <= '1';		--WRITE PRECTED ENABLED. READ ONLY. 
	--********************************************************

	eeprom_read		: EEPROM_I2C_INTERFACE_READ
	port map (
		CLK			=> CLK_COUNTER(9),
		ADDRESS		=> ADDRESS_TEST,
		COMMAND		=> COMMAND_TEST,
		----------------------------------------------
		--total # of bytes to read from EEPROM
		--it will be the index of bytes when transfer out the data 
		NUM_OF_BYTES		=>	NUM_OF_BYTES_TEST,
		----------------------------------------------
		EXECUTE				=> EXECUTE_TEST,
		state_I2C			=> state_I2C_test,
		COMMAND_RUNNING	=> COMMAND_RUNNING_TEST,
		INDEX_OF_BYTES		=> INDEX_OF_BYTES_TEST,
		DATA_OUT_BYTE		=> DATA_OUT_BYTE_TEST,
		
		SCL	=> SCL_TEST,
		SDA	=> SDA_TEST
		);

	----------------------------------------------------------------
	reduce_requency: PROCESS(bclk_50MHz)
	BEGIN
		IF RISING_EDGE(bclk_50MHz) THEN
			
			CLK_COUNTER <= CLK_COUNTER + 1;
			
		end if;
	END PROCESS reduce_requency;
	----------------------------------------------------------------

	process (CLK_COUNTER(9))
		--======================================================================
		-----------COMMAND FOR EEPROM_I2C_INTERFACE_READ MODULE----------------
		CONSTANT CMD_CHECK_COMMAND			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
		CONSTANT CMD_SET_ADDRESS			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "001";
		CONSTANT CMD_READ_EEPROM			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
		CONSTANT CMD_TRANSFER_READ_OUT	: STD_LOGIC_VECTOR(2 DOWNTO 0) := "011";
		
		-----------------------------------------------------------------------
	
		variable step_counter, sub_step_counter				: integer range 0 to 7 := 0;

		--======================================================================
	BEGIN
		--LED <= DATA_OUT_BYTE_TEST;
		IF RISING_EDGE(CLK_COUNTER(9)) THEN
			
			IF (EXECUTE_TEST = '1') THEN
				EXECUTE_TEST <= '0';
			END IF;
			
			if step_counter = 0 then
				if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then
					ADDRESS_TEST <= "0" & x"000";		--13 bits of address
					COMMAND_TEST <= CMD_SET_ADDRESS;
					EXECUTE_TEST <= '1';
					step_counter := step_counter + 1;
				end if; 
			elsif step_counter = 1 then
				if COMMAND_RUNNING_TEST = CMD_SET_ADDRESS then
					step_counter := step_counter + 1;
				end if;
			elsif step_counter = 2 then
				if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then
					NUM_OF_BYTES_TEST <= "100000";		--read 32 bytes 
					COMMAND_TEST <= CMD_READ_EEPROM;
					EXECUTE_TEST <= '1';
					step_counter := step_counter + 1;
				end if; 
			elsif step_counter = 3 then
				if COMMAND_RUNNING_TEST = CMD_READ_EEPROM then
					step_counter := step_counter + 1;
				end if;
			
			elsif step_counter = 4 then
				if sub_step_counter = 0 then
					if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then
						NUM_OF_BYTES_TEST <= "00" & switcher;
						COMMAND_TEST <= CMD_TRANSFER_READ_OUT;
						EXECUTE_TEST <= '1';
						sub_step_counter := sub_step_counter + 1;
					end if;
				elsif sub_step_counter = 1 then
					if COMMAND_RUNNING_TEST = CMD_TRANSFER_READ_OUT then
						sub_step_counter := sub_step_counter + 1;
					end if;
				else
					if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then
						LED <= DATA_OUT_BYTE_TEST;
						if btn_show_index = '1' then
							LED <= "000" & INDEX_OF_BYTES_TEST;
						end if;
						sub_step_counter := 0;
					end if;
				end if;
			end if;
		END IF;
	END PROCESS;
	mon(0) <= CLK_COUNTER(9);
	mon(1) <= SCL_TEST;
	mon(2) <= SDA_TEST;
	mon(3) <= '1';
	mon(4) <= state_I2C_test(2);
	mon(5) <= state_I2C_test(1);
	mon(6) <= state_I2C_test(0);
	mon(7) <= '1';
	mon(8) <= COMMAND_RUNNING_TEST(2);
	mon(9) <= COMMAND_RUNNING_TEST(1);
	mon(10) <= COMMAND_RUNNING_TEST(0);
	SCL <= SCL_TEST;
	SDA <= SDA_TEST;
end Behavioral;

