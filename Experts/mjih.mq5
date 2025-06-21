//+------------------------------------------------------------------+
//|                                      1. Zone Recovery RSI EA.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade obj_Trade;
//--- Includes the MQL5 Trade library for handling trading operations.

// Global variables for RSI logic
int rsiPeriod = 14;                //--- The period used for calculating the RSI indicator.
int rsiHandle;                     //--- Handle for the RSI indicator, used to retrieve RSI values.
double rsiBuffer[];                //--- Array to store the RSI values retrieved from the indicator.
datetime lastBarTime = 0;          //--- Holds the time of the last processed bar to prevent duplicate signals.

// Global ZoneRecovery object
class ZoneRecovery {
private:
   CTrade trade;                    //--- Object to handle trading operations.
   double initialLotSize;           //--- The initial lot size for the first trade.
   double currentLotSize;           //--- The lot size for the current trade in the sequence.
   double zoneSize;                 //--- Distance in points defining the range of the recovery zone.
   double targetSize;               //--- Distance in points defining the target profit range.
   double multiplier;               //--- Multiplier to increase lot size in recovery trades.
   string symbol;                   //--- Symbol for trading (e.g., currency pair).
   ENUM_ORDER_TYPE lastOrderType;   //--- Type of the last executed order (BUY or SELL).
   double lastOrderPrice;           //--- Price at which the last order was executed.
   double zoneHigh;                 //--- Upper boundary of the recovery zone.
   double zoneLow;                  //--- Lower boundary of the recovery zone.
   double zoneTargetHigh;           //--- Upper boundary for target profit range.
   double zoneTargetLow;            //--- Lower boundary for target profit range.
   bool isRecovery;                 //--- Flag indicating whether the recovery process is active.

   // Calculate dynamic zones and targets
   void CalculateZones() {
      if (lastOrderType == ORDER_TYPE_BUY) {
         zoneHigh = lastOrderPrice;                 //--- Upper boundary starts from the last BUY price.
         zoneLow = zoneHigh - zoneSize;             //--- Lower boundary is calculated by subtracting zone size.
         zoneTargetHigh = zoneHigh + targetSize;    //--- Profit target above the upper boundary.
         zoneTargetLow = zoneLow - targetSize;      //--- Buffer below the lower boundary for recovery trades.
      } else if (lastOrderType == ORDER_TYPE_SELL) {
         zoneLow = lastOrderPrice;                  //--- Lower boundary starts from the last SELL price.
         zoneHigh = zoneLow + zoneSize;             //--- Upper boundary is calculated by adding zone size.
         zoneTargetLow = zoneLow - targetSize;      //--- Buffer below the lower boundary for profit range.
         zoneTargetHigh = zoneHigh + targetSize;    //--- Profit target above the upper boundary.
      }
      Print("Zone recalculated: ZoneHigh=", zoneHigh, ", ZoneLow=", zoneLow, ", TargetHigh=", zoneTargetHigh, ", TargetLow=", zoneTargetLow);
   }

   // Open a trade based on the given type
   bool OpenTrade(ENUM_ORDER_TYPE type) {
      if (type == ORDER_TYPE_BUY) {
         if (trade.Buy(currentLotSize, symbol)) {
            lastOrderType = ORDER_TYPE_BUY;         //--- Mark the last trade as BUY.
            lastOrderPrice = SymbolInfoDouble(symbol, SYMBOL_BID); //--- Store the current BID price.
            CalculateZones();                       //--- Recalculate zones after placing the trade.
            Print(isRecovery ? "RECOVERY BUY order placed" : "INITIAL BUY order placed", " at ", lastOrderPrice, " with lot size ", currentLotSize);
            isFirstPosition = isRecovery ? false : true;
            isRecovery = true;                      //--- Set recovery state to true after the first trade.
            return true;
         }
      } else if (type == ORDER_TYPE_SELL) {
         if (trade.Sell(currentLotSize, symbol)) {
            lastOrderType = ORDER_TYPE_SELL;        //--- Mark the last trade as SELL.
            lastOrderPrice = SymbolInfoDouble(symbol, SYMBOL_BID); //--- Store the current BID price.
            CalculateZones();                       //--- Recalculate zones after placing the trade.
            Print(isRecovery ? "RECOVERY SELL order placed" : "INITIAL SELL order placed", " at ", lastOrderPrice, " with lot size ", currentLotSize);
            isFirstPosition = isRecovery ? false : true;
            isRecovery = true;                      //--- Set recovery state to true after the first trade.
            return true;
         }
      }
      return false;                                 //--- Return false if the trade fails.
   }

public:
   bool isFirstPosition;

public:
   // Constructor
   ZoneRecovery(double initialLot, double zonePts, double targetPts, double lotMultiplier, string _symbol) {
      initialLotSize = initialLot;
      currentLotSize = initialLot;                 //--- Start with the initial lot size.
      zoneSize = zonePts * _Point;                 //--- Convert zone size to points.
      targetSize = targetPts * _Point;             //--- Convert target size to points.
      multiplier = lotMultiplier;
      symbol = _symbol;                            //--- Initialize the trading symbol.
      lastOrderType = ORDER_TYPE_BUY;
      lastOrderPrice = 0.0;                        //--- No trades exist initially.
      isRecovery = false;                          //--- No recovery process active at initialization.
      isFirstPosition = false;
   }

   // Trigger trade based on external signals
   void HandleSignal(ENUM_ORDER_TYPE type) {
      if (lastOrderPrice == 0.0)                   //--- Open the first trade if no trades exist.
         OpenTrade(type);
   }

   // Manage zone recovery positions
   void ManageZones() {
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID); //--- Get the current BID price.

      // Open recovery trades based on zones
      if (lastOrderType == ORDER_TYPE_BUY && currentPrice <= zoneLow) {
         currentLotSize *= multiplier;            //--- Increase lot size for recovery.
         OpenTrade(ORDER_TYPE_SELL);              //--- Open a SELL order for recovery.
      } else if (lastOrderType == ORDER_TYPE_SELL && currentPrice >= zoneHigh) {
         currentLotSize *= multiplier;            //--- Increase lot size for recovery.
         OpenTrade(ORDER_TYPE_BUY);               //--- Open a BUY order for recovery.
      }
   }

   // Check and close trades at zone targets
   void CheckCloseAtTargets() {
      double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID); //--- Get the current BID price.

      // Close BUY trades at target high
      if (lastOrderType == ORDER_TYPE_BUY && currentPrice >= zoneTargetHigh) {
         for (int i = PositionsTotal() - 1; i >= 0; i--) { //--- Loop through all open positions.
            if (PositionGetSymbol(i) == symbol) { //--- Check if the position belongs to the current symbol.
               ulong ticket = PositionGetInteger(POSITION_TICKET); //--- Retrieve the ticket number.
               int retries = 10;
               while (retries > 0) {
                  if (trade.PositionClose(ticket)) { //--- Attempt to close the position.
                     Print("Closed BUY position with ticket: ", ticket);
                     break;
                  } else {
                     Print("Failed to close BUY position with ticket: ", ticket, ". Retrying... Error: ", GetLastError());
                     retries--;
                     Sleep(100);                   //--- Wait 100ms before retrying.
                  }
               }
               if (retries == 0)
                  Print("Gave up on closing BUY position with ticket: ", ticket);
            }
         }
         Reset();                                  //--- Reset the strategy after closing all positions.
      }
      // Close SELL trades at target low
      else if (lastOrderType == ORDER_TYPE_SELL && currentPrice <= zoneTargetLow) {
         for (int i = PositionsTotal() - 1; i >= 0; i--) { //--- Loop through all open positions.
            if (PositionGetSymbol(i) == symbol) { //--- Check if the position belongs to the current symbol.
               ulong ticket = PositionGetInteger(POSITION_TICKET); //--- Retrieve the ticket number.
               int retries = 10;
               while (retries > 0) {
                  if (trade.PositionClose(ticket)) { //--- Attempt to close the position.
                     Print("Closed SELL position with ticket: ", ticket);
                     break;
                  } else {
                     Print("Failed to close SELL position with ticket: ", ticket, ". Retrying... Error: ", GetLastError());
                     retries--;
                     Sleep(100);                   //--- Wait 100ms before retrying.
                  }
               }
               if (retries == 0)
                  Print("Gave up on closing SELL position with ticket: ", ticket);
            }
         }
         Reset();                                  //--- Reset the strategy after closing all positions.
      }
   }

   // Reset the strategy after hitting targets
   void Reset() {
      currentLotSize = initialLotSize;             //--- Reset lot size to the initial value.
      lastOrderType = -1;                          //--- Clear the last order type.
      lastOrderPrice = 0.0;                        //--- Clear the last order price.
      isRecovery = false;                          //--- Set recovery state to false.
      isFirstPosition = false;
      Print("Strategy reset after closing trades.");
   }
};

ZoneRecovery zoneRecovery(0.1, 700, 1400, 2.0, _Symbol);
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
      } else if (rsiBuffer[1] < 70 && rsiBuffer[0] >= 70) { //--- Check for RSI crossing above 70 (overbought signal).
         Print("SELL SIGNAL"); //--- Log a SELL signal.
         zoneRecovery.HandleSignal(ORDER_TYPE_SELL); //--- Trigger the Zone Recovery SELL logic.
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

//+------------------------------------------------------------------+
//|      FUNCTION TO APPLY TRAILING STOP                             |
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

