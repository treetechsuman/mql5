//+------------------------------------------------------------------+
//|                                                  AdaptiveBB.mq5  |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>

// Input parameters
input double   RiskPercent    = 1.0;    // Risk per trade (% of balance)
input int      BBPeriod       = 20;     // Bollinger Bands period
input double   BBDeviation    = 2.0;    // Bollinger Bands deviation
input int      RSIPeriod      = 14;     // RSI period
input int      ADXPeriod      = 14;     // ADX period
input int      VolLookback    = 50;     // Volatility lookback periods
input double   SqueezeFactor  = 0.75;   // Squeeze threshold factor
input bool     UseVolume      = true;   // Use volume confirmation

// Global variables
int rsiHandle, bbHandle, adxHandle;
double upperBand[], middleBand[], lowerBand[], rsi[], adx[], plusDI[], minusDI[];
long volumes[];
datetime lastTradeTime;
MqlRates priceData[];
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create indicator handles
   bbHandle = iBands(_Symbol, _Period, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, _Period, ADXPeriod);
   
   // Set indicator buffers
   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(middleBand, true);
   ArraySetAsSeries(lowerBand, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(plusDI, true);
   ArraySetAsSeries(minusDI, true);
   ArraySetAsSeries(volumes, true);
   ArraySetAsSeries(priceData, true);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(bbHandle);
   IndicatorRelease(rsiHandle);
   IndicatorRelease(adxHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   if(lastTradeTime == iTime(_Symbol, _Period, 0)) return;
   lastTradeTime = iTime(_Symbol, _Period, 0);
   
   // Load price and volume data
   CopyRates(_Symbol, _Period, 0, VolLookback, priceData);
   CopyTickVolume(_Symbol, _Period, 0, VolLookback, volumes);
   
   // Refresh indicator values
   CopyBuffer(bbHandle, 1, 0, VolLookback, upperBand);     // Upper band
   CopyBuffer(bbHandle, 0, 0, VolLookback, middleBand);    // Middle band (20 SMA)
   CopyBuffer(bbHandle, 2, 0, VolLookback, lowerBand);     // Lower band
   CopyBuffer(rsiHandle, 0, 0, VolLookback, rsi);          // RSI values
   CopyBuffer(adxHandle, 0, 0, VolLookback, adx);          // ADX main line
   CopyBuffer(adxHandle, 1, 0, VolLookback, plusDI);       // +DI line
   CopyBuffer(adxHandle, 2, 0, VolLookback, minusDI);      // -DI line
   
   // Get current market information
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   
   // Calculate position size
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100);
   double lotSize = 0.1;  // Default size (will be recalculated)
   
   // Determine market state
   int marketState = GetMarketState();
   //Print(marketState);
   // Strategy execution based on market state
   switch(marketState)
   {
      case 1: // Squeeze state
         HandleSqueezeState(ask, bid, point, spread, riskAmount, lotSize);
         break;
         
      case 2: // Trending state
         HandleTrendingState(sd.symbol,ask, bid, point, spread, riskAmount, lotSize);
         break;
         
      case 3: // Ranging state
         HandleRangingState(ask, bid, point, spread, riskAmount, lotSize);
         break;
   }
   
   // Close positions based on exit rules
   ManageExits(ask, bid, point);
}

//+------------------------------------------------------------------+
//| Determine current market state                                   |
//+------------------------------------------------------------------+
int GetMarketState()
{
   // Calculate Bollinger Band width
   double currentBandWidth = upperBand[0] - lowerBand[0];
   
   // Calculate average bandwidth
   double avgBandWidth = 0;
   for(int i = 1; i < VolLookback; i++)
      avgBandWidth += (upperBand[i] - lowerBand[i]);
   avgBandWidth /= VolLookback;
   
   // Squeeze condition
   if(currentBandWidth < avgBandWidth * SqueezeFactor)
      return 1; // Squeeze state
   
   // Trending condition (ADX > 25 and +DI/-DI dominance)
   if(adx[0] > 25)
   {
      if(plusDI[0] > minusDI[0] && priceData[0].close > middleBand[0])
         return 2; // Uptrend
      if(minusDI[0] > plusDI[0] && priceData[0].close < middleBand[0])
         return 2; // Downtrend
   }
   
   // Ranging condition
   if(adx[0] < 20 && 
      MathAbs(upperBand[0] - upperBand[1]) < 10*_Point && 
      MathAbs(lowerBand[0] - lowerBand[1]) < 10*_Point)
      return 3; // Ranging state
   
   return 0; // No clear state
}

//+------------------------------------------------------------------+
//| Handle squeeze state logic                                       |
//+------------------------------------------------------------------+
void HandleSqueezeState(double ask, double bid, double point, double spread, 
                         double riskAmount, double &lotSize)
{
   // Breakout confirmation rules
   bool bullishBreakout = priceData[0].close > upperBand[0] && 
                         (volumes[0] > volumes[1] || !UseVolume) && 
                         rsi[0] > 50;
   
   bool bearishBreakout = priceData[0].close < lowerBand[0] 
                          && (volumes[0] > volumes[1] || !UseVolume) 
                          && rsi[0] < 50;
                         
   
   // Entry with pullback confirmation
   if(bullishBreakout && priceData[1].close < upperBand[1])
   {
      double sl = lowerBand[0] - spread;
      double slDistance = ask - sl;
      lotSize = NormalizeDouble(riskAmount / (slDistance / point), 2);
      
      if(lotSize > 0)
         trade.Buy(lotSize, _Symbol, ask, sl, 0, "BB-Squeeze-Bull");
   }
   else if(bearishBreakout && priceData[1].close > lowerBand[1])
   {
      double sl = upperBand[0] + spread;
      double slDistance = sl - bid;
      lotSize = NormalizeDouble(riskAmount / (slDistance / point), 2);
      
      if(lotSize > 0)
         trade.Sell(lotSize, _Symbol, bid, sl, 0, "BB-Squeeze-Bear");
   }
}

//+------------------------------------------------------------------+
//| Handle trending state logic                                      |
//+------------------------------------------------------------------+
void HandleTrendingState(string symbol,double ask, double bid, double point, double spread, 
                         double riskAmount, double &lotSize)
{
   // Uptrend conditions
   if(plusDI[0] > minusDI[0] && priceData[0].close > middleBand[0])
   {
      // Pullback to 20 SMA with RSI confirmation
      if(priceData[0].low <= middleBand[0] && rsi[0] > 40 && rsi[0] < 60)
      {
         double sl = middleBand[0] - 100*point - spread;
         double slDistance = ask - sl;
         lotSize = NormalizeDouble(riskAmount / (slDistance / point), 2);
         
         if(lotSize > 0)
            trade.Buy(lotSize, _Symbol, ask, sl, 0, "BB-Trend-Bull");
      }
   }
   // Downtrend conditions
   else if(minusDI[0] > plusDI[0] && priceData[0].close < middleBand[0])
   {
      // Pullback to 20 SMA with RSI confirmation
      if(priceData[0].high >= middleBand[0] && rsi[0] > 40 && rsi[0] < 60)
      {
         double sl = middleBand[0] + 100*point + spread;
         double slDistance = sl - bid;
         lotSize = NormalizeDouble(riskAmount / (slDistance / point), 2);
         
         if(lotSize > 0)
            trade.Sell(lotSize, _Symbol, bid, sl, 0, "BB-Trend-Bear");
      }
   }
}

//+------------------------------------------------------------------+
//| Handle ranging state logic                                       |
//+------------------------------------------------------------------+
void HandleRangingState(double ask, double bid, double point, double spread, 
                        double riskAmount, double &lotSize)
{
   // Upper band rejection (short signal)
   if(priceData[0].high >= upperBand[0] && rsi[0] > 70)
   {
      double sl = upperBand[0] + 50*point + spread;
      double slDistance = sl - bid;
      lotSize = NormalizeDouble(riskAmount / (slDistance / point), 2);
      
      if(lotSize > 0)
         trade.Sell(lotSize, _Symbol, bid, sl, middleBand[0], "BB-Range-Short");
   }
   // Lower band rejection (long signal)
   else if(priceData[0].low <= lowerBand[0] && rsi[0] < 30)
   {
      double sl = lowerBand[0] - 50*point - spread;
      double slDistance = ask - sl;
      lotSize = NormalizeDouble(riskAmount / (slDistance / point), 2);
      
      if(lotSize > 0)
         trade.Buy(lotSize, _Symbol, ask, sl, middleBand[0], "BB-Range-Long");
   }
}

//+------------------------------------------------------------------+
//| Manage position exits                                            |
//+------------------------------------------------------------------+
void ManageExits(double ask, double bid, double point)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol == _Symbol)
      {
         int posType = (int)PositionGetInteger(POSITION_TYPE);
         string comment = PositionGetString(POSITION_COMMENT);
         double currentTP = PositionGetDouble(POSITION_TP);
         
         // Breakout trade exit (trail to middle band)
         if(StringFind(comment, "Squeeze") != -1)
         {
            if(posType == POSITION_TYPE_BUY && bid < middleBand[0])
               trade.PositionClose(ticket);
            else if(posType == POSITION_TYPE_SELL && ask > middleBand[0])
               trade.PositionClose(ticket);
         }
         
         // Trend trade partial exit at opposite band
         if(StringFind(comment, "Trend") != -1)
         {
            double positionSize = PositionGetDouble(POSITION_VOLUME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            
            if(posType == POSITION_TYPE_BUY && bid > upperBand[0] && positionSize > 0.1)
            {
               // Close half position at opposite band
               trade.PositionClosePartial(ticket, NormalizeDouble(positionSize/2, 2));
            }
            else if(posType == POSITION_TYPE_SELL && ask < lowerBand[0] && positionSize > 0.1)
            {
               // Close half position at opposite band
               trade.PositionClosePartial(ticket, NormalizeDouble(positionSize/2, 2));
            }
         }
      }
   }
}
//+------------------------------------------------------------------+