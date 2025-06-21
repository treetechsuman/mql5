//+------------------------------------------------------------------+
//| Multi-Currency Triangle Breakout EA                             |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade trade;
CPositionInfo positionInfo;

input string SymbolsList = "EURUSD,AUDUSD,GBPUSD,USDJPY,EURJPY";//"EURUSD,AUDUSD";
string symbols[];
datetime lastBarTime[];
int atrHandles[], adxHandles[], maHandles[];

// Input parameters (unchanged)
input int      RegressionPeriod   = 30;
input double   BreakoutBuffer     = 1.5;
input double   RiskPercent        = 1.0;
input bool     UseTrendFilter     = true;
input int      TrendSMA           = 50;
input double   MinADX             = 25.0;
input int      MinATR             = 15;
input double   RiskReward         = 2.5;
input bool     UseTrailingStop    = true;
input int      TrailingStart      = 30;
input int      TrailingStep       = 10;
input bool     UsePartialProfit   = true;
input double   PartialCloseLevel  = 0.75;
input double   PartialClosePercent= 50;

int OnInit()
{
   StringSplit(SymbolsList, ',', symbols);
   int count = ArraySize(symbols);

   ArrayResize(lastBarTime, count);
   ArrayResize(atrHandles, count);
   ArrayResize(adxHandles, count);
   ArrayResize(maHandles, count);

   for(int i = 0; i < count; i++)
   {
      atrHandles[i] = iATR(symbols[i], PERIOD_CURRENT, 14);
      adxHandles[i] = iADX(symbols[i], PERIOD_CURRENT, 14);
      if (UseTrendFilter)
         maHandles[i] = iMA(symbols[i], PERIOD_CURRENT, TrendSMA, 0, MODE_SMA, PRICE_CLOSE);
   }
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
   for (int i = 0; i < ArraySize(symbols); i++)
   {
      string sym = symbols[i];
      datetime currentBar = iTime(sym, PERIOD_CURRENT, 0);
      if (lastBarTime[i] == currentBar) continue;
      lastBarTime[i] = currentBar;

      if (!IsVolatileMarket(sym, atrHandles[i])) continue;

      int trend = MarketTrendDirection(sym, adxHandles[i], maHandles[i]);

      double upper, lower;
      CalculateRegressionChannel(sym, upper, lower);

      double atrBuffer[]; ArraySetAsSeries(atrBuffer, true);
      if (CopyBuffer(atrHandles[i], 0, 0, 1, atrBuffer) <= 0) continue;
      double buffer = BreakoutBuffer * atrBuffer[0];

      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);

      if(trend > 0 && bid > upper + buffer && CountOpenPositions(sym) == 0)
      {
         double sl = upper - buffer;
         double tp = ask + (ask - sl) * RiskReward;
         double lot = CalculateLotSize(sym, ask, sl);
         trade.Buy(lot, sym, ask, sl, tp);
      }
      else if(trend < 0 && ask < lower - buffer && CountOpenPositions(sym) == 0)
      {
         double sl = lower + buffer;
         double tp = bid - (sl - bid) * RiskReward;
         double lot = CalculateLotSize(sym, bid, sl);
         trade.Sell(lot, sym, bid, sl, tp);
      }

      ManagePositions(sym);
   }
}

int MarketTrendDirection(string sym, int adxHandle, int maHandle)
{
   double adx[], pdi[], ndi[];
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(pdi, true);
   ArraySetAsSeries(ndi, true);
   if(CopyBuffer(adxHandle, 0, 0, 1, adx) <= 0) return 0;
   if(CopyBuffer(adxHandle, 1, 0, 1, pdi) <= 0) return 0;
   if(CopyBuffer(adxHandle, 2, 0, 1, ndi) <= 0) return 0;
   if(adx[0] < MinADX) return 0;

   if(UseTrendFilter)
   {
      double ma[]; ArraySetAsSeries(ma, true);
      if(CopyBuffer(maHandle, 0, 0, 1, ma) <= 0) return 0;
      double price = SymbolInfoDouble(sym, SYMBOL_BID);
      if(price > ma[0] && pdi[0] > ndi[0]) return 1;
      if(price < ma[0] && ndi[0] > pdi[0]) return -1;
   }
   return 0;
}

bool IsVolatileMarket(string sym, int atrHandle)
{
   double atr[]; ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return false;
   double atrPips = atr[0] / SymbolInfoDouble(sym, SYMBOL_POINT);
   return (atrPips >= MinATR);
}

double CalculateLotSize(string sym, double entry, double stopLoss)
{
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (RiskPercent/100);
   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double pointValue = SymbolInfoDouble(sym, SYMBOL_POINT);
   double riskPips = MathAbs(entry - stopLoss) / pointValue;
   if(riskPips == 0 || tickValue == 0) return 0.1;
   double lots = riskAmount / (riskPips * tickValue);
   lots = MathFloor(lots / 0.01) * 0.01;
   return MathMin(lots, SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX));
}

void CalculateRegressionChannel(string sym, double &upper, double &lower)
{
   double high[], low[], x[];
   ArrayResize(high, RegressionPeriod);
   ArrayResize(low, RegressionPeriod);
   ArrayResize(x, RegressionPeriod);
   for(int i = 0; i < RegressionPeriod; i++)
   {
      high[i] = iHigh(sym, PERIOD_CURRENT, i);
      low[i]  = iLow(sym, PERIOD_CURRENT, i);
      x[i]    = i;
   }
   double sumX = 0, sumYHigh = 0, sumXYHigh = 0, sumXX = 0;
   for(int i = 0; i < RegressionPeriod; i++)
   {
      sumX += x[i]; sumYHigh += high[i]; sumXYHigh += x[i]*high[i]; sumXX += x[i]*x[i];
   }
   double slopeHigh = (RegressionPeriod*sumXYHigh - sumX*sumYHigh) / (RegressionPeriod*sumXX - sumX*sumX);
   double interceptHigh = (sumYHigh - slopeHigh*sumX) / RegressionPeriod;
   upper = slopeHigh*(RegressionPeriod-1) + interceptHigh;

   double sumYLow = 0, sumXYLow = 0;
   for(int i = 0; i < RegressionPeriod; i++)
   {
      sumYLow += low[i]; sumXYLow += x[i]*low[i];
   }
   double slopeLow = (RegressionPeriod*sumXYLow - sumX*sumYLow) / (RegressionPeriod*sumXX - sumX*sumX);
   double interceptLow = (sumYLow - slopeLow*sumX) / RegressionPeriod;
   lower = slopeLow*(RegressionPeriod-1) + interceptLow;
}

int CountOpenPositions(string sym)
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i) && positionInfo.Symbol() == sym)
         count++;
   }
   return count;
}

void ManagePositions(string sym)
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i) && positionInfo.Symbol() == sym)
      {
         ulong ticket = positionInfo.Ticket();
         double openPrice = positionInfo.PriceOpen();
         double sl = positionInfo.StopLoss();
         double tp = positionInfo.TakeProfit();
         double profit = positionInfo.Profit();
         double point = SymbolInfoDouble(sym, SYMBOL_POINT);
         double riskDistance = MathAbs(openPrice - sl);
         if(riskDistance == 0) continue;
         if(UsePartialProfit && tp == 0 && profit >= riskDistance * PartialCloseLevel * positionInfo.Volume())
         {
            double closeVolume = positionInfo.Volume() * (PartialClosePercent/100);
            trade.PositionClosePartial(ticket, closeVolume);
            continue;
         }
         if(UseTrailingStop)
         {
            double newSL = 0;
            if(positionInfo.PositionType() == POSITION_TYPE_BUY)
            {
               double trailLevel = openPrice + TrailingStart * point;
               if(SymbolInfoDouble(sym, SYMBOL_BID) > trailLevel)
               {
                  newSL = SymbolInfoDouble(sym, SYMBOL_BID) - TrailingStep * point;
                  if(newSL > sl) trade.PositionModify(ticket, newSL, tp);
               }
            }
            else
            {
               double trailLevel = openPrice - TrailingStart * point;
               if(SymbolInfoDouble(sym, SYMBOL_ASK) < trailLevel)
               {
                  newSL = SymbolInfoDouble(sym, SYMBOL_ASK) + TrailingStep * point;
                  if(newSL < sl) trade.PositionModify(ticket, newSL, tp);
               }
            }
         }
      }
   }
}
