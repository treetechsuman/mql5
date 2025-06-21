//+------------------------------------------------------------------+
//|                      Scalper RSI Trend EA                         |
//|                   Optimized for Profitability                     |
//+------------------------------------------------------------------+
#property strict

datetime lastBarTime[];
#include <Trade/Trade.mqh>
#include <ChartObjects/ChartObjectsTxtControls.mqh>
CTrade trade;
/*
input string SymbolsList = "EURUSD,USDJPY,GBPUSD,AUDUSD,USDCAD"; // Focus on major pairs
input int MinVolumeThreshold = 100; 
input ENUM_TIMEFRAMES Timeframe = PERIOD_M1; // Changed to M1 for scalping
input int RSI_Period = 5; // Faster RSI for scalping
input int Rsi_BuyLevel = 38; // Adjusted for early entries
input int Rsi_SellLevel = 62; // Adjusted for early entries
input int EMA_Period = 12; // Faster trend detection
input double ATRMultiplierSL = 0.8; // Tighter stops
input double ATRMultiplierTP = 2.5; // Improved risk-reward ratio
input int Atr_Period = 5; // Shorter ATR for scalping
input double RiskPercent = 0.3; // Reduced risk per trade
input int MACDFastEMA = 5; // Faster MACD settings
input int MACDSlowEMA = 12;
input int MACDSignalSMA = 4;
input bool UseMACDFilter = true;
input bool UseRSIFilter = true;
input bool RequireBothSignals = true; // Stricter entry requirements

// New scalping parameters
input int MaxSpread = 20; // Max allowed spread (points)
input int MaxTradeDuration = 15; // Minutes
input bool UseCandleFilter = true; // Volatility filter
input double TrailingStart = 0.0005; // 5 pips
input double TrailingStep = 0.0003; // 3 pips
*/
input string SymbolsList = "EURUSD,USDJPY,GBPUSD,AUDUSD,USDCAD"; 
input int MinVolumeThreshold = 500;  // Higher for H1
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;

input int RSI_Period = 14;           // Standard RSI for H1
input int Rsi_BuyLevel = 30;         // Deeper oversold
input int Rsi_SellLevel = 70;        // Higher overbought

input int EMA_Period = 21;           // Slower EMA for trend
input double ATRMultiplierSL = 1.5;  // Wider SL for volatility
input double ATRMultiplierTP = 3.0;  // Good risk-reward
input int Atr_Period = 14;           // Standard ATR

input double RiskPercent = 1.0;      // Slightly higher for fewer trades

input int MACDFastEMA = 12;          
input int MACDSlowEMA = 26;          
input int MACDSignalSMA = 9;         // Default MACD settings for H1

input bool UseMACDFilter = true;
input bool UseRSIFilter = true;
input bool RequireBothSignals = true;

input int MaxSpread = 30;            // Allow higher spreads on H1
input int MaxTradeDuration = 240;    // 4 hours max duration
input bool UseCandleFilter = true;
input double TrailingStart = 0.0015; // 15 pips trailing start
input double TrailingStep = 0.0010;  // 10 pips step

string symbolsRaw[];
double lastTrailing[];

int OnInit() {
   StringSplit(SymbolsList, ',', symbolsRaw);
   ArrayResize(lastBarTime, ArraySize(symbolsRaw));
   ArrayResize(lastTrailing, ArraySize(symbolsRaw));
   ArrayInitialize(lastTrailing, 0);
   return INIT_SUCCEEDED;
}

void OnTick() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   //if (hour < SessionStartHour || hour > SessionEndHour) return;

   for (int i = 0; i < ArraySize(symbolsRaw); i++) {
      string symbol = symbolsRaw[i];
      double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
      if (spread > MaxSpread) continue;
      
      MqlRates rates[];
      if (CopyRates(symbol, Timeframe, 0, 5, rates) < 5) continue;
      
      // Volatility filter (skip wide range candles)
      if (UseCandleFilter) {
         double avgRange = 0;
         for (int b = 1; b <= 3; b++) avgRange += (rates[b].high - rates[b].low);
         avgRange /= 3;
         if ((rates[1].high - rates[1].low) > avgRange * 1.8) continue;
      }

      // Check volume on current symbol
      if (rates[1].tick_volume < MinVolumeThreshold) continue;
      if (!SymbolSelect(symbol, true)) continue;

      // Handle open positions
      ManageOpenPositions(symbol, i, rates[0].time);
      
      // Generate signals only on new bar
      bool isNewBar = (lastBarTime[i] != rates[1].time);
      if (isNewBar && !PositionSelect(symbol)) {
         lastBarTime[i] = rates[1].time;
         ProcessSignal(symbol, i);
      }
   }
}

void ProcessSignal(string symbol, int idx) {
   int rsiHandle = iRSI(symbol, Timeframe, RSI_Period, PRICE_CLOSE);
   int emaHandle = iMA(symbol, Timeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   int atrHandle = iATR(symbol, Timeframe, Atr_Period);
   
   if (rsiHandle == INVALID_HANDLE || emaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE) return;

   double rsi[2], ema[3], atr[2];
   if (CopyBuffer(rsiHandle, 0, 0, 2, rsi) != 2) return;
   if (CopyBuffer(emaHandle, 0, 0, 3, ema) != 3) return;
   if (CopyBuffer(atrHandle, 0, 0, 2, atr) != 2) return;

   double macdMain[2], macdSignal[2];
   bool macdUp = true, macdDown = true;

   if (UseMACDFilter) {
      int macdHandle = iMACD(symbol, Timeframe, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE);
      if (macdHandle != INVALID_HANDLE) {
         if (CopyBuffer(macdHandle, 0, 0, 2, macdMain) == 2 && 
             CopyBuffer(macdHandle, 1, 0, 2, macdSignal) == 2) {
            macdUp = macdMain[1] > macdSignal[1] && macdMain[0] > macdSignal[0];
            macdDown = macdMain[1] < macdSignal[1] && macdMain[0] < macdSignal[0];
         }
      }
   }

   MqlRates currentRates[3];
   CopyRates(symbol, Timeframe, 0, 3, currentRates);
   
   bool trendUp = currentRates[1].close > ema[1] && ema[1] > ema[2];
   bool trendDown = currentRates[1].close < ema[1] && ema[1] < ema[2];

   bool rsiBuyOk = !UseRSIFilter || (rsi[1] < Rsi_BuyLevel && rsi[0] > rsi[1]);
   bool rsiSellOk = !UseRSIFilter || (rsi[1] > Rsi_SellLevel && rsi[0] < rsi[1]);
   bool macdBuyOk = !UseMACDFilter || macdUp;
   bool macdSellOk = !UseMACDFilter || macdDown;

   bool buySignal = RequireBothSignals ? (rsiBuyOk && macdBuyOk) : (rsiBuyOk || macdBuyOk);
   bool sellSignal = RequireBothSignals ? (rsiSellOk && macdSellOk) : (rsiSellOk || macdSellOk);

   if (trendUp && buySignal) 
      OpenTrade(symbol, ORDER_TYPE_BUY, SymbolInfoDouble(symbol, SYMBOL_ASK), atr[1]);
   else if (trendDown && sellSignal) 
      OpenTrade(symbol, ORDER_TYPE_SELL, SymbolInfoDouble(symbol, SYMBOL_BID), atr[1]);
}

void OpenTrade(string symbol, ENUM_ORDER_TYPE type, double price, double atr) {
   double sl = (type == ORDER_TYPE_BUY) ? price - atr * ATRMultiplierSL : price + atr * ATRMultiplierSL;
   double tp = (type == ORDER_TYPE_BUY) ? price + atr * ATRMultiplierTP : price - atr * ATRMultiplierTP;
   double lotSize = CalculateLotSize(symbol, RiskPercent, atr);

   trade.SetExpertMagicNumber(1001);

   bool result = false;
   if (type == ORDER_TYPE_BUY)
      result = trade.Buy(lotSize, symbol, price, sl, tp);
   else
      result = trade.Sell(lotSize, symbol, price, sl, tp);

   if (result)
      Print(symbol, ": Trade opened ", EnumToString(type), " Lot: ", lotSize);
   else
      Print(symbol, ": Trade failed. Error: ", GetLastError());
}

double CalculateLotSize(string symbol, double riskPercent, double atr) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   if (tickValue <= 0 || tickSize <= 0 || atr <= 0) return 0.01;
   double pipValue = (tickValue / tickSize) * 10; // Approximate pip value
   double stopLossPips = atr * 10;

   double lot = NormalizeDouble(riskAmount / (stopLossPips * pipValue), 2);
   return MathMax(lot, 0.01);
}

void ManageOpenPositions(string symbol, int idx, datetime currentTime) {
   if (PositionSelect(symbol)) {
      ulong ticket = PositionGetTicket(0);
      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double newSL = openPrice + (openPrice - currentSL) * 0.5;
         
         // Time-based exit
         //if (currentTime - PositionGetInteger(POSITION_TIME) > MaxTradeDuration * 60) {
         //   trade.PositionClose(ticket);
         //   return;
         //}
         
         // Trailing stop logic
         if (currentPrice > openPrice + TrailingStart) {
            if (currentPrice - TrailingStep > currentSL) {
               trade.PositionModify(ticket, currentPrice - TrailingStep, PositionGetDouble(POSITION_TP));
            }
         }
      }
      else { // SELL position
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double newSL = openPrice - (currentSL - openPrice) * 0.5;
         
         // Time-based exit
         //if (currentTime - PositionGetInteger(POSITION_TIME) > MaxTradeDuration * 60) {
         //   trade.PositionClose(ticket);
         //   return;
         //}
         
         // Trailing stop logic
         if (currentPrice < openPrice - TrailingStart) {
            if (currentPrice + TrailingStep < currentSL) {
               trade.PositionModify(ticket, currentPrice + TrailingStep, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}