// best performer
//input string Symbols = "AUDCAD,GBPUSD,NZDUSD,USDJPY,CADJPY,USDCHF,USDCAD,EURJPY,XAUUSD";           // Keep major liquid pairs
input string Symbols = "EURUSD,GBPUSD";

input ENUM_TIMEFRAMES Timeframe = PERIOD_M1;             // 1-hour for swing/day trades
input double RiskPercent = 0.5;                           // Lower risk per trade, more room for SL
input int RSIPeriod = 14;                                // Standard RSI for smoother signal
input int ATRPeriod = 14;                                // ATR over more candles for stability
input int ADXPeriod = 14;                                // Standard ADX period
input int MaFastPeriod = 20;                             // Typical short MA for H1
input int MaSlowPeriod = 50;                             // Typical long MA for trend confirmation
input int VolLookback = 20;                              // Look back further due to larger TF


