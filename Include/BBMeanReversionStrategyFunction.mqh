//+------------------------------------------------------------------+
//| This function caclulate pip value for different symbol        |
//+------------------------------------------------------------------+
double GetPipValue()
{
   if(_Digits >=4)
   {
      return 0.0001;
   }
   else
   {
      return 0.01;
   }
}

//+------------------------------------------------------------------+
//| This function caclulate stoploss for buy or sell        |
//+------------------------------------------------------------------+
double GetStopLossPrice(bool bIsLongPosition, double entryPrice, int maxLossInPips)
{
   double stopLossPrice;
   if (bIsLongPosition)
   {
      stopLossPrice = entryPrice - maxLossInPips * 0.0001;
   }
   else
   {
      stopLossPrice = entryPrice + maxLossInPips * 0.0001;
   }
   return stopLossPrice;
}

//+------------------------------------------------------------------+
//| This function caclulate optimalLotSize        |
//+------------------------------------------------------------------+
double OptimalLotSize(double maxRiskPrc, int maxLossInPips)
{

  double accEquity = AccountInfoDouble(ACCOUNT_EQUITY);
  //Print("accEquity: " + accEquity);
  
  double lotSize = SymbolInfoDouble(NULL,SYMBOL_TRADE_CONTRACT_SIZE);
  //Print("lotSize: " + lotSize);
  
  double tickValue = SymbolInfoDouble(NULL,SYMBOL_TRADE_TICK_VALUE);
  
  if(_Digits <= 3){
   tickValue = tickValue /100;
  }
  
  //Print("tickValue: " + tickValue);
  
  double maxLossDollar = accEquity * maxRiskPrc;
  //Print("maxLossDollar: " + maxLossDollar);
  
  double maxLossInQuoteCurr = maxLossDollar / tickValue;
  //Print("maxLossInQuoteCurr: " + maxLossInQuoteCurr);
  
  double optimalLotSize = NormalizeDouble(maxLossInQuoteCurr /(maxLossInPips * GetPipValue())/lotSize,2);
  
  return optimalLotSize;
 
}
double OptimalLotSize(double maxRiskPrc, double entryPrice, double stopLoss)
{
   int maxLossInPips = MathAbs(entryPrice - stopLoss)/GetPipValue();
   return OptimalLotSize(maxRiskPrc,maxLossInPips);
}

void DisplayInfoInChart(double rsiValue){
   double Ask,Bid,tickValue;
   int Spread;
   Ask=SymbolInfoDouble(Symbol(),SYMBOL_ASK);
   Bid=SymbolInfoDouble(Symbol(),SYMBOL_BID);
   Spread=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD);
   //tickValue =SymbolInfoDouble(NULL,SYMBOL_TRADE_TICK_VALUE);
   Comment(StringFormat("Show prices\nAsk = %G\nBid = %G\nSpread = %d\nRsiValue = %d",Ask,Bid,Spread,rsiValue));
}

//+------------------------------------------------------------------+
//| This function caclulate takeProfit for buy or sell        |
//+------------------------------------------------------------------+
double CalculateTakeProfit(bool isLong, double entryPrice, int pips)
{
   double takeProfit;
   if(isLong)
   {
      takeProfit = entryPrice + pips * GetPipValue();
   }
   else
   {
      takeProfit = entryPrice - pips * GetPipValue();
   }
   
   return takeProfit;
}
//+------------------------------------------------------------------+
//| This function caclulate stoploss for buy or sell        |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isLong, double entryPrice, int pips)
{
   double stopLoss;
   if(isLong)
   {
      stopLoss = entryPrice - pips * GetPipValue();
   }
   else
   {
      stopLoss = entryPrice + pips * GetPipValue();
   }
   return stopLoss;
}

//+------------------------------------------------------------------+
//| Returns current ask or bid price                  |
//+------------------------------------------------------------------+
  double GetCurrentPrice(string type){
      MqlTick last_tick;
      SymbolInfoTick(_Symbol,last_tick);
      if(type=="Ask"){
         return last_tick.ask;
      }else{
         return last_tick.bid;
      }
      
   }
//+------------------------------------------------------------------+
//| Returns bool for trading time                 |
//+------------------------------------------------------------------+  
  bool TradingTime(string fromTimeString, string toTimeString){
      MqlDateTime fromTime;
      TimeToStruct(StringToTime(fromTimeString),fromTime);
      
      MqlDateTime toTime;
      TimeToStruct(StringToTime(toTimeString),toTime);
      
      MqlDateTime currentTime;
      TimeToStruct(TimeGMT(),currentTime);
      
      //Print("FromTime Hour :" , fromTime.hour);
      if(currentTime.hour>=fromTime.hour&&currentTime.hour<=toTime.hour){
         if(currentTime.min>=fromTime.min&&(currentTime.min<=toTime.min||toTime.min == 00)){
            return true;
         }  
      }
      return false;
  }

