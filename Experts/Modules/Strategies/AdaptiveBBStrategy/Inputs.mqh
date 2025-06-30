// Input parameters
//input string   Symbols        = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,NZDUSD"; // Comma-separated symbols
//input string Symbols = "XAUUSD,EURUSD,GBPUSD,USDJPY,AUDUSD,NZDUSD,USDCAD,USDCHF,EURJPY,GBPJPY,AUDJPY,NZDJPY,CHFJPY,CADJPY,EURAUD,EURNZD,EURCAD,GBPAUD,GBPCHF,AUDCAD";
input string Symbols = "EURUSD,GBPUSD";
input ENUM_TIMEFRAMES Timeframe    = PERIOD_H1;
input double   RiskPercent    = 1.0;             // Risk per trade (% of balance)
input int      BBPeriod       = 20;              // Bollinger Bands period

input int      BBEntryDeviation = 2;
input int      BBProfitExitDeviation = 1;
input int      BBLossExitDeviation = 6;

input int      RSIPeriod      = 14;              // RSI period
input int      RSIUpperLevel    = 55;
input int      RSILowerLevel    = 45;

input int      ADXPeriod      = 14;              // ADX period
input int      ADXTradeValue = 25;

input int      fastMaPeriod   =9;
input int      slowMaPeriod   =21;

input int      ATRPeriod      =21;

input int      VolLookback    = 30;              // Volatility lookback periods
input double   SqueezeFactor  = 0.85;            // Squeeze threshold factor
input bool     UseVolume      = true;            // Use volume confirmation
