//+------------------------------------------------------------------+
//|                          MultiSymbolBBReversalEA.mq5             |
//|               Mean Reversion with Bollinger Bands               |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input string Symbols = "EURUSD,GBPUSD,USDCHF,USDJPY";
input double RiskPercent = 0.02;
input int bbPeriod = 50;
input int bbStdEntry = 2;
input int bbStdTP = 1;
input int bbStdSL = 6;
input int rsiPeriod = 14;
input int rsiBuyLevel = 40;
input int rsiSellLevel = 60;
input int adxPeriod = 14;
input int adxThreshold = 25;
input ulong MagicNumber = 123456;

string symbolList[];

datetime lastTime[];

int OnInit() {
    StringSplit(Symbols, ',', symbolList);
    ArrayResize(lastTime, ArraySize(symbolList));
    trade.SetExpertMagicNumber(MagicNumber);
    return INIT_SUCCEEDED;
}

void OnTick() {
    for (int i = 0; i < ArraySize(symbolList); i++) {
        string symbol = symbolList[i];
        if (IsNewBar(symbol, i)) {
            ProcessSymbol(symbol);
        }
        modifyPosition(symbol);
    }
}

void ProcessSymbol(string symbol) {
    double upperBB[], lowerBB[];
    double rsiBuffer[], adxBuffer[];
    MqlRates rates[];

    int bbHandle = iBands(symbol, _Period, bbPeriod, 0, bbStdEntry, PRICE_CLOSE);
    int rsiHandle = iRSI(symbol, _Period, rsiPeriod, PRICE_CLOSE);
    int adxHandle = iADX(symbol, _Period, adxPeriod);

    ArraySetAsSeries(rates, true);
    ArraySetAsSeries(upperBB, true);
    ArraySetAsSeries(lowerBB, true);
    ArraySetAsSeries(rsiBuffer, true);
    ArraySetAsSeries(adxBuffer, true);

    if (CopyRates(symbol, _Period, 0, 3, rates) < 3 ||
        CopyBuffer(bbHandle, UPPER_BAND, 0, 3, upperBB) < 3 ||
        CopyBuffer(bbHandle, LOWER_BAND, 0, 3, lowerBB) < 3 ||
        CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) < 3 ||
        CopyBuffer(adxHandle, 0, 0, 3, adxBuffer) < 3) {
        return;
    }

    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

    if (rates[1].open < lowerBB[1] && rates[1].close > lowerBB[1] && rsiBuffer[1] < rsiBuyLevel && adxBuffer[1] > adxThreshold) {
        if (!PositionExists(symbol)) {
            double sl = NormalizeDouble(lowerBB[1], digits);
            double tp = NormalizeDouble(iBands(symbol, _Period, bbPeriod, 0, bbStdTP, PRICE_CLOSE), digits);
            double lot = CalculateLotSize(symbol, ask, sl);
            trade.Buy(lot, symbol, ask, sl, tp);
        }
    }

    if (rates[1].open > upperBB[1] && rates[1].close < upperBB[1] && rsiBuffer[1] > rsiSellLevel && adxBuffer[1] > adxThreshold) {
        if (!PositionExists(symbol)) {
            double sl = NormalizeDouble(upperBB[1], digits);
            double tp = NormalizeDouble(iBands(symbol, _Period, bbPeriod, 0, bbStdTP, PRICE_CLOSE), digits);
            double lot = CalculateLotSize(symbol, bid, sl);
            trade.Sell(lot, symbol, bid, sl, tp);
        }
    }
}

void modifyPosition(string currencyPair) {
    double lowerProfitExitBBBuffer[], upperProfitExitBBBuffer[], lowerLossExitBBBuffer[], upperLossExitBBBuffer[];
    int bbHandleTPUpper = iBands(currencyPair, _Period, bbPeriod, 0, bbStdTP, PRICE_CLOSE);
    int bbHandleTPLower = bbHandleTPUpper;
    int bbHandleSLUpper = iBands(currencyPair, _Period, bbPeriod, 0, bbStdSL, PRICE_CLOSE);
    int bbHandleSLLower = bbHandleSLUpper;

    CopyBuffer(bbHandleTPUpper, UPPER_BAND, 0, 3, upperProfitExitBBBuffer);
    CopyBuffer(bbHandleTPLower, LOWER_BAND, 0, 3, lowerProfitExitBBBuffer);
    CopyBuffer(bbHandleSLLower, LOWER_BAND, 0, 3, lowerLossExitBBBuffer);
    CopyBuffer(bbHandleSLUpper, UPPER_BAND, 0, 3, upperLossExitBBBuffer);

    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong position_ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(position_ticket)) {
            int positionType = PositionGetInteger(POSITION_TYPE);
            double optimalTakeProfit;
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double positionStopLoss = PositionGetDouble(POSITION_SL);
            double positionTakeProfit = PositionGetDouble(POSITION_TP);
            string positionSymbol = PositionGetString(POSITION_SYMBOL);

            if (positionType == POSITION_TYPE_BUY) {
                optimalTakeProfit = NormalizeDouble(upperProfitExitBBBuffer[0], _Digits);
            } else {
                optimalTakeProfit = NormalizeDouble(lowerProfitExitBBBuffer[0], _Digits);
            }

            double tPDistance = NormalizeDouble(MathAbs(positionTakeProfit - optimalTakeProfit), _Digits) / SymbolInfoDouble(positionSymbol, SYMBOL_POINT);
            double diffBtntakeProfitAndEntryPrice = NormalizeDouble(MathAbs(entryPrice - optimalTakeProfit), _Digits) / SymbolInfoDouble(positionSymbol, SYMBOL_POINT);

            if (positionTakeProfit != optimalTakeProfit && tPDistance >= 5 && positionSymbol == currencyPair && diffBtntakeProfitAndEntryPrice >= 20) {
                trade.PositionModify(position_ticket, positionStopLoss, optimalTakeProfit);
            }
        }
    }
}

bool PositionExists(string symbol) {
    for (int i = 0; i < PositionsTotal(); i++) {
        if (PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            return true;
        }
    }
    return false;
}

double CalculateLotSize(string symbol, double entry, double sl) {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * RiskPercent;
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double slDistance = MathAbs(entry - sl);
    double lotSize = riskAmount / (slDistance / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) * tickValue);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    lotSize = MathMax(minLot, MathMin(maxLot, NormalizeDouble(lotSize, 2)));
    return lotSize;
}

bool IsNewBar(string symbol, int index) {
    datetime timeArray[];
    if (CopyTime(symbol, _Period, 0, 1, timeArray) != 1) return false;

    if (timeArray[0] != lastTime[index]) {
        lastTime[index] = timeArray[0];
        return true;
    }
    return false;
}
