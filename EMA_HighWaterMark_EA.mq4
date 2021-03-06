//+------------------------------------------------------------------+
//|                                         EMA_HighWaterMark_EA.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

//--- input parameters
input int Magic_Number = 1;

input bool Flat_Lot = False;
input double Flat_Lot_Rate = 0.01;

input bool MM_Lot = True;
input double MM_Rate = 100000;
// entry lot = AccountEquity() / MM_Rate * 0.01

input bool HighWaterMark = True;
extern double Start_Funds = 1000000;
input double Pool_Percent_Ratio = 50;

input int EMA_Period = 52;
input int EMA_Slope_pips = 0;
input bool Reverse_Entry = False;
input int TP = 50;
input int SL = 50;

input int Base_Period_Friday_Hour_Shift = 1;
input int JST_OffSet = 6;


string thisSymbol;

double poolFunds;
double entryFunds;

double emaDiff;
double lastMaxEquity;

double tp;
double sl;

double minLot;
double maxLot;
double lotSize;
double lotStep;

bool hasPosition;

const string sFunds = "Start Funds";
const string pFunds = "Pool Funds";
const string eFunds = "Entry Funds";

const string closeID = "Closing Time";
const string closeLabelID = "Close Label";


#define  HR2400 86400       // 24 * 3600
int      TimeOfDay(datetime when){  return( when % HR2400          );         }
datetime DateOfDay(datetime when){  return( when - TimeOfDay(when) );         }
datetime Today(){                   return(DateOfDay( TimeCurrent() ));       }
datetime Tomorrow(int shift){       return(Today() + HR2400 * shift);         }


int getSignal() {

  double ema2 = iMA(Symbol(), PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_WEIGHTED, 2);
  double ema1 = iMA(Symbol(), PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_WEIGHTED, 1);
  double ema0 = iMA(Symbol(), PERIOD_CURRENT, EMA_Period, 0, MODE_EMA, PRICE_WEIGHTED, 0);

  if((Ask + Bid) / 2.0 < ema0) {
    if(emaDiff < ema2 - ema1 || emaDiff == 0.0) {
      if(!Reverse_Entry) {
        return OP_SELL;
      }
      else {
        return OP_BUY;
      }
    }
  }
  else {
    if(emaDiff < ema1 - ema2 || emaDiff == 0.0) {
      if(!Reverse_Entry) {
        return OP_BUY;
      }
      else {
        return OP_SELL;
      }
    }
  }

  return -1;
}

void drawVLine(string hour, string minute, color clr = clrAqua, int width = 1, int style = 1) {

  if(style < 0 || 4 < style) {
    style = 0;
  }
  if(width < 1) {
    width = 1;
  }

  datetime time = StrToTime(TimeToStr(5 - Tomorrow(DayOfWeek()), TIME_DATE) + " " + hour + ":" + minute);

  ObjectCreate(closeID, OBJ_VLINE, 0, time, 0);
  ObjectSet(closeID, OBJPROP_WIDTH, width);
  ObjectSet(closeID, OBJPROP_COLOR, clr);
  ObjectSet(closeID, OBJPROP_STYLE, style);
  ObjectSet(closeID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  
  ObjectSetInteger(0, closeID, OBJPROP_SELECTABLE, false);
  ObjectSetText(closeID, closeID, 12, "Arial", clr);
}

void drawLabel() {

  ObjectCreate(0, sFunds, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, sFunds, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(sFunds, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, sFunds, OBJPROP_SELECTABLE, false);

  string lbl = "Start Funds: " + DoubleToString(Start_Funds, 0);
  ObjectSetText(sFunds, lbl, 16, "Arial", clrYellow);
  ObjectSetInteger(0, sFunds, OBJPROP_YDISTANCE, 20);

  ObjectCreate(0, closeLabelID, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, closeLabelID, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(closeLabelID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, closeLabelID, OBJPROP_SELECTABLE, false);

  string time = IntegerToString((23 - Base_Period_Friday_Hour_Shift + JST_OffSet) % 24) + ":" + IntegerToString(59);
  string tlbl = "Saturday Close Time: " + time;
  ObjectSetText(closeLabelID, tlbl, 16, "Arial", clrAqua);
  ObjectSetInteger(0, closeLabelID, OBJPROP_YDISTANCE, 110);


  ObjectCreate(0, pFunds, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, pFunds, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(pFunds, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, pFunds, OBJPROP_SELECTABLE, false);

  string llbl = "Pool Funds: " + DoubleToStr(poolFunds, 0);
  ObjectSetText(pFunds, llbl, 16, "Arial", clrWhite);

  ObjectCreate(0, eFunds, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, eFunds, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(eFunds, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, eFunds, OBJPROP_SELECTABLE, false);

  string elbl = "Entry Funds: " + DoubleToStr(entryFunds, 0);
  ObjectSetText(eFunds, elbl, 16, "Arial", clrWhite);
  ObjectSetInteger(0, eFunds, OBJPROP_YDISTANCE, 80);
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
  
  thisSymbol = Symbol();

  tp = TP * Point * 10.0;
  sl = SL * Point * 10.0;
  
  hasPosition = False;

  if(Start_Funds <= 0.0) {
    Start_Funds = AccountEquity();
  }
  
  lastMaxEquity = AccountEquity();
  
  if(Start_Funds == AccountEquity()) {
    poolFunds = 0;
    entryFunds = Start_Funds;
  }
  else if(Start_Funds < AccountEquity()) {
    poolFunds = (AccountEquity() - Start_Funds) * Pool_Percent_Ratio / 100.0;
    if(Start_Funds < AccountEquity() - poolFunds) {
      entryFunds = AccountEquity() - poolFunds;
    }
    else {
      entryFunds = Start_Funds;
    }
  }
  else if (AccountEquity() < Start_Funds) {
    poolFunds = (AccountEquity() - Start_Funds) * Pool_Percent_Ratio / 100.0;
    if(Start_Funds < AccountEquity() - poolFunds) {
      entryFunds = AccountEquity() - poolFunds;
    }
    else {
      entryFunds = Start_Funds;
    }
  }
  
  emaDiff = EMA_Slope_pips * Point * 10.0;

  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  lotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
  
  drawLabel();
  //---
  return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  ObjectDelete(0, sFunds);
  ObjectDelete(0, pFunds);
  ObjectDelete(0, eFunds);
  ObjectDelete(0, closeID);
  ObjectDelete(0, closeLabelID);

  //---   
}

bool closeAll(bool pendingOnly = False) {

  int toClose = 0;
  int initialTotal = OrdersTotal();
  
  for(int i = 0; i < initialTotal; i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderType() == OP_BUY && !pendingOnly) {
          toClose ++;
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(thisSymbol, MODE_BID), Digits), 0)) {
            Print("Error on closing long order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELL && !pendingOnly) {
          toClose ++;
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(thisSymbol, MODE_ASK), Digits), 3)) {
            Print("Error on closing short order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_BUYSTOP) {
          toClose ++;
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting buy stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELLSTOP) {
          toClose ++;
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting sell stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
      }
    }
  }
  
  return (initialTotal - toClose == OrdersTotal());
}

bool validateParameters() {

  if(MM_Rate == 0.0) {
    Print("MM_Rate must be grater than zero.");
    return False;
  }

  return True;
}

double calcLot() {

  double lot = 0.0;

  if(Flat_Lot) {
    lot = Flat_Lot_Rate;
  }
  else if(MM_Lot) {
    lot = entryFunds / MM_Rate * lotStep;
  }
  
  lot = MathRound(lot / lotStep) * lotStep;
  
  if(maxLot < lot) {
    lot = maxLot;
    Print("Lot size(", lot, ") is larger than max(", maxLot, "). Rounded to ", maxLot, ".");
  }
  else if(lot < minLot) {
    lot = 0.0;
    Print("Lot size(", lot, ") is smaller than min(", minLot, "). Entry skipped.");
  }

  return lot;
}

int countOrders() {

  int c = 0;

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        c ++;
      }
    }
  }
  
  return c;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  if(DayOfWeek() == 5) {
  
    if(0.0 == ObjectGetTimeByValue(0, closeID, OBJPROP_TIME1)) {
      drawVLine(IntegerToString(23 - Base_Period_Friday_Hour_Shift), IntegerToString(59));
    }

    // close everything at Friday (24 - Base_Period_Friday_Hour_Shift) + 59
    if(1438 < 60 * (Hour() + Base_Period_Friday_Hour_Shift) + 59) {
      closeAll();
      return;
    }
  }
  
  if(!validateParameters()) {
    return;
  }
  
  else if(0 < countOrders()) {
    hasPosition = True;
    return;
  }
  else if (hasPosition){
    double diff = (AccountEquity() - lastMaxEquity) * Pool_Percent_Ratio / 100.0;
      
    if(!HighWaterMark) {
      entryFunds = AccountEquity();
    }
    
    else if(0.0 < diff && HighWaterMark) {
      poolFunds += diff;
      
      if(entryFunds < AccountEquity() - poolFunds) {
        entryFunds = AccountEquity() - poolFunds;
      }
    
      ObjectSetText(pFunds, "Pool Funds: " + DoubleToStr(poolFunds, 0), 16, "Arial", clrWhite);
      ObjectSetText(eFunds, "Entry Funds: " + DoubleToStr(entryFunds, 0), 16, "Arial", clrWhite);
    }
    hasPosition = False;
  }
  
  int signal = getSignal();
  
  if(signal == OP_BUY) {
    if(lastMaxEquity < AccountEquity()) {
      lastMaxEquity = AccountEquity();
    }
    int ticket = OrderSend(Symbol(), OP_BUY, calcLot(), NormalizeDouble(Ask, Digits), 3, NormalizeDouble(Ask - sl, Digits), NormalizeDouble(Ask + tp, Digits), NULL, Magic_Number);
    if(0 < ticket) {
      hasPosition = True;
    }
  }
  else if(signal == OP_SELL) {
    if(lastMaxEquity < AccountEquity()) {
      lastMaxEquity = AccountEquity();
    }
    int ticket = OrderSend(Symbol(), OP_SELL, calcLot(), NormalizeDouble(Bid, Digits), 3, NormalizeDouble(Bid + sl, Digits), NormalizeDouble(Bid - tp, Digits), NULL, Magic_Number);
    if(0 < ticket) {
      hasPosition = True;
    }
  }
}
