#include <Trade/Trade.mqh>
CTrade obj_Trade;
//--- Includes the MQL5 Trade library for handling trading operations.



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
   
   double getZoneHigh(){
      return this.zoneHigh;
   }
   double getZoneLow(){
      return this.zoneLow;
   }
   double getZoneTargetHigh(){
      return this.zoneTargetHigh;
   }
   double getZoneTargetLow(){
      return this.zoneTargetLow;
   }

};