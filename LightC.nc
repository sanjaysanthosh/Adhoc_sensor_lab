#define NEW_PRINTF_SEMANTICS

configuration LightC {
}
implementation {

	components MainC, LightP, LedsC;
	LightP -> MainC.Boot;
	LightP.Leds -> LedsC;
	components IPStackC;
	components IPDispatchC;
	components UdpC;
	components UDPShellC;
	components RPLRoutingC;;

	components StaticIPAddressTosIdC;

	LightP.RadioControl -> IPStackC;

	components new ShellCommandC("read") as ReadCmd;
	components new ShellCommandC("stream") as StreamCmd;
	LightP.ReadCmd -> ReadCmd;
	LightP.StreamCmd -> StreamCmd;
	components new ShellCommandC("threshold") as TheftCmd;
	LightP.TheftCmd -> TheftCmd;

	components new TimerMilliC() as SensorReadTimer;
	LightP.SensorReadTimer -> SensorReadTimer;
	components new TimerMilliC() as Timer1;
	LightP.Timer1 -> Timer1;
	components new HamamatsuS1087ParC() as SensorPar;
	LightP.ReadPar -> SensorPar.Read;
	LightP.StreamPar -> SensorPar.ReadStream;
	LightP.TheftPar -> SensorPar.ReadStream;
	//components new HamamatsuS1087ParC() as LightPar;
	components new HamamatsuS10871TsrC() as LightTsr;
	//LightP.LightPar -> LightPar.Read;
	LightP.LightTsr -> LightTsr.Read;

	components new  SensirionSht11C() as TemperateHumiditySensor;
	LightP.Temperature -> TemperateHumiditySensor.Temperature;
	LightP.Humidity -> TemperateHumiditySensor.Humidity;

#ifdef PRINTFUART_ENABLED
  /* This component wires printf directly to the serial port, and does
   * not use any framing.  You can view the output simply by tailing
   * the serial device.  Unlike the old printfUART, this allows us to
   * use PlatformSerialC to provide the serial driver.
   *
   * For instance:
   * $ stty -F /dev/ttyUSB0 115200
   * $ tail -f /dev/ttyUSB0
  */
  components SerialPrintfC;

  /* This is the alternative printf implementation which puts the
   * output in framed tinyos serial messages.  This lets you operate
   * alongside other users of the tinyos serial stack.
   */
  // components PrintfC;
  // components SerialStartC;
#endif
}
