//+------------------------------------------------------------------+
//|                                          BulkHistoryLoader.mq5   |
//|   Loads historical data for multiple symbols & timeframes        |
//+------------------------------------------------------------------+
#property script_show_inputs

input string SymbolsList = "EURUSD,AUDUSD,GBPUSD,USDJPY,EURJPY";
input int LookBackDays = 3650; // ~10 years

ENUM_TIMEFRAMES timeframes[] = {
   PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30,
   PERIOD_H1, PERIOD_H4, PERIOD_D1
};

void OnStart()
{
   string symbols[];
   StringSplit(SymbolsList, ',', symbols);
   datetime fromTime = TimeCurrent() - LookBackDays * 86400;

   for (int i = 0; i < ArraySize(symbols); i++)
   {
      string sym = symbols[i];
      Print("Fetching data for ", sym);

      for (int j = 0; j < ArraySize(timeframes); j++)
      {
         ENUM_TIMEFRAMES tf = timeframes[j];
         MqlRates rates[];  // Allocate proper array for CopyRates

         Print(" - ", EnumToString(tf), ": loading...");
         if (!SeriesInfoInteger(sym, tf, SERIES_SYNCHRONIZED))
         {
            while (!SeriesInfoInteger(sym, tf, SERIES_SYNCHRONIZED))
               Sleep(100);
         }

         int bars = CopyRates(sym, tf, fromTime, TimeCurrent(), rates);
         if (bars > 0)
            Print("   ✔ Loaded ", bars, " bars for ", sym, " [", EnumToString(tf), "]");
         else
            Print("   ❌ Failed to load ", EnumToString(tf), " for ", sym);
      }
   }

   Print("✅ Done loading history.");
}
