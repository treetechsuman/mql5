#ifndef EMAWITHSLOPE_MQH
#define EMAWITHSLOPE_MQH

//+------------------------------------------------------------------+
//| MA Crossover Signal with Slope Confirmation                      |
//+------------------------------------------------------------------+
string MaSignal(string symbol,ENUM_TIMEFRAMES Timeframe,int MAPeriod) {
   int maHandle = iMA(symbol, Timeframe, MAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(maHandle == INVALID_HANDLE) return "NoTrade";

   double ma[3], close[1];
   if(CopyBuffer(maHandle, 0, 0, 3, ma) < 3) return "NoTrade";
   if(CopyClose(symbol, Timeframe, 0, 1, close) < 1) return "NoTrade";

   double slope = ma[0] - ma[2]; // Compare current MA to MA two bars back

   if(close[0] > ma[0] && slope > 0)
      return "BUY";
   else if(close[0] < ma[0] && slope < 0)
      return "SELL";
   else
      return "NoTrade";
}


#endif