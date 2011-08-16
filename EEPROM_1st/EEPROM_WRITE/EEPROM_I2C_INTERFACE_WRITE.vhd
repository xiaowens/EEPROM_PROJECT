----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:14:48 07/25/2011 
-- Design Name: 
-- Module Name:    EEPROM_I2C_INTERFACE_WRITE - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
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
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity EEPROM_I2C_INTERFACE_WRITE is
	generic(
		PAGE_SIZE			: integer := 32
		);
	port(
		CLK								: IN		STD_LOGIC;
		DATA_IN_BYTE					: IN		STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		----------------DEFINE COMMAND-----------------------------------
		--"000"	st_check_state, get ready for the next step. either save more data or write bytes to EEPROM
		--"001"	st_save_data_byte, save data in array. Set COMMAND to "00" to save a new byte.
		--"010"	st_write_to_EEPROM_bytes, write all bytes in the array, MAX. 32 bytes,
		--			from the last EEPROM address.
		--"011"	st_reset_EEPROM_address, clear EEPROM_address, so next byte will be written to the beginning
		--"100"	st_reset_bytes_saved, clear the counter for bytes saved to save new data.
		COMMAND							: IN		STD_LOGIC_VECTOR(2 DOWNTO 0);
		-------------------------------------------------------------------
		--COMMAND_DONE					: OUT		STD_LOGIC_VECTOR(2 DOWNTO 0);
		COMMAND_RUNNING				: OUT		STD_LOGIC_VECTOR(2 DOWNTO 0);
		EXECUTE							: IN		STD_LOGIC;
		--SAVE_DATA_SUCCEED				: OUT		STD_LOGIC;
		--WRITE_TO_EEPROM_SUCCEED		: OUT		STD_LOGIC;
		state_counter_i2c					: out		std_logic_vector(2 downto 0);
		state_counter						: out		std_logic_vector(2 downto 0);
		
		SCL		: INOUT STD_LOGIC;
		SDA		: INOUT STD_LOGIC
		);
end EEPROM_I2C_INTERFACE_WRITE;

architecture Behavioral of EEPROM_I2C_INTERFACE_WRITE is

	component I2C_Module 
	port (
		CLK		: IN		STD_LOGIC;
		SCL		: INOUT	STD_LOGIC;
		SDA		: INOUT	STD_LOGIC;
		COMMAND		: IN	STD_LOGIC_VECTOR(2 DOWNTO 0);		
		--COMMAND_DONE			: OUT	STD_LOGIC_vector(2 downto 0);
		COMMAND_RUNNING			: OUT	STD_LOGIC_vector(2 downto 0);
		state_counter			: out std_logic_vector(2 downto 0);
		
		EXECUTE					: IN STD_LOGIC;
		DATA_IN_BYTE		: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
		DATA_OUT_BYTE		: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0)
			);
	end component;

--------------------------------------SIGNAL-------------------------------------------------------
---------------------MAIN STATE TYPE------------------------------------------------
	type EEPROM_I2C_INTERFACE_WRITE_MAIN_STATE_TYPE is 
		(	st_save_data_byte,
			st_write_to_EEPROM_bytes,
			st_reset_EEPROM_address,
			st_reset_bytes_saved,
			st_check_state
		);

	signal state      : EEPROM_I2C_INTERFACE_WRITE_MAIN_STATE_TYPE := st_check_state;
	
----------------SUB-STATE TYPE FOR "st_write_to_EEPROM_bytes" in the main state---------
	type WRITE_TO_EEPROM_STATE_TYPE is
		(	send_control_byte,
			write_eeprom_and_ack,
			write_address,
			write_bytes,
			write_stop
		);
	signal state_write, state_write_next	: WRITE_TO_EEPROM_STATE_TYPE := send_control_byte;
------------------------------------------------------------------------------------------
	type bytes_to_write_type is array(0 TO PAGE_SIZE-1) of std_logic_vector(7 downto 0);
	
	signal bytes_to_write					: bytes_to_write_type;
	signal bytes_to_write_counter			: integer range 0 to PAGE_SIZE := 0;
	
	
	signal EEPROM_address		: unsigned(15 downto 0) := x"0000"; --2 bytes address 
	SIGNAL COMMAND_I2C			: STD_LOGIC_VECTOR(2 DOWNTO 0);
	--SIGNAL COMMAND_DONE_I2C		: STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL COMMAND_RUNNING_I2C		: STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL EXECUTE_I2C			: STD_LOGIC := '0';
	SIGNAL DATA_IN_BYTE_I2C		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DATA_OUT_BYTE_I2C	: STD_LOGIC_VECTOR(7 DOWNTO 0);
	signal byte_index_counter			: integer := 0;	--use to count while writing bytes to EEPROM
	
	
----------------------------------------------------------------------------------------------------------------

begin
----------------------------------------
	I2C	: I2C_Module 
	port map (
		CLK		=> CLK,
		SCL		=> SCL,
		SDA		=> SDA,
		COMMAND		=> COMMAND_I2C,		
		--COMMAND_DONE		=> COMMAND_DONE_I2C,
		COMMAND_RUNNING		=> COMMAND_RUNNING_I2C,
		EXECUTE				=> EXECUTE_I2C,
		
		state_counter		=> state_counter_i2c,
		
		DATA_IN_BYTE		=> DATA_IN_BYTE_I2C,
		DATA_OUT_BYTE		=> DATA_OUT_BYTE_I2C
			);
-----------------------------------------
	
	process(CLK)
	--=============================================================================
		------------COMMANDS FOR I2C MODULE USED HERE--------------------
		--CONSTANT CMD_CHECK_COMMAND					: STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
		CONSTANT CMD_WRITE_BYTE		: STD_LOGIC_VECTOR(2 DOWNTO 0) := "001"; 
		CONSTANT CMD_READ_BYTE		: STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
		CONSTANT CMD_START				: STD_LOGIC_VECTOR(2 DOWNTO 0) := "011";
		CONSTANT CMD_WAIT_FOR_ACK	: STD_LOGIC_VECTOR(2 DOWNTO 0) := "101";
		CONSTANT CMD_SEND_ACK			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "110";
		CONSTANT CMD_STOP				: STD_LOGIC_VECTOR(2 DOWNTO 0) := "111";
		----------------------------------------------------------------
		-----------COMMAND FOR EEPROM_I2C_INTERFACE_WRITE MODULE----------------
		CONSTANT CMD_SAVE_DATA_BYTE				: STD_LOGIC_VECTOR(2 DOWNTO 0) := "001"; 
		CONSTANT CMD_WRITE_TO_EEPROM_BYTES		: STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
		CONSTANT CMD_RESET_EEPROM_ADDRESS		: STD_LOGIC_VECTOR(2 DOWNTO 0) := "011";
		CONSTANT CMD_RESET_BYTES_SAVED			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "100";
		CONSTANT CMD_CHECK_COMMAND					: STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
		
		-----------------------------------------------------------------
		variable step_counter	: integer range 0 to 7 := 0;
		variable data_in_i2c_temp : std_logic_vector(7 downto 0) := (others => '0');
		variable address_byte_counter : integer range 0 to 2 := 0;
		variable wait_counter : integer range 0 to 100 := 0;
	--=============================================================================
	BEGIN
		--SAVE_DATA_SUCCEED <= is_data_saved;
		--WRITE_TO_EEPROM_SUCCEED <= is_EEPROM_written;
		
		IF rising_edge(CLK) THEN
			IF EXECUTE_I2C = '1' THEN
				EXECUTE_I2C <= '0';
			END IF;
			CASE state IS 
				when st_check_state =>
					COMMAND_RUNNING <= "000";
					state_counter <= CMD_CHECK_COMMAND;
					IF EXECUTE = '1' THEN
					CASE COMMAND IS
						--WHEN "000" =>
						--	is_data_saved <= '0';
						--	is_EEPROM_written <= '0';
						WHEN CMD_SAVE_DATA_BYTE =>
							state <= st_save_data_byte;
						WHEN CMD_WRITE_TO_EEPROM_BYTES =>
							state <= st_write_to_EEPROM_bytes;
						WHEN CMD_RESET_EEPROM_ADDRESS =>
							state <= st_reset_EEPROM_address;  --clear EEPROM address start from the beginning
						WHEN CMD_RESET_BYTES_SAVED =>
							state <= st_reset_bytes_saved;	--clear all bytes saved
						WHEN OTHERS =>
							state <= st_check_state;
					END CASE;
					END IF;
				
				----------------------------------------------------
				when st_save_data_byte =>
					state_counter <= "001";
					COMMAND_RUNNING <= CMD_SAVE_DATA_BYTE;
					--if is_data_saved = '0' then
					if (step_counter = 0) then
						--COMMAND_DONE <= "000";
						bytes_to_write(bytes_to_write_counter) <= DATA_IN_BYTE;
						bytes_to_write_counter <= bytes_to_write_counter + 1;
						--is_data_saved <= '1';
						
						step_counter := step_counter + 1;
						
					else
						if EXECUTE = '0' then
							--COMMAND_DONE <= "001";
							step_counter := 0;
							state <= st_check_state;
							
						end if;
					end if;
				----------------------------------------------------------------
				
				when st_write_to_EEPROM_bytes =>
					state_counter <= "010";
					COMMAND_RUNNING <= CMD_WRITE_TO_EEPROM_BYTES;
					
					case  state_write is
					when send_control_byte =>
						if step_counter = 0 then
							if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
								--COMMAND_DONE <= "000";
								COMMAND_I2C <= CMD_START;	--send a 'START' signal to EEPROM
								EXECUTE_I2C <= '1';
								step_counter := step_counter + 1;
							end if;
						elsif step_counter = 1 then
							if COMMAND_RUNNING_I2C = CMD_START then
								step_counter := step_counter + 1;
							end if;
						elsif step_counter = 2 then
							if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
								data_in_i2c_temp := "10100000";	--send the control byte.
								--cmd_i2c_temp	:= CMD_WRITE_BYTE;
								state_write <= write_eeprom_and_ack;
								state_write_next <= write_address;
								step_counter := 0;
							end if;
						end if;
						
					when write_eeprom_and_ack =>
						if step_counter = 0 then
							if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
								DATA_IN_BYTE_I2C <= data_in_i2c_temp;	--send the control byte.
								COMMAND_I2C <= CMD_WRITE_BYTE;
								EXECUTE_I2C <= '1';
								step_counter := step_counter + 1;
							end if;
						elsif step_counter = 1 then
							if COMMAND_RUNNING_I2C = CMD_WRITE_BYTE then
								step_counter := step_counter + 1;
							end if;
						elsif step_counter = 2 then
							if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then 
								COMMAND_I2C <= CMD_WAIT_FOR_ACK;  --wait for ack from slave.
								EXECUTE_I2C <= '1';
								step_counter := step_counter + 1;
							end if;
						elsif step_counter = 3 then
							if COMMAND_RUNNING_I2C = CMD_WAIT_FOR_ACK then
								step_counter := step_counter + 1;
							end if;
						else 
							if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then 
								step_counter := 0;
								state_write <= state_write_next;
							elsif COMMAND_RUNNING_I2C = CMD_WAIT_FOR_ACK then	--need to wait for EEPROM finishing the internal cycle sometimes!
								wait_counter := wait_counter + 1;
								if wait_counter > 100 then
									step_counter := 0;
									wait_counter := 0;
									state_write <= send_control_byte;
								end if;
							end if;
							 
						end if;
						
					when write_address =>
						if address_byte_counter = 0 then		--higher byte
							data_in_i2c_temp := std_logic_vector(EEPROM_address(15 DOWNTO 8));
							state_write_next <= write_address;
							state_write <= write_eeprom_and_ack;
							address_byte_counter := address_byte_counter + 1;
						elsif address_byte_counter = 1 then		--lower byte
							data_in_i2c_temp := std_logic_vector(EEPROM_address(7 DOWNTO 0));
							state_write <= write_eeprom_and_ack;
							state_write_next <= write_bytes;
							address_byte_counter := 0;
						end if;
						
					when write_bytes =>
						--if step_counter = 0 then
							if byte_index_counter < bytes_to_write_counter then	--repeat to write all bytes to EEPROM. Size varies.
								data_in_i2c_temp := bytes_to_write(byte_index_counter);
								state_write <= write_eeprom_and_ack;
								state_write_next <= write_bytes;
								byte_index_counter <= byte_index_counter + 1;
							else		--after all bytes are written to EEPROM
								EEPROM_address <= EEPROM_address + bytes_to_write_counter;	--update the address for next time.
								byte_index_counter <= 0;
								state_write <= write_stop;
								state_write_next <= write_stop;
							end if;
						--end if;
						
					when write_stop =>
						if step_counter = 0 then
							if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
								COMMAND_I2C <= CMD_STOP;
								EXECUTE_I2C <= '1';
								step_counter := step_counter + 1;
							end if;
						elsif step_counter = 1 then
							if COMMAND_RUNNING_I2C = CMD_STOP then
								step_counter := step_counter + 1;
							end if;
						elsif step_counter = 2 then
							if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
								step_counter := step_counter + 1;
							end if;
						else
							if EXECUTE = '0' then
								state <= st_check_state;
								--COMMAND_DONE <= "010";
								step_counter := 0;
								state_write <= send_control_byte;	--reset the state_write, not sure if it works.
							end if;
						end if;
						
					when others =>
						state_write <= write_stop;
					
					end case;
	
				when st_reset_EEPROM_address =>
					state_counter <= "011";
					COMMAND_RUNNING <= CMD_RESET_EEPROM_ADDRESS;
					if step_counter = 0 then
						EEPROM_address <= x"0000";
						--COMMAND_DONE <= "000";
						step_counter := step_counter + 1;
					else
						if EXECUTE = '0' then
							state <= st_check_state;
							step_counter := 0;
							--COMMAND_DONE <= "011";
						end if;
					end if;
					
				when st_reset_bytes_saved =>
					COMMAND_RUNNING <= CMD_RESET_BYTES_SAVED;
					state_counter <= "100";
					if step_counter = 0 then
						bytes_to_write_counter <= 0;
						--COMMAND_DONE <= "000";
						step_counter := step_counter + 1;
					else
					
						if EXECUTE = '0' then
							--COMMAND_DONE <= "100";
							state <= st_check_state;
							
							step_counter := 0;
						end if;
					end if;
					
				
				when others =>
					state <= st_check_state;
					
			END CASE;
		
		END IF;
	END PROCESS;

end Behavioral;
--================================================================
