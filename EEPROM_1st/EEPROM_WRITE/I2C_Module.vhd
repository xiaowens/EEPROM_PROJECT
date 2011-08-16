----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:47:52 07/27/2011 
-- Design Name: 
-- Module Name:    I2C_Module - Behavioral 
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

entity I2C_Module is
	generic (
		constant BIT_WIDTH : integer := 8		--ONE BYTE
			);
	port (
		CLK		: IN		STD_LOGIC;
		
		SCL		: INOUT	STD_LOGIC;
		SDA		: INOUT	STD_LOGIC;
		
		-----------COMMAND DEFINE------------------
		--'000'--IDLE
		--'001'--WRITE_BYTE
		--'010'--READ_BYTE
		--'011'--START
		--'100'--SEND_NO_ACK
		--'101'--WAIT_FOR_ACK
		--'110'--SEND_ACK
		--'111'--STOP
		
		
		
		COMMAND		: IN	STD_LOGIC_VECTOR(2 DOWNTO 0);		
		-----------------------------------------------
		EXECUTE		: IN	STD_LOGIC;		--set it back to '0' after send the signal '1'
		--ALWAYS check '--COMMAND_DONE' signal before sending another 'COMMAND'!!
		--COMMAND_DONE			: OUT	STD_LOGIC_vector(2 downto 0);		
		COMMAND_RUNNING			: OUT	STD_LOGIC_vector(2 downto 0);
		state_counter			: out std_logic_vector(2 downto 0);
		
		DATA_IN_BYTE		: IN	STD_LOGIC_VECTOR(7 DOWNTO 0);
		DATA_OUT_BYTE		: OUT	STD_LOGIC_VECTOR(7 DOWNTO 0)
		
			);
end I2C_Module;

architecture Behavioral of I2C_Module is

	type I2C_STATE_TYPE is 
		(	
			st_check_state,
			st_start,			
			st_write_byte,	
			st_read_byte,
			st_idle,
			st_send_no_ack,		
			st_wait_for_ack,
			st_send_ack,		
			st_stop				
		);

	signal state      						: I2C_STATE_TYPE := st_check_state;
	
	
	
begin
	PROCESS (CLK) 
		variable data_to_write_byte				: std_logic_vector(7 downto 0) := x"00";
		variable step_counter						: unsigned(1 downto 0) 	:= "00";
		variable bit_counter						: integer range 0 to BIT_WIDTH  := 0;
		variable data_to_read_byte					: std_logic_vector(7 downto 0) := x"00";
		variable wait_counter					: integer range 0 to 255 := 0;
	BEGIN
		data_to_write_byte := DATA_IN_BYTE;
				
		IF RISING_EDGE(CLK) THEN
			CASE state IS
			WHEN st_check_state =>
				COMMAND_RUNNING <= "000";
				if (EXECUTE = '1') then
					--if (COMMAND /= cmd) then
					--	cmd <= COMMAND;
					--else		--won't work, since EXECUTE goes back to '0'
					
					bit_counter := 0;
					CASE COMMAND IS
					WHEN "000" =>
						state <= st_idle;		--was st_idle
					WHEN "001" =>
						state <= st_write_byte;
					WHEN "010" =>
						state <= st_read_byte;
					WHEN "011" =>
						state <= st_start;		--was st_idle
					WHEN "100" =>
						state <= st_send_no_ack;
					WHEN "101" =>
						state <= st_wait_for_ack;
					WHEN "110" =>
						state <= st_send_ack;
					WHEN "111" =>
						state <= st_stop;
					WHEN OTHERS =>
						state <= st_check_state;		--was st_idle
					END CASE;
					--end if;	--end if (COMMAND /= cmd)
				end if;	
				
			WHEN st_start =>
				state_counter <= "011";
				COMMAND_RUNNING <= "011";
				if (step_counter = 0) then
					----COMMAND_DONE <= "000";
					SCL <= '0';
					step_counter := step_counter + 1;
				elsif (step_counter = 1) then
					SDA <= '1';
					step_counter := step_counter + 1;
				elsif (step_counter = 2) then
					SCL <= '1';
					step_counter := step_counter + 1;
				else
					SDA <= '0';
					if EXECUTE = '0' then
						--COMMAND_DONE <= "011";
						step_counter := "00";
						state <= st_check_state;
					end if;
				end if;	
						
			WHEN st_write_byte =>
				COMMAND_RUNNING <= "001";
				state_counter <= "001";
				if bit_counter < BIT_WIDTH then   
					if step_counter = 0 then 
						--COMMAND_DONE <= "000";
						SCL <= '0';
						step_counter := step_counter + 1;
					elsif step_counter = 1 then
								SDA <= data_to_write_byte(7 - bit_counter);
								--SDA <= DATA_IN_BYTE(7 - bit_counter);
								step_counter := step_counter + 1;
					elsif step_counter = 2 then
								SCL <= '1';
								bit_counter := bit_counter + 1;
								step_counter := "00";
					end if;
				else   --after 1 byte is sent
					if EXECUTE = '0' then
						--COMMAND_DONE <= "001";
						--step_counter := "00";
						bit_counter := 0;
						state <= st_check_state;
					end if;		
				end if;
						
						
			WHEN st_read_byte =>
				COMMAND_RUNNING <= "010";
				state_counter <= "010";
				if bit_counter < BIT_WIDTH  then   
					if step_counter = 0 then 
						--COMMAND_DONE <= "000";
						SCL <= '0';
						step_counter := step_counter + 1;
					elsif step_counter = 1 then
						SCL <= '1';
						step_counter := step_counter + 1;
					elsif step_counter = 2 then
						data_to_read_byte(7 - bit_counter) := SDA;  
						bit_counter := bit_counter + 1;
						step_counter := "00";
					end if;
				else   --after 1 byte is read
					if step_counter = 0 then
						DATA_OUT_BYTE <= data_to_read_byte;
						step_counter := step_counter + 1;
					else
						if EXECUTE = '0' then
							--COMMAND_DONE <= "010";
							step_counter := "00";
							state <= st_check_state;
							bit_counter := 0;
						end if;	
					end if;		
				end if;
						
						
			WHEN st_idle =>
				COMMAND_RUNNING <= "000";
				state_counter <= "000";
				SCL <= '1';
				SDA <= '1';
				if EXECUTE = '0' then
					--COMMAND_DONE <= "000";
					state <= st_check_state;
				end if;
						
			WHEN st_send_no_ack =>
				COMMAND_RUNNING <= "100";
				state_counter <= "100";
				if (step_counter = 0) then
					--COMMAND_DONE <= "000";
					SCL <= '0';
					step_counter := step_counter + 1;
				elsif (step_counter = 1) then
					SDA <= '1';  			 --sending the 'NO' ack to the slave
					step_counter := step_counter + 1;
				elsif (step_counter = 2) then
					SCL <= '1';
					step_counter := step_counter + 1;
				elsif (step_counter = 3) then
					SCL <= '0';
					--SDA <= 'Z';				 --release the SDA wire for the slave
					if EXECUTE = '0' then
						--COMMAND_DONE <= "100";
						step_counter := "00";
						state <= st_check_state;
					end if;
				end if;
						
					
			WHEN st_wait_for_ack =>
				COMMAND_RUNNING <= "101";
				state_counter <= "101";
				if step_counter = 0 then
					--COMMAND_DONE <= "000";
					SCL <= '0';
					step_counter := step_counter + 1;
				elsif step_counter = 1 then
					SDA <= 'Z';
					step_counter := step_counter + 1;
				elsif step_counter = 2 then
					SCL <= '1';
					step_counter := step_counter + 1;
				elsif step_counter = 3 then
					if SDA = '0' then
						if EXECUTE = '0' then
							--COMMAND_DONE <= "101";
							step_counter := "00";
							state <= st_check_state;
						end if;
					else
						wait_counter := wait_counter + 1;
						if wait_counter > 200 then
							if EXECUTE = '0' then
								step_counter := "00";
								state <= st_check_state;
							end if;
						end if;
					end if;
				end if;
						
						
			WHEN st_send_ack =>
				COMMAND_RUNNING <= "110";
				state_counter <= "110";
				if (step_counter = 0) then
					--COMMAND_DONE <= "000";
					SCL <= '0';
					step_counter := step_counter + 1;
				elsif (step_counter = 1) then
					SDA <= '0';  			 --sending the ack to the slave
					step_counter := step_counter + 1;
				elsif (step_counter = 2) then
					SCL <= '1';
					step_counter := step_counter + 1;
				elsif (step_counter = 3) then
					SCL <= '0';
					SDA <= 'Z';				 --release the SDA wire for the slave
					if EXECUTE = '0' then
						--COMMAND_DONE <= "110";
						step_counter := "00";
						state <= st_check_state;
					end if;	
				end if;
					
			WHEN st_stop =>
				COMMAND_RUNNING <= "111";
				state_counter <= "111";
				if step_counter = 0 then
					--COMMAND_DONE <= "000";
					SCL <= '0';
					step_counter := step_counter + 1;
				elsif step_counter = 1 then
					SDA <= '0';
					step_counter := step_counter + 1;
				elsif step_counter = 2 then
					SCL <= '1';
					step_counter := step_counter + 1;
				else
					SDA <= '1';
					if EXECUTE = '0' then
						--COMMAND_DONE <= "111";
						step_counter := "00";
						state <= st_check_state;
					end if;
				end if;
				
			END CASE;		
		END IF;  --RISING_EDGE(CLK)
	END PROCESS;

end Behavioral;

