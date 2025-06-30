#include "Context.mqh"
// Confirm breakout with buffer, follow-through, and candle strength
bool IsBreakoutConfirmed(SymbolContext *ctx, string direction, double bufferPoints) {
    double prevClose = ctx.sd.priceData[1].close;
    double prevOpen = ctx.sd.priceData[1].open;
    double candleBody = MathAbs(prevClose - prevOpen);
    double candleRange = ctx.sd.priceData[1].high - ctx.sd.priceData[1].low;

    if (candleRange == 0) return false;

    double bodyRatio = candleBody / candleRange;

    if (direction == "bull") {
        return (
            prevClose > ctx.GetEntryBBUpper(2) + bufferPoints &&
            ctx.sd.priceData[2].close < ctx.GetEntryBBUpper(2) &&
            ctx.sd.priceData[1].close > ctx.sd.priceData[2].close &&     // follow-through
            (prevClose - prevOpen) > 0 && bodyRatio > 0.6
        );
    }

    if (direction == "bear") {
        return (
            prevClose < ctx.GetEntryBBLower(2) - bufferPoints &&
            ctx.sd.priceData[2].close > ctx.GetEntryBBLower(2) &&
            ctx.sd.priceData[1].close < ctx.sd.priceData[2].close &&     // follow-through
            (prevOpen - prevClose) > 0 && bodyRatio > 0.6
        );
    }

    return false;
}


// Detects bullish and bearish divergence over last `window` bars
void DetectRSIDivergence(SymbolContext *ctx, int window, bool &bullishDiv, bool &bearishDiv) {
    bullishDiv = false;
    bearishDiv = false;

    double lowestPrice = ctx.sd.priceData[1].low;
    int lowestIndex = 1;
    double highestPrice = ctx.sd.priceData[1].high;
    int highestIndex = 1;

    // Step 1: Find lowest low and highest high in price over `window` bars
    for(int i = 2; i <= window; i++) {
        if(ctx.sd.priceData[i].low < lowestPrice) {
            lowestPrice = ctx.sd.priceData[i].low;
            lowestIndex = i;
        }
        if(ctx.sd.priceData[i].high > highestPrice) {
            highestPrice = ctx.sd.priceData[i].high;
            highestIndex = i;
        }
    }

    // Step 2: Compare RSI values
    double rsiNow = ctx.GetRSI(1);  // latest closed bar
    double rsiAtLow = ctx.GetRSI(lowestIndex);
    double rsiAtHigh = ctx.GetRSI(highestIndex);

    // Bullish Divergence: Price lower low, RSI higher low
    if(ctx.sd.priceData[1].low > lowestPrice && rsiNow > rsiAtLow)
        bullishDiv = true;

    // Bearish Divergence: Price higher high, RSI lower high
    if(ctx.sd.priceData[1].high < highestPrice && rsiNow < rsiAtHigh)
        bearishDiv = true;
}
// candle------------------------------------------------------------
bool IsBullishEngulfing(SymbolContext *ctx) {
   return (ctx.sd.priceData[2].close < ctx.sd.priceData[2].open &&               // Previous candle bearish
           ctx.sd.priceData[1].close > ctx.sd.priceData[1].open &&               // Current candle bullish
           ctx.sd.priceData[1].open < ctx.sd.priceData[2].close &&               // Current open below prev close
           ctx.sd.priceData[1].close > ctx.sd.priceData[2].open);                // Current close above prev open
}
bool IsBearishEngulfing(SymbolContext *ctx) {
   return (ctx.sd.priceData[2].close > ctx.sd.priceData[2].open &&               // Previous candle bullish
           ctx.sd.priceData[1].close < ctx.sd.priceData[1].open &&               // Current candle bearish
           ctx.sd.priceData[1].open > ctx.sd.priceData[2].close &&               // Current open above prev close
           ctx.sd.priceData[1].close < ctx.sd.priceData[2].open);                // Current close below prev open
}
string IsPinbar(SymbolContext *ctx,double wickRatio = 2.0) {
   double body = MathAbs(ctx.sd.priceData[1].close - ctx.sd.priceData[1].open);
   double upperWick = ctx.sd.priceData[1].high - MathMax(ctx.sd.priceData[1].close, ctx.sd.priceData[1].open);
   double lowerWick = MathMin(ctx.sd.priceData[1].close, ctx.sd.priceData[1].open) - ctx.sd.priceData[1].low;

   if (upperWick > wickRatio * body && lowerWick < 0.3 * body)
      return "BearishPinbar";  // Long upper wick
   else if (lowerWick > wickRatio * body && upperWick < 0.3 * body)
      return "BullishPinbar";  // Long lower wick
   return "";
}