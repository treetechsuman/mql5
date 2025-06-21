//+------------------------------------------------------------------+
//|                        SymbolReport.mqh                          |
//|     Modular reporting for multi-symbol MQL5 Expert Advisors     |
//+------------------------------------------------------------------+
#ifndef __SYMBOL_REPORT_MQH__
#define __SYMBOL_REPORT_MQH__

#include <Arrays/ArrayObj.mqh>
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
   double totalDuration; // total holding time in seconds
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
   
   double TotalTrade(){
      return this.totalTrades;
   }

   void WriteCSV() {
      string file = "Report_" + symbol + ".csv";
      int handle = FileOpen(file, FILE_WRITE | FILE_CSV);
      if(handle != INVALID_HANDLE) {
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
