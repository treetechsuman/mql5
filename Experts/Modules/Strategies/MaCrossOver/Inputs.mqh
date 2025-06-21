// Inputs
//input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,NZDUSD";
input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCAD";
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double RiskPercent = 1.0;
input int RSIPeriod = 14;
input int ATRPeriod = 7;
input int ADXPeriod = 7;
input int MaPeriod = 5;
input int VolLookback = 30;