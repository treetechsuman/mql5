//+------------------------------------------------------------------+
//|                                      1. Zone Recovery RSI EA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "Modules/ZoneRecovery.mqh";


// Global variables for RSI logic
int rsiPeriod = 14;                //--- The period used for calculating the RSI indicator.
int rsiHandle;                     //--- Handle for the RSI indicator, used to retrieve RSI values.
double rsiBuffer[];                //--- Array to store the RSI values retrieved from the indicator.
datetime lastBarTime = 0;          //--- Holds the time of the last processed bar to prevent duplicate signals.
input int inputzonePts = 700;           //--- equal to 50 pips
input int inputtargetPts = 1400;         //--- equal to 100 pips
input double initialLotSize = 0.1;


ZoneRecovery zoneRecovery(initialLotSize, inputzonePts, inputtargetPts, 2.0, _Symbol);
//--- Initialize the ZoneRecovery object with specified parameters.

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   //--- Initialize RSI indicator
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, rsiPeriod, PRICE_CLOSE); //--- Create RSI indicator handle.
   if (rsiHandle == INVALID_HANDLE) { //--- Check if RSI handle creation failed.
      Print("Failed to create RSI handle. Error: ", GetLastError());
      return(INIT_FAILED); //--- Return failure status if RSI initialization fails.
   }
   ArraySetAsSeries(rsiBuffer, true); //--- Set the RSI buffer as a time series to align values.
   Print("Zone Recovery Strategy initialized."); //--- Log successful initialization.
   int minStopLossPoints = SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL);
   double minStopLossPips = minStopLossPoints * _Point / GetPipSize();
   
   Print("Minimum Stop Loss in Points: ", minStopLossPoints);
   Print("Minimum Stop Loss in Pips: ", minStopLossPips);
   return(INIT_SUCCEEDED); //--- Return success status.
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if (rsiHandle != INVALID_HANDLE) //--- Check if RSI handle is valid.
      IndicatorRelease(rsiHandle); //--- Release RSI indicator handle to free resources.

   Print("Zone Recovery Strategy deinitialized."); //--- Log deinitialization message.
}
double GetPipSize()
{
    if (SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 3 || SymbolInfoInteger(Symbol(), SYMBOL_DIGITS) == 5)
        return 10 * _Point; // Normal pairs (EUR/USD, GBP/USD)
    else
        return _Point; // JPY pairs (USD/JPY, EUR/JPY)
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   //--- Copy RSI values
   if (CopyBuffer(rsiHandle, 0, 1, 2, rsiBuffer) <= 0) { //--- Attempt to copy RSI buffer values.
      Print("Failed to copy RSI buffer. Error: ", GetLastError()); //--- Log failure if copying fails.
      return; //--- Exit the function on failure to avoid processing invalid data.
   }

   //--- Check RSI crossover signals
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0); //--- Get the time of the current bar.
   if (currentBarTime != lastBarTime) { //--- Ensure processing happens only once per bar.
      lastBarTime = currentBarTime; //--- Update the last processed bar time.
      if (rsiBuffer[1] > 30 && rsiBuffer[0] <= 30) { //--- Check for RSI crossing below 30 (oversold signal).
         Print("BUY SIGNAL"); //--- Log a BUY signal.
         zoneRecovery.HandleSignal(ORDER_TYPE_BUY); //--- Trigger the Zone Recovery BUY logic.
         //double price = SymbolInfoDouble(Symbol(), SYMBOL_BID); // Current price
         DrawHorizontalLine("ZoneTargetHigh", zoneRecovery.getZoneTargetHigh(), clrGreen);
         DrawHorizontalLine("ZoneHigh", zoneRecovery.getZoneHigh(), clrRed);
         DrawHorizontalLine("ZoneLow", zoneRecovery.getZoneLow(), clrRed);
         DrawHorizontalLine("ZoneTargetLow", zoneRecovery.getZoneTargetLow(), clrGreen);
         Print("ConvertPointsToPips :",ConvertPointsToPips(inputzonePts));
         
      } else if (rsiBuffer[1] < 70 && rsiBuffer[0] >= 70) { //--- Check for RSI crossing above 70 (overbought signal).
         Print("SELL SIGNAL"); //--- Log a SELL signal.
         zoneRecovery.HandleSignal(ORDER_TYPE_SELL); //--- Trigger the Zone Recovery SELL logic.
         DrawHorizontalLine("ZoneTargetHigh", zoneRecovery.getZoneTargetHigh(), clrGreen);
         DrawHorizontalLine("ZoneHigh", zoneRecovery.getZoneHigh(), clrRed);
         DrawHorizontalLine("ZoneLow", zoneRecovery.getZoneLow(), clrRed);
         DrawHorizontalLine("ZoneTargetLow", zoneRecovery.getZoneTargetLow(), clrGreen);
      }
   }

   //--- Manage zone recovery logic
   zoneRecovery.ManageZones(); //--- Perform zone recovery logic for active positions.

   //--- Check and close at zone targets
   zoneRecovery.CheckCloseAtTargets(); //--- Evaluate and close trades when target levels are reached.
   
   if (zoneRecovery.isFirstPosition == true){ //--- Check if this is the first position in the Zone Recovery process
      applyTrailingStop(100, obj_Trade, 0, 100); //--- Apply a trailing stop with 100 points, passing the "obj_Trade" object, a magic number of 0, and a minimum profit of 100 points
   }
   
   if (zoneRecovery.isFirstPosition == true && PositionsTotal() == 0){ //--- Check if this is the first position and if there are no open positions
      zoneRecovery.Reset(); //--- Reset the Zone Recovery system, restoring initial settings and clearing previous trade data
   }
   
}

double ConvertPointsToPips(double points)
{
    return points / (10 * _Point);
}

//-------
   //-------------------------
   void DrawHorizontalLine(string lineName, double priceLevel, color lineColor = clrRed)
   {
       // Delete the line if it already exists
       if (ObjectFind(0, lineName) != -1)
           ObjectDelete(0, lineName);
   
       // Create the horizontal line
       ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, priceLevel);
       
       // Set the line color and width
       ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
       ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
   }
//+------------------------------------------------------------------+
//|      FUNCTION TO APPLY TRAILING STOP                              |
//+------------------------------------------------------------------+
void applyTrailingStop(double slPoints, CTrade &trade_object, int magicNo=0, double minProfitPoints=0){
   double buySl = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID) - slPoints*_Point, _Digits); //--- Calculate the stop loss price for BUY trades
   double sellSl = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK) + slPoints*_Point, _Digits); //--- Calculate the stop loss price for SELL trades
   
   for (int i = PositionsTotal() - 1; i >= 0; i--){ //--- Loop through all open positions
      ulong ticket = PositionGetTicket(i); //--- Get the ticket number of the current position
      if (ticket > 0){ //--- Check if the ticket is valid
         if (PositionSelectByTicket(ticket)){ //--- Select the position by its ticket number
            if (PositionGetString(POSITION_SYMBOL) == _Symbol && //--- Check if the position belongs to the current symbol
               (magicNo == 0 || PositionGetInteger(POSITION_MAGIC) == magicNo)){ //--- Check if the position matches the given magic number or if no magic number is specified
               
               double positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN); //--- Get the opening price of the position
               double positionSl = PositionGetDouble(POSITION_SL); //--- Get the current stop loss of the position
               
               if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){ //--- Check if the position is a BUY trade
                  double minProfitPrice = NormalizeDouble(positionOpenPrice + minProfitPoints * _Point, _Digits); //--- Calculate the minimum price at which profit is locked
                  if (buySl > minProfitPrice &&  //--- Check if the calculated stop loss is above the minimum profit price
                      buySl > positionOpenPrice && //--- Check if the calculated stop loss is above the opening price
                      (buySl > positionSl || positionSl == 0)){ //--- Check if the calculated stop loss is greater than the current stop loss or if no stop loss is set
                     trade_object.PositionModify(ticket, buySl, PositionGetDouble(POSITION_TP)); //--- Modify the position to update the stop loss
                  }
               }
               else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){ //--- Check if the position is a SELL trade
                  double minProfitPrice = NormalizeDouble(positionOpenPrice - minProfitPoints * _Point, _Digits); //--- Calculate the minimum price at which profit is locked
                  if (sellSl < minProfitPrice &&  //--- Check if the calculated stop loss is below the minimum profit price
                      sellSl < positionOpenPrice && //--- Check if the calculated stop loss is below the opening price
                      (sellSl < positionSl || positionSl == 0)){ //--- Check if the calculated stop loss is less than the current stop loss or if no stop loss is set
                     trade_object.PositionModify(ticket, sellSl, PositionGetDouble(POSITION_TP)); //--- Modify the position to update the stop loss
                  }
               }
            }
         }
      }
   }
}
