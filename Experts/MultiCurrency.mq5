//+------------------------------------------------------------------+
//|                                  MultiCurrencyBBMeanReversal.mq5 |
//|                                  Copyright 2021, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include <Trade\Trade.mqh>
#include "Modules/MeanFunction.mqh";

//Create a Create instance
CTrade trade;

input double riskPerTrade = 0.02;
input int stopLossInPips = 10;
input int takeProfitInPips = 30;
long magic = 55555;
input int bbPeriod = 50;

input int bandStdEntry = 2;
input int bandStdProfitExit = 1;
input int bandStdLossExit = 6;

int rsiPeriod =14;
input int rsiLowerLevel = 40;
input int rsiUpperLevel = 60;
input int adxTradeValue = 25;

int watingCandleForTrade = 1;
//ranging curriency
//"EURGBP.PRO","GBPCHF.PRO","EURCHF.PRO","AUDNZD.PRO","EURNOK.PRO","EURSEK.PRO","NOKSEK.PRO","EURPLN.PRO"
string currencyList[28]={
    "AUDCAD.PRO","AUDCHF.PRO","AUDJPY.PRO","AUDNZD.PRO","AUDUSD.PRO","CADCHF.PRO","CADJPY.PRO",
   "USDJPY.PRO","CHFJPY.PRO","EURAUD.PRO","EURCAD.PRO","EURCHF.PRO","EURGBP.PRO","USDCHF.PRO",
   "EURJPY.PRO","EURNZD.PRO","EURUSD.PRO","GBPAUD.PRO","GBPCAD.PRO","GBPCHF.PRO","GBPJPY.PRO",
   "GBPNZD.PRO","GBPUSD.PRO","NZDCAD.PRO","NZDCHF.PRO","NZDJPY.PRO","NZDUSD.PRO","USDCAD.PRO"
   
   };
/*string currencyList[6]={
   "EURAUD.PRO"
   ,"GBPCHF.PRO"
   ,"EURJPY.PRO"
   ,"EURGBP.PRO"
   ,"NZDCHF.PRO"
   ,"EURNZD.PRO"
};*/
struct Decision
   {
      string            currencyPair;           // currency pair     
      double            lowerEntryBBBuffer[];
      double            upperEntryBBBuffer[];
      double            lowerProfitExitBBBuffer[];
      double            upperProfitExitBBBuffer[];
      double            lowerLossExitBBBuffer[];
      double            upperLossExitBBBuffer[];
      double            rsiBuffer[];
      double            adxBuffer[];
      MqlRates          priceInfo[];
      string            bandCrossSignal;        // crossOver signal SELL,BUY,NOTREAD
      int               candleBar;
   };
Decision CurrencyDecision[28];
//Decision CurrencyDecision[6];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //set magic number for trade
   trade.SetExpertMagicNumber(magic);
   
   //fill decision sturcture
   for(int i=ArraySize(currencyList)-1;i>=0; i--){
      CurrencyDecision[i].currencyPair=currencyList[i];
      CurrencyDecision[i].bandCrossSignal="NOTREAD";
      CurrencyDecision[i].candleBar = Bars(CurrencyDecision[i].currencyPair,Period());
   }
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
      //loop through currency list
      for(int i=ArraySize(currencyList)-1;i>=0; i--){
         getBBand(CurrencyDecision[i].lowerEntryBBBuffer,bandStdEntry,LOWER_BAND,currencyList[i]);
         getBBand(CurrencyDecision[i].upperEntryBBBuffer,bandStdEntry,UPPER_BAND,currencyList[i]);
         getBBand(CurrencyDecision[i].lowerProfitExitBBBuffer,bandStdProfitExit,LOWER_BAND,currencyList[i]);
         getBBand(CurrencyDecision[i].upperProfitExitBBBuffer,bandStdProfitExit,UPPER_BAND,currencyList[i]);
         getBBand(CurrencyDecision[i].lowerLossExitBBBuffer,bandStdLossExit,LOWER_BAND,currencyList[i]);
         getBBand(CurrencyDecision[i].upperLossExitBBBuffer,bandStdLossExit,UPPER_BAND,currencyList[i]);
         
         getRsi(CurrencyDecision[i].rsiBuffer,currencyList[i]);
         getAdx(CurrencyDecision[i].adxBuffer,currencyList[i]);
         
         //modify position
         modifyPosition(currencyList[i]);
         
         //check for new candle bar
         int currentBar = Bars(CurrencyDecision[i].currencyPair,Period());
         //dont do any things if not a new bar
         if(CurrencyDecision[i].candleBar==currentBar) {return;}
         
         if(CurrencyDecision[i].candleBar<currentBar){//new bare is appared update candlebar
            CurrencyDecision[i].candleBar=currentBar;
            //Print("New bar APPared");
         }
         //for loading price
         ArraySetAsSeries(CurrencyDecision[i].priceInfo,true);
         CopyRates(currencyList[i],Period(),0,5,CurrencyDecision[i].priceInfo);
         
         MqlDateTime mydate;
         TimeGMT(mydate);
         
         string info;
         CurrencyDecision[i].bandCrossSignal=getBandCrossSignalConfirmation(currencyList[i]);
         Print(currencyList[i],CurrencyDecision[i].bandCrossSignal);
         if(
               CurrencyDecision[i].bandCrossSignal=="BUY"
               &&!CheckSymbolPositionOpenOrNot(magic,CurrencyDecision[i].currencyPair)
            ){
               //double entryPrice = CurrencyDecision[i].priceInfo[1].close;
               double Ask = NormalizeDouble(SymbolInfoDouble(currencyList[i],SYMBOL_ASK),_Digits);
               double entryPrice = Ask;
               double stopLoss = CurrencyDecision[i].lowerLossExitBBBuffer[1];
               //double stopLoss = CurrencyDecision[i].priceInfo[1].low - (stopLossInPips*GetPipValue());
               double takeProfit = CurrencyDecision[i].upperProfitExitBBBuffer[1];
               double lotSize = OptimalLotSize(riskPerTrade,entryPrice,stopLoss); 
               datetime expiration = (iTime(CurrencyDecision[i].currencyPair,Period(),0)+watingCandleForTrade*PeriodSeconds()-1);
               
               /*trade.BuyStop(
                  lotSize, //how much or lotsize
                  entryPrice,//Ask,  //buy price
                  CurrencyDecision[i].currencyPair, //current symbol  
                  stopLoss, // Stop Loss
                  takeProfit, //takeprofit
                  ORDER_TIME_SPECIFIED,//order lifetime
                  expiration,//order expiration time
                  NULL //comment
               );*/
               trade.Buy(
                     lotSize, //how much or lotsize
                     CurrencyDecision[i].currencyPair, //current symbol
                     entryPrice,  //buy price 
                     stopLoss, // Stop Loss 
                     takeProfit,//take profit
                     NULL //comment
                  );
                     
         }
         
         if(
               CurrencyDecision[i].bandCrossSignal=="SELL"
               &&!CheckSymbolPositionOpenOrNot(magic,CurrencyDecision[i].currencyPair)
            ){
               //double entryPrice = CurrencyDecision[i].priceInfo[1].close;
               double Bid = NormalizeDouble(SymbolInfoDouble(currencyList[i],SYMBOL_BID),_Digits);
               double entryPrice=Bid;
               double stopLoss = CurrencyDecision[i].upperLossExitBBBuffer[1];
               //double stopLoss = CurrencyDecision[i].priceInfo[1].high + (stopLossInPips*GetPipValue());
               double takeProfit = CurrencyDecision[i].lowerProfitExitBBBuffer[1];
               double lotSize = OptimalLotSize(riskPerTrade,entryPrice,stopLoss); 
               datetime expiration = (iTime(CurrencyDecision[i].currencyPair,Period(),0)+watingCandleForTrade*PeriodSeconds()-1);
               
               /*trade.SellStop(
                  lotSize, //how much or lotsize
                  entryPrice,//Ask,  //buy price
                  CurrencyDecision[i].currencyPair, //current symbol  
                  stopLoss, // Stop Loss
                  takeProfit, //takeprofit
                  ORDER_TIME_SPECIFIED,//order lifetime
                  expiration,//order expiration time
                  NULL //comment
               );*/
               trade.Sell(
                     lotSize, //how much or lotsize
                     CurrencyDecision[i].currencyPair, //current symbol
                     entryPrice,  //buy price 
                     stopLoss, // Stop Loss 
                     takeProfit,//take profit
                     NULL //comment
                  );
               
            
         }
      
      }//for loop end
   
  }
//+------------------------------------------------------------------+

string getBandCrossSignalConfirmation(string currencyPair="EURUSD"){
   // Get the Ask price
   double Ask = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
      
   // Get the Bid price
   double Bid = NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   
   double lowerEntryBBBuffer[], upperEntryBBBuffer[], rsiBuffer[],adxBuffer[];
   getBBand(lowerEntryBBBuffer,bandStdEntry,LOWER_BAND,currencyPair);
   getBBand(upperEntryBBBuffer,bandStdEntry,UPPER_BAND,currencyPair);
   getRsi(rsiBuffer,currencyPair);
   getAdx(adxBuffer,currencyPair);
   
   //for loading price
   MqlRates          priceInfoLocal[];
   ArraySetAsSeries(priceInfoLocal,true);
   CopyRates(currencyPair,Period(),0,5,priceInfoLocal);
   
   if( //Check for buy signal
         //(priceInfoLocal[2].open>lowerEntryBBBuffer[2])//open above lower entry band
         //&&(priceInfoLocal[2].close<lowerEntryBBBuffer[2])//close below lower entry band
         //&&
         (priceInfoLocal[1].open<lowerEntryBBBuffer[1])//open below lower entry band
         &&(priceInfoLocal[1].close>lowerEntryBBBuffer[1])//close above lower entry band
         && (rsiBuffer[1]<rsiLowerLevel)
         && (NormalizeDouble(adxBuffer[1],2)>adxTradeValue)
      )
      {  return("BUY");   }
      else if( //Check for sell signal
         //(priceInfoLocal[2].open<upperEntryBBBuffer[2])//open below upper entry band
         //&&(priceInfoLocal[2].close>upperEntryBBBuffer[2])//close above upper entry band
         //&&
         (priceInfoLocal[1].open>upperEntryBBBuffer[1])//open above upper entry band
         &&(priceInfoLocal[1].close<upperEntryBBBuffer[1])//close below upper entry band
         && (rsiBuffer[1]>rsiUpperLevel)
         && (NormalizeDouble(adxBuffer[1],2)>adxTradeValue)//to determine range of market
      ){ return("SELL");}
      else{
         return("NOTREAD");
      }
}

void getBBand(double& BBArray[],int bandStd,int bandLocation = UPPER_BAND,string currencyPair="EURUSD"){
   //int handle = iMA(currencyPair,_Period,maPeriod,0,MODE_SMA,PRICE_CLOSE);
   int handle = iBands(currencyPair,_Period,bbPeriod,0,bandStd,PRICE_CLOSE);
   //int handle = iMA(_Symbol,_Period,fastMA,0,MODE_SMA,PRICE_CLOSE);
   ArraySetAsSeries(BBArray,true);
   //CopyBuffer(handle,UPPER_BAND,0,3,BBArray);
   if(!CopyBuffer(handle,bandLocation,0,3,BBArray)){
         Print("Problem loading BBand data");
         return;
    }
}
void getRsi(double& RsiArray[],string currencyPair="EURUSD"){
   //int handle = iMA(currencyPair,_Period,maPeriod,0,MODE_SMA,PRICE_CLOSE);
   //int handle = iBands(currencyPair,_Period,bbPeriod,0,bandStd,PRICE_CLOSE);
   int handle=iRSI(currencyPair,0,rsiPeriod,PRICE_CLOSE);
   //int handle = iMA(_Symbol,_Period,fastMA,0,MODE_SMA,PRICE_CLOSE);
   ArraySetAsSeries(RsiArray,true);
   if(!CopyBuffer(handle,0,0,5,RsiArray)){
         Print("Problem loading Rsi data");
         return;
    }
}

void getAdx(double& AdxArray[],string currencyPair="EURUSD"){
   int handle=iADX(currencyPair,_Period,14);
   
   ArraySetAsSeries(AdxArray,true);
   //handle.oneline,current candle,3candles ,store result
   if(!CopyBuffer(handle,0,0,5,AdxArray)){
         Print("Problem loading adx data");
         return;
    }
}

int CheckTotalPosition(int MagicNr,string symbol)

{
   int totalOrdersStop = 0;

   for(int i=0; i<PositionsTotal(); i++)
   {
      string OrderSymbol = PositionGetSymbol(i);
      //OrderSymbol.PositionGetInteger(POSITION_MAGIC);
      int Magic = PositionGetInteger(POSITION_MAGIC);
      
      //Alert(" Position MagicNumber",Magic);
      
      PositionSelect(PositionGetTicket(i));
      if(OrderSymbol == symbol)
      if(Magic == MagicNr )
      {
        ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        if(
        type==POSITION_TYPE_BUY 
        || type==POSITION_TYPE_SELL
        ){
        totalOrdersStop ++;
        }
      }
   }
   return(totalOrdersStop);
}
bool CheckSymbolPositionOpenOrNot(int MagicNr,string symbol)

{
   bool result=false;
   for(int i=0; i<PositionsTotal(); i++)
   {
      string OrderSymbol = PositionGetSymbol(i);
      if(OrderSymbol == symbol)
      {
         result=true;
        return(result);
      }
   }
   return(result);
}

void modifyPosition(string currencyPair){
   double lowerProfitExitBBBuffer[], upperProfitExitBBBuffer[],lowerLossExitBBBuffer[],upperLossExitBBBuffer[];
   getBBand(lowerProfitExitBBBuffer,bandStdProfitExit,LOWER_BAND,currencyPair);
   getBBand(upperProfitExitBBBuffer,bandStdProfitExit,UPPER_BAND,currencyPair);
   getBBand(lowerLossExitBBBuffer,bandStdLossExit,LOWER_BAND,currencyPair);
   getBBand(upperLossExitBBBuffer,bandStdLossExit,UPPER_BAND,currencyPair);
   //modifing existing order
      if(PositionsTotal()>0){
         for (int i = PositionsTotal() - 1; i >=0; i-- ) {
            ulong position_ticket =  PositionGetTicket(i);
            if (PositionSelectByTicket(position_ticket) ) {
               int positionType = PositionGetInteger(POSITION_TYPE);
               double optimalTakeProfit;
               double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double positionStopLoss = PositionGetDouble(POSITION_SL);
               double positionTakeProfit = PositionGetDouble(POSITION_TP);
               string positionSymbol = PositionGetString(POSITION_SYMBOL);
               if(positionType==0){//buy
                  optimalTakeProfit = NormalizeDouble(upperProfitExitBBBuffer[0],_Digits);
                  //positionStopLoss = NormalizeDouble(lowerLossExitBBBuffer[0],_Digits);
               }
               else{//sell
                  optimalTakeProfit = NormalizeDouble(lowerProfitExitBBBuffer[0],_Digits);
                  //positionStopLoss = NormalizeDouble(upperLossExitBBBuffer[0],_Digits);
               }
               
               //Print("positionTakeProfit",positionTakeProfit);
               //Print("optimalTakeProfit",optimalTakeProfit);
               double tPDistance = NormalizeDouble(MathAbs(positionTakeProfit-optimalTakeProfit),_Digits)/GetPipValue();
               //Print(tPDistance);
               double diffBtntakeProfitAndEntryPrice=NormalizeDouble(MathAbs(entryPrice-optimalTakeProfit),_Digits)/GetPipValue();
               if(
                  positionTakeProfit!=optimalTakeProfit 
                  && tPDistance>=5
                  && positionSymbol == currencyPair
                  && diffBtntakeProfitAndEntryPrice>=20
               ){
                  trade.PositionModify(position_ticket,positionStopLoss ,optimalTakeProfit);
                  //Print("trade Modified");
               }
            
           } // position select
            
         }//loop
      }

}
