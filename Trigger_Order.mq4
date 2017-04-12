//+------------------------------------------------------------------+
//|                                                Trigger_Order.mq4 |
//|                           Copyright 2017, Palawan Software, Ltd. |
//|                             https://coconala.com/services/204383 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Palawan Software, Ltd."
#property link      "https://coconala.com/services/204383"
#property description "Author: Kotaro Hashimoto <hasimoto.kotaro@gmail.com>"
#property version   "1.00"
#property strict

//--- input parameters
input int Magic_Number = 170410;
input bool Weekend_Exit = True;
input int Base_Period_Friday_Hour_Shift = 1;

input int Monitor_Ticket_1 = 0;
input int Monitor_Ticket_2 = 0;
input double Action_Price = 0;

enum Order {
  NONE = -1,
  BUY = OP_BUY,
  SELL = OP_SELL,
  BUY_LIMIT = OP_BUYLIMIT,
  SELL_LIMIT = OP_SELLLIMIT,
  BUY_STOP = OP_BUYSTOP,
  SELL_STOP = OP_SELLSTOP
};

extern Order Order_1 = NONE;
input double Entry_Price_1 = 0.0;
input double Entry_Lot_1 = 0.0;
input double StopLoss_1 = 0.0;
input double TakeProfit_1 = 0.0;

extern Order Order_2 = NONE;
input double Entry_Price_2 = 0.0;
input double Entry_Lot_2 = 0.0;
input double StopLoss_2 = 0.0;
input double TakeProfit_2 = 0.0;

bool order1Activated;
bool order2Activated;

bool maskOperation = False;
string errMsg;

string thisSymbol;

double minSL;
double minLot;
double maxLot;
double lotStep;

const string order1ID = "Order 1";
const string order2ID = "Order 2";
const string orderSL1ID = "Order 1 SL";
const string orderSL2ID = "Order 2 SL";
const string orderTP1ID = "Order 1 TP";
const string orderTP2ID = "Order 2 TP";

const string actionPriceID = "Action Price";

const string monitorID1 = "Monitor Ticket1: ";
const string monitorID2 = "Monitor Ticket2: ";

const string closeID = "Closing Time";
const string closeLabelID = "Close Label";


#define  HR2400 86400       // 24 * 3600
int      TimeOfDay(datetime when){  return( when % HR2400          );         }
datetime DateOfDay(datetime when){  return( when - TimeOfDay(when) );         }
datetime Today(){                   return(DateOfDay( TimeCurrent() ));       }
datetime Tomorrow(int shift){       return(Today() + HR2400 * shift);         }

void drawHLine(string id, double pos, string label, color clr = clrYellow, int width = 2, int style = 0, bool selectable = True) {

  if(style < 0 || 4 < style) {
    style = 0;
  }
  if(width < 1) {
    width = 1;
  }

  ObjectCreate(id, OBJ_HLINE, 0, 0, pos);
  ObjectSet(id, OBJPROP_COLOR, clr);
  ObjectSet(id, OBJPROP_WIDTH, width);
  ObjectSet(id, OBJPROP_STYLE, style);
  ObjectSet(id, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  
  ObjectSetInteger(0, id, OBJPROP_SELECTABLE, selectable);
  ObjectSetText(id, label, 12, "Arial", clr);
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

  ObjectCreate(0, monitorID1, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, monitorID1, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(monitorID1, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, monitorID1, OBJPROP_SELECTABLE, false);
  ObjectSetText(monitorID1, monitorID1 + IntegerToString(Monitor_Ticket_1), 16, "Arial", clrYellow);
  ObjectSetInteger(0, monitorID1, OBJPROP_YDISTANCE, 20);

  ObjectCreate(0, monitorID2, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, monitorID2, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(monitorID2, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, monitorID2, OBJPROP_SELECTABLE, false);
  ObjectSetText(monitorID2, monitorID2 + IntegerToString(Monitor_Ticket_2), 16, "Arial", clrYellow);


  ObjectCreate(0, closeLabelID, OBJ_LABEL, 0, 0, 0);
  ObjectSetInteger(0, closeLabelID, OBJPROP_CORNER, CORNER_LEFT_UPPER);
  ObjectSet(closeLabelID, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
  ObjectSetInteger(0, closeLabelID, OBJPROP_SELECTABLE, false);

  string time = IntegerToString(23 - Base_Period_Friday_Hour_Shift) + ":" + IntegerToString(59);
  string tlbl = "Friday Close Time: " + time;
  ObjectSetText(closeLabelID, tlbl, 16, "Arial", clrAqua);
  ObjectSetInteger(0, closeLabelID, OBJPROP_YDISTANCE, 75);
}

string OrderToString(Order type) {

  switch(type) {
    case BUY:
      return " BUY ";
    case SELL:
      return " SELL ";
    case BUY_LIMIT:
      return " BUY LIMIT ";
    case BUY_STOP:
      return " BUY STOP ";
    case SELL_LIMIT:
      return " SELL LIMIT ";
    case SELL_STOP:
      return " SELL STOP ";     
  }
  
  return "";
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{  
  thisSymbol = Symbol();

  minSL = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
  minLot = MarketInfo(Symbol(), MODE_MINLOT);
  maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
  lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
  
  order1Activated = False;
  order2Activated = False;
  
  if(!validateParameters()) {
    maskOperation = True;
    Alert(errMsg);
    return -1;
  }
  else {
    maskOperation = False;
  }
  
  if(0.0 < Action_Price) {
    drawHLine(actionPriceID, Action_Price, actionPriceID, clrYellow, 1, 0, False);
  }
  if(Order_1 != NONE) {
    if(0.0 < Entry_Price_1) {
      drawHLine(order1ID, Entry_Price_1, order1ID + OrderToString(Order_1) + " Lot:" + DoubleToString(Entry_Lot_1, 2), clrLime, 1, 1, False);
    }
    if(0.0 < StopLoss_1) {
      drawHLine(orderSL1ID, StopLoss_1, orderSL1ID, clrMagenta, 1, 1, False);
    }
    if(0.0 < TakeProfit_1) {
      drawHLine(orderTP1ID, TakeProfit_1, orderTP1ID, clrMagenta, 1, 1, False);
    }
  }

  if(Order_2 != NONE) {
    if(0.0 < Entry_Price_2) {
      drawHLine(order2ID, Entry_Price_2, order2ID + OrderToString(Order_2) + " Lot:" + DoubleToString(Entry_Lot_2, 2), clrLime, 1, 1, False);
    }
    if(0.0 < StopLoss_2) {
      drawHLine(orderSL2ID, StopLoss_2, orderSL2ID, clrMagenta, 1, 1, False);
    }
    if(0.0 < TakeProfit_2) {
      drawHLine(orderTP2ID, TakeProfit_2, orderTP2ID, clrMagenta, 1, 1, False);
    }
  }

  drawLabel();
  
  //---
  return(INIT_SUCCEEDED);
}

void clearObject() {

  ObjectDelete(0, actionPriceID);

  ObjectDelete(0, order1ID);
  ObjectDelete(0, order2ID);
  ObjectDelete(0, orderSL1ID);
  ObjectDelete(0, orderSL2ID);
  ObjectDelete(0, orderTP1ID);
  ObjectDelete(0, orderTP2ID);

  ObjectDelete(0, monitorID1);
  ObjectDelete(0, monitorID2);

  ObjectDelete(0, closeID);
  ObjectDelete(0, closeLabelID);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  clearObject();  
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

  if(0 < Monitor_Ticket_1) {
    if(!OrderSelect(Monitor_Ticket_1, SELECT_BY_TICKET)) {
      errMsg = "Monitor_Ticket_1(" + IntegerToString(Monitor_Ticket_1) + ") does not exist.";
      return False;
    } else if(OrderCloseTime() != 0) {
      errMsg = "Monitor_Ticket_1(" + IntegerToString(Monitor_Ticket_1) + ") already closed.";
      return False;      
    }
  }

  if(0 < Monitor_Ticket_2) {
    if(!OrderSelect(Monitor_Ticket_2, SELECT_BY_TICKET)) {
      errMsg = "Monitor_Ticket_2(" + IntegerToString(Monitor_Ticket_2) + ") does not exist.";
      return False;
    } else if(OrderCloseTime() != 0) {
      errMsg = "Monitor_Ticket_2(" + IntegerToString(Monitor_Ticket_2) + ") already closed.";
      return False;      
    }
  }

  if(Order_1 == BUY_LIMIT || Order_1 == BUY_STOP) {
    if(Entry_Price_1 <= 0.0) {
      errMsg = "Entry_Price_1(" + DoubleToString(Entry_Price_1, Digits) + ") is invalid.";
      return False;
    }
    else if(Entry_Price_1 - StopLoss_1 < minSL && 0.0 < StopLoss_1) {
      errMsg = "StopLoss_1(" + DoubleToString(StopLoss_1, Digits) + ") is too close or above Entry_Price_1(" + DoubleToString(Entry_Price_1, Digits) + ")";
      return False;
    }
    else if(TakeProfit_1 - Entry_Price_1 < minSL && 0.0 < TakeProfit_1) {
      errMsg = "TakeProfit_1(" + DoubleToString(TakeProfit_1, Digits) + ") is too close or below Entry_Price_1(" + DoubleToString(Entry_Price_1, Digits) + ")";
      return False;
    }
    else if(Entry_Lot_1 < minLot || maxLot < Entry_Lot_1) {
      errMsg = "Entry_Lot_1(" + DoubleToString(Entry_Lot_1, 2) + ") is too small or too large.";
      return False;
    }
  }
  else if(Order_1 == SELL_LIMIT || Order_1 == SELL_STOP) {
    if(Entry_Price_1 <= 0.0) {
      errMsg = "Entry_Price_1(" + DoubleToString(Entry_Price_1, Digits) + ") is invalid.";
      return False;
    }
    else if(StopLoss_1 - Entry_Price_1 < minSL && 0.0 < StopLoss_1) {
      errMsg = "StopLoss_1(" + DoubleToString(StopLoss_1, Digits) + ") is too close or below Entry_Price_1(" + DoubleToString(Entry_Price_1, Digits) + ")";
      return False;
    }
    else if(Entry_Price_1 - TakeProfit_1 < minSL && 0.0 < TakeProfit_1) {
      errMsg = "TakeProfit_1(" + DoubleToString(TakeProfit_1, Digits) + ") is too close or above Entry_Price_1(" + DoubleToString(Entry_Price_1, Digits) + ")";
      return False;
    }
    else if(Entry_Lot_1 < minLot || maxLot < Entry_Lot_1) {
      errMsg = "Entry_Lot_1(" + DoubleToString(Entry_Lot_1, 2) + ") is too small or too large.";
      return False;
    }
  }
  else if(Order_1 == BUY) {
    if(TakeProfit_1 - StopLoss_1 < 2.0 * minSL && 0.0 < StopLoss_1 && 0.0 < TakeProfit_1) {
      errMsg = "StopLoss_1(" + DoubleToString(StopLoss_1, Digits) + ") is too close or above TakeProfit_1(" + DoubleToString(TakeProfit_1, Digits) + ")";
      return False;
    }  
    else if(Entry_Lot_1 < minLot || maxLot < Entry_Lot_1) {
      errMsg = "Entry_Lot_1(" + DoubleToString(Entry_Lot_1, 2) + ") is too small or too large.";
      return False;
    }
  }
  else if(Order_1 == SELL) {
    if(StopLoss_1 - TakeProfit_1 < 2.0 * minSL && 0.0 < StopLoss_1 && 0.0 < TakeProfit_1) {
      errMsg = "StopLoss_1(" + DoubleToString(StopLoss_1, Digits) + ") is too close or below TakeProfit_1(" + DoubleToString(TakeProfit_1, Digits) + ")";
      return False;
    }  
    else if(Entry_Lot_1 < minLot || maxLot < Entry_Lot_1) {
      errMsg = "Entry_Lot_1(" + DoubleToString(Entry_Lot_1, 2) + ") is too small or too large.";
      return False;
    }
  }

  if(Order_2 == BUY_LIMIT || Order_2 == BUY_STOP) {
    if(Entry_Price_2 <= 0.0) {
      errMsg = "Entry_Price_2(" + DoubleToString(Entry_Price_2, Digits) + ") is invalid.";
      return False;
    }
    else if(Entry_Price_2 - StopLoss_2 < minSL && 0.0 < StopLoss_2) {
      errMsg = "StopLoss_2(" + DoubleToString(StopLoss_2, Digits) + ") is too close or above Entry_Price_1(" + DoubleToString(Entry_Price_2, Digits) + ")";
      return False;
    }
    else if(TakeProfit_2 - Entry_Price_2 < minSL && 0.0 < TakeProfit_2) {
      errMsg = "TakeProfit_2(" + DoubleToString(TakeProfit_2, Digits) + ") is too close or below Entry_Price_2(" + DoubleToString(Entry_Price_2, Digits) + ")";
      return False;
    }
    else if(Entry_Lot_2 < minLot || maxLot < Entry_Lot_2) {
      errMsg = "Entry_Lot_2(" + DoubleToString(Entry_Lot_2, 2) + ") is too small or too large.";
      return False;
    }
  }
  else if(Order_2 == SELL_LIMIT || Order_2 == SELL_STOP) {
    if(Entry_Price_2 <= 0.0) {
      errMsg = "Entry_Price_2(" + DoubleToString(Entry_Price_2, Digits) + ") is invalid.";
      return False;
    }
    else if(StopLoss_2 - Entry_Price_2 < minSL && 0.0 < StopLoss_2) {
      errMsg = "StopLoss_2(" + DoubleToString(StopLoss_2, Digits) + ") is too close or below Entry_Price_2(" + DoubleToString(Entry_Price_2, Digits) + ")";
      return False;
    }
    else if(Entry_Price_2 - TakeProfit_2 < minSL && 0.0 < TakeProfit_2) {
      errMsg = "TakeProfit_2(" + DoubleToString(TakeProfit_2, Digits) + ") is too close or above Entry_Price_2(" + DoubleToString(Entry_Price_2, Digits) + ")";
      return False;
    }
    else if(Entry_Lot_2 < minLot || maxLot < Entry_Lot_2) {
      errMsg = "Entry_Lot_2(" + DoubleToString(Entry_Lot_2, 2) + ") is too small or too large.";
      return False;
    }
  }
  else if(Order_2 == BUY) {
    if(TakeProfit_2 - StopLoss_2 < 2.0 * minSL && 0.0 < StopLoss_2 && 0.0 < TakeProfit_2) {
      errMsg = "StopLoss_2(" + DoubleToString(StopLoss_2, Digits) + ") is too close or above TakeProfit_2(" + DoubleToString(TakeProfit_2, Digits) + ")";
      return False;
    }  
    else if(Entry_Lot_2 < minLot || maxLot < Entry_Lot_2) {
      errMsg = "Entry_Lot_2(" + DoubleToString(Entry_Lot_2, 2) + ") is too small or too large.";
      return False;
    }
  }
  else if(Order_2 == SELL) {
    if(StopLoss_2 - TakeProfit_2 < 2.0 * minSL && 0.0 < StopLoss_2 && 0.0 < TakeProfit_2) {
      errMsg = "StopLoss_2(" + DoubleToString(StopLoss_2, Digits) + ") is too close or below TakeProfit_2(" + DoubleToString(TakeProfit_2, Digits) + ")";
      return False;
    }  
    else if(Entry_Lot_2 < minLot || maxLot < Entry_Lot_2) {
      errMsg = "Entry_Lot_2(" + DoubleToString(Entry_Lot_2, 2) + ") is too small or too large.";
      return False;
    }
  }

  return True;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  if(maskOperation) {
//    Print(errMsg);
    return;
  }

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
  
  if(Order_1 != NONE && Action_Price == 0) {
    order1Activated = True;
  }
  else if(Order_1 == BUY || Order_1 == BUY_LIMIT || Order_1 == BUY_STOP) {
    if(Action_Price < Ask && !order1Activated) {
      order1Activated = True;
    }
  }
  else if(Order_1 == SELL || Order_1 == SELL_LIMIT || Order_1 == SELL_STOP) {
    if(Bid < Action_Price && !order1Activated) {
      order1Activated = True;
    }
  }

  if(Order_2 != NONE && Action_Price == 0) {
    order2Activated = True;
  }
  else if(Order_2 == BUY || Order_2 == BUY_LIMIT || Order_2 == BUY_STOP) {
    if(Action_Price < Ask && !order2Activated) {
      order2Activated = True;
    }
  }
  else if(Order_2 == SELL || Order_2 == SELL_LIMIT || Order_2 == SELL_STOP) {
    if(Bid < Action_Price && !order2Activated) {
      order2Activated = True;
    }
  }

  if(0 < Monitor_Ticket_1) {
    if(OrderSelect(Monitor_Ticket_1, SELECT_BY_TICKET)) {
      if(OrderCloseTime() == 0) {
        return;
      }
    }
  }
  if(0 < Monitor_Ticket_2) {
    if(OrderSelect(Monitor_Ticket_2, SELECT_BY_TICKET)) {
      if(OrderCloseTime() == 0) {
        return;
      }
    }
  }
  if(order1Activated) {
    int ticket = OrderSend(thisSymbol, Order_1, Entry_Lot_1, NormalizeDouble(Entry_Price_1, Digits), 3, NormalizeDouble(StopLoss_1, Digits), NormalizeDouble(TakeProfit_1, Digits), NULL, Magic_Number);
    if(0 < ticket) {
      Order_1 = NONE;
      order1Activated = False;
      ObjectDelete(0, order1ID);
      ObjectDelete(0, orderSL1ID);
      ObjectDelete(0, orderTP1ID);
    }
  }
  
  if(order2Activated) {
    int ticket = OrderSend(thisSymbol, Order_2, Entry_Lot_2, NormalizeDouble(Entry_Price_2, Digits), 3, NormalizeDouble(StopLoss_2, Digits), NormalizeDouble(TakeProfit_2, Digits), NULL, Magic_Number);
    if(0 < ticket) {
      Order_2 = NONE;
      order2Activated = False;
      ObjectDelete(0, order2ID);
      ObjectDelete(0, orderSL2ID);
      ObjectDelete(0, orderTP2ID);
    }
  }
}

