// best performer
input string Symbols = "EURUSD,GBPUSD,XAUUSD";           // Keep major liquid pairs
//input string Symbols = "EURUSD,GBPUSD,USDJPY,AUDUSD,NZDUSD,USDCAD,USDCHF,EURJPY,GBPJPY,AUDJPY,NZDJPY,CHFJPY,CADJPY,EURAUD,EURNZD,EURCAD,GBPAUD,GBPCHF,AUDCAD";

input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;             // 1-hour for swing/day trades
input double RiskPercent = 2;                           // Lower risk per trade, more room for SL
input int RSIPeriod = 14;                                // Standard RSI for smoother signal
input int ATRPeriod = 14;                                // ATR over more candles for stability
input int ADXPeriod = 14;                                // Standard ADX period
input int Ma15MPeriod = 20;                             // Typical short MA for H1
input int Ma1HPeriod = 50;                             // Typical long MA for trend confirmation
input int VolLookback = 20;                              // Look back further due to larger TF


//scalping

//input string Symbols = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,NZDUSD";  // Major pairs with low spread
//input ENUM_TIMEFRAMES Timeframe = PERIOD_M5;                         // M5 timeframe for scalping
//input double RiskPercent = 0.5;                                      // Lower risk per fast trade
//input int RSIPeriod = 9;                                             // Faster RSI
//input int ATRPeriod = 7;                                             // ATR reacts quickly to spikes
//input int ADXPeriod = 5;                                             // Shorter to capture early trend
//input int MaFastPeriod = 5;                                          // Fast MA for quick cross
//input int MaSlowPeriod = 13;                                         // Smoother but responsive
//input int VolLookback = 10;                                          // Tighter volume window

// 4 hour 
//input string Symbols        = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,NZDUSD";  // Major pairs remain the same
//input ENUM_TIMEFRAMES Timeframe = PERIOD_H4;                                // Switched to H4
//
//input double RiskPercent    = 1.0;      // Still good; can lower to 0.5% for high drawdown systems
//
//// === Indicator Periods (scaled for H4) ===
//input int RSIPeriod         = 21;       // Smoother RSI for H4 (14 x 1.5)
//input int ATRPeriod         = 28;       // Capture broader H4 volatility (21 x 1.3)
//input int ADXPeriod         = 20;       // Catch mid- to long-term trends
//
//input int MaFastPeriod      = 34;       // 20 on H1 ≈ 34 on H4 (scaling x1.7)
//input int MaSlowPeriod      = 89;       // 50 on H1 ≈ 89 on H4 (commonly used slow MA)
//
//input int VolLookback       = 30;       // More candles = better volume context for higher TF