//+------------------------------------------------------------------+
//|                        SymbolReport.mqh                          |
//|     Modular reporting for multi-symbol MQL5 Expert Advisors     |
//+------------------------------------------------------------------+
#ifndef __SYMBOL_REPORT_MQH__
#define __SYMBOL_REPORT_MQH__

#include <Arrays/ArrayObj.mqh>

// --- Sorting helper ---
int CompareByNetProfit(const CObject *a, const CObject *b)
{
   CSymbolReportData *ra = (CSymbolReportData*)a;
   CSymbolReportData *rb = (CSymbolReportData*)b;

   if(ra == NULL || rb == NULL) return 0;
   return (ra.netProfit > rb.netProfit) ? -1 : (ra.netProfit < rb.netProfit) ? 1 : 0;
}

// --- Main class ---
class CSymbolReportData : public CObject {
public:
   string symbol;
   int totalTrades;
   int wins;
   int losses;
   int consecutiveWins;
   int consecutiveLosses;
   int maxConsecWins;
   int maxConsecLosses;
   double grossProfit;
   double grossLoss;
   double netProfit;
   double maxDrawdown;
   double bestTrade;
   double worstTrade;
   double totalDuration;
   datetime lastOpenTime;

   CSymbolReportData(string sym) {
      symbol = sym;
      totalTrades = wins = losses = consecutiveWins = consecutiveLosses = 0;
      maxConsecWins = maxConsecLosses = 0;
      grossProfit = grossLoss = netProfit = 0;
      maxDrawdown = bestTrade = worstTrade = totalDuration = 0;
      lastOpenTime = 0;
   }

   void StartTimer(datetime openTime) {
      lastOpenTime = openTime;
   }

   void Update(double profit, datetime closeTime) {
      totalTrades++;
      double duration = (lastOpenTime > 0) ? (closeTime - lastOpenTime) : 0;
      totalDuration += duration;

      netProfit += profit;
      if(profit > 0) {
         wins++;
         consecutiveWins++;
         consecutiveLosses = 0;
         if(consecutiveWins > maxConsecWins) maxConsecWins = consecutiveWins;
         grossProfit += profit;
         if(profit > bestTrade) bestTrade = profit;
      } else {
         losses++;
         consecutiveLosses++;
         consecutiveWins = 0;
         if(consecutiveLosses > maxConsecLosses) maxConsecLosses = consecutiveLosses;
         grossLoss += MathAbs(profit);
         if(profit < worstTrade) worstTrade = profit;
      }

      double drawdown = MathAbs(grossProfit - grossLoss);
      if(drawdown > maxDrawdown) maxDrawdown = drawdown;
   }

   double WinRate() {
      return (totalTrades > 0) ? (100.0 * wins / totalTrades) : 0.0;
   }

   double ProfitFactor() {
      return (grossLoss > 0) ? (grossProfit / grossLoss) : 0.0;
   }

   double AvgTradeDuration() {
      return (totalTrades > 0) ? (totalDuration / totalTrades) : 0.0;
   } 

   void WriteCSV() {
      string filename = "reports/summary.txt"; 
      int handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_TXT | FILE_ANSI);
      if(handle != INVALID_HANDLE) {
         FileSeek(handle, 0, SEEK_END);
         FileWrite(handle, "Metric", "Value");
         FileWrite(handle, "Symbol", symbol);
         FileWrite(handle, "Total Trades", totalTrades);
         FileWrite(handle, "Wins", wins);
         FileWrite(handle, "Losses", losses);
         FileWrite(handle, "Win Rate (%)", WinRate());
         FileWrite(handle, "Net Profit", netProfit);
         FileWrite(handle, "Gross Profit", grossProfit);
         FileWrite(handle, "Gross Loss", grossLoss);
         FileWrite(handle, "Profit Factor", ProfitFactor());
         FileWrite(handle, "Max Drawdown", maxDrawdown);
         FileWrite(handle, "Best Trade", bestTrade);
         FileWrite(handle, "Worst Trade", worstTrade);
         FileWrite(handle, "Avg Trade Duration (s)", AvgTradeDuration());
         FileWrite(handle, "Max Consecutive Wins", maxConsecWins);
         FileWrite(handle, "Max Consecutive Losses", maxConsecLosses);
         FileWrite(handle, "");  // spacing
         FileClose(handle);
      }
   }

   void PrintReport() {
      Print("==== Report for ", symbol, " ====");
      Print("Total Trades: ", totalTrades);
      Print("Wins: ", wins);
      Print("Losses: ", losses);
      Print("Win Rate (%): ", WinRate());
      Print("Net Profit: ", netProfit);
      Print("Gross Profit: ", grossProfit);
      Print("Gross Loss: ", grossLoss);
      Print("Profit Factor: ", ProfitFactor());
      Print("Max Drawdown: ", maxDrawdown);
      Print("Best Trade: ", bestTrade);
      Print("Worst Trade: ", worstTrade);
      Print("Avg Duration (s): ", AvgTradeDuration());
      Print("Max Consecutive Wins: ", maxConsecWins);
      Print("Max Consecutive Losses: ", maxConsecLosses);
   }
};

// --- Report Manager ---
class CSymbolReportManager {
private:
   CArrayObj reportList;

public:
   void StartTrade(string symbol, datetime openTime) {
      for(int i = 0; i < reportList.Total(); i++) {
         CSymbolReportData *r = (CSymbolReportData*)reportList.At(i);
         if(r != NULL && r.symbol == symbol) {
            r.StartTimer(openTime);
            return;
         }
      }
      CSymbolReportData *newReport = new CSymbolReportData(symbol);
      newReport.StartTimer(openTime);
      reportList.Add(newReport);
   }

   void UpdateReport(string symbol, double profit, datetime closeTime) {
      for(int i = 0; i < reportList.Total(); i++) {
         CSymbolReportData *r = (CSymbolReportData*)reportList.At(i);
         if(r != NULL && r.symbol == symbol) {
            r.Update(profit, closeTime);
            return;
         }
      }
      CSymbolReportData *newReport = new CSymbolReportData(symbol);
      newReport.Update(profit, closeTime);
      reportList.Add(newReport);
   }

   void ExportAll() {
      for(int i = 0; i < reportList.Total(); i++) {
         CSymbolReportData *r = (CSymbolReportData*)reportList.At(i);
         if(r != NULL) r.WriteCSV();
      }
   }

   void PrintAll() {
      for(int i = 0; i < reportList.Total(); i++) {
         CSymbolReportData *r = (CSymbolReportData*)reportList.At(i);
         if(r != NULL) r.PrintReport();
      }
   }

   

   CSymbolReportData* GetReport(string symbol) {
      for(int i = 0; i < reportList.Total(); i++) {
         CSymbolReportData *r = (CSymbolReportData*)reportList.At(i);
         if(r != NULL && r.symbol == symbol)
            return r;
      }
      return NULL;
   }

   bool HasReport(string symbol) {
      return (GetReport(symbol) != NULL);
   }
};

#endif // __SYMBOL_REPORT_MQH__
