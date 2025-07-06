// optimized pair
//input string   Symbols        = "EURUSD,GBPUSD,EURGBP"; // Comma-separated symbols
//input string Symbols = "EURUSD,GBPUSD,EURGBP,EURCHF,AUDNZD,GBPCHF,NZDCAD,USDCAD,EURCAD,AUDCAD,CHFJPY";
input string Symbols = "EURUSD,GBPUSD,EURGBP,EURCHF,AUDNZD,GBPCHF,NZDCAD,USDCAD,EURCAD,AUDCAD,CHFJPY";
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

input int      VolLookback    = 48;              // Volatility lookback periods
input double   SqueezeFactor  = 0.85;            // Squeeze threshold factor
input bool     UseVolume      = true;            // Use volume confirmation
