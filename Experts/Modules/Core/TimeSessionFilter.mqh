//+------------------------------------------------------------------+
//|              TradeSessionFilter.mqh                             |
//|   Filters trade entries based on hour and day                   |
//+------------------------------------------------------------------+
#ifndef __TRADE_SESSION_FILTER_MQH__
#define __TRADE_SESSION_FILTER_MQH__

bool IsTradingHour(int hourStart = 10, int hourEnd = 18) {
   int hour = TimeHour(TimeCurrent());
   return (hour >= hourStart && hour <= hourEnd);
}

bool IsTradingDay() {
   ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)TimeDayOfWeek(TimeCurrent());
   return (dow >= MONDAY && dow <= FRIDAY);
}

bool AllowEntryNow(int hourStart = 10, int hourEnd = 18) {
   return IsTradingDay() && IsTradingHour(hourStart, hourEnd);
}

#endif // __TRADE_SESSION_FILTER_MQH__
