#ifndef EMARSIGNAL_MQH
#define EMASIGNAL_MQH

string EmaSignal(int emaFastPeriod,int emaSlowPeriod){
   //create an array for several prices
   double emaFastAverageArray[],emaSlowAverageArray[],emaVerySlowAverageArray[];
   
   // Handle creation for indicators( defind the property of moving average)
    int handleFast = iMA(Symbol(), Period(), emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    int handleSlow = iMA(Symbol(), Period(), emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
    int handleVerySlow = iMA(Symbol(), Period(), 50, 0, MODE_EMA, PRICE_CLOSE);
    
   // sort the price array from the current candle downwards
   ArraySetAsSeries(emaFastAverageArray,true);
   ArraySetAsSeries(emaSlowAverageArray,true);
   ArraySetAsSeries(emaVerySlowAverageArray,true);
   
   //put the value to array
   CopyBuffer(handleFast,0,0,3,emaFastAverageArray);
   CopyBuffer(handleSlow,0,0,3,emaSlowAverageArray);
   CopyBuffer(handleVerySlow,0,0,3,emaVerySlowAverageArray);
   
   //check if the fast(20) moving MA is above the slow(50) moving MA
   if(
      (emaFastAverageArray[1] < emaSlowAverageArray[1])  // Fast MA was below Medium MA (previous bar)
    && (emaFastAverageArray[0] > emaSlowAverageArray[0])  // Fast MA is now above Medium MA (crossover happens)
    //&& (emaSlowAverageArray[1] < emaVerySlowAverageArray[1])  // Medium MA was below Slow MA (previous bar)
    && (emaSlowAverageArray[0] > emaVerySlowAverageArray[0])  // Medium MA is now above Slow MA (crossover happens)
   ){
      //Comment("BUY");
      return "BUY";
   }
   if(
      (emaFastAverageArray[1] > emaSlowAverageArray[1])  // Fast MA was above Medium MA (previous bar)
    && (emaFastAverageArray[0] < emaSlowAverageArray[0])  // Fast MA is now below Medium MA (crossover happens)
    //&& (emaSlowAverageArray[1] > emaVerySlowAverageArray[1])  // Medium MA was above Slow MA (previous bar)
    && (emaSlowAverageArray[0] < emaVerySlowAverageArray[0])  // Medium MA is now below Slow MA (crossover happens)
      
   ){
      //Comment("SELL");
      return "SELL";
   }
   return "NoTrade";
   
}

#endif