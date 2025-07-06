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

#include "Modules/Strategies/MaDayTrading/Context.mqh"
#include "Modules/Strategies/MaDayTrading/Strategy.mqh"

CArrayObj contexts;
//CTrade trade;
 CSymbolReportManager reportManager;
string Rows[] = {"EntryHour","H1 Trend","EmaSlop","Rsi","Info","Engulfing"};
datetime lastTradeTime[];

//+------------------------------------------------------------------+
int OnInit() {
   contexts.Clear();
   string list[];
   StringSplit(Symbols, ',', list);

   for (int i = 0; i < ArraySize(list); i++) {
      SymbolData *sd = new SymbolData;
      if (sd.Init(list[i])) {
         SymbolContext *ctx = new SymbolContext(sd,RSIPeriod,ATRPeriod,ADXPeriod, Ma15MPeriod, Ma1HPeriod, VolLookback, Timeframe);
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
   //reportManager.ExportAll();
   contexts.Clear();
   
}

//+------------------------------------------------------------------+
void OnTick() {
   for (int i = 0; i < contexts.Total(); i++) {
      SymbolContext *ctx = (SymbolContext*)contexts.At(i);
      SymbolData *sd = ctx.sd;
      //ClosePositionsOnMACross(ctx);
      //UpdateTrailingSL(ctx);
      if (!sd.IsNewCandle(Timeframe)) continue;

      sd.LoadMarketData(Timeframe, VolLookback);
      ctx.LoadIndicators();
      //display infor in dashboard
      

      
      MaDayTradingStrategy(ctx);
      
      
      //ProcessSymbol(ctx);
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

