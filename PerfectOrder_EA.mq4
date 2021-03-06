//+------------------------------------------------------------------+
//|                                              PerfectOrder_EA.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

//--- input parameters
input int Magic_Number = 201707;

input bool Flat_Lot = False;
input double Flat_Lot_Rate = 0.01;

input bool MM_Lot = True;
input double MM_Rate = 100000;
// entry lot = AccountEquity() / MM_Rate * 0.01

input bool HighWaterMark = True;
extern double Start_Funds = 1000000;
input double Pool_Percent_Ratio = 50;

input ENUM_MA_METHOD MA_Type = MODE_SMA;
input int Long_EMA_Period = 200;
input int Mid_EMA_Period = 62;
input int Short_EMA_Period = 20;

input bool Slope_Check = True;
input bool Perfect_Soon_Entry = False;
input bool Tick_Decided_Entry = false;

input int Exit_Tick_Number = 3;
input bool Exit_Loss_Hold = True;

input double TP_Pips = 0;
input double SL_Pips = 50;
input double Safe_SL_Pips = 20;
input bool Trailing_Stop = True;
input double Trailing_Stop_Pips = 40;

input int Base_Period_Friday_Hour_Shift = 1;
input int Saturday_Exit = False;
input int JST_OffSet = 6;

input bool Succession = True;
input int Succession_Times = 3;

string thisSymbol;

double poolFunds;
double entryFunds;

double lastMaxEquity;

double tp;
double sl;

double ssl;
double tsl;

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

  int offset = Tick_Decided_Entry ? 1 : 0;

  double lma_0 = iMA(Symbol(), PERIOD_CURRENT, Long_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset);
  double lma_1 = iMA(Symbol(), PERIOD_CURRENT, Long_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset + 1);

  double mma_0 = iMA(Symbol(), PERIOD_CURRENT, Mid_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset);
  double mma_1 = iMA(Symbol(), PERIOD_CURRENT, Mid_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset + 1);

  double sma_0 = iMA(Symbol(), PERIOD_CURRENT, Short_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset);
  double sma_1 = iMA(Symbol(), PERIOD_CURRENT, Short_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset + 1);

  if(lma_0 > mma_0 && mma_0 > sma_0 && ((lma_0 < lma_1 && mma_0 < mma_1 && sma_0 < sma_1 && Slope_Check) || !Slope_Check)) {
    if(!Perfect_Soon_Entry) {    
      double sma = iMA(Symbol(), PERIOD_CURRENT, Short_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset + 1);
      if(!(iLow(Symbol(), PERIOD_CURRENT, offset + 1) < sma && sma < iHigh(Symbol(), PERIOD_CURRENT, offset + 1))) {
        sma = iMA(Symbol(), PERIOD_CURRENT, Short_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset);
        if(iHigh(Symbol(), PERIOD_CURRENT, offset) < sma) {
          return OP_SELL;
        }
      }
    }
    else {
      return OP_SELL;
    }
  }  
  else if(lma_0 < mma_0 && mma_0 < sma_0 && ((lma_0 > lma_1 && mma_0 > mma_1 && sma_0 > sma_1 && Slope_Check) || !Slope_Check)) {
    if(!Perfect_Soon_Entry) {    
      double sma = iMA(Symbol(), PERIOD_CURRENT, Short_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset + 1);
      if(!(iLow(Symbol(), PERIOD_CURRENT, offset + 1) < sma && sma < iHigh(Symbol(), PERIOD_CURRENT, offset + 1))) {
        sma = iMA(Symbol(), PERIOD_CURRENT, Short_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, offset);
        if(sma < iLow(Symbol(), PERIOD_CURRENT, offset)) {
          return OP_BUY;
        }
      }
    }
    else {
      return OP_BUY;
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

  tp = TP_Pips * Point * 10.0;
  sl = SL_Pips * Point * 10.0;
  
  ssl = Safe_SL_Pips * Point * 10.0;
  tsl = Trailing_Stop_Pips * Point * 10.0;
  
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

void closeAll(bool pendingOnly = False) {

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(OrderType() == OP_BUY && !pendingOnly) {
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(thisSymbol, MODE_BID), Digits), 0)) {
            Print("Error on closing long order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELL && !pendingOnly) {
          if(!OrderClose(OrderTicket(), OrderLots(), NormalizeDouble(MarketInfo(thisSymbol, MODE_ASK), Digits), 3)) {
            Print("Error on closing short order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_BUYSTOP) {
          if(!OrderDelete(OrderTicket())) {
            Print("Error on deleting buy stop order: ", GetLastError());
          }
          else {
            i = -1;
          }
        }
        else if(OrderType() == OP_SELLSTOP) {
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
  
  return;
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

double sltp(double price, double delta) {

  if(delta == 0.0) {
    return 0.0;
  }
  else {
    return NormalizeDouble(price + delta, Digits);
  }
}

bool scanHistory() {

  double p0 = 0;
  double p1 = 0;
  double p2 = 0;

  int total = OrdersHistoryTotal();
  for(int i = total - 1; 0 <= i; i--) {
    if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
        if(p0 == 0) {
          p0 = OrderProfit();
        }
        else if(p1 == 0) {
          p1 = OrderProfit();
        }
        else if(p2 == 0) {
          p2 = OrderProfit();
        }
        else {
          break;
        }
      }
    }
  }        
   
  return 0 < p0 && 0 < p1 && 0 < p2;   
}


int trail(double& profit) {

  int overLapCount;
  profit = 0.0;
  
  for(overLapCount = 0; overLapCount < Exit_Tick_Number; overLapCount++) {
    double sma = iMA(Symbol(), PERIOD_CURRENT, Short_EMA_Period, 0, MA_Type, PRICE_WEIGHTED, overLapCount + 1);
    if(!(iLow(Symbol(), PERIOD_CURRENT, overLapCount + 1) < sma && sma < iHigh(Symbol(), PERIOD_CURRENT, overLapCount + 1))) {
      break;
    }
  }  

  for(int i = 0; i < OrdersTotal(); i++) {
    if(OrderSelect(i, SELECT_BY_POS)) {
      if(!StringCompare(OrderSymbol(), thisSymbol) && OrderMagicNumber() == Magic_Number) {
      
        profit += OrderProfit();
      
        if(OrderType() == OP_BUY) {
          double sslp = OrderOpenPrice() + ssl / 4.0;          
          if((OrderStopLoss() == 0 || OrderStopLoss() < sslp) && OrderOpenPrice() + ssl < Bid) {
            bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(sslp, Digits), OrderTakeProfit(), 0);
          }
          
          double tslp = OrderOpenPrice() + tsl;
          if((OrderStopLoss() == 0 || OrderStopLoss() < tslp) && OrderOpenPrice() + 2.0 * tsl < Bid && Trailing_Stop) {
            bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(tslp, Digits), OrderTakeProfit(), 0);
          }
        }
        
        if(OrderType() == OP_SELL) {
          double sslp = OrderOpenPrice() - ssl / 4.0;          
          if((OrderStopLoss() == 0 || sslp < OrderStopLoss()) && Ask < OrderOpenPrice() - ssl) {
            bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(sslp, Digits), OrderTakeProfit(), 0);
          }
          
          double tslp = OrderOpenPrice() - tsl;
          if((OrderStopLoss() == 0 || tslp < OrderStopLoss()) && Ask < OrderOpenPrice() - 2.0 * tsl && Trailing_Stop) {
            bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), NormalizeDouble(tslp, Digits), OrderTakeProfit(), 0);
          }
        }
      }
    }
  }  
  
  return overLapCount;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

  if(DayOfWeek() == 5 && Saturday_Exit) {
  
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

  double profit;
  int overLap = trail(profit);
  if(((Exit_Loss_Hold && 0 < profit) || !Exit_Loss_Hold) && overLap == Exit_Tick_Number) {
    closeAll();
  }
  
  if(0 < countOrders()) {
    hasPosition = True;
    return;
  }
  else if(hasPosition){
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
    int ticket = OrderSend(Symbol(), OP_BUY, calcLot(), NormalizeDouble(Ask, Digits), 3, sltp(Ask, -1.0 * sl), sltp(Ask, tp), NULL, Magic_Number);
    if(0 < ticket) {
      hasPosition = True;
    }
  }
  else if(signal == OP_SELL) {
    if(lastMaxEquity < AccountEquity()) {
      lastMaxEquity = AccountEquity();
    }
    int ticket = OrderSend(Symbol(), OP_SELL, calcLot(), NormalizeDouble(Bid, Digits), 3, sltp(Bid, sl), sltp(Bid, -1.0 * tp), NULL, Magic_Number);
    if(0 < ticket) {
      hasPosition = True;
    }
  }
}
