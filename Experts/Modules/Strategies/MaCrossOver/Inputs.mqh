// Inputs for 5 min
//input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,NZDUSD";
/*
input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCAD";
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double RiskPercent = 2.0;
input int RSIPeriod = 5;
input int ATRPeriod = 5;
input int ADXPeriod = 3;
input int MaPeriod = 3;
input int VolLookback = 10;*/


// best for one hour
input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCAD";
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;
input double RiskPercent = 1.0;
input int RSIPeriod = 14;
input int ATRPeriod = 7;
input int ADXPeriod = 7;
input int MaPeriod = 5;
input int VolLookback = 30;