//+------------------------------------------------------------------+
//|                      MarketState.mqh                             |
//|     Utility module to detect market state: Squeeze, Trend,      |
//|     Range, Neutral. Simple version (no memory, per call only)   |
//+------------------------------------------------------------------+
#ifndef MARKET_STATE_MQH
#define MARKET_STATE_MQH

#include "Context.mqh"
#include"../../Core/Utils.mqh"
string GetMarketState(SymbolContext *ctx, int VolLookback = 48,int ConfirmBars = 3, double SqueezeFactor = 0.8, double ADXTradeValue = 22) {
   double totalBW,totalADX,totalPlusDI,totalMinusDI,totalPrice,totalMid=0;
   for (int i = 0; i < ConfirmBars; i++) {
        totalBW += ctx.GetEntryBBUpper(i) - ctx.GetEntryBBLower(i);
        totalADX += ctx.GetADX(i);
        totalPlusDI += ctx.GetPlusDI(i);
        totalMinusDI += ctx.GetMinusDI(i);
        totalPrice += ctx.sd.priceData[i].close;
        totalMid += ctx.GetMiddleBB(i);
    }

    double avgBW = 0;
    for (int i = 1; i <= VolLookback; i++)
        avgBW += (ctx.GetEntryBBUpper(i) - ctx.GetEntryBBLower(i));
    avgBW /= VolLookback;

    double bw = totalBW / ConfirmBars;
    double adx = totalADX / ConfirmBars;
    double plusDI = totalPlusDI / ConfirmBars;
    double minusDI = totalMinusDI / ConfirmBars;
    double price = totalPrice / ConfirmBars;
    double midBand = totalMid / ConfirmBars;
    double diGap = MathAbs(plusDI - minusDI);

    // === Squeeze Detection ===
    if (bw < avgBW * SqueezeFactor && adx < ADXTradeValue)
        return "Squeeze";

    // === Trending Market Detection ===
    if (adx > ADXTradeValue && diGap > 2) {
        if (plusDI > minusDI && price > midBand) return "TrendingUp";
        if (minusDI > plusDI && price < midBand) return "TrendingDown";
    }
    int RangeScoreThreshold = 4;
    double FlatnessFactor = 0.4; 
    double RangeHeightFactor = 3.5;
    int score = 0;
    // === Ranging Market Detection ===
    double highestHigh = GetRecentSwingHigh(ctx.sd.symbol,Timeframe,ConfirmBars);
    double lowestLow = GetRecentSwingLow(ctx.sd.symbol,Timeframe,ConfirmBars);
    double rangeHeight = highestHigh - lowestLow;
    double atr = ctx.GetATR(0);
    
    for (int i = 0; i < ConfirmBars; i++) {
        // Low ADX
        if (ctx.GetADX(i) < ADXTradeValue) score++;

        // Flat BB Upper/Lower
        if (MathAbs(ctx.GetEntryBBUpper(i) - ctx.GetEntryBBUpper(i+1)) < atr * FlatnessFactor &&
            MathAbs(ctx.GetEntryBBLower(i) - ctx.GetEntryBBLower(i+1)) < atr * FlatnessFactor)
            score++;

        // Small Range Height
        if (rangeHeight < atr * RangeHeightFactor) score++;

        // Price near Mid-BB
        double price = ctx.sd.priceData[i].close;
        double midBB = ctx.GetMiddleBB(i);
        if (MathAbs(price - midBB) < atr * 0.5) score++;
    }

    if (score >= RangeScoreThreshold)
        return "Ranging";

   

    // === Fallback ===
    return "Trending";
}

#endif // MARKET_STATE_MQH
