----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:17:22 07/25/2011 
-- Design Name: 
-- Module Name:    EEPROM_WRITE_TEST - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 	brief testing module for EEPROM_READ_TEST Module.
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
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
--================================================================================
entity EEPROM_WRITE_TEST is
	port(
		bclk_50MHz			: IN		STD_LOGIC;
		SCL			: INOUT	STD_LOGIC;
		SDA			: INOUT	STD_LOGIC;
		VCC_PIN		: OUT		STD_LOGIC;		--PROVIDE POWER FOR THE EEPROM
		WP_PIN		: OUT		STD_LOGIC;		--WHEN IT'S '0', WRITE OPERATION ARE ENABLED
		
		mon			: out 	std_logic_vector(2 downto 0);
		
		led			: out		std_logic
		);
end EEPROM_WRITE_TEST;

architecture Behavioral of EEPROM_WRITE_TEST is
--================================================================================
	-----------------------------COMPONENT---------------------------------
	component EEPROM_I2C_INTERFACE_WRITE
	--generic(
		--PAGE_SIZE			: unsigned := 32
		--);
	port(
		CLK								: IN		STD_LOGIC;
		DATA_IN_BYTE					: IN		STD_LOGIC_VECTOR(7 DOWNTO 0);
		COMMAND							: IN		STD_LOGIC_VECTOR(2 DOWNTO 0);
		EXECUTE							: IN		STD_LOGIC;
		COMMAND_RUNNING					: OUT		STD_LOGIC_vector(2 DOWNTO 0);

		SCL		: INOUT STD_LOGIC;
		SDA		: INOUT STD_LOGIC
		);
	end component EEPROM_I2C_INTERFACE_WRITE;
	
	----------------------------------------------------------------------------

	
	SIGNAL 	CLK_COUNTER					: UNSIGNED(9 DOWNTO 0) := x"00"&"00";
	signal DATA_IN_BYTE_TEST			: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL COMMAND_TEST					: STD_LOGIC_VECTOR(2 DOWNTO 0);	
	SIGNAL COMMAND_RUNNING_TEST		: STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL EXECUTE_TEST					: STD_LOGIC := '0';
	signal SCL_internal					: std_logic;
	SIGNAL SDA_internal					: std_logic;
	
--==================================================================================


begin
	-----------------Power and Write Protection--------------
	VCC_PIN <= '1';
	WP_PIN <= '0';
	---------------------------------------------------------
	EEPROM_WRITE : EEPROM_I2C_INTERFACE_WRITE
	port map (
		CLK					=> CLK_COUNTER(9),
		DATA_IN_BYTE		=> DATA_IN_BYTE_TEST,
		COMMAND				=> COMMAND_TEST,
		COMMAND_RUNNING	=> COMMAND_RUNNING_TEST,
		EXECUTE				=> EXECUTE_TEST,
		SCL					=> SCL_internal,
		SDA					=> SDA_internal
		);
	---------------------------------------------------------	
	reduce_requency: PROCESS(bclk_50MHz)
	BEGIN
		IF RISING_EDGE(bclk_50MHz) THEN
			
			CLK_COUNTER <= CLK_COUNTER + 1;
			
		end if;
	END PROCESS reduce_requency;
	----------------------------------------------------------
	
	process (CLK_COUNTER(9))
	--==================================================================================
	-----------COMMAND FOR EEPROM INTERFACE USED HERE----------------
		CONSTANT CMD_SAVE_DATA_BYTE				: STD_LOGIC_VECTOR(2 DOWNTO 0) := "001"; 
		CONSTANT CMD_WRITE_TO_EEPROM_BYTES		: STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
		CONSTANT CMD_RESET_EEPROM_ADDRESS		: STD_LOGIC_VECTOR(2 DOWNTO 0) := "011";
		CONSTANT CMD_RESET_BYTES_SAVED			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "100";
		CONSTANT CMD_CHECK_COMMAND					: STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
	-----------------------------------------------------------------
	type bytes_to_write_type is array(0 TO 13) of std_logic_vector(7 downto 0);
	
	variable bytes_to_write					: bytes_to_write_type :=
				(0 	=> x"53",	--S
				 1 	=> x"43",	--C
				 2 	=> x"52",	--R
				 3 	=> x"4F",	--O
				 4 	=> x"44",	--D
				 5 	=> x"20",	--SPACE
				 6 	=> x"72",	--r
				 7 	=> x"65",	--e
				 8 	=> x"76",	--v
				 9 	=> x"41",	--A
				 10 	=> x"20",	--space
				 11 	=> x"49",	--I
				 12 	=> x"44",   --D
				 13 	=> x"20"	--space
				 
					
				);
	variable bytes_to_write_counter		: integer range 0 to 14 := 0;
	variable counter, step_counter		:	integer range 0 to 15 := 0;
	--==================================================================================
	
	BEGIN
		
		IF RISING_EDGE(CLK_COUNTER(9)) THEN
		
			--#############################
			IF EXECUTE_TEST = '1' THEN
				EXECUTE_TEST <= '0';			--RESET SIGNAL 'EXECUTE' TO '0'!
			END IF;
			--#############################
			
			
			if counter = 0 then
				if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then
					COMMAND_TEST <= CMD_RESET_BYTES_SAVED;	--clear bytes saved
					EXECUTE_TEST <= '1';
					counter := counter + 1;
				end if;
			elsif counter = 1 then
				if COMMAND_RUNNING_TEST = CMD_RESET_BYTES_SAVED then	
					counter := counter + 1;
				end if;

			elsif counter = 2 then	--transfer all the data in the array.
				if bytes_to_write_counter < 14 then
					if step_counter = 0 then
						if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then	
							DATA_IN_BYTE_TEST <= bytes_to_write(bytes_to_write_counter);
							COMMAND_TEST <= CMD_SAVE_DATA_BYTE;	--SAVE THE BYTE
							EXECUTE_TEST <= '1';
							step_counter := step_counter + 1;
						end if;
					elsif step_counter = 1 then
						if COMMAND_RUNNING_TEST = CMD_SAVE_DATA_BYTE then
							bytes_to_write_counter := bytes_to_write_counter + 1;
							step_counter := 0;
						end if;
					end if;
				else	--all bytes are sent to EEPROM_write module
					counter := counter + 1;
				end if;
			

			elsif counter = 3 then
				if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then
					--DATA_IN_BYTE_TEST <= "11111111";		--testing write another byte.
					--COMMAND_TEST <= CMD_SAVE_DATA_BYTE;	--SAVE THE BYTE
					--EXECUTE_TEST <= '1';
					counter := counter + 1;
				end if;
			elsif counter = 4 then
					--if COMMAND_RUNNING_TEST = CMD_SAVE_DATA_BYTE then
						counter := counter + 1;
					--end if;
			
			
			
			elsif counter = 5 then
				if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then
					
					COMMAND_TEST <= CMD_RESET_EEPROM_ADDRESS;	--RESET THE EEPROM ADDRESS
					EXECUTE_TEST <= '1';
					counter := counter + 1;
				end if;
			elsif counter = 6 then
					if COMMAND_RUNNING_TEST = CMD_RESET_EEPROM_ADDRESS then
						counter := counter + 1;
					end if;		
			
			
			elsif counter = 7 then
				if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then		
					COMMAND_TEST <= CMD_WRITE_TO_EEPROM_BYTES;	--WRITE DATA TO EEPROM
					EXECUTE_TEST <= '1';
					counter := counter + 1;
				end if;
			elsif counter = 8 then
				
				if COMMAND_RUNNING_TEST = CMD_WRITE_TO_EEPROM_BYTES then		
					counter := counter + 1;
					
				end if;
			elsif counter = 9 then
				if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then		
					COMMAND_TEST <= CMD_WRITE_TO_EEPROM_BYTES;	--WRITE DATA TO EEPROM. testing! write the same package again
					EXECUTE_TEST <= '1';
					counter := counter + 1;
				end if;
			elsif counter = 10 then
				
				if COMMAND_RUNNING_TEST = CMD_WRITE_TO_EEPROM_BYTES then		
					counter := counter + 1;
					
				end if;
			else 
				if COMMAND_RUNNING_TEST = CMD_CHECK_COMMAND then	
					led <= '1';
				end if;
			end if;
			
	
		
		END IF;
	END PROCESS;
	mon(0) <= CLK_COUNTER(9);
	mon(1) <= SCL_internal;
	mon(2) <= SDA_internal;
	--mon(3) <= '1';
	--mon(4) <= state_counter_i2c(2);
	--mon(5) <= state_counter_i2c(1);
	--mon(6) <= state_counter_i2c(0);
	--mon(7) <= '1';
	--mon(8) <= state_counter(2);
	--mon(9) <= state_counter(1);
	--mon(10) <= state_counter(0);
	--mon(11) <= '1';
	--mon(11) <= COMMAND_RUNNING_TEST(2);
	--mon(12) <= COMMAND_RUNNING_TEST(1);
	--mon(13) <= COMMAND_RUNNING_TEST(0);
	
	SCL <= SCL_internal;
	SDA <= SDA_internal;
end Behavioral;

