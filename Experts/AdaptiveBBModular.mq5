//+------------------------------------------------------------------+
//|                     ModularEA_Refactored.mq5                     |
//|     Refactored EA using SymbolData and per-symbol indicators   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>

#include "Modules/Core/Core.mqh"
#include "Modules/Reports/SymbolReport.mqh"
#include "Modules/Indicators/RSIIndicator.mqh"
#include "Modules/Indicators/MaIndicator.mqh"

#include "Modules/Strategies/AdaptiveBBStrategy/Context.mqh"
#include "Modules/Strategies/AdaptiveBBStrategy/Strategy.mqh"

CArrayObj contexts;
//CTrade trade;
 CSymbolReportManager reportManager;
string Rows[] = {"MarketSignal","Symbol","RSI","ADX"};
datetime lastTradeTime[];

//+------------------------------------------------------------------+
int OnInit() {
   contexts.Clear();

   string list[];
   StringSplit(Symbols, ',', list);

   for (int i = 0; i < ArraySize(list); i++) {
      SymbolData *sd = new SymbolData;
      if (sd.Init(list[i])) {
         SymbolContext *ctx = new SymbolContext(sd,RSIPeriod,ATRPeriod,ADXPeriod, BBPeriod, BBLossExitDeviation,BBEntryDeviation,BBProfitExitDeviation, VolLookback, Timeframe);
         contexts.Add(ctx);
      } else {
         delete sd;
      }
   }
   ArrayResize(lastTradeTime, ArraySize(list));
   InitDashboard(list, Rows, 20, 20);
   ArrayInitialize(lastTradeTime, 0);
   InitDailyLossLimiter();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   for (int i = 0; i < contexts.Total(); i++) {
      SymbolContext *ctx = (SymbolContext*)contexts.At(i);
      delete ctx;
   }
   reportManager.PrintAll();  // This prints to Experts log
   contexts.Clear();
}

//+------------------------------------------------------------------+
void OnTick() {
   for (int i = 0; i < contexts.Total(); i++) {
      SymbolContext *ctx = (SymbolContext*)contexts.At(i);
      SymbolData *sd = ctx.sd;
      UpdateTrailingSL(ctx);
      if (!sd.IsNewCandle(Timeframe)) continue;
      

      sd.LoadMarketData(Timeframe, VolLookback);
      ctx.LoadIndicators();
      //display infor in dashboard
      string marketState = GetMarketState(ctx);
      SignalStatus s1;
      ArrayResize(s1.values, 4);
      s1.values[0] = marketState;
      s1.values[1] = sd.symbol;
      s1.values[2] = DoubleToString(NormalizeDouble(ctx.GetRSI(0),2),1) + " ";   
      s1.values[3] = DoubleToString(NormalizeDouble(ctx.GetADX(0),2),1) + " ";  
      UpdateDashboard(sd.symbol, s1);

      

      if(marketState=="Squeeze") {
         //BBSqueezeStrategy(ctx);
      }
      if(marketState=="Trending") {
         
      }
      if(marketState=="Ranging") {
         //BBRangingStrategy(ctx);
      }
      //BBSqueezeStrategy(ctx);
      //UpdateTrailingSL(ctx);
      //ProcessSymbol(ctx);
      //BBRangingStrategy(ctx);
      BBRangingStrategy(ctx);
   }
}

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

string GetMarketState(SymbolContext *ctx) {
   double bw = ctx.GetEntryBBUpper(0) - ctx.GetEntryBBLower(0);  // current BB width
   double avgBW = 0;
   for(int i = 1; i < VolLookback; i++) 
      avgBW += (ctx.GetEntryBBUpper(i) - ctx.GetEntryBBLower(1));
   avgBW /= VolLookback;

   double atr = ctx.GetATR(0);  // assume you're storing ATR per symbol in sd

   // === Squeeze Detection with Buffer ===
   double strictSqueeze = avgBW * SqueezeFactor;           // e.g., 0.8
   double bufferSqueeze = strictSqueeze * 1.1;              // add 10% tolerance

   //if(bw < strictSqueeze) return "Squeeze";
   //if(bw < strictSqueeze && avgBW > 0.0001) return "Squeeze";
   //if(bw < bufferSqueeze) return "SqueezeLikely";  // transitional

   // === Trending Detection with ADX Buffer ===
   double adx = ctx.GetADX(0);
   double plusDI = ctx.GetPlusDI(0);
   double minusDI = ctx.GetMinusDI(0);
   double price = ctx.sd.priceData[1].close;
   double midBand = ctx.GetMiddleBB(0);
   double diGap = MathAbs(plusDI - minusDI);
   if(adx > (ADXTradeValue+2)&& diGap > 2) {
      double diGap = MathAbs(plusDI - minusDI);
      if(plusDI > minusDI && price > midBand) return "Trending";
      if(minusDI > plusDI && price < midBand) return "Trending";
   }

   // === Ranging Detection with ATR-based Band Stability ===
   if(adx < (ADXTradeValue-2) &&
      MathAbs(ctx.GetEntryBBUpper(0) - ctx.GetEntryBBUpper(1)) < atr * 0.1 &&
      MathAbs(ctx.GetEntryBBLower(0) - ctx.GetEntryBBLower(1)) < atr * 0.1)
      return "Ranging";

   // === Neutral fallback ===
   //double slope = ctx.GetMiddleBB(0) - ctx.GetMiddleBB(3);  // Over 3 candles
   //if(MathAbs(slope) < atr * 0.1) return "Neutral";  // Not strong enough
   return "Ranging";
}
