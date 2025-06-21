//+------------------------------------------------------------------+
//|              MultiSymbol Report EA for Testing                  |
//|        Uses SymbolReport.mqh to log trades by symbol            |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

#include "Modules/SymbolReport.mqh"

input string   SymbolsList = "EURUSD,GBPUSD"; // Comma-separated symbols
input double   LotSize     = 0.1;
input int      MagicNumber = 123456;

CTrade trade;
CSymbolReportManager reportManager;
string symbols[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   StringSplit(SymbolsList, ',', symbols);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //reportManager.ExportAll();
   reportManager.PrintAll();  // This prints to Experts log
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   for(int i = 0; i < ArraySize(symbols); i++) {
      string sym = symbols[i];
      if(reportManager.HasReport("EURUSD")) {
         CSymbolReportData *data = reportManager.GetReport("EURUSD");
         Print("Win Rate: ", data.WinRate(), "%");
      }
      if(PositionSelect(sym)) continue; // Skip if already in trade

      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double sl = ask - 100 * _Point;
      double tp = ask + 100 * _Point;

      reportManager.StartTrade(sym, TimeCurrent());

      if(trade.Buy(LotSize, sym, ask, sl, tp, NULL)) {
         Print("Trade opened on ", sym);
      }
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

