//+------------------------------------------------------------------+
//|              Hybrid Trend + Zone Recovery EA (Refactored)        |
//|              Author: OpenAI Assistant                            |
//|              Fixes: Critical logic errors & improvements         |
//+------------------------------------------------------------------+
#property strict

// Input parameters (unchanged)
input double TrailingStart = 0.0005; // 5 pips
input double TrailingStep = 0.0003;  // 3 pips
input double DynamicTPMultiplier = 2.5;
input string SymbolsList = "EURUSD,GBPUSD";
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15;
input double RiskPercent = 1.0;
input int EMAFast = 12;
input int EMASlow = 26;
input int RSI_Period = 14;
input int RSI_BuyLevel = 55;
input int RSI_SellLevel = 45;
input double ATRMultiplier = 1.5;
input int ATR_Period = 14;
input double MinPinBarATR = 0.0004; // Minimum ATR filter for pin bar
input int MaxRecoverySteps = 5;
input double RecoveryMultiplier = 2.0;
input double BaseLot = 0.1;
input double MinATRThreshold = 0.0003;
input int StartHour = 8;
input int EndHour = 20;
input int MaxTradesPerDay = 10;

// Global variables (improved tracking)
int tradesToday = 0;
datetime lastTradeDay = 0;
double lastEntryPrice = 0;
int recoveryStep = 0;
bool inRecovery = false;
ulong tradeOrderTicket = 0;
double lastPositionVolume = BaseLot; // Track last trade volume

#include <Trade/Trade.mqh>
#include <Indicators/Trend.mqh>
#include <Indicators/Oscilators.mqh>
#include <ChartObjects/ChartObjectsLines.mqh>

CTrade trade;

string symbolsRaw[];
datetime lastTradeTimeMap[];

int OnInit() {
   StringSplit(SymbolsList, ',', symbolsRaw);
   ArrayResize(lastTradeTimeMap, ArraySize(symbolsRaw));
   for (int i = 0; i < ArraySize(symbolsRaw); i++) lastTradeTimeMap[i] = 0;
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Helper: Detect Bullish Engulfing Pattern                         |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(string symbol, ENUM_TIMEFRAMES tf) {
    double o1 = iOpen(symbol, tf, 1);
    double c1 = iClose(symbol, tf, 1);
    double o0 = iOpen(symbol, tf, 0);
    double c0 = iClose(symbol, tf, 0);
    return (c1 < o1 && c0 > o0 && o0 < c1 && c0 > o1);
}

//+------------------------------------------------------------------+
//| Helper: Detect Bearish Engulfing Pattern                         |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(string symbol, ENUM_TIMEFRAMES tf) {
    double o1 = iOpen(symbol, tf, 1);
    double c1 = iClose(symbol, tf, 1);
    double o0 = iOpen(symbol, tf, 0);
    double c0 = iClose(symbol, tf, 0);
    return (c1 > o1 && c0 < o0 && o0 > c1 && c0 < o1);
}



//+------------------------------------------------------------------+
//| Helper functions (added)                                         |
//+------------------------------------------------------------------+
bool IsWithinTradingSession() {
    MqlDateTime tm;
    TimeToStruct(TimeCurrent(), tm);
    return (tm.hour >= StartHour && tm.hour < EndHour);
}

void DrawDashboard(string symbol) {
    Comment("Hybrid Trend Zone Recovery EA\n",
            "Symbol: ", symbol, "\n",
            "Trades Today: ", tradesToday, "\n",
            "In Recovery: ", inRecovery, "\n",
            "Recovery Step: ", recoveryStep);
}

double GetZoneDistance(string symbol) {
    int handle = iATR(symbol, Timeframe, ATR_Period);
    if (handle == INVALID_HANDLE) return -1;

    double atr[];
    ArraySetAsSeries(atr, true);
    if (CopyBuffer(handle, 0, 0, 1, atr) < 1) return -1;

    if (atr[0] < MinATRThreshold) return -1;
    return atr[0] * ATRMultiplier;
}

void DrawZoneLines(string symbol, double price, double zone) {
    string lineSL = symbol + "_SL", lineTP = symbol + "_TP";
    ObjectCreate(0, lineSL, OBJ_HLINE, 0, 0, price - zone);
    ObjectSetInteger(0, lineSL, OBJPROP_COLOR, clrRed);

    ObjectCreate(0, lineTP, OBJ_HLINE, 0, 0, price + zone * DynamicTPMultiplier);
    ObjectSetInteger(0, lineTP, OBJPROP_COLOR, clrGreen);
}

//+------------------------------------------------------------------+
//| Fixed: Correct trailing stop implementation                     |
//+------------------------------------------------------------------+
void ApplyTrailingStop(string symbol) {
    if(!PositionSelect(symbol)) return;
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                          SymbolInfoDouble(symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    double sl = PositionGetDouble(POSITION_SL);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double newSl = sl;
    double profitPoints = 0;

    // Calculate current profit in points
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
        profitPoints = (currentPrice - openPrice) / point;
        if(profitPoints > TrailingStart / point && currentPrice - sl > TrailingStep / point) {
            newSl = currentPrice - TrailingStep;
        }
    }
    else {
        profitPoints = (openPrice - currentPrice) / point;
        if(profitPoints > TrailingStart / point && sl - currentPrice > TrailingStep / point) {
            newSl = currentPrice + TrailingStep;
        }
    }
    
    // Modify SL only if new value is better
    if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && newSl > sl) || 
       (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && newSl < sl)) {
        trade.PositionModify(symbol, newSl, PositionGetDouble(POSITION_TP));
    }
}

//+------------------------------------------------------------------+
//| Fixed: Recovery trade logic                                      |
//+------------------------------------------------------------------+
void ManageRecovery(string symbol) {
    // Get last closed position from history
    HistorySelect(TimeCurrent()-86400, TimeCurrent());
    int totalDeals = HistoryDealsTotal();
    
    if(totalDeals > 0) {
        ulong dealTicket = HistoryDealGetTicket(totalDeals-1);
        if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            
            if(profit < 0 && recoveryStep < MaxRecoverySteps) {
                // Determine recovery direction (opposite of losing trade)
                ENUM_ORDER_TYPE recoveryDirection = (dealType == DEAL_TYPE_BUY) ? 
                                                    ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                
                // Calculate recovery lot size
                double recoveryLot = volume * RecoveryMultiplier;
                recoveryLot = NormalizeDouble(recoveryLot, 2);
                
                // Place recovery trade
                if(PlaceTrade(symbol, recoveryDirection, recoveryLot)) {
                    recoveryStep++;
                    inRecovery = true;
                    tradesToday++;
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Helper: Get current ATR value                                     |
//+------------------------------------------------------------------+
double GetCurrentATR(string symbol, ENUM_TIMEFRAMES tf, int period) {
    int handle = iATR(symbol, tf, period);
    if(handle == INVALID_HANDLE) return 0.0;

    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(handle, 0, 0, 1, atr) < 1) return 0.0;
    return atr[0];
}

//+------------------------------------------------------------------+
//| Helper: Detect Pin Bar Pattern                                   |
//+------------------------------------------------------------------+
bool IsBullishPinBar(string symbol, ENUM_TIMEFRAMES tf) {
    double open = iOpen(symbol, tf, 0);
    double close = iClose(symbol, tf, 0);
    double high = iHigh(symbol, tf, 0);
    double low = iLow(symbol, tf, 0);
    double body = MathAbs(close - open);
    double tail = open < close ? open - low : close - low;
    double atr = GetCurrentATR(symbol, tf, ATR_Period);
    return (atr > MinPinBarATR && body < (high - low) * 0.3 && tail > body * 2);
}

bool IsBearishPinBar(string symbol, ENUM_TIMEFRAMES tf) {
    double open = iOpen(symbol, tf, 0);
    double close = iClose(symbol, tf, 0);
    double high = iHigh(symbol, tf, 0);
    double low = iLow(symbol, tf, 0);
    double body = MathAbs(close - open);
    double wick = open > close ? high - open : high - close;
    double atr = GetCurrentATR(symbol, tf, ATR_Period);
    return (atr > MinPinBarATR && body < (high - low) * 0.3 && wick > body * 2);
}

//+------------------------------------------------------------------+
//| Determine Trend with Candlestick + ATR Filter + MA slope check  |
//+------------------------------------------------------------------+
int DetermineTrend(string symbol) {
    int fastHandle = iMA(symbol, Timeframe, EMAFast, 0, MODE_EMA, PRICE_CLOSE);
    int slowHandle = iMA(symbol, Timeframe, EMASlow, 0, MODE_EMA, PRICE_CLOSE);
    int rsiHandle = iRSI(symbol, Timeframe, RSI_Period, PRICE_CLOSE);

    double emaFast[], emaFastPrev[], emaSlow[], emaSlowPrev[], rsi[];
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaFastPrev, true);
    ArraySetAsSeries(emaSlow, true);
    ArraySetAsSeries(emaSlowPrev, true);
    ArraySetAsSeries(rsi, true);

    if(CopyBuffer(fastHandle, 0, 0, 2, emaFast) < 2) return -1;
    if(CopyBuffer(slowHandle, 0, 0, 2, emaSlow) < 2) return -1;
    if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) < 1) return -1;

    double slopeFast = emaFast[0] - emaFast[1];
    double slopeSlow = emaSlow[0] - emaSlow[1];

    if(emaFast[0] > emaSlow[0] && slopeFast > 0 && slopeSlow > 0 && rsi[0] > RSI_BuyLevel && 
      (IsBullishEngulfing(symbol, Timeframe) || IsBullishPinBar(symbol, Timeframe)))
        return ORDER_TYPE_BUY;

    if(emaFast[0] < emaSlow[0] && slopeFast < 0 && slopeSlow < 0 && rsi[0] < RSI_SellLevel && 
      (IsBearishEngulfing(symbol, Timeframe) || IsBearishPinBar(symbol, Timeframe)))
        return ORDER_TYPE_SELL;

    return -1;
}

// The rest of the code remains unchanged...

//+------------------------------------------------------------------+
//| Fixed: Trade execution with proper error handling               |
//+------------------------------------------------------------------+
bool PlaceTrade(string symbol, ENUM_ORDER_TYPE type, double lot) {
    // Price validation
    double price = (type == ORDER_TYPE_BUY) ? 
                   SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                   SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(price <= 0) {
        Print("Invalid price for ", symbol);
        return false;
    }
    
    // Zone distance calculation
    double zone = GetZoneDistance(symbol);
    if(zone <= 0) {
        Print("Invalid zone distance for ", symbol);
        return false;
    }
    
    // SL/TP calculation
    double sl = (type == ORDER_TYPE_BUY) ? price - zone : price + zone;
    double tp = (type == ORDER_TYPE_BUY) ? price + zone * DynamicTPMultiplier : 
                                          price - zone * DynamicTPMultiplier;
    
    // Execute trade
    if(!trade.PositionOpen(symbol, type, lot, price, sl, tp)) {
        Print("Trade failed: ", trade.ResultRetcodeDescription());
        return false;
    }
    
    // Update tracking variables
    lastEntryPrice = price;
    lastPositionVolume = lot;
    tradeOrderTicket = (ulong)trade.ResultOrder();
    DrawZoneLines(symbol, price, zone);
    
    return true;
}

//+------------------------------------------------------------------+
//| Fixed: Daily trade reset logic                                  |
//+------------------------------------------------------------------+
void CheckDailyReset() {
    MqlDateTime today;
    TimeToStruct(TimeCurrent(), today);
    today.hour = 0;
    today.min = 0;
    today.sec = 0;
    datetime todayStart = StructToTime(today);
    
    if(todayStart != lastTradeDay) {
        tradesToday = 0;
        recoveryStep = 0;
        inRecovery = false;
        lastTradeDay = todayStart;
    }
}

//+------------------------------------------------------------------+
//| Main OnTick with improved structure                             |
//+------------------------------------------------------------------+
void OnTick() {
    //string symbol = SymbolsList;
    for (int i = 0; i < ArraySize(symbolsRaw); i++) {
       string symbol = symbolsRaw[i];
       StringTrimLeft(symbol); 
       StringTrimRight(symbol);
       // Reset daily counters if needed
       CheckDailyReset();
       
       // Skip if trade limit reached or outside session hours
       if(tradesToday >= MaxTradesPerDay || !IsWithinTradingSession()) {
           DrawDashboard(symbol);
           return;
       }
       
       // Manage open positions
       if(PositionSelect(symbol)) {
           ApplyTrailingStop(symbol);
           return;
       }
       
       // Handle recovery after closed position
       if(!PositionSelect(symbol)) {
           ManageRecovery(symbol);
       }
       
       // Enter new trend trade if no recovery in progress
       if(!inRecovery && tradesToday < MaxTradesPerDay) {
           int signal = DetermineTrend(symbol);
           if(signal != -1 && PlaceTrade(symbol, (ENUM_ORDER_TYPE)signal, BaseLot)) {
               tradesToday++;
           }
       }
       
       DrawDashboard(symbol);
    }
}
