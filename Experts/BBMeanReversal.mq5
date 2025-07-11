//+------------------------------------------------------------------+
//|                                              BollingerAndRsi.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "Modules/Signal.mqh";
#include "Modules/RiskManagement.mqh";
//#include "Modules/TradeExecution.mqh";
#include "Modules/Utils.mqh";
#include "Modules/ChartComment.mqh";
#include <Trade\Trade.mqh>
CTrade trade;

// Global instance of the TradeExecution class
//TradeExecution tradeExec;
ChartComment chartComment;

input int BBStopLoss = 6;
input int BBEntry = 2;
input int BBTakeProfit = 1;
input int BBPeriod = 50;

input double LOTSize = 0.01;

input int RSIPeriod = 14;            // RSI period
input int RSIUpperLevel = 60;      // RSI level for buy
input int RSILowerLevel = 40;     // RSI level for sell

input int RISKPercentage = 2;

datetime lastBarTime = 0; 
//+------------------------------------------------------------------+
//| Expert initializatioddn function  v                                 |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
long minStopLossPoints = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double minStopLossPips = minStopLossPoints * _Point / GetPipSize();
   
   Print("Minimum Stop Loss in Points: ", minStopLossPoints);
   Print("Minimum Stop Loss in Pips : ", minStopLossPips);
   return(INIT_SUCCEEDED);
  }
  
  double GetPipSize()
{
    if (SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 3 || SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 5)
        return 10 * _Point; // Normal pairs (EUR/USD, GBP/USD)
    else
        return _Point; // JPY pairs (USD/JPY, EUR/JPY)
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
double GetBandValue(int maPeriod, double deviation, string location){
   // Bollinger Bands handle with corrected parameters
    int handleBollinger = iBands(_Symbol, _Period, maPeriod, 0, deviation, PRICE_CLOSE);
    if (handleBollinger == INVALID_HANDLE)
    {
        Print("Error: Failed to create Bollinger Bands handle. LastError: ", GetLastError());
        return 0;
    }

    // Get Bollinger Bands data
    double upperBandArray[], lowerBandArray[];
    ArraySetAsSeries(upperBandArray, true);
    ArraySetAsSeries(lowerBandArray, true);

    // Copy data for 3 bars (index 1 = most recent closed bar)
    if (CopyBuffer(handleBollinger, 1, 0, 3, upperBandArray) < 3 ||
        CopyBuffer(handleBollinger, 2, 0, 3, lowerBandArray) < 3)
    {
        Print("Error: Failed to copy Bollinger Bands values. LastError: ", GetLastError());
        IndicatorRelease(handleBollinger);
        return 0;
    }

    IndicatorRelease(handleBollinger);

    if(location=="UPPER"){
         return upperBandArray[1];
    }
    else if(location=="LOWER"){
         return lowerBandArray[1];
    }else{
      return 0;
    }
    

}
void OnTick()
  {
//---
   /*string bbTouchSignal = BollingerTouchSignal(BBPeriod,BBDeviation);
   if(bbTouchSignal=="CLOSESELL" ){
         tradeExec.CloseSellTrades();
   }
   if(bbTouchSignal=="CLOSEBUY"){
      tradeExec.CloseBuyTrades();
   }
   
   // Loop through all open positions
   
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0)
        {
            // Apply trailing stop with 50 pips activation and 20 pips trailing distance
            tradeExec.ApplyTrailingStop(ticket, 50, 20);
        }
    }
    */
   //--- Check for signals
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0); //--- Get the time of the current bar.
   if (currentBarTime != lastBarTime) { //--- Ensure processing happens only once per bar.
      lastBarTime = currentBarTime; //--- Update the last processed bar time.
      
      string bbEntrySignal = BollingerBandSignal(BBPeriod,BBEntry);
      
      
      string rsiSignal = RsiSignal(RSIPeriod,RSIUpperLevel,RSILowerLevel);
      // Example: Display real-time dynamic information
       string messages[];
       ArrayResize(messages, 6);
       messages[0] = "Symbol: " + _Symbol;
       messages[1] = "Bid: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), 5);
       messages[2] = "Ask: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 5);
       messages[3] = "BBEntrySignal: " + bbEntrySignal;
       //messages[4] = "BBTouchSignal: " + bbTouchSignal;
       messages[5] = "Rsi Signal: " + rsiSignal;
       
       chartComment.Show("Market Information", messages, ArraySize(messages));
       
      if (
         
            (rsiSignal=="BUY")&&
            (bbEntrySignal=="BUY")
            //bbSignal=="BUY"
            //rsiSignal=="BUY"
         
      ) { //--- Check for  RSI crossing below 30 (oversold signal).
         Print("BUY SIGNAL"); //--- Log a BUY signal.
         //tradeExec.OpenTrade(ORDER_TYPE_BUY,dynamicLotSize,0,0);
         double stopLoss = GetBandValue(BBPeriod,BBStopLoss,"LOWER");
         double takeProfit = GetBandValue(BBPeriod,BBTakeProfit,"UPPER");
         if(stopLoss!=0){
            double targetPrice = stopLoss;
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double pipDiff = GetPipDifference(targetPrice, ask);
            double dynamicLotSize = CalculateLotSize(RISKPercentage,pipDiff);
            Print(" BUY Stoploss :",stopLoss," ask :", ask, "TakeProfit :", takeProfit);
            //tradeExec.OpenTrade(ORDER_TYPE_BUY,dynamicLotSize,50,100);
            trade.Buy(dynamicLotSize, _Symbol, ask, stopLoss, takeProfit, "Buy Order");
         }else{
            Print("Stoploss and takeprofit calculation error");
         }
         
         
         
      } else if (
         (rsiSignal=="SELL")&&
         (bbEntrySignal=="SELL")
         //bbSignal=="SELL"
         //rsiSignal=="SELL"
      ) { //--- Check for RSI crossing above 70 (overbought signal).
         Print("SELL SIGNAL"); //--- Log a SELL signa00l.
         //tradeExec.OpenTrade(ORDER_TYPE_SELL,dynamicLotSize,0,0);
         double stopLoss = GetBandValue(BBPeriod,BBStopLoss,"UPPER");
         double takeProfit = GetBandValue(BBPeriod,BBTakeProfit,"LOWER");
         if(stopLoss!=0){
            double targetPrice = stopLoss;
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double pipDiff = GetPipDifference(targetPrice, bid);
            double dynamicLotSize = CalculateLotSize(RISKPercentage,pipDiff);
            Print(" BUY Stoploss :",stopLoss," ask :", bid, "TakeProfit :", takeProfit);
            //tradeExec.OpenTrade(ORDER_TYPE_SELL,dynamicLotSize,50,100);
            trade.Sell(dynamicLotSize, _Symbol, bid, stopLoss, takeProfit, "Sell Order");
         }else{
            Print("Stoploss and takeprofit calculation error");
         }
      }
      
      
   }
   
  }
//+------------------------------------------------------------------+
