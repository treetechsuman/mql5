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
#include "Modules/TradeExecution.mqh";
#include "Modules/Utils.mqh";
#include "Modules/ChartComment.mqh";

// Global instance of the TradeExecution class
TradeExecution tradeExec;
ChartComment chartComment;

input double BBDeviation = 2.0;
input int    BBPeriod = 20;

input double LOTSize = 0.01;
input int STOPLoss = 50;
input int TAKEProfit = 100;

input int RSIPeriod = 14;            // RSI period
input int RSIUpperLevel = 70;      // RSI level for buy
input int RSILowerLevel = 30;     // RSI level for sell

input int RISKPercentage = 2;

datetime lastBarTime = 0; 
//+------------------------------------------------------------------+
//| Expert initializatioddn function  v                                 |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
int minStopLossPoints = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
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
void OnTick()
  {
//---
   string bbTouchSignal = BollingerTouchSignal(BBPeriod,BBDeviation);
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
    
   //--- Check for signals
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0); //--- Get the time of the current bar.
   if (currentBarTime != lastBarTime) { //--- Ensure processing happens only once per bar.
      lastBarTime = currentBarTime; //--- Update the last processed bar time.
      
      string bbSignal = BollingerBandSignal(BBPeriod,BBDeviation);
      
      string rsiSignal = RsiSignal(RSIPeriod,RSIUpperLevel,RSILowerLevel);
      // Example: Display real-time dynamic information
       string messages[];
       ArrayResize(messages, 6);
       messages[0] = "Symbol: " + _Symbol;
       messages[1] = "Bid: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), 5);
       messages[2] = "Ask: " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 5);
       messages[3] = "BBSignal: " + bbSignal;
       messages[4] = "BBTouchSignal: " + bbTouchSignal;
       messages[5] = "Rsi Signal: " + rsiSignal;
       
       chartComment.Show("Market Information", messages, ArraySize(messages));
       double dynamicLotSize = CalculateLotSize(RISKPercentage,STOPLoss);
      if (
         
            (bbSignal==rsiSignal)&&(bbSignal=="BUY")
            //bbSignal=="BUY"
            //rsiSignal=="BUY"
         
      ) { //--- Check for  RSI crossing below 30 (oversold signal).
         Print("BUY SIGNAL"); //--- Log a BUY signal.
         tradeExec.OpenTrade(ORDER_TYPE_BUY,dynamicLotSize,0,0);
         //tradeExec.OpenTrade(ORDER_TYPE_BUY,dynamicLotSize,STOPLoss,TAKEProfit);
         
         
      } else if (
         (bbSignal==rsiSignal)&&(bbSignal=="SELL")
         //bbSignal=="SELL"
         //rsiSignal=="SELL"
      ) { //--- Check for RSI crossing above 70 (overbought signal).
         Print("SELL SIGNAL"); //--- Log a SELL signa00l.
         tradeExec.OpenTrade(ORDER_TYPE_SELL,dynamicLotSize,0,0);
         //tradeExec.OpenTrade(ORDER_TYPE_SELL,dynamicLotSize,STOPLoss,TAKEProfit);
      }
      
      
   }
   
  }
//+------------------------------------------------------------------+
