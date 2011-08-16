----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:21:23 07/29/2011 
-- Design Name: 
-- Module Name:    EEPROM_I2C_INTERFACE_READ - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		It can read at any given address from the EEPROM.
--							The max. size of read out data is 32 bytes. Size of every read out could vary.
--							The address pointer in the EEPROM will automatically increase by one after every byte was read.
--							So for a sequencial reading out, just send an control byte with the 'read' bit 'hight'.
--							Need to specify # of bytes to be read out each time through input port 'NUM_OF_BYTES'.
--							It transfers out the saved read out data one byte at a time.
--							Input 'NUM_OF_BYTES' will work as part of the transferring command 
--								to transfer certain byte at that position of the data array. range 0 to 31. could vary.
--								e.g. if 'NUM_OF_BYTES'=0, byte_array[0] will be transferred out.
--							Output 'INDEX_OF_BYTES' is used to indicate which byte was transferred out.  
-- Dependencies: 		I2C_Module
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
--=======================================================================================================
entity EEPROM_I2C_INTERFACE_READ is
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
		
		INDEX_OF_BYTES	: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);	--showing which byte is transferred out. MAX # OF BYTES => 2^5=32 BYTES
		DATA_OUT_BYTE	: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
		
		SCL				: INOUT STD_LOGIC;
		SDA				: INOUT STD_LOGIC
		);
end EEPROM_I2C_INTERFACE_READ;
--=======================================================================================================
architecture Behavioral of EEPROM_I2C_INTERFACE_READ is

--=======================================================================================================
	----------------------------------------------------------------------------------------
	component I2C_Module 
	port (
		CLK		: IN		STD_LOGIC;
		SCL		: INOUT	STD_LOGIC;
		SDA		: INOUT	STD_LOGIC;
		COMMAND		: IN	STD_LOGIC_VECTOR(2 DOWNTO 0);		
		COMMAND_RUNNING			: OUT	STD_LOGIC_vector(2 downto 0);	
		
		EXECUTE				: IN	STD_LOGIC;	
		DATA_IN_BYTE		: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
		DATA_OUT_BYTE		: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0)
			);
	end component;
	----------------------------------------------------------------------------------------

	SIGNAL COMMAND_RUNNING_I2C		: STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL DATA_IN_BYTE_I2C		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL DATA_OUT_BYTE_I2C		: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL COMMAND_I2C			: STD_LOGIC_VECTOR(2 DOWNTO 0);
	SIGNAL EXECUTE_I2C					: STD_LOGIC;
	
	---------------------MAIN STATE TYPE------------------------------------------------
	type EEPROM_I2C_INTERFACE_READ_MAIN_STATE_TYPE is 
		(	st_set_address,
			st_read_EEPROM,
			st_transfer_read_out,
			st_check_state
		);

	signal state      : EEPROM_I2C_INTERFACE_READ_MAIN_STATE_TYPE := st_check_state;
	
----------------SUB-STATE TYPE FOR "st_set_address" in the main state---------
	type SET_ADDRESS_STATE_TYPE is
		(	send_control_byte,
			write_eeprom_and_ack,
			write_address,
			set_address_done
		);
	signal state_set_address, state_set_address_next	: SET_ADDRESS_STATE_TYPE := send_control_byte;
------------------------------------------------------------------------------------------
	type bytes_read_out_type is array(0 TO PAGE_SIZE-1) of std_logic_vector(7 downto 0);
	
	signal bytes_read_out					: bytes_read_out_type;
	signal bytes_read_out_counter			: integer range 0 to PAGE_SIZE := 0;
	
--=======================================================================================================	
begin
------------------------------------------------------
	I2C	: I2C_Module 
	port map (
		CLK		=> CLK,
		SCL		=> SCL,
		SDA		=> SDA,
		COMMAND		=> COMMAND_I2C,		
		COMMAND_RUNNING		=> COMMAND_RUNNING_I2C,	
		EXECUTE			=> EXECUTE_I2C,	
		DATA_IN_BYTE		=> DATA_IN_BYTE_I2C,
		DATA_OUT_BYTE		=> DATA_OUT_BYTE_I2C
			);
------------------------------------------------------
	PROCESS (CLK)
	
		--=============================================================================
		------------COMMANDS FOR I2C MODULE USED HERE--------------------
		CONSTANT CMD_CHECK_COMMAND			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";		
		CONSTANT CMD_WRITE_BYTE				: STD_LOGIC_VECTOR(2 DOWNTO 0) := "001"; 
		CONSTANT CMD_READ_BYTE				: STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
		CONSTANT CMD_START					: STD_LOGIC_VECTOR(2 DOWNTO 0) := "011";
		CONSTANT CMD_SEND_NO_ACK			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "100";
		CONSTANT CMD_WAIT_FOR_ACK			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "101";
		CONSTANT CMD_SEND_ACK				: STD_LOGIC_VECTOR(2 DOWNTO 0) := "110";
		CONSTANT CMD_STOP						: STD_LOGIC_VECTOR(2 DOWNTO 0) := "111";
		----------------------------------------------------------------
		-----------COMMAND FOR EEPROM_I2C_INTERFACE_READ MODULE----------------
		CONSTANT CMD_SET_ADDRESS			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "001";
		CONSTANT CMD_READ_EEPROM			: STD_LOGIC_VECTOR(2 DOWNTO 0) := "010";
		CONSTANT CMD_TRANSFER_READ_OUT	: STD_LOGIC_VECTOR(2 DOWNTO 0) := "011";
		
		-----------------------------------------------------------------------
		variable EEPROM_address							: std_logic_vector(15 downto 0) := x"0000";
		variable step_counter, sub_step_counter	: integer range 0 to 16 := 0;
		variable num_of_bytes_to_read					: integer range 0 to PAGE_SIZE := 0;
		variable data_in_i2c_temp						: std_logic_vector(7 downto 0);
		variable wait_counter							: integer range 0 to 128 := 0;
		variable address_byte_counter					: integer range 0 to 1 := 0;
		variable index_of_bytes_to_transfer			: integer range 0 to (PAGE_SIZE-1) := 0;
		
		--==============================================================================
	BEGIN
		IF RISING_EDGE(CLK) THEN
			--#############################
			IF EXECUTE_I2C = '1' THEN
				EXECUTE_I2C <= '0';			--RESET SIGNAL 'EXECUTE' TO '0'!
			END IF;
			--#############################
			--==============================CASE STATE BEGIN==================================================
			CASE state IS
				-----------------------------------------------------------------------------------------------	
				WHEN st_check_state =>
					COMMAND_RUNNING <= CMD_CHECK_COMMAND;
					if EXECUTE = '1' then
						case COMMAND is
							when CMD_SET_ADDRESS =>
								state <= st_set_address;
							when CMD_READ_EEPROM =>
								state <= st_read_EEPROM;
							when CMD_TRANSFER_READ_OUT =>
								state <= st_transfer_read_out;
							when others =>
								state <= st_check_state;
						end case;
					end if;
				-----------------------------------------------------------------------------------------------		
				WHEN st_set_address =>
					COMMAND_RUNNING <= CMD_SET_ADDRESS;
					EEPROM_address(15 downto 0) :=  "000" & ADDRESS(12 downto 0);
					--=======================CASE STATE_SET_ADDRESS BEGIN=========================
					CASE state_set_address IS
					---------------------------------------------------------------
					when send_control_byte =>
						if step_counter = 0 then
							if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
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
								state_set_address <= write_eeprom_and_ack;
								state_set_address_next <= write_address;
								step_counter := 0;
							end if;
						end if;
					---------------------------------------------------------------	
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
								state_set_address <= state_set_address_next;
							elsif COMMAND_RUNNING_I2C = CMD_WAIT_FOR_ACK then	--need to wait for EEPROM finishing the internal cycle sometimes!
								wait_counter := wait_counter + 1;
								if wait_counter > 100 then
									step_counter := 0;
									wait_counter := 0;
									state_set_address <= send_control_byte;
								end if;
							end if;
							 
						end if;
					---------------------------------------------------------------	
					when write_address =>
						if address_byte_counter = 0 then		--higher byte
							data_in_i2c_temp := std_logic_vector(EEPROM_address(15 DOWNTO 8));
							state_set_address_next <= write_address;
							state_set_address <= write_eeprom_and_ack;
							address_byte_counter := address_byte_counter + 1;
						elsif address_byte_counter = 1 then		--lower byte
							data_in_i2c_temp := std_logic_vector(EEPROM_address(7 DOWNTO 0));
							state_set_address <= write_eeprom_and_ack;
							state_set_address_next <= set_address_done;
							address_byte_counter := 0;
						end if;
					---------------------------------------------------------------	
						
					when set_address_done =>
						if EXECUTE = '0' then
								state <= st_check_state;
								state_set_address <= send_control_byte;
						end if;
					---------------------------------------------------------------
					when others =>
						state_set_address <= send_control_byte;

					END CASE;
					--=======================CASE STATE_SET_ADDRESS END=========================
				-----------------------------------------------------------------------------------------------		
					
				WHEN st_read_EEPROM =>
					COMMAND_RUNNING <= CMD_READ_EEPROM;
					if step_counter = 0 then
						
						num_of_bytes_to_read := to_integer(unsigned(NUM_OF_BYTES));
						if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
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
								DATA_IN_BYTE_I2C <= "10100001";	--send the control byte, ready to read.
								COMMAND_I2C <= CMD_WRITE_BYTE;
								EXECUTE_I2C <= '1';
								step_counter := step_counter + 1;
						end if;
					elsif step_counter = 3 then
						if COMMAND_RUNNING_I2C = CMD_WRITE_BYTE then
							step_counter := step_counter + 1;
						end if;
					elsif step_counter = 4 then
						if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
								COMMAND_I2C <= CMD_WAIT_FOR_ACK;		--ACK
								EXECUTE_I2C <= '1';
								step_counter := step_counter + 1;
						end if;
					elsif step_counter = 5 then
						if COMMAND_RUNNING_I2C = CMD_WAIT_FOR_ACK then
							step_counter := step_counter + 1;
						end if;	
					elsif step_counter = 6 then
						if bytes_read_out_counter < num_of_bytes_to_read then	--repeat to read all bytes to EEPROM. Size varies.
							if sub_step_counter = 0 then
								if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
									COMMAND_I2C <= CMD_READ_BYTE;
									EXECUTE_I2C <= '1';
									sub_step_counter := sub_step_counter + 1; 
								end if;
							elsif sub_step_counter = 1 then
								if COMMAND_RUNNING_I2C = CMD_READ_BYTE then
									sub_step_counter := sub_step_counter + 1;
								end if;
							elsif sub_step_counter = 2 then
								if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
									bytes_read_out(bytes_read_out_counter) <= DATA_OUT_BYTE_I2C;
									if (bytes_read_out_counter /= (num_of_bytes_to_read - 1)) then
										COMMAND_I2C <= CMD_SEND_ACK;
									else
										COMMAND_I2C <= CMD_SEND_NO_ACK;	--TO TERMINATE THE READING
									end if;
									EXECUTE_I2C <= '1';
									sub_step_counter := sub_step_counter + 1;
								end if;
							elsif sub_step_counter = 3 then
								if (COMMAND_RUNNING_I2C = CMD_SEND_ACK) OR (COMMAND_RUNNING_I2C = CMD_SEND_NO_ACK) then
									sub_step_counter := sub_step_counter + 1;
								end if;
							elsif sub_step_counter = 4 then
								if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
									sub_step_counter := 0;
									bytes_read_out_counter <= bytes_read_out_counter + 1;
								end if;
							end if;	
						else --after read out the # of bytes
								bytes_read_out_counter <= 0;
								step_counter := step_counter + 1;
						end if;
						
					elsif step_counter = 7 then
						if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
								COMMAND_I2C <= CMD_STOP;		--STOP
								EXECUTE_I2C <= '1';
								step_counter := step_counter + 1;
						end if;
					elsif step_counter = 8 then
						if COMMAND_RUNNING_I2C = CMD_STOP then
							step_counter := step_counter + 1;
						end if;	
					else
						if COMMAND_RUNNING_I2C = CMD_CHECK_COMMAND then
							if EXECUTE_I2C = '0' then 
								state <= st_check_state;
								step_counter := 0;
							end if;
						end if;
					end if;
				-----------------------------------------------------------------------------------------------	

				WHEN st_transfer_read_out =>
					COMMAND_RUNNING <= CMD_TRANSFER_READ_OUT;
					index_of_bytes_to_transfer := to_integer(unsigned(NUM_OF_BYTES));
					if index_of_bytes_to_transfer < num_of_bytes_to_read then
						DATA_OUT_BYTE <= bytes_read_out(index_of_bytes_to_transfer);
						INDEX_OF_BYTES <= std_logic_vector(to_unsigned(index_of_bytes_to_transfer, 5));
					end if;
					state <= st_check_state;
				-----------------------------------------------------------------------------------------------	
					
				WHEN OTHERS =>
					state <= st_check_state;
		
			END CASE;
			--==============================CASE STATE END==================================================
		END IF;
	END PROCESS;
	state_I2C <= COMMAND_RUNNING_I2C;	--for debugging. send the state of I2C_Module to oscilloscope.
end Behavioral;

