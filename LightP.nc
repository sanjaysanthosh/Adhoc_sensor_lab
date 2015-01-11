#include <lib6lowpan/ip.h>

#include <Timer.h>
#include "blip_printf.h"

module LightP {
	uses {
		interface Boot;
		interface Leds;
		interface SplitControl as RadioControl;
		interface Timer<TMilli> as SensorReadTimer;

		interface Read<uint16_t> as ReadPar;
		interface ReadStream<uint16_t> as StreamPar;
		interface ReadStream<uint16_t> as TheftPar;
		interface Read<uint16_t> as LightTsr;
		interface Read<uint16_t> as Temperature;
		interface Read<uint16_t> as Humidity;

		interface ShellCommand as ReadCmd;
		interface ShellCommand as StreamCmd;
		interface ShellCommand as TheftCmd;
		interface Timer<TMilli> as Timer1;
	}
} implementation {
	uint16_t m_LightPar, m_LightTsr, m_temp, m_humid;
	uint32_t average=0,threshold=10;
	enum {
		SAMPLE_RATE = 2000,
		SAMPLE_SIZE = 10,
		NUM_SENSORS = 1,
	};
	uint8_t flag=0;

	bool timerStarted = FALSE;
	uint8_t m_remaining = NUM_SENSORS;
	uint32_t m_seq = 0;
	//uint16_t m_par,m_tsr,m_hum,m_temp;
	uint16_t m_parSamples[SAMPLE_SIZE];
	uint16_t m_theftSamples[SAMPLE_SIZE];

	event void Boot.booted() {
		call RadioControl.start();
		call Timer1.startPeriodic(1000);

	}

	error_t checkDone() {
		int len;
		char *reply_buf = call ReadCmd.getBuffer(128); 
		if (--m_remaining == 0) {
			len = sprintf(reply_buf, "%ld %d %d %d %d\r\n", m_seq, m_LightPar,m_LightTsr,m_humid,m_temp);
			//len=sprintf(reply_buf, "%d \t %ld \t %d  \t %d \t %d \t %d \t \n",m_seq,m_LightPar, m_LightTsr,m_temp,m_humid,m_humid);
			m_remaining = NUM_SENSORS;
			m_seq++;
			call ReadCmd.write(reply_buf, len);
		}
		return SUCCESS;
	}
void set_value(error_t error, uint16_t val,uint16_t* var) {
		if (error == SUCCESS)
		  *var = val;
		else
		 *var = 0xFFFF;
	}
	task void checkStreamPar()
	 {
		uint8_t i;
		char *reply_buf = call StreamCmd.getBuffer(128);
		int len = 0;

		 
			for (i = 0; i < SAMPLE_SIZE; i++) 
			{
				average=average+m_parSamples[i];
			}  
			
	//if(flag==0)
		{
		len = sprintf(reply_buf, "[Average: %d] \n", average/SAMPLE_SIZE);
		call StreamCmd.write(reply_buf, len + 1);
		}
	//else if (flag==1)
		/*{
			if (average/10<threshold)
			{
			call Leds.led0On();
			}
			else 
			call Leds.led0Off();
		}*/

		average=0;
	}

	event void SensorReadTimer.fired() {
		call ReadPar.read();
		call LightTsr.read();
		call Temperature.read();
		call Humidity.read();
	}

	event void ReadPar.readDone(error_t e, uint16_t val) {
		//m_par = data;
		set_value(e,val,&m_LightPar); 
		checkDone();
	}

	event void StreamPar.readDone(error_t ok, uint32_t usActualPeriod) {
		if (ok == SUCCESS) {
			flag = 0;
			post checkStreamPar();
		}
	}
event void LightTsr.readDone(error_t error, uint16_t val) {
		set_value(error,val,&m_LightTsr); 
		checkDone();
	}

	event void Temperature.readDone(error_t error, uint16_t val) {
		set_value(error,val,&m_temp);
		checkDone();
	}

	event void Humidity.readDone(error_t error, uint16_t val) {
		set_value(error,val,&m_humid); 
		checkDone();
	}

	event void StreamPar.bufferDone(error_t ok, uint16_t *buf,uint16_t count) {}

	event char* ReadCmd.eval(int argc, char** argv) {
		char* reply_buf = call ReadCmd.getBuffer(18);
		if (timerStarted == FALSE) {
			strcpy(reply_buf, ">>>Start sampling\n");
			call SensorReadTimer.startPeriodic(SAMPLE_RATE);
			timerStarted = TRUE;
		} else {
			strcpy(reply_buf, ">>>Stop sampling\n");
			call SensorReadTimer.stop();
			timerStarted = FALSE;
		}
		return reply_buf;
	}

	event char* StreamCmd.eval(int argc, char* argv[]) {
		char* reply_buf = call StreamCmd.getBuffer(35);
		uint16_t sample_period = 10000; // us -> 100 Hz
		switch (argc) {
			case 2:
				sample_period = atoi(argv[1]);
			case 1: 
				sprintf(reply_buf, "sampleperiod of %d\n", sample_period);
				call StreamPar.postBuffer(m_parSamples, SAMPLE_SIZE);
				call StreamPar.read(sample_period);
				break;
			default:
				strcpy(reply_buf, "Usage: stream <sampleperiod/in us>\n");
		}
		return reply_buf;
	}
	event char* TheftCmd.eval(int argc, char* argv[])
	{
		int len = 0;
		char* reply_buf = call TheftCmd.getBuffer(4);
		threshold = ((uint32_t)argv[1][0]-48)*10+(uint32_t)argv[1][1]-48;
		len=sprintf(reply_buf, "New threshold value:%d \n", threshold);
		return reply_buf;
	}
	event void Timer1.fired()
	{
		call TheftPar.postBuffer(m_parSamples, SAMPLE_SIZE);
		call TheftPar.read(10000);
	}

	task void CheckTheftPar() {
		uint8_t i;
		char *reply_buf = call StreamCmd.getBuffer(128);
		int len = 0;
		
		for (i = 0; i < SAMPLE_SIZE; i++)
		 {
				
				average=average+m_parSamples[i];
		}  
			
		if (average/10<threshold)
		{
			call Leds.led0On();
			len=sprintf(reply_buf,"[Theft Detected!!!]\n");

		}
		else
		{ 
			call Leds.led0Off();
			len=sprintf(reply_buf,"[No Theft Detected]\n");
		}
		average=0;
		return reply_buf;
	}
	event void TheftPar.bufferDone(error_t ok, uint16_t *buf,uint16_t count) {}
	event void TheftPar.readDone(error_t ok, uint32_t usActualPeriod) {
		if (ok == SUCCESS) {
			post CheckTheftPar();
		}
	}

	event void RadioControl.startDone(error_t e) {
		
	}
	event void RadioControl.stopDone(error_t e) {}
}
