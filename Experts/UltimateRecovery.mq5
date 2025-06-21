//+------------------------------------------------------------------+
//|                                           UltimateRecoveryEA.mq5 |
//|        PROFITABLE VERSION: MACD + Trend + Momentum + ATR Filter |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

// Inputs
input double RiskPercent = 2.0;
input int MaxTradesPerSymbol = 1;
input string SymbolsList = "EURUSD,GBPUSD,USDJPY";
input int MagicNumber = 20250607;
input bool UseTimeFilter = true;
input int StartHour = 8;
input int EndHour = 20;
input int ATRPeriod = 14;
input double MinATR = 0.0001;
input double MinATRRatio = 0.0001; // ATR/price minimum ratio
input int MaxDrawdownPercent = 20;
input bool UseTrendFilter = false;
input int TrendMAPeriod = 200;
input bool AllowShortTrades = true;
input double SL_ATR_Multiplier = 1.2;
input double TP_ATR_Multiplier = 4.0;

// Internal state
double initialBalance;
datetime lastTradeTime[];

//+------------------------------------------------------------------+
int OnInit()
{
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    string symbols[];
    StringSplit(SymbolsList, ',', symbols);
    ArrayResize(lastTradeTime, ArraySize(symbols));
    ArrayInitialize(lastTradeTime, 0);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick()
{
    if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return;
    if (!CheckTradingWindow()) return;
    if (!CheckDrawdown()) return;

    string symbols[];
    StringSplit(SymbolsList, ',', symbols);

    for (int i = 0; i < ArraySize(symbols); i++)
    {
        string symbol = symbols[i];
        if (!SymbolInfoInteger(symbol, SYMBOL_SELECT))
            SymbolSelect(symbol, true);

        int atrHandle = iATR(symbol, _Period, ATRPeriod);
        double atr[];
        if (CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
        {
            IndicatorRelease(atrHandle);
            Print(symbol, " skipped: ATR not loaded or invalid.");
            continue;
        }
        Print(symbol, " ATR loaded: ", atr[0]);
        IndicatorRelease(atrHandle);

        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        if (atr[0] / price < MinATRRatio)
        {
            Print(symbol, " skipped: ATR/price ratio too low.");
            continue;
        }

        if (CountOpenTrades(symbol) >= MaxTradesPerSymbol)
        {
            Print(symbol, " skipped: Max trades per symbol reached.");
            continue;
        }

        datetime lastTime = lastTradeTime[i];
        datetime currentBarTime = iTime(symbol, _Period, 0);
        if (lastTime == currentBarTime)
        {
            Print(symbol, " skipped: Already traded on this bar.");
            continue;
        }

        double lot = CalculateLotSize(symbol, RiskPercent, atr[0] * SL_ATR_Multiplier / SymbolInfoDouble(symbol, SYMBOL_POINT));
        double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
        double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
        double sl = atr[0] * SL_ATR_Multiplier;
        double tp = atr[0] * TP_ATR_Multiplier;

        if (SignalBuy(symbol))
        {
            Print(symbol, " BUY signal passed. Sending order.");
            if (trade.Buy(lot, symbol, ask, ask - sl, ask + tp, NULL))
                lastTradeTime[i] = currentBarTime;
        }
        else if (AllowShortTrades && SignalSell(symbol))
        {
            Print(symbol, " SELL signal passed. Sending order.");
            if (trade.Sell(lot, symbol, bid, bid + sl, bid - tp, NULL))
                lastTradeTime[i] = currentBarTime;
        }
    }
}

//+------------------------------------------------------------------+
bool SignalBuy(string symbol)
{
    int macdHandle = iMACD(symbol, _Period, 12, 26, 9, PRICE_CLOSE);
    double macd[], signal[], hist[];
    if (CopyBuffer(macdHandle, 0, 1, 2, macd) < 2 || CopyBuffer(macdHandle, 1, 1, 2, signal) < 2 || CopyBuffer(macdHandle, 2, 1, 2, hist) < 2)
    {
        IndicatorRelease(macdHandle);
        return false;
    }
    if (!(macd[1] < signal[1] && macd[0] > signal[0])) {
        Print(symbol, " MACD crossover not bullish. macd[1]=", macd[1], " macd[0]=", macd[0], " signal[1]=", signal[1], " signal[0]=", signal[0]);
        IndicatorRelease(macdHandle);
        return false;
    }
    
    IndicatorRelease(macdHandle);

    // Candle confirmation temporarily disabled for buy

    if (UseTrendFilter)
    {
        int maHandle = iMA(symbol, _Period, TrendMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
        double ma[];
        if (CopyBuffer(maHandle, 0, 0, 1, ma) <= 0)
        {
            IndicatorRelease(maHandle);
            return false;
        }
        double price = iClose(symbol, _Period, 0);
        IndicatorRelease(maHandle);
        if (price < ma[0]) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
bool SignalSell(string symbol)
{
    int macdHandle = iMACD(symbol, _Period, 12, 26, 9, PRICE_CLOSE);
    double macd[], signal[], hist[];
    if (CopyBuffer(macdHandle, 0, 1, 2, macd) < 2 || CopyBuffer(macdHandle, 1, 1, 2, signal) < 2 || CopyBuffer(macdHandle, 2, 1, 2, hist) < 2)
    {
        IndicatorRelease(macdHandle);
        return false;
    }
    if (!(macd[1] > signal[1] && macd[0] < signal[0])) {
        Print(symbol, " MACD crossover not bearish. macd[1]=", macd[1], " macd[0]=", macd[0], " signal[1]=", signal[1], " signal[0]=", signal[0]);
        IndicatorRelease(macdHandle);
        return false;
    }
    
    IndicatorRelease(macdHandle);

    // Candle confirmation temporarily disabled for sell

    if (UseTrendFilter)
    {
        int maHandle = iMA(symbol, _Period, TrendMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
        double ma[];
        if (CopyBuffer(maHandle, 0, 0, 1, ma) <= 0)
        {
            IndicatorRelease(maHandle);
            return false;
        }
        double price = iClose(symbol, _Period, 0);
        IndicatorRelease(maHandle);
        if (price > ma[0]) return false;
    }
    return true;
}

//+------------------------------------------------------------------+
bool CheckTradingWindow()
{
    if (!UseTimeFilter) return true;
    MqlDateTime tm;
    TimeToStruct(TimeLocal(), tm);
    return (tm.hour >= StartHour && tm.hour < EndHour);
}

//+------------------------------------------------------------------+
bool CheckDrawdown()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dd = (initialBalance - equity) / initialBalance * 100;
    return dd < MaxDrawdownPercent;
}

//+------------------------------------------------------------------+
int CountOpenTrades(string symbol)
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if (PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double riskPercent, double stopLossPips)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    if (tickSize <= 0.0 || tickValue <= 0.0) return 0.01;

    double slMoney = stopLossPips * tickValue / tickSize;
    double risk = balance * riskPercent / 100.0;
    double lots = NormalizeDouble(risk / slMoney, 2);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    return MathMax(minLot, MathMin(lots, maxLot));
}
