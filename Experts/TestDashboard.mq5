#include "Modules/InfoDashboard.mqh"
#include "Modules/Signal.mqh";


input string   Symbols             = "EURUSD,GBPUSD,USDJPY"; // Trade symbols
input ENUM_TIMEFRAMES Timeframe    = PERIOD_M15;
input double   RiskPercent         = 1.0;        // Risk per trade (%)
input int      MAPeriod            = 20;         // MA Period
string   tradeSymbols[];
datetime lastTradeTime[];
string Rows[] = {"EMA Signal", "RSI Signal", "Recovery", "Other Info"};
int OnInit() {   
   // Parse symbol list
   StringSplit(Symbols, ',', tradeSymbols);
   ArrayResize(lastTradeTime, ArraySize(tradeSymbols));
   InitDashboard(tradeSymbols, Rows, 20, 20);
   ArrayInitialize(lastTradeTime, 0);
   return INIT_SUCCEEDED;
}

void OnTick() {
   for(int i = 0; i < ArraySize(tradeSymbols); i++) {
      string symbol = tradeSymbols[i];
      string maSignal = MaSignal(symbol,Timeframe,MAPeriod);
      
      SignalStatus s1;
      ArrayResize(s1.values, 4);
      s1.values[0] = maSignal;
      s1.values[1] = "SELL";
      s1.values[2] = "Recovery 1";
      s1.values[3] = "ATR: 0.0021";
      UpdateDashboard(symbol, s1);
      
   }
   
   
}
