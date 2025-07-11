//+------------------------------------------------------------------+
//|                                                  AdaptiveBB.mq5  |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include <Arrays\ArrayObj.mqh> // Required for CArrayObj
#include "Modules/InfoDashboard.mqh"
#include "Modules/SymbolReport.mqh"
#include "Modules/Utils.mqh"
#include "Modules/LossCooldownManager.mqh"

// Input parameters
input string   Symbols        = "EURUSD,GBPUSD,USDJPY,USDCHF,USDCAD,NZDUSD"; // Comma-separated symbols
input ENUM_TIMEFRAMES Timeframe    = PERIOD_H1;
input double   RiskPercent    = 1.0;             // Risk per trade (% of balance)
input int      BBPeriod       = 20;              // Bollinger Bands period
input double   BBDeviation    = 2.0;             // Bollinger Bands deviation
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

input int      VolLookback    = 30;              // Volatility lookback periods
input double   SqueezeFactor  = 0.85;            // Squeeze threshold factor
input bool     UseVolume      = true;            // Use volume confirmation

// Global objects
class SymbolData : public CObject {
public:
   string symbol;
   int fastMaHandle, slowMaHandle,rsiHandle, bbEntryHandle,bbProfitExitHandle,bbLossExitHandle, adxHandle, atrHandle;
   double fastMa[],slowMa[],atr[], upperLossExitBand[], lowerLossExitBand[], upperProfitExitBand[],lowerProfitExitBand[], upperEntryBand[],lowerEntryBand[], middleBand[], rsi[], adx[], plusDI[], minusDI[];
   long volumes[];
   datetime lastTradeTime;
   MqlRates priceData[];

   bool Init(string sym) {
      symbol = sym;
      rsiHandle = iRSI(symbol, Timeframe, RSIPeriod, PRICE_CLOSE);
      bbEntryHandle = iBands(symbol, Timeframe, BBPeriod, 0, BBEntryDeviation, PRICE_CLOSE);
      bbProfitExitHandle = iBands(symbol, Timeframe, BBPeriod, 0, BBProfitExitDeviation, PRICE_CLOSE);
      bbLossExitHandle = iBands(symbol, Timeframe, BBPeriod, 0, BBLossExitDeviation, PRICE_CLOSE);
      adxHandle = iADX(symbol, Timeframe, ADXPeriod);
      atrHandle = iATR(symbol,Timeframe,20);
      fastMaHandle = iMA(symbol,Timeframe,fastMaPeriod,0,MODE_EMA,PRICE_CLOSE);
      slowMaHandle = iMA(symbol,Timeframe,slowMaPeriod,0,MODE_EMA,PRICE_CLOSE);

      ArraySetAsSeries(upperEntryBand, true);
      ArraySetAsSeries(middleBand, true);
      ArraySetAsSeries(lowerEntryBand, true);
      ArraySetAsSeries(upperProfitExitBand, true);
      ArraySetAsSeries(lowerProfitExitBand, true);
      ArraySetAsSeries(upperLossExitBand, true);
      ArraySetAsSeries(lowerLossExitBand, true);
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(adx, true);
      ArraySetAsSeries(plusDI, true);
      ArraySetAsSeries(minusDI, true);
      ArraySetAsSeries(volumes, true);
      ArraySetAsSeries(priceData, true);
      ArraySetAsSeries(slowMa, true);
      ArraySetAsSeries(fastMa, true);
      return (rsiHandle != INVALID_HANDLE && bbEntryHandle != INVALID_HANDLE &&bbProfitExitHandle != INVALID_HANDLE &&bbLossExitHandle != INVALID_HANDLE && adxHandle != INVALID_HANDLE);
   }
};

CArrayObj contexts;
CTrade trade;
string   tradeSymbols[];
datetime lastTradeTime[];
string Rows[] = {"MarketSignal", "CandelSignal", "RsiSignal","ADX Confirmation", "Symbol"};
CSymbolReportManager reportManager;
LossCooldownManager cooldown(2, 60);  // Max 2 losses, 60 min cooldown

int TimeHour(datetime t) {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
}

//+------------------------------------------------------------------+
int OnInit() {
   contexts.Clear();
   string list[];
   StringSplit(Symbols, ',', list);
   for(int i = 0; i < ArraySize(list); i++) {
      SymbolData *sd = new SymbolData;
      if(sd.Init(list[i]))
         contexts.Add(sd);
      else
         delete sd;
   }
   ArrayResize(lastTradeTime, ArraySize(list));
   InitDashboard(list, Rows, 20, 20);
   ArrayInitialize(lastTradeTime, 0);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for(int i = 0; i < contexts.Total(); i++) {
      SymbolData *sd = (SymbolData*)contexts.At(i);
      IndicatorRelease(sd.rsiHandle);
      IndicatorRelease(sd.bbEntryHandle);
      IndicatorRelease(sd.bbProfitExitHandle);
      IndicatorRelease(sd.bbLossExitHandle);
      IndicatorRelease(sd.adxHandle);
      IndicatorRelease(sd.fastMaHandle);
      IndicatorRelease(sd.slowMaHandle);
      
   }
   reportManager.PrintAll();  // This prints to Experts log
   contexts.Clear();
}

//+------------------------------------------------------------------+
void OnTick() {
   for(int i = 0; i < contexts.Total(); i++) {
      SymbolData *sd = (SymbolData*)contexts.At(i);
      ProcessSymbol(sd);
      string symbol = sd.symbol;
      string symbolReport="No report yet";
      if(reportManager.HasReport("EURUSD")) {
         CSymbolReportData *data = reportManager.GetReport(symbol);
         //Print("Win Rate: ", data.WinRate(), "%");
         symbolReport = "Trade:";// + DoubleToString(data.WinRate(), 2);  // 2 = number of decimals;
         
      }
      string marketSignal = GetMarketState(sd);
      string candleSignal = CandelSignal(sd);
      string rsiSignal = RsiSignal(sd);
      string adxValue = NormalizeDouble(sd.adx[0],2);
      SignalStatus s1;
      ArrayResize(s1.values, 5);
      s1.values[0] = marketSignal;
      s1.values[1] = candleSignal;
      s1.values[2] = rsiSignal;
      s1.values[3] = adxValue;
      s1.values[4] = symbol;
      UpdateDashboard(symbol, s1);
   }
}

//+------------------------------------------------------------------+
void ProcessSymbol(SymbolData *sd) {
   if(sd.lastTradeTime == iTime(sd.symbol, Timeframe, 0)) return;
   sd.lastTradeTime = iTime(sd.symbol, Timeframe, 0);

   CopyRates(sd.symbol, Timeframe, 0, VolLookback, sd.priceData);
   CopyTickVolume(sd.symbol, Timeframe, 0, VolLookback, sd.volumes);
   CopyBuffer(sd.bbEntryHandle, 1, 0, VolLookback, sd.upperEntryBand);
   CopyBuffer(sd.bbEntryHandle, 0, 0, VolLookback, sd.middleBand);
   CopyBuffer(sd.bbEntryHandle, 2, 0, VolLookback, sd.lowerEntryBand);
   CopyBuffer(sd.bbProfitExitHandle, 1, 0, VolLookback, sd.upperProfitExitBand);
   CopyBuffer(sd.bbProfitExitHandle, 2, 0, VolLookback, sd.lowerProfitExitBand);
    CopyBuffer(sd.bbLossExitHandle, 1, 0, VolLookback, sd.upperLossExitBand);
   CopyBuffer(sd.bbLossExitHandle, 2, 0, VolLookback, sd.lowerLossExitBand);
   
   CopyBuffer(sd.rsiHandle, 0, 0, VolLookback, sd.rsi);
   CopyBuffer(sd.adxHandle, 0, 0, VolLookback, sd.adx);
   CopyBuffer(sd.adxHandle, 1, 0, VolLookback, sd.plusDI);
   CopyBuffer(sd.adxHandle, 2, 0, VolLookback, sd.minusDI);
   CopyBuffer(sd.atrHandle, 0, 0, VolLookback, sd.atr);
   CopyBuffer(sd.slowMaHandle, 0, 0, VolLookback, sd.slowMa);
   CopyBuffer(sd.fastMaHandle, 0, 0, VolLookback, sd.fastMa);

   double ask = SymbolInfoDouble(sd.symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sd.symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(sd.symbol, SYMBOL_POINT);
   double spread = SymbolInfoInteger(sd.symbol, SYMBOL_SPREAD) * point;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100);
   double lotSize = 0.1;

   string marketState = GetMarketState(sd);

   if(marketState=="Squeeze") {
      //HandleSqueezeState(sd, ask, bid, point, spread, riskAmount, lotSize);
      //HandleRangingState(sd, ask, bid, point, spread, riskAmount, lotSize);
   }
   if(marketState=="Trending") {
      HandleTrendingState(sd, ask, bid, point, spread, riskAmount, lotSize);
      //HandleMaTrendingState(sd, ask, bid, point, spread, riskAmount, lotSize);
      //HandleRangingState(sd, ask, bid, point, spread, riskAmount, lotSize);
   }
   if(marketState=="Ranging") {
      //HandleRangingState(sd, ask, bid, point, spread, riskAmount, lotSize);
   }
      

   ManageExits(sd, ask, bid, point);
}

//+------------------------------------------------------------------+
/*string GetMarketState(SymbolData *sd) {
   double bw = sd.upperEntryBand[0] - sd.lowerEntryBand[0], avgBW = 0;
   for(int i = 1; i < VolLookback; i++) avgBW += (sd.upperEntryBand[i] - sd.lowerEntryBand[i]);
   avgBW /= VolLookback;
   if(bw < avgBW * SqueezeFactor) return "Squeeze";
   if(sd.adx[0] > 25) {
      if(sd.plusDI[0] > sd.minusDI[0] && sd.priceData[0].close > sd.middleBand[0]) return "Trending";
      if(sd.minusDI[0] > sd.plusDI[0] && sd.priceData[0].close < sd.middleBand[0]) return "Trending";
   }
   if(sd.adx[0] < 20 &&
      MathAbs(sd.upperEntryBand[0] - sd.upperEntryBand[1]) < 10*_Point &&
      MathAbs(sd.lowerEntryBand[0] - sd.lowerEntryBand[1]) < 10*_Point) return "Ranging";
   return "non";
}*/

string GetMarketState(SymbolData *sd) {
   double bw = sd.upperEntryBand[0] - sd.lowerEntryBand[0];  // current BB width
   double avgBW = 0;
   for(int i = 1; i < VolLookback; i++) 
      avgBW += (sd.upperEntryBand[i] - sd.lowerEntryBand[i]);
   avgBW /= VolLookback;

   double atr = sd.atr[0];  // assume you're storing ATR per symbol in sd

   // === Squeeze Detection with Buffer ===
   double strictSqueeze = avgBW * SqueezeFactor;           // e.g., 0.8
   double bufferSqueeze = strictSqueeze * 1.1;              // add 10% tolerance

   if(bw < strictSqueeze) return "Squeeze";
   if(bw < strictSqueeze && avgBW > 0.0001) return "Squeeze";
   if(bw < bufferSqueeze) return "SqueezeLikely";  // transitional

   // === Trending Detection with ADX Buffer ===
   double adx = sd.adx[0];
   double plusDI = sd.plusDI[0];
   double minusDI = sd.minusDI[0];
   double price = sd.priceData[0].close;
   double midBand = sd.middleBand[0];
   double diGap = MathAbs(plusDI - minusDI);
   if(adx > (ADXTradeValue+2)&& diGap > 2) {
      double diGap = MathAbs(plusDI - minusDI);
      if(plusDI > minusDI && price > midBand) return "Trending";
      if(minusDI > plusDI && price < midBand) return "Trending";
   }

   // === Ranging Detection with ATR-based Band Stability ===
   if(adx < (ADXTradeValue-2) &&
      MathAbs(sd.upperEntryBand[0] - sd.upperEntryBand[1]) < atr * 0.1 &&
      MathAbs(sd.lowerEntryBand[0] - sd.lowerEntryBand[1]) < atr * 0.1)
      return "Ranging";

   // === Neutral fallback ===
   double slope = sd.middleBand[0] - sd.middleBand[3];  // Over 3 candles
   if(MathAbs(slope) < atr * 0.1) return "Neutral";  // Not strong enough
   return "Neutral";
}


//+------------------------------------------------------------------+
void HandleSqueezeState(SymbolData *sd, double ask, double bid, double point, double spread, double riskAmount, double &lotSize) {
    // 1. Add SQUEEZE CONDITION (essential for this strategy)
    double bandwidth = (sd.upperEntryBand[1] - sd.lowerEntryBand[1]) / sd.middleBand[1];
    bool isSqueeze = bandwidth < 0.05;  // Threshold varies by instrument
    double atr = sd.atr[1];
    double breakoutBuffer = 1.5 * point;
    
    
    bool bullishRSI = sd.rsi[2] < 50 && sd.rsi[1] > 50; // upward cross of RSI midpoint
    double rsiSlope = sd.rsi[1] - sd.rsi[3];  // 2-bar slope

      bool rsiBullishSlope = rsiSlope > 5;   // customizable threshold
      
      bool rsiBearishSlope = rsiSlope < -5;
      
      bool bullishDiv = false, bearishDiv = false;
      DetectRSIDivergence(sd, 20, bullishDiv, bearishDiv);
      
      if (!cooldown.CanTrade(sd.symbol))
      return;  // skip due to cooldown
    // Final entry condition
   bool bull = isSqueeze
       && IsBreakoutConfirmed(sd,"bull",breakoutBuffer)        // Breakout with buffer
       && sd.volumes[1] > sd.volumes[2]*1.2
       && bullishRSI
       && rsiBullishSlope
       && bullishDiv
       && sd.rsi[0] < 70;
                                         // Avoid overbought
    bool bearishRSI = sd.rsi[2] > 50 && sd.rsi[1] < 50; // downward cross of RSI midpoint
    bool bear = isSqueeze 
       && IsBreakoutConfirmed(sd, "bear", breakoutBuffer)
       && sd.volumes[1] > sd.volumes[2]*1.2
       && bearishRSI
       && rsiBearishSlope
       && bearishDiv
       && sd.rsi[0] > 30;

    // 3. Improved Position Management
    if(bull&&IsNewBar(sd.symbol,Timeframe)) {
        double sl = ask-1.5*atr; // Below recent low
        double tp = ask + 3*atr;                        // 1:2 risk-reward
        
        double dist = ask - sl;
        if(dist > 0) {
            lotSize = NormalizeDouble(riskAmount / (dist / point), 2);
            if(lotSize > 0) trade.Buy(lotSize, sd.symbol, ask, sl, tp, "Squeeze-Bull");
        }
    }
    else if(bear&&IsNewBar(sd.symbol,Timeframe)) {
        double sl = bid + 1.5*atr;
        double tp = bid-3*atr;
        
        double dist = sl - bid;
        if(dist > 0) {
            lotSize = NormalizeDouble(riskAmount / (dist / point), 2);
            if(lotSize > 0) trade.Sell(lotSize, sd.symbol, bid, sl, tp, "Squeeze-Bear");
        }
    }
}
// Confirm breakout with buffer, follow-through, and candle strength
bool IsBreakoutConfirmed(SymbolData *sd, string direction, double bufferPoints) {
    double prevClose = sd.priceData[1].close;
    double prevOpen = sd.priceData[1].open;
    double candleBody = MathAbs(prevClose - prevOpen);
    double candleRange = sd.priceData[1].high - sd.priceData[1].low;

    if (candleRange == 0) return false;

    double bodyRatio = candleBody / candleRange;

    if (direction == "bull") {
        return (
            prevClose > sd.upperEntryBand[2] + bufferPoints &&
            sd.priceData[2].close < sd.upperEntryBand[2] &&
            sd.priceData[1].close > sd.priceData[2].close &&     // follow-through
            (prevClose - prevOpen) > 0 && bodyRatio > 0.6
        );
    }

    if (direction == "bear") {
        return (
            prevClose < sd.lowerEntryBand[2] - bufferPoints &&
            sd.priceData[2].close > sd.lowerEntryBand[2] &&
            sd.priceData[1].close < sd.priceData[2].close &&     // follow-through
            (prevOpen - prevClose) > 0 && bodyRatio > 0.6
        );
    }

    return false;
}


// Detects bullish and bearish divergence over last `window` bars
void DetectRSIDivergence(SymbolData *sd, int window, bool &bullishDiv, bool &bearishDiv) {
    bullishDiv = false;
    bearishDiv = false;

    double lowestPrice = sd.priceData[1].low;
    int lowestIndex = 1;
    double highestPrice = sd.priceData[1].high;
    int highestIndex = 1;

    // Step 1: Find lowest low and highest high in price over `window` bars
    for(int i = 2; i <= window; i++) {
        if(sd.priceData[i].low < lowestPrice) {
            lowestPrice = sd.priceData[i].low;
            lowestIndex = i;
        }
        if(sd.priceData[i].high > highestPrice) {
            highestPrice = sd.priceData[i].high;
            highestIndex = i;
        }
    }

    // Step 2: Compare RSI values
    double rsiNow = sd.rsi[1];  // latest closed bar
    double rsiAtLow = sd.rsi[lowestIndex];
    double rsiAtHigh = sd.rsi[highestIndex];

    // Bullish Divergence: Price lower low, RSI higher low
    if(sd.priceData[1].low > lowestPrice && rsiNow > rsiAtLow)
        bullishDiv = true;

    // Bearish Divergence: Price higher high, RSI lower high
    if(sd.priceData[1].high < highestPrice && rsiNow < rsiAtHigh)
        bearishDiv = true;
}


//+------------------------------------------------------------------+
string SqueezeTradeSignal(SymbolData *sd) {
   bool bull = sd.priceData[0].close > sd.upperEntryBand[0] && (sd.volumes[0] > sd.volumes[1] || !UseVolume);// && sd.rsi[0] > 50;
   bool bear = sd.priceData[0].close < sd.lowerEntryBand[0] && (sd.volumes[0] > sd.volumes[1] || !UseVolume);// && sd.rsi[0] < 50;
   if(
      bull 
      //&& sd.priceData[1].close < sd.upperEntryBand[1]
      ) {
      return "BUY";
   } else if(
      bear 
      //&& sd.priceData[1].close > sd.lowerEntryBand[1]
      ) {
      return "SELL";
   }else{
      return "NoTrade";
   }
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void HandleTrendingState(
    SymbolData *sd, double ask, double bid, double point, 
    double spread, double riskAmount, double &lotSize
) {
    // 1. Bollinger Band Slope = Trend Direction
    bool isUptrend = sd.middleBand[0] > sd.middleBand[1] && sd.middleBand[1] > sd.middleBand[2];
    bool isDowntrend = sd.middleBand[0] < sd.middleBand[1] && sd.middleBand[1] < sd.middleBand[2];
    double tpMult = GetTPMultiplier(sd.adx[1]);
    // Inside buy/sell blocks:
   double riskRewardRatio = (sd.adx[1] > 35) ? 1.5 : 1.2; // Dynamic RR

    if (isUptrend && IsNewBar(sd.symbol, Timeframe)&& IsCleanTrendEntryDeep(sd, "bull")&&!IsLongPositionOpen(sd.symbol)&& WasMarketSqueezedRecently(sd)) {
        
            //double sl = sd.lowerEntryBand[0] - sd.atr[1] * 0.5;
            double sl = sd.middleBand[0] - sd.atr[1] * 0.2;
            //double tp = ask + tpMult * sd.atr[1];
            double tp = ask + 4 * sd.atr[1];
            double riskPoints = MathMax((ask - sl) / point, 10.0);
            lotSize = NormalizeDouble(riskAmount / riskPoints, 2);
            
            if (lotSize > 0)
                trade.Buy(lotSize, sd.symbol, ask, sl, 0, "BB-Trend-Bull");
   
    }

    // 3. Sell Setup (Downtrend Pullback + Rejection)
    else if (isDowntrend && IsNewBar(sd.symbol, Timeframe)&& IsCleanTrendEntryDeep(sd, "bear")&&!IsShortPositionOpen(sd.symbol)&& WasMarketSqueezedRecently(sd)) {
        
            //double sl = sd.upperEntryBand[0] + sd.atr[1] * 0.5;
            double sl = sd.middleBand[0] + sd.atr[1] * 0.2;
            //double tp = bid - tpMult * sd.atr[1];
            double tp = bid - 4 * sd.atr[1];
            double riskPoints = MathMax((sl - bid) / point, 10.0);
            lotSize = NormalizeDouble(riskAmount / riskPoints, 2);
            
            if (lotSize > 0)
                trade.Sell(lotSize, sd.symbol, bid, sl, 0, "BB-Trend-Bear");
       
    }
}
double GetTPMultiplier(double adx) {
   if(adx >= 40) return 5.0;   // Very strong trend
   if(adx >= 30) return 4.0;   // Strong
   if(adx >= 25) return 3.0;   // Normal
   return 2.0;                 // Weak or no trend
}
bool WasMarketSqueezedRecently(SymbolData *sd, int minLookback = 2, int maxLookback = 5) {
   for (int i = minLookback; i <= maxLookback; i++) {
      double bw = sd.upperEntryBand[i] - sd.lowerEntryBand[i];
      double avgBW = 0;

      for (int j = i + 1; j <= i + VolLookback && (j < ArraySize(sd.upperEntryBand)); j++) {
         avgBW += (sd.upperEntryBand[j] - sd.lowerEntryBand[j]);
      }

      avgBW /= VolLookback;
      double strictSqueeze = avgBW * SqueezeFactor;

      if (bw < strictSqueeze) {
         return true; // Found a squeeze candle in lookback window
      }
   }
   return false;
}
bool IsCleanTrendEntryDeep(SymbolData* sd, string direction, double atrMultiplier = 1.5) {
//need more work
    const int currentIndex = 1;  // Last closed candle

    // Check data availability
    if (ArraySize(sd.priceData) < 5 || ArraySize(sd.upperEntryBand) < 2 || ArraySize(sd.rsi) < 5)
        return false;
   
    MqlRates candle = sd.priceData[currentIndex];
    double bodySize = MathAbs(candle.close - candle.open);
    double candleRange = candle.high - candle.low;
    if (candleRange == 0 || bodySize / candleRange < 0.6) {
        Print("❌ Rejected: Weak candle body");
        return false;
    }
    if(sd.atr[1] < 0.0005 * candle.close) return false;
    int hour = TimeHour(TimeCurrent());
      if (hour < 8 || hour > 20) {
          Print("⏰ Skipping low-probability hour: ", hour);
          return false;
      }
    // Optional: volume spike check based on SMA
    double avgVolume = (sd.volumes[2] + sd.volumes[3] + sd.volumes[4]) / 3.0;
    if (sd.volumes[1] < avgVolume * 1.2) {
        Print("❌ Rejected: No volume spike");
        return false;
    }

    // Bollinger Band width filter (trend strength)
    double bandWidth = sd.upperEntryBand[currentIndex] - sd.lowerEntryBand[currentIndex];
    if (bandWidth < sd.atr[currentIndex] * atrMultiplier) {
        Print("❌ Rejected: Bandwidth too narrow");
        return false;
    }

    // Dynamic RSI slope requirement
    double rsiSlope = sd.rsi[currentIndex] - sd.rsi[currentIndex + 2];
    double minSlope = 1.0 + (sd.adx[1] / 50.0);  // e.g., ~2.0 when ADX=50

    if (direction == "bull" && rsiSlope < minSlope) {
        PrintFormat("❌ Rejected: RSI slope %.2f < %.2f", rsiSlope, minSlope);
        return false;
    }
    if (direction == "bear" && rsiSlope > -minSlope) {
        PrintFormat("❌ Rejected: RSI slope %.2f > -%.2f", rsiSlope, minSlope);
        return false;
    }

    // Position relative to middle band
    if (direction == "bull") {
        if (candle.close <= sd.middleBand[currentIndex] || candle.close < candle.open)
            return false;
    } else if (direction == "bear") {
        if (candle.close >= sd.middleBand[currentIndex] || candle.close > candle.open)
            return false;
    }

    return true;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
string TrendingTradeSignal(SymbolData *sd) {
//default buy 40 ,sell 60
   if(sd.plusDI[0] > sd.minusDI[0] && sd.priceData[0].close > sd.middleBand[0]) {
      if(
         sd.priceData[0].low <= sd.middleBand[0] 
         //&& sd.rsi[0] > 35 
         //&& sd.rsi[0] < 65
         ) {
         return "BUY";
      }else{
      return "NoTrade";
   }
   } else if(sd.minusDI[0] > sd.plusDI[0] && sd.priceData[0].close < sd.middleBand[0]) {
      if(
         sd.priceData[0].high >= sd.middleBand[0] 
         //&& sd.rsi[0] > 35 
         //&& sd.rsi[0] < 65
         ) {
         return "SELL";
      }else{
      return "NoTrade";
   }
   }else{
      return "NoTrade";
   }
}

//+------------------------------------------------------------------+
void HandleRangingState(SymbolData *sd, double ask, double bid, double point, double spread, double riskAmount, double &lotSize) {
      string marketSignal = GetMarketState(sd);
      string candleSignal = CandelSignal(sd);
      string rsiSignal = RsiSignal(sd);
   if(
      candleSignal=="SELL"
      &&rsiSignal =="SELL"
      ) {
      double sl = sd.upperLossExitBand[0] + 1*point + spread;
      lotSize = NormalizeDouble(riskAmount / ((sl - bid) / point), 2);
      if(lotSize > 0) trade.Sell(lotSize, sd.symbol, bid, sl, sd.lowerProfitExitBand[0], "BB-Range-Short");
   }
   if(
      candleSignal=="BUY"
      &&rsiSignal =="BUY"
      ) {
      double sl = sd.lowerLossExitBand[0] - 1*point - spread;
      lotSize = NormalizeDouble(riskAmount / ((ask - sl) / point), 2);
      if(lotSize > 0) trade.Buy(lotSize, sd.symbol, ask, sl, sd.upperProfitExitBand[0], "BB-Range-Long");
   }
}

//+------------------------------------------------------------------+
string CandelSignal(SymbolData *sd) {
   //default buy 70 ,sell 30
   if(//price cross above the lower entry bb band
      sd.priceData[1].open <= sd.lowerEntryBand[1] 
      &&sd.priceData[1].close >= sd.lowerEntryBand[1] 
      //&& sd.rsi[0] > 40
      ) {
      return "BUY";
   } else if(//price cross below the upper entry bb band
      sd.priceData[1].open >= sd.upperEntryBand[1]
      &&sd.priceData[1].close <= sd.upperEntryBand[1] 
      //&& sd.rsi[0] < 40
      ) {
      return "SELL";
   }else{
      return "NoTrade";
   }
}
string RsiSignal(SymbolData *sd) {
   //default buy 70 ,sell 30
   if( sd.rsi[0] < RSILowerLevel
      ) {
      return "BUY";
   } else if( sd.rsi[0] > RSIUpperLevel
      ) {
      return "SELL";
   }else{
      return "NoTrade";
   }
}
string AdxRangeSignal(SymbolData *sd) {
   //default buy 70 ,sell 30
   if( sd.adx[0] < ADXTradeValue
      ) {
      return "Go";
   }else{
      return "Wait";
   }
}

//+------------------------------------------------------------------+
void ManageExits(SymbolData *sd, double ask, double bid, double point) {
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket) || PositionGetString(POSITION_SYMBOL) != sd.symbol) 
         continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);
      double size = PositionGetDouble(POSITION_VOLUME);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double atrBuffer = sd.atr[0] * 0.5; // Wider buffer for trends
      double atr = sd.atr[0];  // Always use current ATR
      double spread = SymbolInfoInteger(sd.symbol, SYMBOL_SPREAD) * point;
      string symbol = PositionGetString(POSITION_SYMBOL);
          
          
            
      // 1. Squeeze Trade Exits (mean-reversion)
      if(StringFind(comment, "Squeeze") != -1) {
         cooldown.RecordTrade(sd.symbol, profit);
         //if(type == POSITION_TYPE_BUY && bid < sd.middleBand[0] - atrBuffer)
            //trade.PositionClose(ticket);
         //else if(type == POSITION_TYPE_SELL && ask > sd.middleBand[0] + atrBuffer)
            //trade.PositionClose(ticket);
      }
      
      if (StringFind(comment, "Trend") != -1) {
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
         
            if (type == POSITION_TYPE_BUY) {
               double gain = bid - entryPrice;
               double newSL = sl;
            
               // 🧩 1. Tiered trailing (for early trend stages)
               if (gain > 4.0 * atr)
                  newSL = entryPrice + 2.5 * atr;
               else if (gain > 3.0 * atr)
                  newSL = entryPrice + 1.5 * atr;
               else if (gain > 2.0 * atr)
                  newSL = entryPrice + 1.2 * atr;
               else if (gain > 1.5 * atr)
                  newSL = entryPrice + 0.6 * atr;
               else if (gain > 1.3 * atr)
                  newSL = entryPrice + spread + 0.1 * atr;
            
               // 🧩 2. Dynamic trailing logic for strong trends (e.g., gain > 4.0 ATR)
               if (gain > 4.0 * atr) {
                  double trailRatio = 0.70; // trail 50% of gain
                  double dynamicSL = entryPrice + gain * trailRatio;
            
                  // Choose the stricter (higher) SL: either tiered or dynamic
                  newSL = MathMax(newSL, dynamicSL);
               }
            
               // ✅ Ensure SL never moves backward
               if (newSL > sl && newSL > entryPrice && (MathAbs(newSL - sl) > point)) {
                  trade.PositionModify(symbol, newSL, tp);
                  Print("🔵 SL Trailed (BUY): ", DoubleToString(newSL, _Digits));
               }
            }
         
            if (type == POSITION_TYPE_SELL) {
               double gain = entryPrice - ask;
               double newSL = sl;
            
               if (gain > 4.0 * atr)
                  newSL = entryPrice - 2.5 * atr;
               else if (gain > 3.0 * atr)
                  newSL = entryPrice - 2.0 * atr;
               else if (gain > 2.0 * atr)
                  newSL = entryPrice - 1.2 * atr;
               else if (gain > 1.5 * atr)
                  newSL = entryPrice - 0.6 * atr;
               else if (gain > 1.3 * atr)
                  newSL = entryPrice - spread - 0.1 * atr;
            
               if (gain > 4.0 * atr) {
                  double trailRatio = 0.70;
                  double dynamicSL = entryPrice - gain * trailRatio;
                  newSL = MathMin(newSL, dynamicSL);
               }
            
               if (newSL < sl && newSL < entryPrice && (MathAbs(newSL - sl) > point)) {
                  trade.PositionModify(symbol, newSL, tp);
                  Print("🔴 SL Trailed (SELL): ", DoubleToString(newSL, _Digits));
               }
            }

         }//end of trend

      
      
    }//for close
      
      
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &req, const MqlTradeResult &res) {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD &&
      (trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)) {

      string sym = trans.symbol;
      double profit = 0;
      datetime closeTime = TimeCurrent();

      datetime now = TimeCurrent();
      HistorySelect(now - 60, now + 60);

      ulong ticket = trans.deal;
      if(ticket > 0 && HistoryDealSelect(ticket)) {
         profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      }

      reportManager.UpdateReport(sym, profit, closeTime);
   }
}
