//+------------------------------------------------------------------+
//|                 SymbolManager.mqh                                 |
//|   Handles multi-symbol data loading, validation, and sync        |
//+------------------------------------------------------------------+
#ifndef __SYMBOLMANAGER_MQH__
#define __SYMBOLMANAGER_MQH__

#include <Trade\Trade.mqh>

class SymbolManager {
private:
   string  coreSymbols[];
   string  requiredSymbols[];
   datetime defaultFrom;
   datetime defaultTo;
   ENUM_TIMEFRAMES timeframe;

   bool IsRequired(string sym) {
      for(int i = 0; i < ArraySize(requiredSymbols); i++) {
         if(requiredSymbols[i] == sym)
            return true;
      }
      return false;
   }

   bool DownloadRates(string sym) {
      // Strategy Tester-safe download method
      if(MQLInfoInteger(MQL_TESTER)) {
         Print("⚠️ Strategy Tester detected - using direct history sync for ", sym);
         return HistorySync(sym);
      }
      
      // Normal terminal handling
      long chartID = ChartOpen(sym, timeframe);
      if(chartID <= 0) {
         Print("❌ Failed to open chart for ", sym);
         return false;
      }
      
      // Force data download
      ChartSetInteger(chartID, CHART_FOREGROUND, false);
      ChartRedraw(chartID);
      Print("⬇️ Downloading data for ", sym, "...");
      ChartClose(chartID);
      return true;
   }

   bool HistorySync(string sym) {
      // Strategy Tester-specific synchronization
      if(HistorySelect(defaultFrom, defaultTo)) {
         int bars = Bars(sym, timeframe);
         if(bars > 0) return true;
      }
      
      // Request server synchronization
      Print("⌛ Requesting server sync for ", sym);
      ResetLastError();
      if(!SymbolSelect(sym, true)) {
         Print("❌ Failed to select symbol: ", sym, " [", GetLastError(), "]");
         return false;
      }
      
      datetime from = defaultFrom;
      datetime to = defaultTo;
      if(!SeriesInfoInteger(sym, timeframe, SERIES_SERVER_FIRSTDATE, from)) from = defaultFrom;
      if(!SeriesInfoInteger(sym, timeframe, SERIES_LASTBAR_DATE, to)) to = defaultTo;
      
      if(!HistorySelect( from, to)) {
         Print("❌ HistorySelect failed for ", sym, " [", GetLastError(), "]");
         return false;
      }
      
      return true;
   }

public:
   // Constructor
   void Init(string &symbols[], ENUM_TIMEFRAMES tf = PERIOD_M15, datetime from = 0, datetime to = 0) {
      ArrayCopy(coreSymbols, symbols);
      timeframe = tf;
      defaultFrom = (from == 0) ? D'2023.01.01' : from;
      defaultTo = (to == 0) ? TimeCurrent() : to;
   }

   // Define required symbols
   void SetRequiredSymbols(string &symbols[]) {
      ArrayCopy(requiredSymbols, symbols);
   }

   // Ensure history and rates are available
   bool PrepareSymbols() {
      bool allRequiredLoaded = true;

      for(int i = 0; i < ArraySize(coreSymbols); i++) {
         string sym = coreSymbols[i];

         if(!SymbolSelect(sym, true)) {
            Print("❌ Failed to select symbol: ", sym, " [Error:", GetLastError(), "]");
            if(IsRequired(sym))
               allRequiredLoaded = false;
            continue;
         }

         int attempts = 0;
         const int maxAttempts = 3;
         MqlRates rates[];
         bool success = false;

         while(attempts < maxAttempts && !success) {
            // Strategy Tester requires different handling
            if(MQLInfoInteger(MQL_TESTER)) {
               success = HistorySync(sym);
            } 
            else {
               // Normal terminal handling
               if(CopyRates(sym, timeframe, defaultFrom, defaultTo, rates) > 0 && ArraySize(rates) > 0) {
                  success = true;
               }
            }
            
            if(success) break;
            
            // Attempt to download missing data
            if(attempts == 0) DownloadRates(sym); // Only try once
            
            // Wait with increasing intervals
            int waitTime = 500 * (attempts + 1);
            Sleep(waitTime);
            attempts++;
         }

         if(!success) {
            Print("❌ Failed to load rates for ", sym, " after ", attempts, " attempts [Error:", GetLastError(), "]");
            if(IsRequired(sym))
               allRequiredLoaded = false;
         }
         else {
            int bars = Bars(sym, timeframe);
            Print("✅ Symbol initialized: ", sym, " [Bars: ", bars, "]");
         }
      }

      if(!allRequiredLoaded) {
         Print("❌ One or more required symbols failed to initialize");
         return false;
      }

      return true;
   }
};

#endif