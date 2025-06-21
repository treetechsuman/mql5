//+------------------------------------------------------------------+
//|                Forex Day Trading EA (MQL5 Version)              |
//|     Enhanced with Multi-Timeframe, Volatility Filter,          |
//|     News Filter, Dynamic Lot Sizing, and Trailing Stop         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

CTrade trade;

// Strategy Parameters
input double RiskPercent = 1.0;       // Risk per trade (%)
input int FastEMA = 20;               // Fast EMA period
input int SlowEMA = 50;               // Slow EMA period
input int ATRPeriod = 14;             // ATR period for SL/TP
input int RSIPeriod = 14;             // RSI period
input int ADXPeriod = 14;             // ADX period
input bool NewsFilter = true;         // Enable news filter

//+------------------------------------------------------------------+
//| Check High Impact News (Dummy Function - Needs Real Implementation) |
//+------------------------------------------------------------------+
bool IsHighImpactNews() {
    // Placeholder for news filter logic
    return false; // Replace with actual news data check
}

//+------------------------------------------------------------------+
//| Dynamic Lot Sizing                                              |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double slDistance) {
    double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (riskPercent / 100);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotSize = (riskAmount / (slDistance / SymbolInfoDouble(_Symbol, SYMBOL_POINT))) / tickValue;

    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    lotSize = MathMax(minLot, MathMin(lotSize, maxLot));
    lotSize = MathFloor(lotSize / lotStep) * lotStep;

    return lotSize;
}

//+------------------------------------------------------------------+
//| Trailing Stop Logic                                             |
//+------------------------------------------------------------------+
void TrailStop(double atr) {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket)) {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double stopLoss = 0;

            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                stopLoss = currentPrice - (atr * 1.5);
                if (stopLoss > PositionGetDouble(POSITION_SL)) {
                    trade.PositionModify(ticket, stopLoss, PositionGetDouble(POSITION_TP));
                }
            } else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                stopLoss = currentPrice + (atr * 1.5);
                if (stopLoss < PositionGetDouble(POSITION_SL)) {
                    trade.PositionModify(ticket, stopLoss, PositionGetDouble(POSITION_TP));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Entry Logic                                                     |
//+------------------------------------------------------------------+
void OnTick() {
    double fastEMA = 0, slowEMA = 0, rsi = 0, adx = 0, atr = 0;

    int emaFastHandle = iMA(_Symbol, PERIOD_H1, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
    int emaSlowHandle = iMA(_Symbol, PERIOD_H1, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
    int rsiHandle = iRSI(_Symbol, PERIOD_H1, RSIPeriod, PRICE_CLOSE);
    int atrHandle = iATR(_Symbol, PERIOD_H1, ATRPeriod);
    int adxHandle = iADX(_Symbol, PERIOD_H1, ADXPeriod);

    double emaFastBuffer[], emaSlowBuffer[], rsiBuffer[], atrBuffer[], adxBuffer[];

    if (CopyBuffer(emaFastHandle, 0, 1, 1, emaFastBuffer) > 0) fastEMA = emaFastBuffer[0];
    if (CopyBuffer(emaSlowHandle, 0, 1, 1, emaSlowBuffer) > 0) slowEMA = emaSlowBuffer[0];
    if (CopyBuffer(rsiHandle, 0, 1, 1, rsiBuffer) > 0) rsi = rsiBuffer[0];
    if (CopyBuffer(atrHandle, 0, 1, 1, atrBuffer) > 0) atr = atrBuffer[0];
    if (CopyBuffer(adxHandle, 0, 1, 1, adxBuffer) > 0) adx = adxBuffer[0];

    // Check if EMA and other indicators are initialized properly
    if (fastEMA == 0 || slowEMA == 0 || atr == 0) return;

    // Check news filter
    if (NewsFilter && IsHighImpactNews()) return;
    
    // Buy conditions
    if (fastEMA > slowEMA && rsi > 50 && adx > 25) {
        double sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - atr;
        double tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (2 * atr);
        double lot = CalculateLotSize(RiskPercent, atr);
        if(PositionsTotal()==0){
        trade.Buy(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), sl, tp, "Buy");
        }
        
    }

    // Sell conditions
    if (fastEMA < slowEMA && rsi < 50 && adx > 25) {
        double sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) + atr;
        double tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (2 * atr);
        double lot = CalculateLotSize(RiskPercent, atr);
        if(PositionsTotal()==0){
        trade.Sell(lot, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), sl, tp, "Sell");
        }
    }

    // Trailing stop logic
    TrailStop(atr);
}
//+------------------------------------------------------------------+
